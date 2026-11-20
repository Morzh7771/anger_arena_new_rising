if not IsServer() then return end

-- "Отстающая команда" (2026-11-16) - механика камбэка, модификатор modifiers/modifier_aa_underdog.lua.
--
-- Раз в CHECK_PERIOD с до UNTIL_MIN-й минуты сравниваем нетворс команд (кошелёк + запас сверх
-- 50 000 + предметы). Отставание = 1 - НВ отстающих / НВ лидеров.
--   отставание <= GAP_START (30%)  - баффа нет;
--   GAP_START..GAP_FULL (30..60%)  - бафф растёт линейно от 0 до MAX_PCT;
--   >= GAP_FULL (60%)              - MAX_PCT (30%): +30% золота, +30% урона по крипам, -30% урона от крипов.
-- Условие по убийствам: если отстающая по нетворсу команда ВПЕРЕДИ по убийствам - баффа нет
-- (это раздача фарма, а не проигрыш: один фармит, четверо гангают).
-- Пороги подобраны по 174 матчам (2026-11-16): медианный разрыв 35-40%, при разрыве >45%
-- отстающие выигрывают 16-18% игр, к 30-й минуте - 8%.

Underdog = Underdog or {}

local U = Underdog

local CHECK_PERIOD = 10
local UNTIL_MIN = 30
local GAP_START = 0.30
local GAP_FULL = 0.60
local MAX_PCT = 30
local MODIFIER = "modifier_aa_underdog"
local TEAMS = { DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS }

U.pct = U.pct or {} -- [team] = текущая сила баффа, %

-- нетворс игрока с запасом сверх кошелька (AngelArena:GiveGold копит его в tPlayers[pid].gold)
local function NetWorth(pid)
	local nw = PlayerResource:GetNetWorth(pid) or 0
	local tp = AngelArena and AngelArena.tPlayers and AngelArena.tPlayers[pid]

	return nw + (tp and tp.gold or 0)
end

local function TeamStats(team)
	local nw, kills = 0, 0

	for pid = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(pid) and PlayerResource:GetTeam(pid) == team then
			nw = nw + NetWorth(pid)
			kills = kills + (PlayerResource:GetKills(pid) or 0)
		end
	end

	return nw, kills
end

-- сила баффа для команды team против other
local function CalcPct(team, other)
	local nw, kills = TeamStats(team)
	local onw, okills = TeamStats(other)

	if onw <= 0 or nw >= onw then return 0 end
	if kills > okills then return 0 end

	local gap = 1 - nw / onw

	if gap <= GAP_START then return 0 end

	local k = math.min(1, (gap - GAP_START) / (GAP_FULL - GAP_START))

	return math.floor(MAX_PCT * k + 0.5)
end

local function ApplyTeam(team, pct)
	U.pct[team] = pct

	for pid = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(pid) and PlayerResource:GetTeam(pid) == team then
			local hero = PlayerResource:GetSelectedHeroEntity(pid)

			if hero and not hero:IsNull() then
				local mod = hero:FindModifierByName(MODIFIER)

				if pct > 0 then
					if not mod then mod = hero:AddNewModifier(hero, nil, MODIFIER, {}) end
					if mod and mod:GetStackCount() ~= pct then mod:SetStackCount(pct) end
				elseif mod then
					mod:Destroy()
				end
			end
		end
	end
end

function U:Tick()
	local state = GameRules:State_Get()

	if state > DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then return nil end

	if state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		local minutes = GameRules:GetDOTATime(false, false) / 60

		if minutes >= UNTIL_MIN then
			-- после 30-й минуты механики нет: снимаем и больше не считаем
			for _, team in ipairs(TEAMS) do ApplyTeam(team, 0) end

			return nil
		end

		ApplyTeam(DOTA_TEAM_GOODGUYS, CalcPct(DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS))
		ApplyTeam(DOTA_TEAM_BADGUYS, CalcPct(DOTA_TEAM_BADGUYS, DOTA_TEAM_GOODGUYS))
	end

	return CHECK_PERIOD
end

-- множитель золота для AngelArena:GoldFilter
function U:GoldMult(pid)
	local pct = U.pct[PlayerResource:GetTeam(pid)] or 0

	return 1 + pct / 100
end

if not U.started then
	U.started = true

	Timers:CreateTimer(CHECK_PERIOD, function()
		local ok, res = pcall(U.Tick, U)

		if not ok then
			print("[Underdog] tick: " .. tostring(res))

			return CHECK_PERIOD
		end

		return res
	end)
end
