-- Премиум-стадия перед ванильным выбором героя (2026-11-12, doc/premium_features_roadmap.md п.1).
--
-- Основной экран - ВАНИЛЬНЫЙ пик доты: ванильные баны, потом ванильный общий выбор.
-- Если в игре есть игрок с поддержкой проекта, ванильная стадия банов удлиняется на T_PREMIUM,
-- и первые T_PREMIUM секунд идёт премиум-стадия:
--   * премиум-игрок выбирает героя в своём окне (panorama pick_stages.*, свёрстано под ванильный пик);
--   * остальные видят затемнение "Ожидание премиум-игроков" с таймером; взять героя они не могут
--     и по правилам движка - в это время идёт ванильная стадия банов, пикать в ней нельзя.
-- Когда все премиумы выбрали или время вышло - окно и затемнение закрываются, дальше обычные
-- ванильные баны (остаток времени) и ванильный пик. Герой премиума ставится через
-- player:SetSelectedHero сразу; если движок в стадии банов его не принял - повторяем, как только
-- баны закончились (до этого клиент показывает полоску "занято премиумом").
--
--   нет-таблица aa_pick["state"]  = { stage, ends_at, n, premium = {pid=1}, picks = {pid=hero} }
--                                     stage: wait | premium | open | done
--               aa_pick["heroes"] = { i = {name, attr} }
--   клиент -> сервер  aa_pick_select { hero }  - пик премиума (стадия premium)
--   сервер -> клиент  aa_pick_error  { msg }

if not IsServer() then return end
if AAPick ~= nil then return end

AAPick = {
	stage = "wait",
	ends_at = 0,
	n = 0,
	premium = {},
	picks = {},
	applied = {},
	heroes = {},
	enabled = {},
	planned = false,     -- стадия банов удлинена под премиум-стадию
}

local P = AAPick

local T_PREMIUM = 20

-- DEV-ТЕСТ премиум-стадии (только в тулзах, IsInToolsMode). true - с реальных игроков премиум
-- в пике снимается, вместо них в игре "фантомный" премиум DEV_FAKE_PID: он ничего не пикает,
-- поэтому видно все 20 с ожидания, а после - вернулись ли бан и пик. Ещё в dev-режиме обычные
-- баны (AAPICK_BAN_TIME) идут и в чит-режиме, чтобы было что проверять после ожидания.
-- В обычном состоянии - false. Включить: поставить true и перезапустить карту.
local DEV_FAKE_PREMIUM = false
local DEV_FAKE_PID = 23

local function DevFake()
	return DEV_FAKE_PREMIUM and IsInToolsMode()
end
local START_DELAY = 1.0     -- даём клиентам прогрузить экран выбора

-- Ванильные тайминги ставит addon_game_mode.lua, отсюда - только длина банов.
AAPICK_BAN_TIME = 20        -- обычная игра; в чит-режиме 0 (стадии банов нет)
AAPICK_PREMIUM_TIME = T_PREMIUM

local ATTR = {
	DOTA_ATTRIBUTE_STRENGTH = "str",
	DOTA_ATTRIBUTE_AGILITY = "agi",
	DOTA_ATTRIBUTE_INTELLECT = "int",
	DOTA_ATTRIBUTE_ALL = "all",
}

local function Players()
	local out = {}

	for pid = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(pid) and PlayerResource:GetTeam(pid) ~= DOTA_TEAM_NOTEAM then
			out[#out + 1] = pid
		end
	end

	return out
end

local function IsPremium(pid)
	if DevFake() then return false end

	return CosmeticsCore ~= nil and CosmeticsCore.IsPremium ~= nil and CosmeticsCore:IsPremium(pid) == true
end

function P:LoadHeroes()
	local list = LoadKeyValues("scripts/npc/herolist.txt") or {}
	local data = (PreloadCache and PreloadCache.GetHeroData and PreloadCache:GetHeroData()) or {}

	self.heroes = {}
	self.enabled = {}

	for name, on in pairs(list) do
		if tonumber(on) ~= 0 and string.find(name, "^npc_dota_hero_") then
			local kv = data[name] or {}

			self.enabled[name] = true
			self.heroes[#self.heroes + 1] = { name = name, attr = ATTR[kv.AttributePrimary or ""] or "all" }
		end
	end

	table.sort(self.heroes, function(a, b) return a.name < b.name end)
end

function P:Publish()
	local picks = {}

	for pid, hero in pairs(self.picks) do picks[tostring(pid)] = hero end

	local prem = {}

	for pid, v in pairs(self.premium) do if v then prem[tostring(pid)] = 1 end end

	CustomNetTables:SetTableValue("aa_pick", "state", {
		stage = self.stage,
		ends_at = self.ends_at,
		n = self.n,
		premium = prem,
		picks = picks,
	})
end

function P:IsTaken(hero)
	for _, h in pairs(self.picks) do
		if h == hero then return true end
	end

	return false
end

-- героя уже взяли обычным ванильным пиком
function P:HeroTakenInEngine(hero, except)
	for _, pid in ipairs(Players()) do
		if pid ~= except and PlayerResource:HasSelectedHero(pid) and PlayerResource:GetSelectedHeroName(pid) == hero then
			return true
		end
	end

	return false
end

local function Error(pid, msg)
	local player = PlayerResource:GetPlayer(pid)

	if player then CustomGameEventManager:Send_ServerToPlayer(player, "aa_pick_error", { msg = msg }) end
end

-- Отдать выбор премиума движку. true - больше пробовать не надо.
function P:Apply(pid)
	local hero = self.picks[pid]

	if not hero or self.applied[pid] then return true end

	if PlayerResource:HasSelectedHero(pid) then
		self.applied[pid] = true

		return true
	end

	-- пока шли баны, героя успели взять обычным пиком - бронь снимаем, игрок выберет в ванильном меню
	if self:HeroTakenInEngine(hero, pid) then
		self.picks[pid] = nil
		Error(pid, "taken")
		self:Publish()

		return true
	end

	local player = PlayerResource:GetPlayer(pid)

	if player then
		local ok, err = pcall(function() player:SetSelectedHero(hero) end)

		if not ok then print("[AAPick] SetSelectedHero failed " .. tostring(err)) end
	end

	return false
end

function P:Assign(pid, hero)
	self.picks[pid] = hero
	self.applied[pid] = nil

	print(string.format("[AAPick] pid %d -> %s (%s)", pid, hero, self.stage))

	self:Apply(pid)
end

-- Пики, которые движок не принял в стадии банов, ставим, как только баны кончились.
function P:ApplyThink()
	if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_HERO_SELECTION then return nil end

	local banning = GameRules.IsInBanPhase ~= nil and GameRules:IsInBanPhase()
	local pending = {}

	for pid, _ in pairs(self.picks) do
		if not self.applied[pid] then pending[#pending + 1] = pid end
	end

	self.tries = self.tries or {}

	for _, pid in ipairs(pending) do
		if PlayerResource:HasSelectedHero(pid) then
			self.applied[pid] = true
			self.tries[pid] = nil
		elseif not banning then
			self:Apply(pid)

			-- Движок молча не принимает героя (например, его забанили в ванильных банах - так
			-- было с Линой 2026-11-15: меню закрылось, а героя не дали). После ~2 с попыток
			-- снимаем бронь и говорим игроку - пусть выберет другого, а не остаётся ни с чем.
			self.tries[pid] = (self.tries[pid] or 0) + 1

			if self.tries[pid] >= 8 and self.picks[pid] and not PlayerResource:HasSelectedHero(pid) then
				print("[AAPick] движок не принял " .. tostring(self.picks[pid]) .. " для pid " .. pid .. " - бронь снята")
				self.picks[pid] = nil
				self.applied[pid] = nil
				self.tries[pid] = nil
				Error(pid, "taken")
				self:Publish()
			end
		end
	end

	return 0.25
end

-- ------------------------------------------------------------------ стадии

function P:SetStage(stage, duration)
	self.stage = stage
	self.n = self.n + 1
	self.ends_at = duration and (GameRules:GetGameTime() + duration) or 0

	self:Publish()

	if duration then
		local n = self.n

		Timers:CreateTimer(duration, function()
			if self.n == n then self:Next() end
		end)
	end
end

function P:AllPremiumPicked()
	for pid, v in pairs(self.premium) do
		if v and not self.picks[pid] then return false end
	end

	return true
end

function P:Next()
	if self.stage == "premium" then
		self:SetStage("open", nil)
	end
end

function P:Start()
	if self.stage ~= "wait" then return end

	self:LoadHeroes()

	self.premium = {}

	local any = false

	for _, pid in ipairs(Players()) do
		if IsPremium(pid) and PlayerResource:GetConnectionState(pid) == DOTA_CONNECTION_STATE_CONNECTED then
			self.premium[pid] = true
			any = true
		end
	end

	if DevFake() then
		self.premium[DEV_FAKE_PID] = true
		any = true
		print("[AAPick] DEV: фантомный премиум pid " .. DEV_FAKE_PID .. ", реальные игроки без премиума")
	end

	CustomNetTables:SetTableValue("aa_pick", "heroes", self.heroes)

	-- премиум-стадия живёт внутри удлинённой стадии банов: если баны не удлиняли
	-- (премиум появился в последний момент) - стадии нет, иначе она съела бы время обычных банов
	if any and self.planned then
		self:SetStage("premium", T_PREMIUM)

		Timers:CreateTimer(0.25, function()
			local ok, res = pcall(P.ApplyThink, P)

			if not ok then
				print("[AAPick] apply: " .. tostring(res))

				return 0.25
			end

			return res
		end)
	else
		self:SetStage("open", nil)
	end
end

-- Длина ванильной стадии банов: обычные баны + премиум-стадия, если в лобби есть премиум.
-- Зовётся, пока идёт экран команд: к началу выбора героя движок уже должен знать время.
function P:PlanBanTime()
	local any = false

	for pid = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(pid) and IsPremium(pid) then
			any = true

			break
		end
	end

	if DevFake() then any = true end

	local base = (GameRules:IsCheatMode() and not DevFake()) and 0 or AAPICK_BAN_TIME

	self.planned = any

	GameRules:GetGameModeEntity():SetDraftingBanningTimeOverride(base + (any and T_PREMIUM or 0))
	GameRules:SetHeroSelectionTime(90 + (any and T_PREMIUM or 0))
end

-- ------------------------------------------------------------------ действия игроков

function P:OnSelect(data)
	local pid = data and tonumber(data.PlayerID)
	local hero = data and tostring(data.hero or "")

	if pid == nil then return end

	if self.stage ~= "premium" or not self.premium[pid] then return Error(pid, "not_your_stage") end
	if self.picks[pid] or PlayerResource:HasSelectedHero(pid) then return Error(pid, "already") end
	if not self.enabled[hero] then return Error(pid, "bad_hero") end
	if self:IsTaken(hero) or self:HeroTakenInEngine(hero, pid) then return Error(pid, "taken") end

	self:Assign(pid, hero)
	self:Publish()

	if self:AllPremiumPicked() then self:Next() end
end

CustomGameEventManager:RegisterListener("aa_pick_select", function(_, data)
	local ok, err = pcall(P.OnSelect, P, data)

	if not ok then print("[AAPick] select: " .. tostring(err)) end
end)

-- aa_pick_hero_info { hero } -> aa_pick_hero_info { hero_name, abilities, innate, scepter, shard, talents }
-- Те же данные, что у меню репика (RepickMenu:BuildHeroInfo, с кэшем) - чтобы в окне премиум-пика
-- видно скиллы, врождённую, аганим и шард.
CustomGameEventManager:RegisterListener("aa_pick_hero_info", function(_, data)
	local ok, err = pcall(function()
		local pid = data and tonumber(data.PlayerID)
		local hero = data and tostring(data.hero or "")
		local player = pid and PlayerResource:GetPlayer(pid)

		if not player or hero == "" or not P.enabled[hero] then return end
		if not RepickMenu or not RepickMenu.BuildHeroInfo then require("lib/repick_menu") end

		local info = RepickMenu:BuildHeroInfo(hero)

		if not info then return end

		CustomGameEventManager:Send_ServerToPlayer(player, "aa_pick_hero_info", {
			hero_name = info.hero_name, abilities = info.abilities, innate = info.innate,
			scepter = info.scepter, shard = info.shard, talents = info.talents,
		})
	end)

	if not ok then print("[AAPick] hero info: " .. tostring(err)) end
end)

local planning = false

ListenToGameEvent("game_rules_state_change", function()
	local st = GameRules:State_Get()

	if st == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP and not planning then
		planning = true

		-- useGameTime = false: на экране команд игровое время стоит
		Timers:CreateTimer({
			endTime = 0.5,
			useGameTime = false,
			callback = function()
				if GameRules:State_Get() > DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then return nil end

				local ok, err = pcall(P.PlanBanTime, P)

				if not ok then print("[AAPick] plan: " .. tostring(err)) end

				return 0.5
			end,
		})
	elseif st == DOTA_GAMERULES_STATE_HERO_SELECTION then
		Timers:CreateTimer(START_DELAY, function()
			local ok, err = pcall(P.Start, P)

			if not ok then print("[AAPick] start: " .. tostring(err)) end
		end)
	elseif st > DOTA_GAMERULES_STATE_HERO_SELECTION and P.stage ~= "done" then
		pcall(P.SetStage, P, "done", nil)
	end
end, nil)

return P
