if not IsServer() then return end

--[[
	Награда за убийство героя: золото и опыт убийце и героям рядом.

	Основа - формулы доты, поднятые в базе, но главное - ценность жертвы:
	её нетворс + запас золота + съеденные томы (статы и трактаты). Нетворс
	доты томы не видит, а в моде в них уходят десятки тысяч, поэтому без них
	"богатый" герой выглядел бедным и стоил копейки.

	Движковое золото и опыт за героя выключены (AngelArena:GoldFilter и
	ExperienceFilter), всё платится здесь - так формулы полностью наши, а
	суммы видны в своём килфиде (lib/kill_feed.lua).

	ЗОЛОТО (восстановлена формула до экспериментов, подрезка по константам;
	у каждой константы в скобках указано "было X")
	  убийце = [(KILLER_BASE + KILLER_LVL_GOLD*L + KILLER_V_PCT*V) * lvlMult
	            + серия + KILLER_GAP_PCT*разрыв + первая кровь]
	            * KILL_MULT * teamMult
	  рядом  = (AID_BASE + AID_LVL_GOLD*L + AID_V_PCT*V + AID_GAP_PCT*разрыв)
	            * 1.5/(N+0.5) * KILL_MULT * teamMult
	    убийца тоже входит в "рядом" (его доля добавляется к своему золоту)
	  L - уровень жертвы, V - её ценность, N - герои рядом
	  lvlMult  = 1 + 3% за уровень разницы (жертва - убийца), 0.8..1.6
	  разрыв   = max(0, V - ценность убийцы) * min(1, ratio)
	  ratio    = средняя ценность команды жертвы / команды убийц
	  teamMult = clamp(1 + (ratio - 1)*TEAM_W, TEAM_MIN, TEAM_MAX)
	  серия    = STREAK_GOLD[min(S, 10)] при S >= 3 (S - серия жертвы)

	ОПЫТ
	  всего   = (XP_BASE + XP_LEVEL_PCT% опыта уровня жертвы
	            + серия (1.25*S^2 - 2.5*S + 10) * ур.жертвы * XP_STREAK_MULT)
	            * множитель разницы уровней
	  делится между героями в радиусе так же: 1.5 / (N + 0.5)

	Камбэк команды (lib/comeback_system.lua) считается отдельно и тоже от
	ценности команд, см. HeroKillBounty:TeamValue.
]]

local Constants = require('consts')

HeroKillBounty = HeroKillBounty or {}

-- ЗОЛОТО. Формула восстановлена (версия до экспериментов с tanh).
-- Подрезка: базы и доли от уровня -20%, доли от ценности/разрыва -15%,
-- первая кровь -20%, серия без изменений, teamMult усилен (см. ниже).
-- Убийце (из скобок в шапке файла):
local KILLER_BASE = 240        -- было 300
local KILLER_LVL_GOLD = 12     -- было 15, за уровень жертвы
local KILLER_V_PCT = 0.034     -- было 0.04, доля от ценности жертвы
local KILLER_GAP_PCT = 0.085   -- было 0.10, доля от разрыва ценности
local FIRST_BLOOD_GOLD = 240   -- было 300
-- рядом, включая убийцу (делится 1.5/(N+0.5)):
local AID_BASE = 120           -- было 150
local AID_LVL_GOLD = 6.4       -- было 8, за уровень жертвы
local AID_V_PCT = 0.0425       -- было 0.05, доля от ценности жертвы
local AID_GAP_PCT = 0.0425     -- было 0.05, доля от разрыва ценности
-- общий множитель золота (без изменений)
local KILL_MULT = 0.72         -- было 0.72
-- множитель команд: 1 + (ratio - 1) * TEAM_W, в пределах TEAM_MIN..TEAM_MAX
local TEAM_W = 0.8             -- было 0.5
local TEAM_MIN = 0.65          -- было 0.75
local TEAM_MAX = 1.3           -- было 1.25
-- серия жертвы (золото убийце), без изменений
local STREAK_GOLD = { [3] = 90, [4] = 150, [5] = 225, [6] = 315, [7] = 420, [8] = 540, [9] = 675, [10] = 825 }

local AOE_RADIUS = 1300

-- разница уровней: +-3% за уровень (золото и опыт), было 3% / 0.8..1.6 без изменений
local LEVEL_DIFF_PCT = 3
local LEVEL_MULT_MIN = 0.8
local LEVEL_MULT_MAX = 1.6

-- опыт
local XP_BASE = 200
local XP_LEVEL_PCT = 70      -- от опыта, нужного жертве на её следующий уровень
local XP_STREAK_MULT = 1

-- ценность съеденного: очко стата из тома ~1000 золота (том 5000 за +5),
-- трактат здоровья 7000
local GOLD_PER_TOME_STAT = 1000
local GOLD_PER_MEDICAL_TRACTATE = 7000

local TOME_MODIFIERS = { "bonus_str_tome", "bonus_agi_tome", "bonus_int_tome" }

-- ---------------------------------------------------------------------------
-- ценность героя и команды
-- ---------------------------------------------------------------------------

function HeroKillBounty:TomeValue(hero)
	if not hero or hero:IsNull() then return 0 end

	local points = 0

	for _, name in ipairs(TOME_MODIFIERS) do
		local mod = hero:FindModifierByName(name)

		if mod then points = points + mod:GetStackCount() end
	end

	return points * GOLD_PER_TOME_STAT + (hero.medical_tractates or 0) * GOLD_PER_MEDICAL_TRACTATE
end

-- нетворс + запас сверх лимита кошелька (AngelArena:GiveGold) + томы;
-- hero - если известен (у героев из -createhero playerid чужой)
function HeroKillBounty:HeroValue(playerid, hero)
	return AANetWorth:Get(playerid) + self:TomeValue(hero or PlayerResource:GetSelectedHeroEntity(playerid))
end

-- сумма, число героев и средний уровень команды
function HeroKillBounty:TeamValue(team)
	local sum, count, levels = 0, 0, 0

	TeamHelper:ApplyForHeroes(team, function(playerid, hero)
		sum = sum + self:HeroValue(playerid, hero)
		levels = levels + hero:GetLevel()
		count = count + 1
	end)

	return sum, count, count > 0 and levels / count or 0
end

-- опыт, нужный герою этого уровня до следующего
function HeroKillBounty:LevelXP(level)
	local xpTable = Constants.XP_PER_LEVEL_TABLE
	local cur = xpTable[level]
	local nxt = xpTable[level + 1]

	if cur and nxt then return nxt - cur end

	-- за концом таблицы - последний шаг
	local n = #xpTable

	return (xpTable[n] or 0) - (xpTable[n - 1] or 0)
end

-- множитель команд: ratio - во сколько раз команда жертвы богаче команды убийц
local function TeamMult(ratio)
	local mult = 1 + (ratio - 1) * TEAM_W

	return math.max(TEAM_MIN, math.min(TEAM_MAX, mult))
end

local function StreakGold(streak)
	if streak < 3 then return 0 end

	return STREAK_GOLD[math.min(streak, 10)] or 0
end

local function StreakXP(streak, level)
	if streak < 3 then return 0 end

	streak = math.min(streak, 10)

	return (1.25 * streak * streak - 2.5 * streak + 10) * level * XP_STREAK_MULT
end

local function LevelMult(victimLevel, killerLevel)
	local mult = 1 + (victimLevel - killerLevel) * LEVEL_DIFF_PCT / 100

	return math.max(LEVEL_MULT_MIN, math.min(LEVEL_MULT_MAX, mult))
end

-- доля каждого из N героев рядом
local function AoeShare(count)
	return 1.5 / (count + 0.5)
end

-- ---------------------------------------------------------------------------
-- смерть героя
-- ---------------------------------------------------------------------------

local function IsAttackerOf(victim, playerid)
	if not victim.GetNumAttackers then return false end

	for i = 0, victim:GetNumAttackers() - 1 do
		if victim:GetAttacker(i) == playerid then return true end
	end

	return false
end

-- наша выплата: мимо запрета движкового золота за героя, в килфид - строкой
-- этого убийства
-- source - метка для телеметрии (lib/match_telemetry.lua, gold_by_source на
-- сайте): "hero_kill" убийце, "hero_assist" остальным героям рядом
local function PayGold(victim, playerid, gold, source)
	gold = math.floor(gold)

	if gold <= 0 then return end

	local prevSource = MatchTelemetry and MatchTelemetry.goldSource

	if MatchTelemetry then MatchTelemetry.goldSource = source end

	if KillFeed then
		KillFeed:OurPayout(AngelArena.GiveGold, AngelArena, playerid, gold, true, DOTA_ModifyGold_HeroKill)
		KillFeed:AddAssist(victim, playerid, gold)
	else
		HeroKillBounty.ourPayout = true
		local ok, err = pcall(AngelArena.GiveGold, AngelArena, playerid, gold, true, DOTA_ModifyGold_HeroKill)
		HeroKillBounty.ourPayout = false
		if not ok then print("[HeroKillBounty] pay: " .. tostring(err)) end
	end

	if MatchTelemetry then MatchTelemetry.goldSource = prevSource end

	AngelArena:ShowGoldPopup(playerid, gold)
end

local function PayXP(hero, xp)
	xp = math.floor(xp)

	if xp <= 0 then return end

	HeroKillBounty.ourPayout = true
	hero:AddExperience(xp, DOTA_ModifyXP_HeroKill, false, true)
	HeroKillBounty.ourPayout = false
end

function HeroKillBounty:OnEntityKilled(event)
	local victim = event.entindex_killed and EntIndexToHScript(event.entindex_killed)
	local killer = event.entindex_attacker and EntIndexToHScript(event.entindex_attacker)

	if not victim or not IsValidEntity(victim) or not victim:IsRealHero() then return end
	if victim:IsReincarnating() then return end
	-- только основной герой игрока: солдаты Wukong's Command у Monkey King движок
	-- считает реальными героями, и каждый их "труп" платил полную награду
	if victim:IsClone() or victim:IsTempestDouble() then return end
	if victim:HasModifier("modifier_monkey_king_fur_army_soldier")
		or victim:HasModifier("modifier_monkey_king_fur_army_soldier_hidden") then return end
	local victimMain = PlayerResource:GetSelectedHeroEntity(victim:GetPlayerOwnerID())
	if victimMain and victimMain ~= victim then return end
	if not killer or not IsValidEntity(killer) then return end

	local killerTeam = killer:GetTeamNumber()
	local victimTeam = victim:GetTeamNumber()

	if killerTeam == victimTeam then return end
	if killerTeam ~= DOTA_TEAM_GOODGUYS and killerTeam ~= DOTA_TEAM_BADGUYS then return end

	local victimPID = victim:GetPlayerOwnerID()
	local victimLevel = victim:GetLevel()
	local victimValue = self:HeroValue(victimPID, victim)
	local streak = PlayerResource:GetStreak(victimPID) or 0

	-- убийца-игрок: сам герой, хозяин иллюзии или призыва. Башня или крип
	-- команды - убийцы-игрока нет, награду делят только герои рядом.
	local killerPID = killer:GetPlayerOwnerID()
	local killerHero = killerPID and killerPID >= 0 and PlayerResource:GetSelectedHeroEntity(killerPID) or nil

	if killerHero and killerHero:GetTeamNumber() ~= killerTeam then killerHero = nil end

	-- средние ценности команд: ratio - команда жертвы относительно команды убийц
	local teamValue, teamCount = self:TeamValue(killerTeam)
	local victimTeamValue, victimTeamCount = self:TeamValue(victimTeam)
	local killerAvg = teamCount > 0 and teamValue / teamCount or 0
	local victimAvg = victimTeamCount > 0 and victimTeamValue / victimTeamCount or 0
	local ratio = killerAvg > 0 and victimAvg / killerAvg or 1
	local teamMult = TeamMult(ratio)

	local killerValue = killerAvg
	if killerHero then killerValue = self:HeroValue(killerPID, killerHero) end

	-- разрыв ценности жертвы и убийцы (с учётом ratio)
	local gap = math.max(0, victimValue - killerValue) * math.min(1, ratio)
	local value = math.max(0, victimValue)

	-- герои рядом: живые союзники убийцы в радиусе и все, кто бил жертву
	local victimPos = victim:GetAbsOrigin()
	local nearby = {}
	local count = 0

	TeamHelper:ApplyForHeroes(killerTeam, function(playerid, hero)
		if (hero == killerHero)
			or IsAttackerOf(victim, playerid)
			or (hero:IsAlive() and (hero:GetAbsOrigin() - victimPos):Length2D() <= AOE_RADIUS)
		then
			nearby[playerid] = hero
			count = count + 1
		end
	end)

	local share = count > 0 and AoeShare(count) or 0

	-- доля золота каждому из героев рядом (убийца тоже в их числе)
	local aoeGold = (AID_BASE + AID_LVL_GOLD * victimLevel + AID_V_PCT * value + AID_GAP_PCT * gap)
		* share * KILL_MULT * teamMult

	-- золото убийце: своя часть (без доли рядом)
	local killerGold = 0

	if killerHero then
		local bracket = (KILLER_BASE + KILLER_LVL_GOLD * victimLevel + KILLER_V_PCT * value)
			* LevelMult(victimLevel, killerHero:GetLevel())
			+ StreakGold(streak)
			+ KILLER_GAP_PCT * gap

		if not self.firstBloodDone then
			self.firstBloodDone = true
			bracket = bracket + FIRST_BLOOD_GOLD
		end

		killerGold = bracket * KILL_MULT * teamMult
	end

	local xpTotal = XP_BASE + self:LevelXP(victimLevel) * XP_LEVEL_PCT / 100 + StreakXP(streak, victimLevel)

	if killerHero then
		local gold = killerGold + (nearby[killerPID] and aoeGold or 0)

		PayGold(victim, killerPID, gold, "hero_kill")
	end

	for playerid, hero in pairs(nearby) do
		if not (killerHero and playerid == killerPID) then
			PayGold(victim, playerid, aoeGold, "hero_assist")
		end

		-- мёртвым опыт не платим, как в доте: иначе взрывная мантия (сначала смерть, потом взрыв) давала опыт
		if hero:IsAlive() then
			PayXP(hero, xpTotal * share * LevelMult(victimLevel, hero:GetLevel()))
		end
	end
end

function HeroKillBounty:Init()
	if self._started then return end
	self._started = true

	ListenToGameEvent("entity_killed", function(event)
		local ok, err = pcall(HeroKillBounty.OnEntityKilled, HeroKillBounty, event)
		if not ok then print("[HeroKillBounty] " .. tostring(err)) end
	end, nil)
end

HeroKillBounty:Init()
