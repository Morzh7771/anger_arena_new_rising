-- Социальная косметика на сервере: колесо фраз, смайлики над героем, спреи на
-- земле и хай-файвы. Наборы и ассеты - в lib/cosmetics/social_catalog.lua
-- (глобальная SOCIAL_CATALOG), выбор игрока и премиум - в lib/cosmetics/core.lua.
--
-- Клиент (панорама, social_wheel.js и social_emotes.js) только шлёт намерение,
-- сервер всё проверяет сам: премиум, надетый набор, фраза/индекс, кулдаун, цель.
-- Ивенты через защиту (lib/events_protector.lua):
--   клиент -> сервер  aa_soc_request {}                     - запросить каталог
--                     aa_soc_wheel    {phrase_id}           - фраза колеса (id из пула)
--                     aa_soc_wheel_set {slot, phrase_id}    - фраза в слот колеса 1..8
--   нет-таблица aa_wheel[pid] = { ws1..ws8 } - слоты колеса; на бэкенд POST /api/cosmetics/wheel
--                     aa_soc_emote    {target, index}       - похвала: target = playerID цели
--   спрей и хай-файв - способности aa_cos_spray / aa_cos_high_five на юните-кастере
--   (lib/cosmetics/caster.lua), сюда приходят через DoSpray / DoHighFive
--   сервер -> клиент  aa_soc_catalog  {premium, wheel_*, wid1.., wp1.., pool_n,
--                                      pi1.., pt1.., emote_*, en1.., ei1..}
--                     aa_soc_sound    {sound}               - звук фразы колеса
--                     aa_soc_emote_show {hero, image}       - смайлик над героем
--                     aa_soc_tip      {caster, target, image, name} - тост похвалы
-- Данные ивентов плоские: вложенные таблицы в кастомных ивентах не ходят.
-- Отказы пишутся в консоль сервера с префиксом [Social].

if not IsServer() then return end

require('lib/cosmetics/social_catalog')

if CosmeticsSocial ~= nil then return end

CosmeticsSocial = {}

local S = CosmeticsSocial

-- владелец мода: без ядра косметики премиум только у него
local OWNER_ACCOUNT = 960329385

-- кулдауны, секунды
local COOLDOWN = {
	wheel = 5,        -- пауза после серии из WHEEL_BURST фраз (см. Use)
	emote = 30,       -- похвала: тост у всех, чаще спамит
	spray = 30,
	high_five = 5,
}

-- колесо: столько фраз подряд без кулдауна, потом пауза COOLDOWN.wheel
local WHEEL_BURST = 2
local SPRAY_DURATION = 20
local EMOTE_DURATION = 3
local HIGH_FIVE_DURATION = 10
local HIGH_FIVE_RANGE = 300
-- спрей ставят только рядом с героем, иначе его можно кинуть через всю карту
local SPRAY_MAX_DIST = 3000
-- минимальный промежуток между любыми запросами одного игрока (защита от спама)
local MIN_GAP = 0.25

S.cd = S.cd or {}          -- pid -> { [вид] = время, раньше которого нельзя }
S.last_req = S.last_req or {} -- pid -> время последнего запроса
S.sprays = S.sprays or {}  -- pid -> партикл спрея
S.wheel_burst = S.wheel_burst or {} -- pid -> { n = фраз в серии, t = время последней }
S.hf_pending = S.hf_pending or {} -- pid -> { hero, particle, set } поднятая рука

-- отладочный вывод: что пришло и почему отказано (видно в консоли сервера)
local function Dbg(pid, kind, text)
	print("[Social] pid " .. tostring(pid) .. " " .. kind .. ": " .. tostring(text))
end

-- ------------------------------------------------------------------ премиум и набор

local function AccountOf(pid)
	if pid == nil or pid < 0 or not PlayerResource:IsValidPlayerID(pid) then return 0 end

	return PlayerResource:GetSteamAccountID(pid) or 0
end

local function IsPremium(pid)
	-- ядро косметики есть: спрашиваем его (бэкенд + владелец)
	if CosmeticsCore ~= nil and type(CosmeticsCore.IsPremium) == "function" then
		return CosmeticsCore:IsPremium(pid) == true
	end

	-- ядра нет: премиум только у владельца
	return AccountOf(pid) == OWNER_ACCOUNT
end

-- Премиум ничего не открывает: фраза доступна, если она в инвентаре (сундук "Звуки", пасс, покупка),
-- граффити и "дай пять" - если надет свой предмет этого слота
local function OwnsPhrase(pid, id)
	return CosmeticsCore ~= nil and type(CosmeticsCore.Owns) == "function" and CosmeticsCore:Owns(pid, "phrase:" .. tostring(id)) == true
end

local function HasOwnItem(pid, slot)
	return CosmeticsCore ~= nil and type(CosmeticsCore.GetEquipped) == "function" and CosmeticsCore:GetEquipped(pid, slot) ~= nil
end

local function FindItem(slot, id)
	for _, it in ipairs(SOCIAL_CATALOG[slot] or {}) do
		if it.id == id then return it end
	end

	return nil
end

-- Надетый набор слота. Если ничего не надето или ядра нет - первый в каталоге.
local function Equipped(pid, slot)
	local list = SOCIAL_CATALOG[slot] or {}

	if #list == 0 then return nil end

	if CosmeticsCore ~= nil and type(CosmeticsCore.GetEquipped) == "function" then
		local item = CosmeticsCore:GetEquipped(pid, slot)
		local found = type(item) == "table" and FindItem(slot, item.id) or nil

		if found then return found end
	end

	return list[1]
end

-- Все фразы всех наборов колеса: игрок собирает свои 8 из них на панели настроек.
-- Каждой фразе дописываем набор (scope - кому слышно, cat - категория в списке настроек).
-- Пул строится один раз: каталог в матче не меняется.
local POOL = nil
local POOL_BY_ID = nil

local function WheelPool()
	if POOL then return POOL end

	POOL = {}
	POOL_BY_ID = {}

	for _, set in ipairs(SOCIAL_CATALOG.wheel or {}) do
		for _, ph in ipairs(set.phrases) do
			if ph.id and not POOL_BY_ID[ph.id] then
				ph.scope = ph.scope or set.scope or "all"
				ph.cat = ph.cat or set.name_ru
				POOL[#POOL + 1] = ph
				POOL_BY_ID[ph.id] = ph
			end
		end
	end

	return POOL
end

local function FindWheelPhrase(id)
	WheelPool()

	return POOL_BY_ID[id]
end

local WHEEL_SLOTS = 8
local WHEEL_SAVE_DELAY = 2   -- запись на бэкенд не на каждый клик, а через паузу

S.wheel_slots = S.wheel_slots or {}  -- pid -> { [1..8] = phrase_id или "" }
S.wheel_save = S.wheel_save or {}    -- pid -> токен отложенной записи

-- ------------------------------------------------------------------ проверки

-- Можно ли игроку сейчас выполнить действие. Возвращает игрока или nil и причину.
-- Кулдаун ставит Use, и только после того, как действие прошло проверки.
local function CanUse(pid, kind)
	if pid == nil or pid < 0 then return nil, "нет PlayerID" end

	local player = PlayerResource:GetPlayer(pid)

	if player == nil then return nil, "игрок не найден" end

	local now = GameRules:GetGameTime()

	if S.last_req[pid] and now - S.last_req[pid] < MIN_GAP then return nil, "спам, меньше " .. MIN_GAP .. " c" end

	S.last_req[pid] = now

	S.cd[pid] = S.cd[pid] or {}

	local left = (S.cd[pid][kind] or 0) - now

	if left > 0 then return nil, string.format("кулдаун, осталось %.1f c", left) end

	return player
end

local function Use(pid, kind)
	S.cd[pid] = S.cd[pid] or {}

	local now = GameRules:GetGameTime()

	-- колесо: WHEEL_BURST фраз подряд свободно, после последней из серии - пауза.
	-- Серия сбрасывается, если с прошлой фразы прошло больше паузы.
	if kind == "wheel" then
		local b = S.wheel_burst[pid] or { n = 0, t = -1000 }

		if now - b.t > COOLDOWN.wheel then b.n = 0 end

		b.n = b.n + 1
		b.t = now
		S.wheel_burst[pid] = b

		if b.n < WHEEL_BURST then return end

		b.n = 0
	end

	S.cd[pid][kind] = now + COOLDOWN[kind]
end

-- ------------------------------------------------------------------ каталог клиенту

-- Отправляет игроку его надетые наборы (для колеса и смайликов), пул фраз и
-- флаг премиум. Набор шлём всем, даже без премиума: без премиума панель
-- покажется с замком. Вызывается на каждый aa_soc_request, поэтому смена
-- набора в меню видна при следующем запросе (панель шлёт его при каждом открытии).
function S:SendCatalog(pid)
	local player = PlayerResource:GetPlayer(pid)

	if player == nil then return end

	local data = { premium = 1 }   -- колесо открыто всем, доступность - по фразам (po)

	local wheel = Equipped(pid, "wheel")

	if wheel then
		data.wheel_id = wheel.id
		data.wheel_name = wheel.name_ru
		data.wheel_scope = wheel.scope or "all"
		data.wheel_n = #wheel.phrases

		for i, ph in ipairs(wheel.phrases) do
			data["wp" .. i] = ph.text
			data["wid" .. i] = ph.id
		end
	end

	local pool = WheelPool()

	data.pool_n = #pool

	for i, ph in ipairs(pool) do
		data["pi" .. i] = ph.id
		data["pt" .. i] = ph.text
		data["pc" .. i] = ph.cat or ""
		data["ps" .. i] = ph.sound and 1 or 0
		data["pn" .. i] = ph.sound or ""   -- имя звука: прослушать фразу у себя (ПКМ в настройках колеса)
		data["pa" .. i] = ph.scope == "team" and 1 or 0
		data["po" .. i] = OwnsPhrase(pid, ph.id) and 1 or 0
	end

	local emo = Equipped(pid, "emote_set")

	if emo then
		data.emote_id = emo.id
		data.emote_name = emo.name_ru
		data.emote_n = #emo.emotes

		for i, e in ipairs(emo.emotes) do
			data["en" .. i] = e.name_ru
			data["ei" .. i] = e.image
		end
	end

	Dbg(pid, "catalog", "premium=" .. data.premium .. " wheel=" .. tostring(data.wheel_id)
		.. " emote_set=" .. tostring(data.emote_id) .. " pool=" .. data.pool_n)

	CustomGameEventManager:Send_ServerToPlayer(player, "aa_soc_catalog", data)
end

-- ------------------------------------------------------------------ колесо фраз

function S:OnWheel(e)
	local pid = e.PlayerID

	Dbg(pid, "wheel", "пришло phrase_id=" .. tostring(e.phrase_id))

	local player, why = CanUse(pid, "wheel")

	if player == nil then return Dbg(pid, "wheel", "отказ: " .. why) end

	local phrase = FindWheelPhrase(tostring(e.phrase_id or ""))

	if phrase == nil then return Dbg(pid, "wheel", "отказ: нет фразы " .. tostring(e.phrase_id)) end

	if not OwnsPhrase(pid, phrase.id) then return Dbg(pid, "wheel", "отказ: фразы нет в инвентаре " .. phrase.id) end

	Use(pid, "wheel")

	-- кому слышно - по набору, из которого фраза (scope "team" - только своим)
	local team_only = phrase.scope == "team"

	Dbg(pid, "wheel", "ok " .. phrase.id .. (team_only and " (своим)" or ""))

	-- строка в чате от имени игрока, как у ванильного колеса: со значком звука
	Say(player, (phrase.sound and "♫ " or "") .. phrase.text, team_only)

	if phrase.sound then
		if team_only then
			CustomGameEventManager:Send_ServerToTeam(PlayerResource:GetTeam(pid), "aa_soc_sound", { sound = phrase.sound })
		else
			CustomGameEventManager:Send_ServerToAllClients("aa_soc_sound", { sound = phrase.sound })
		end
	end
end

-- ------------------------------------------------------------------ слоты колеса

-- Слоты игрока; пока не настраивал - фразы надетого набора по порядку
function S:GetWheelSlots(pid)
	local slots = self.wheel_slots[pid]

	if slots then return slots end

	slots = {}

	local set = Equipped(pid, "wheel")

	for i = 1, WHEEL_SLOTS do
		local ph = set and set.phrases[i]

		slots[i] = (ph and OwnsPhrase(pid, ph.id)) and ph.id or ""
	end

	return slots
end

-- нет-таблица aa_wheel[pid] = { ws1..ws8 }: клиент читает слоты отсюда и ничего не хранит
function S:PublishWheel(pid)
	local slots = self:GetWheelSlots(pid)
	local out = {}

	for i = 1, WHEEL_SLOTS do out["ws" .. i] = slots[i] or "" end

	CustomNetTables:SetTableValue("aa_wheel", tostring(pid), out)
end

-- Слоты из ответа бэкенда (CosmeticsCore:OnPlayersInfo, row.wheel_slots[8]). Незнакомые id отбрасываем.
function S:LoadWheelSlots(pid, list)
	local slots = {}
	local any = false

	for i = 1, WHEEL_SLOTS do
		local id = list[i] or list[tostring(i)]

		id = id ~= nil and tostring(id) or ""

		if id ~= "" and FindWheelPhrase(id) == nil then id = "" end
		if id ~= "" then any = true end

		slots[i] = id
	end

	if any then self.wheel_slots[pid] = slots end

	self:PublishWheel(pid)
end

function S:PersistWheel(pid)
	local token = {}

	self.wheel_save[pid] = token

	Timers:CreateTimer(WHEEL_SAVE_DELAY, function()
		if self.wheel_save[pid] ~= token then return nil end

		self.wheel_save[pid] = nil

		if not MatchTracker or not MatchTracker.SignedPost or not CosmeticsCore or not CosmeticsCore.SteamIdOf then return nil end

		local slots = self:GetWheelSlots(pid)
		local arr = {}

		for i = 1, WHEEL_SLOTS do arr[i] = slots[i] or "" end

		pcall(function()
			MatchTracker:SignedPost("/api/cosmetics/wheel", {
				steam_id = CosmeticsCore:SteamIdOf(pid),
				slots = arr,
			}, nil)
		end)

		return nil
	end)
end

-- aa_soc_wheel_set { slot 1..8, phrase_id } - поставить фразу в слот ("" - очистить).
-- Фраза, уже стоящая в другом слоте, меняется местами со старой фразой этого слота.
function S:OnWheelSet(e)
	local pid = e.PlayerID

	if pid == nil or pid < 0 then return end


	local slot = tonumber(e.slot)

	if slot == nil or slot < 1 or slot > WHEEL_SLOTS or slot ~= math.floor(slot) then
		return Dbg(pid, "wheel_set", "отказ: слот " .. tostring(e.slot))
	end

	local id = tostring(e.phrase_id or "")

	if id ~= "" and FindWheelPhrase(id) == nil then
		return Dbg(pid, "wheel_set", "отказ: нет фразы " .. id)
	end

	if id ~= "" and not OwnsPhrase(pid, id) then
		return Dbg(pid, "wheel_set", "отказ: фразы нет в инвентаре " .. id)
	end

	local cur = self:GetWheelSlots(pid)
	local slots = {}

	for i = 1, WHEEL_SLOTS do slots[i] = cur[i] or "" end

	if id ~= "" then
		for i = 1, WHEEL_SLOTS do
			if i ~= slot and slots[i] == id then slots[i] = slots[slot] end
		end
	end

	slots[slot] = id

	self.wheel_slots[pid] = slots
	self:PublishWheel(pid)
	self:PersistWheel(pid)
end

-- ------------------------------------------------------------------ смайлики

function S:OnEmote(e)
	local pid = e.PlayerID
	local player, why = CanUse(pid, "emote")

	if player == nil then return Dbg(pid, "emote", "отказ: " .. why) end

	-- target - playerID цели (кнопка "+" под её портретом в верхней панели, social_tips.js)
	local tpid = tonumber(e.target) or -1

	if tpid == pid or tpid < 0 or not PlayerResource:IsValidPlayerID(tpid) then
		return Dbg(pid, "emote", "отказ: плохая цель " .. tostring(e.target))
	end

	local target = PlayerResource:GetSelectedHeroEntity(tpid)

	if not IsValidEntity(target) then
		return Dbg(pid, "emote", "отказ: у цели нет героя (" .. tostring(e.target) .. ")")
	end

	local set = Equipped(pid, "emote_set")
	local emo = set and set.emotes[tonumber(e.index) or 0]

	if emo == nil then return Dbg(pid, "emote", "отказ: нет смайлика " .. tostring(e.index)) end

	Use(pid, "emote")

	Dbg(pid, "emote", "ok " .. emo.id .. " -> entindex " .. target:entindex())

	CustomGameEventManager:Send_ServerToAllClients("aa_soc_emote_show", {
		hero = target:entindex(),
		image = emo.image,
	})

	-- тост справа у всех: мой герой, смайлик, герой цели (social_tips.js). В чат не пишем.
	CustomGameEventManager:Send_ServerToAllClients("aa_soc_tip", {
		caster = pid,
		target = tpid,
		image = emo.image,
		name = emo.name_ru,
	})
end

-- ------------------------------------------------------------------ спреи

local function KillSpray(pid)
	local p = S.sprays[pid]

	if p == nil then return end

	S.sprays[pid] = nil
	-- true - убрать сразу: у спрея бесконечная жизнь (CP1), мягкое удаление его не гасит
	ParticleManager:DestroyParticle(p, true)
	ParticleManager:ReleaseParticleIndex(p)
end

-- Граффити. Зовётся из способности aa_cos_spray на юните-кастере (abilities/aa_cos_spray.lua):
-- прицел, дальность и кулдаун движковые. Возвращает true, если спрей поставлен.
function S:DoSpray(pid, pos)
	if pid == nil or pid < 0 or not HasOwnItem(pid, "spray") then
		Dbg(pid, "spray", "отказ: нет своего граффити")

		return false
	end

	local hero = PlayerResource:GetSelectedHeroEntity(pid)

	if not IsValidEntity(hero) then Dbg(pid, "spray", "отказ: нет героя") return false end

	if (pos - hero:GetAbsOrigin()):Length2D() > SPRAY_MAX_DIST then
		Dbg(pid, "spray", "отказ: далеко от героя")

		return false
	end

	local set = Equipped(pid, "spray")

	if set == nil then Dbg(pid, "spray", "отказ: нет набора") return false end

	Dbg(pid, "spray", "ok " .. set.id)

	-- ресурсы только надетого спрея (юнит npc_aa_cos_<id>); обычно уже загружены в пре-гейме
	if CosmeticsLoader ~= nil and not CosmeticsLoader.IsReady(set) then
		CosmeticsLoader.Ensure(set, function() S:PlaceSpray(pid, pos, set) end)
	else
		S:PlaceSpray(pid, pos, set)
	end

	return true
end

function S:PlaceSpray(pid, pos, set)
	-- один спрей на игрока: новый убирает старый
	KillSpray(pid)

	-- облачко нанесения, как в aaf (spray_custom.lua)
	local cloud = ParticleManager:CreateParticle("particles/sprays/spray_placement.vpcf", PATTACH_WORLDORIGIN, nil)

	ParticleManager:SetParticleControl(cloud, 0, pos)
	ParticleManager:ReleaseParticleIndex(cloud)

	local p = ParticleManager:CreateParticle(set.particle, PATTACH_WORLDORIGIN, nil)

	ParticleManager:SetParticleControl(p, 0, pos)
	-- второй контрол как в ванильных спреях (значение взято из референсного мода)
	ParticleManager:SetParticleControl(p, 1, Vector(196, 99999, 0))

	S.sprays[pid] = p

	-- lib/timers.lua: число в CreateTimer - относительная задержка, не абсолютное время
	Timers:CreateTimer(SPRAY_DURATION, function()
		if S.sprays[pid] == p then KillSpray(pid) end
	end)

	EmitSoundOnLocationWithCaster(pos, "Spraywheel.Paint", PlayerResource:GetSelectedHeroEntity(pid))
end

-- ------------------------------------------------------------------ хай-файвы

local function ClearHighFive(pid)
	local rec = S.hf_pending[pid]

	if rec == nil then return end

	S.hf_pending[pid] = nil

	if rec.particle then
		ParticleManager:DestroyParticle(rec.particle, false)
		ParticleManager:ReleaseParticleIndex(rec.particle)
	end
end

-- Два хай-файва сошлись: летящий между руками эффект и вспышка посередине
local function ConnectHighFive(a, b, set)
	local pa, pb = a:GetAbsOrigin(), b:GetAbsOrigin()
	local mid = (pa + pb) / 2

	local travel = ParticleManager:CreateParticle(set.travel, PATTACH_CUSTOMORIGIN, nil)

	ParticleManager:SetParticleControl(travel, 0, pa)
	ParticleManager:SetParticleControl(travel, 1, pb)
	ParticleManager:ReleaseParticleIndex(travel)

	local impact = ParticleManager:CreateParticle(set.impact, PATTACH_CUSTOMORIGIN, nil)

	ParticleManager:SetParticleControl(impact, 0, mid)
	ParticleManager:SetParticleControl(impact, 3, mid)
	ParticleManager:ReleaseParticleIndex(impact)
end

-- "Дай пять". Зовётся из способности aa_cos_high_five на юните-кастере
-- (abilities/aa_cos_high_five.lua), кулдаун движковый. true - рука поднята или сошлись.
function S:DoHighFive(pid)
	local ok = S:HighFive(pid)

	return ok == true
end

function S:HighFive(pid)
	if pid == nil or pid < 0 or not HasOwnItem(pid, "high_five") then return Dbg(pid, "high_five", "отказ: нет своего «Дай пять»") end

	local hero = PlayerResource:GetSelectedHeroEntity(pid)

	if not IsValidEntity(hero) or not hero:IsAlive() then return Dbg(pid, "high_five", "отказ: герой мёртв") end

	-- рука уже поднята - ждём партнёра, второй раз не поднимаем. Если герой
	-- сменился (repick) или умер, старая запись мёртвая - снимаем её.
	local old = S.hf_pending[pid]

	if old and (not IsValidEntity(old.hero) or old.hero ~= hero or not old.hero:IsAlive()) then
		ClearHighFive(pid)
		old = nil
	end

	if old then return Dbg(pid, "high_five", "отказ: рука уже поднята") end

	local set = Equipped(pid, "high_five")

	if set == nil then return Dbg(pid, "high_five", "отказ: нет набора") end

	if CosmeticsLoader ~= nil then CosmeticsLoader.Ensure(set, nil) end

	local origin = hero:GetAbsOrigin()

	-- чья-то поднятая рука рядом (союзник или враг) - сходимся
	for other_pid, rec in pairs(S.hf_pending) do
		if other_pid ~= pid and IsValidEntity(rec.hero) and rec.hero:IsAlive()
			and (rec.hero:GetAbsOrigin() - origin):Length2D() <= HIGH_FIVE_RANGE then
			ConnectHighFive(rec.hero, hero, set)
			ClearHighFive(other_pid)
			Dbg(pid, "high_five", "ok, сошлись с pid " .. other_pid)

			return true
		end
	end

	Dbg(pid, "high_five", "ok, рука поднята")

	local p = ParticleManager:CreateParticle(set.overhead, PATTACH_OVERHEAD_FOLLOW, hero)

	S.hf_pending[pid] = { hero = hero, particle = p, set = set }

	Timers:CreateTimer(HIGH_FIVE_DURATION, function()
		local rec = S.hf_pending[pid]

		if rec and rec.particle == p then ClearHighFive(pid) end
	end)

	return true
end

-- ------------------------------------------------------------------ прекеш

-- Вызывать из Precache(context) в addon_game_mode.lua. Партиклы из каталога
-- движок не грузит сам, а прекешить их в рантайме нельзя.
function S:Precache(context)
	local seen = {}

	local function add(path)
		if path == nil or seen[path] then return end

		seen[path] = true
		PrecacheResource("particle", path, context)
	end

	for _, it in ipairs(SOCIAL_CATALOG.spray or {}) do
		add(it.particle)
	end

	for _, it in ipairs(SOCIAL_CATALOG.high_five or {}) do
		add(it.overhead)
		add(it.travel)
		add(it.impact)
	end
end

-- ------------------------------------------------------------------ регистрация

local function Safe(fn)
	return function(_, e)
		if type(e) ~= "table" then return end

		local ok, err = pcall(fn, S, e)

		if not ok then print("[CosmeticsSocial] " .. tostring(err)) end
	end
end

CustomGameEventManager:RegisterListener("aa_soc_request", function(_, e)
	if type(e) ~= "table" or e.PlayerID == nil then return end

	S:SendCatalog(e.PlayerID)
	S:PublishWheel(e.PlayerID)
end)

CustomGameEventManager:RegisterListener("aa_soc_wheel", Safe(S.OnWheel))
CustomGameEventManager:RegisterListener("aa_soc_wheel_set", Safe(S.OnWheelSet))
CustomGameEventManager:RegisterListener("aa_soc_emote", Safe(S.OnEmote))

-- при выходе игрока снимаем его спрей и поднятую руку
ListenToGameEvent("player_disconnect", function(data)
	local pid = data and data.PlayerID

	if pid == nil or pid < 0 then return end

	KillSpray(pid)
	ClearHighFive(pid)
end, nil)

-- смерть героя: поднятая рука гаснет вместе с ним (партикл привязан к герою)
ListenToGameEvent("entity_killed", function(data)
	local ent = data and data.entindex_killed and EntIndexToHScript(data.entindex_killed)

	if ent == nil or not IsValidEntity(ent) or not ent:IsRealHero() then return end

	local pid = ent:GetPlayerOwnerID()

	if pid == nil or pid < 0 then return end

	local rec = S.hf_pending[pid]

	if rec and rec.hero == ent then ClearHighFive(pid) end
end, nil)
