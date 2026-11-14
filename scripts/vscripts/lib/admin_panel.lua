-- Админ-панель: отдельная панель слева (клиент: panorama/layout/custom_game/admin_panel.xml).
-- Доступ: Steam-аккаунт 960329385 в любом матче, а также любой игрок при
-- GameRules:IsCheatMode(). Не-владельцу цель - только свой герой.
--
-- Сервер - единственный источник правды. Каждое действие заново проверяет
-- Steam-id отправителя и лимит частоты, и только потом что-то делает. Панель
-- на клиенте лишь рисует кнопки и шлёт действия.
--
-- Ивенты идут через защиту (lib/events_protector.lua):
--   клиент -> сервер: aa_admin_hello (панель загрузилась), aa_admin_action
--   сервер -> клиент: aa_admin_enable (показать панель), aa_admin_info
--                     (состояние матча), aa_admin_result (итог действия)

if not IsServer() then return end

local ADMIN_STEAM_ID = 960329385

local EV_HELLO  = "aa_admin_hello"
local EV_ACTION = "aa_admin_action"
local EV_ENABLE = "aa_admin_enable"
local EV_INFO   = "aa_admin_info"
local EV_RESULT = "aa_admin_result"

local RATE_LIMIT = 5 -- действий в секунду на одного админа

local UNRATED_NOTICE = "Использована админ-панель, матч без рейтинга"

-- действия, которые не портят матч и не снимают рейтинг
local RATED_SAFE = { start_game = true, info = true }

AdminPanel = AdminPanel or {}
local AP = AdminPanel

local unratedSent = false   -- уведомление и отметка - один раз на матч
local history = {}          -- [pid] = { времена действий за последнюю секунду }

-- ---------------------------------------------------------------------------
-- проверки и утилиты
-- ---------------------------------------------------------------------------

-- владелец по Steam-id: полный доступ, цель любой игрок, в любом матче
local function IsAccountAdmin(pid)
	if pid == nil or pid < 0 then return false end
	if not PlayerResource:IsValidPlayerID(pid) then return false end

	return PlayerResource:GetSteamAccountID(pid) == ADMIN_STEAM_ID
end

-- панель доступна владельцу всегда и всем игрокам в лобби с читами.
-- Не-владельцам цель - только свой герой (см. ResolveTarget)
local function IsAllowed(pid)
	if pid == nil or pid < 0 then return false end
	if not PlayerResource:IsValidPlayerID(pid) then return false end

	return IsAccountAdmin(pid) or GameRules:IsCheatMode() or IsInToolsMode()
end

local function SendToPlayerID(pid, name, data)
	local player = PlayerResource:GetPlayer(pid)

	if player then
		CustomGameEventManager:Send_ServerToPlayer(player, name, data or {})
	end
end

local function Reply(pid, ok, text)
	SendToPlayerID(pid, EV_RESULT, { ok = ok and 1 or 0, text = text })
end

local function RateOk(pid)
	local now = Time()
	local fresh = {}

	for _, t in ipairs(history[pid] or {}) do
		if now - t < 1 then
			fresh[#fresh + 1] = t
		end
	end

	if #fresh >= RATE_LIMIT then
		history[pid] = fresh
		return false
	end

	fresh[#fresh + 1] = now
	history[pid] = fresh

	return true
end

-- целое число из ввода в панели, nil если не число или вне диапазона
local function Num(v, lo, hi)
	local n = tonumber(v)

	if n == nil then return nil end

	n = math.floor(n)

	if n < lo or n > hi then return nil end

	return n
end

-- имя юнита или предмета: только латиница, цифры и подчёркивание
local function CleanName(v)
	local s = tostring(v or "")

	s = s:gsub("^%s+", ""):gsub("%s+$", "")

	if s == "" or #s > 64 or not s:match("^[%w_]+$") then return nil end

	return s
end

-- цель действия: игрок, выбранный в панели, либо сам админ.
-- Возвращает pid и героя или nil, если героя нет
local function ResolveTarget(adminPid, data)
	local pid = tonumber(data.target)

	-- не-владелец (чит-лобби) может действовать только над своим героем
	if pid == nil or pid < 0 or not IsAccountAdmin(adminPid) then
		pid = adminPid
	end

	if not PlayerResource:IsValidPlayerID(pid) then return nil end

	local hero = PlayerResource:GetSelectedHeroEntity(pid)

	if not hero or hero:IsNull() then return nil end

	return pid, hero
end

-- первое действие в матче снимает рейтинг. Вызывается до выполнения действия
local function MarkUnrated()
	if unratedSent then return end

	unratedSent = true

	if MatchTracker and MatchTracker.MarkUnrated then pcall(MatchTracker.MarkUnrated, MatchTracker, "admin_panel") end

	Attentions:SendChatMessage(UNRATED_NOTICE)
end

-- ---------------------------------------------------------------------------
-- действия. Каждое: function(adminPid, data) -> ok, текст (текст можно не давать)
-- ---------------------------------------------------------------------------

local ACTIONS = {}

-- золото через AngelArena:GiveGold: учитывает потолок кошелька и запас,
-- как любое другое начисление
ACTIONS.give_gold = function(pid, d)
	local amount = Num(d.amount, 1, 1000000)
	if not amount then return false, "неверная сумма золота" end

	local tpid, hero = ResolveTarget(pid, d)
	if not hero then return false, "цель не найдена" end

	if not AngelArena or not AngelArena.GiveGold then return false, "золото недоступно" end

	AngelArena:GiveGold(tpid, amount, true, 0)

	return true, "золото: +" .. amount
end

ACTIONS.give_xp = function(pid, d)
	local amount = Num(d.amount, 1, 1000000)
	if not amount then return false, "неверное количество опыта" end

	local _, hero = ResolveTarget(pid, d)
	if not hero then return false, "цель не найдена" end

	hero:AddExperience(amount, 0, true, true)

	return true, "опыт: +" .. amount
end

ACTIONS.level_up = function(pid, d)
	local n = Num(d.n or 1, 1, 30)
	if not n then return false, "неверное число уровней" end

	local _, hero = ResolveTarget(pid, d)
	if not hero then return false, "цель не найдена" end

	for _ = 1, n do
		hero:HeroLevelUp(true)
	end

	return true, "уровень: +" .. n
end

-- поднимаем, пока уровень растёт; потолок у движка и у мода свой, поэтому
-- останавливаемся, как только HeroLevelUp перестал что-то менять
ACTIONS.max_level = function(pid, d)
	local _, hero = ResolveTarget(pid, d)
	if not hero then return false, "цель не найдена" end

	for _ = 1, 200 do
		local before = hero:GetLevel()

		hero:HeroLevelUp(true)

		if hero:GetLevel() == before then break end
	end

	return true, "уровень: " .. hero:GetLevel()
end

-- базовые атрибуты: SetBaseX(GetBaseX() + n), как в остальном коде мода
ACTIONS.give_attributes = function(pid, d)
	local s = Num(d.str or 0, 0, 100000)
	local a = Num(d.agi or 0, 0, 100000)
	local i = Num(d.int or 0, 0, 100000)

	if not s or not a or not i then return false, "атрибуты - неотрицательные числа" end

	local _, hero = ResolveTarget(pid, d)
	if not hero then return false, "цель не найдена" end

	hero:SetBaseStrength(hero:GetBaseStrength() + s)
	hero:SetBaseAgility(hero:GetBaseAgility() + a)
	hero:SetBaseIntellect(hero:GetBaseIntellect() + i)

	return true, "атрибуты: +" .. s .. " / +" .. a .. " / +" .. i
end

ACTIONS.refresh = function(pid, d)
	local _, hero = ResolveTarget(pid, d)
	if not hero then return false, "цель не найдена" end

	for i = 0, hero:GetAbilityCount() - 1 do
		local ability = hero:GetAbilityByIndex(i)

		if ability then
			ability:EndCooldown()
			ability:RefreshCharges()
		end
	end

	for slot = 0, 5 do
		local item = hero:GetItemInSlot(slot)

		if item then
			item:EndCooldown()
		end
	end

	hero:SetHealth(hero:GetMaxHealth())
	hero:SetMana(hero:GetMaxMana())

	return true, "кулдауны и здоровье обновлены"
end

ACTIONS.respawn = function(pid, d)
	local _, hero = ResolveTarget(pid, d)
	if not hero then return false, "цель не найдена" end

	if hero:IsAlive() then return false, "герой жив" end

	hero:RespawnHero(false, false)

	return true, "герой возрождён"
end

ACTIONS.kill_target = function(pid, d)
	local _, hero = ResolveTarget(pid, d)
	if not hero then return false, "цель не найдена" end

	if not hero:IsAlive() then return false, "герой уже мёртв" end

	hero:ForceKill(false)

	return true, "герой убит"
end

ACTIONS.toggle_invulnerable = function(pid, d)
	local MOD = "modifier_invulnerable"

	local _, hero = ResolveTarget(pid, d)
	if not hero then return false, "цель не найдена" end

	if hero:HasModifier(MOD) then
		hero:RemoveModifierByName(MOD)
		return true, "неуязвимость выключена"
	end

	hero:AddNewModifier(hero, nil, MOD, { duration = -1 })

	return true, "неуязвимость включена"
end

ACTIONS.give_item = function(pid, d)
	local name = CleanName(d.name)
	if not name then return false, "неверное имя предмета" end

	if name:sub(1, 5) ~= "item_" then
		name = "item_" .. name
	end

	local _, hero = ResolveTarget(pid, d)
	if not hero then return false, "цель не найдена" end

	local item = hero:AddItemByName(name)

	if not item then return false, "предмет не найден: " .. name end

	return true, "выдан " .. name
end

local TEAMS = {
	radiant = DOTA_TEAM_GOODGUYS,
	dire    = DOTA_TEAM_BADGUYS,
}

-- юнит появляется рядом с админом; команда: radiant | dire | mine (команда админа)
ACTIONS.spawn_unit = function(pid, d)
	local name = CleanName(d.name)
	if not name then return false, "неверное имя юнита" end

	local _, hero = ResolveTarget(pid, d)
	if not hero then return false, "нет своего героя" end

	local team = TEAMS[d.team]

	if d.team == "mine" then
		team = hero:GetTeamNumber()
	end

	if not team then return false, "не выбрана команда" end

	local pos = hero:GetAbsOrigin() + RandomVector(RandomFloat(200, 400))
	local unit = CreateUnitByName(name, pos, true, nil, nil, team)

	if not unit then return false, "юнит не найден: " .. name end

	return true, "заспавнен " .. name
end

-- пре-игра: на экране выбора команд - завершаем настройку, на выборе героев
-- и до горна - форсим старт
local PRE_GAME_STATES = {
	[DOTA_GAMERULES_STATE_HERO_SELECTION] = true,
	[DOTA_GAMERULES_STATE_STRATEGY_TIME]  = true,
	[DOTA_GAMERULES_STATE_PRE_GAME]       = true,
}

-- меню репика в обход запретов (босс, дуэль): разрешение на один выбор
ACTIONS.open_repick = function(pid, d)
	local tpid = ResolveTarget(pid, d)
	local player = tpid and PlayerResource:GetPlayer(tpid)
	if not player or not RepickMenu then return false, "репик недоступен" end

	RepickMenu.admin_bypass = RepickMenu.admin_bypass or {}
	RepickMenu.admin_bypass[tpid] = true
	RepickMenu:Open(player, true)

	return true, "меню репика открыто"
end

ACTIONS.start_game = function()
	local state = GameRules:State_Get()

	if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
		GameRules:FinishCustomGameSetup()
		return true, "настройка завершена"
	end

	if PRE_GAME_STATES[state] then
		GameRules:ForceGameStart()
		return true, "игра начата"
	end

	return false, "игра уже идёт или ещё не готова"
end

ACTIONS.spawn_bosses = function()
	-- инициализацию BossSpawner делает OnGameStart; до неё классов нет
	if not BossSpawner or not BossSpawner.inited then return false, "боссы ещё не инициализированы" end

	local spawned = 0

	BossSpawner:ForBossClass(function(boss)
		if BossSpawner:IsBossAlive(boss.name) then return end

		BossSpawner:SpawnBoss(boss)
		spawned = spawned + 1
	end)

	return true, "заспавнено боссов: " .. spawned
end

ACTIONS.start_duel = function()
	if not DuelController or not DuelController.StartDuel then return false, "дуэли недоступны" end

	DuelController:StartDuel()

	return true, "дуэль запущена"
end

-- тот же KILL_LIMIT, что читают AngelArena:OnEntityKilled и табло; глобальный,
-- без локальной копии. Текущий счёт команд не трогаем
ACTIONS.set_kill_limit = function(pid, d)
	local n = Num(d.value, 1, 10000)
	if not n then return false, "неверный лимит убийств" end

	KILL_LIMIT = n
	_G.KILL_LIMIT = n

	Attentions:SetKillLimit(n)

	-- лимит проверяется только в момент убийства: если команда уже набрала
	-- новый лимит, объявляем последнюю дуэль сразу (как при обычном убийстве)
	for _, team in ipairs({ DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS }) do
		if (_G.Kills and _G.Kills[team] or 0) >= n and not DuelController:IsLastDuelTeam(team) then
			DuelController:AddLastDuelTeam(team)
			Attentions:SendAttentionText("#aa_last_duel_coming", 10, 3)
			if KillFeed then KillFeed:LastDuel() end
		end
	end

	return true, "лимит убийств: " .. n
end

ACTIONS.end_game = function(pid, d)
	local team = TEAMS[d.team]

	if not team then return false, "не выбрана команда" end

	GameEnder:ForceEnd(team)

	return true, "игра завершена"
end

-- состояние для панели; текста в ответ нет
ACTIONS.info = function(pid)
	SendToPlayerID(pid, EV_INFO, {
		kill_limit = KILL_LIMIT or 0,
		kills_radiant = (_G.Kills and _G.Kills[DOTA_TEAM_GOODGUYS]) or 0,
		kills_dire = (_G.Kills and _G.Kills[DOTA_TEAM_BADGUYS]) or 0,
		state = GameRules:State_Get(),
	})

	return true, nil
end

-- ---------------------------------------------------------------------------
-- вход действий
-- ---------------------------------------------------------------------------

local function OnAction(event)
	local pid = tonumber(event.PlayerID)

	if not IsAllowed(pid) then
		print("[AdminPanel] WARNING: действие от игрока без доступа, pid " .. tostring(pid) .. " - игнорирую")
		return
	end

	if not RateOk(pid) then
		Reply(pid, false, "слишком часто, подожди секунду")
		return
	end

	local name = tostring(event.action or "")
	local action = ACTIONS[name]

	if not action then
		print("[AdminPanel] WARNING: неизвестное действие '" .. name .. "' от pid " .. pid)
		Reply(pid, false, "неизвестное действие")
		return
	end

	-- владелец (Steam-id) пользуется молча: матч считается, в чат ничего.
	-- В чит-лобби и тулзах матч и так без рейтинга - отметка для остальных
	if not RATED_SAFE[name] and not IsAccountAdmin(pid) then
		MarkUnrated()
	end

	local called, ok, text = pcall(action, pid, event)

	if not called then
		print("[AdminPanel] ERROR в действии " .. name .. ": " .. tostring(ok))
		Reply(pid, false, "ошибка, см. лог сервера")
		return
	end

	if text ~= nil then
		Reply(pid, ok, text)
	end
end

-- панель шлёт hello, когда загрузилась и получила ключ защиты; отвечаем
-- включением только тем, кому панель положена. full = 1 - владелец (можно
-- выбирать цель), 0 - чит-лобби без выбора цели
function AP.Announce(pid)
	if not IsAllowed(pid) then return end

	SendToPlayerID(pid, EV_ENABLE, { full = IsAccountAdmin(pid) and 1 or 0 })
end

CustomGameEventManager:RegisterListener(EV_ACTION, function(_, data)
	OnAction(data)
end)

CustomGameEventManager:RegisterListener(EV_HELLO, function(_, data)
	AP.Announce(tonumber(data.PlayerID))
end)

-- игрок прошёл рукопожатие защиты (lib/events_protector.lua)
if RegisterLoadListener then
	RegisterLoadListener(function(player)
		if player then AP.Announce(player:GetPlayerID()) end
	end)
end

-- герой появился (включая возрождение) - на случай, если панель перезагрузилась
ListenToGameEvent("npc_spawned", function(event)
	local unit = EntIndexToHScript(event.entindex)

	if not unit or unit:IsNull() or not unit:IsRealHero() then return end

	AP.Announce(unit:GetPlayerOwnerID())
end, nil)
