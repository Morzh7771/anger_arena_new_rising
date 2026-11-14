require('lib/attentions')
require('lib/team_helper')

--[[
	Камбэк: доплата за убийство команде, которая отстаёт.

	Отставание считаем по ценности героя, как и награда за убийство
	(HeroKillBounty:HeroValue): нетворс + запас золота + съеденные томы.
	Раньше считалось накопленное золото команды, и герой, который всё вложил
	в томы, выглядел бедным - камбэк шёл не тем.

	Серию жертвы камбэк больше не платит: она входит в награду за убийство
	(lib/hero_kill_bounty.lua), иначе платилась бы дважды.

	Отдельной строкой в килфиде камбэк не показывается - он просто
	прибавляется к золоту убийцы и героев рядом.
]]

ComebackSystem = ComebackSystem or class({})

-- Порог: пока команда отстаёт меньше чем на столько ценности на героя,
-- камбэка нет. Растёт со временем и не может быть меньше доли от ценности
-- богатой команды - в конце игры отставание в 2000 это уже ничто.
local MIN_GAP = 500
local MIN_GAP_PER_MINUTE = 100
local MIN_GAP_VALUE_PCT = 10

-- сколько от отставания сверх порога уходит за одно убийство
local GAP_PCT = 25

-- надбавка просто за то, что команда беднее
local BASE_GOLD = 100
local BASE_GOLD_PER_MINUTE = 7

-- Опыт: если команда отстаёт по уровням больше чем на LEVEL_GAP_FREE,
-- за убийство доплачиваем долю уровня за каждый следующий уровень отставания.
local LEVEL_GAP_FREE = 1
local LEVEL_XP_PCT = 15
local LEVEL_GAP_MAX = 6

-- доля камбэка героям рядом (остальное убийце)
local GOLD_TO_TEAMMATES = 40
local TEAM_MATE_AOE = 1300

local function GiveGoldTo( playerid, gold, deadHero )
	if not PlayerResource:IsValidPlayerID( playerid ) then return end

	gold = math.floor( gold )

	if gold <= 0 then return end

	-- не упираемся в дотовские 99999: что не влезло в кошелёк, сразу уходит
	-- в запас и видно игроку через нет-таблицу gold
	-- камбек в командную делёжку не попадает (lib/team_gold_share.lua)
	-- в килфид камбэк идёт строкой убийства, а не как движковое золото
	if KillFeed then KillFeed.ourPayout = true end

	if TeamGoldShare then
		TeamGoldShare:Bypass(AngelArena.GiveGold, AngelArena, playerid, gold, true, DOTA_ModifyGold_HeroKill)
	else
		AngelArena:GiveGold( playerid, gold, true, DOTA_ModifyGold_HeroKill )
	end

	if KillFeed then
		KillFeed.ourPayout = false
		KillFeed:AddComeback(deadHero, playerid, gold)
	end

	if EndGameStats then EndGameStats:OnComebackGold(playerid, gold) end

	AngelArena:ShowGoldPopup(playerid, gold)
end

local function GiveXPTo( hero, xp )
	xp = math.floor(xp)

	if xp <= 0 or not hero or hero:IsNull() then return end

	if HeroKillBounty then HeroKillBounty.ourPayout = true end

	hero:AddExperience(xp, DOTA_ModifyXP_HeroKill, false, true)

	if HeroKillBounty then HeroKillBounty.ourPayout = false end
end

-- золото команды за игру: больше в расчёте камбэка не участвует, но его
-- собирает статистика и читы
function ComebackSystem:OnGiveGold( playerid, gold, isReliable, reason )
	local team = PlayerResource:GetTeam( playerid )

	self.teamGolds[ team ] = (self.teamGolds[ team ] or 0) + gold
end

function ComebackSystem:_GetTeamGold( team )
	return self.teamGolds[team] or 0
end

function ComebackSystem:OnKill( killerPlayerID, killerTeam, victimPlayerID, victimTeam )
	if killerTeam == victimTeam then return end
	if killerTeam ~= DOTA_TEAM_GOODGUYS and killerTeam ~= DOTA_TEAM_BADGUYS then return end
	if not HeroKillBounty then return end

	local deadHero = PlayerResource:GetSelectedHeroEntity( victimPlayerID )

	if not deadHero or deadHero:IsNull() or not IsValidEntity(deadHero) then return end

	local minute = math.max(0, GameRules:GetDOTATime( false, false ) / 60)

	local killerValue, killerCount, killerLevel = HeroKillBounty:TeamValue(killerTeam)
	local victimValue, victimCount, victimLevel = HeroKillBounty:TeamValue(victimTeam)

	if killerCount == 0 or victimCount == 0 then return end

	-- отставание на одного героя: команда убийцы беднее - число больше нуля
	local gap = victimValue / victimCount - killerValue / killerCount

	if gap <= 0 then return end

	local minGap = math.max(MIN_GAP + MIN_GAP_PER_MINUTE * minute, (victimValue / victimCount) * MIN_GAP_VALUE_PCT / 100)

	local totalGold = BASE_GOLD + BASE_GOLD_PER_MINUTE * minute + math.max(0, gap - minGap) * GAP_PCT / 100

	-- отставание по уровням оплачиваем опытом
	local levelGap = math.min(LEVEL_GAP_MAX, victimLevel - killerLevel - LEVEL_GAP_FREE)
	local totalXP = 0

	if levelGap > 0 then
		totalXP = HeroKillBounty:LevelXP(math.floor(killerLevel)) * LEVEL_XP_PCT / 100 * levelGap
	end

	-- герои рядом с местом смерти, кроме убийцы
	local deadHeroPos = deadHero:GetAbsOrigin()
	local mates = {}
	local nPlayers = 0

	TeamHelper:ApplyForHeroes(killerTeam, function( teammatePlayerID, hero )
		if teammatePlayerID == killerPlayerID then return end
		if not hero:IsAlive() then return end
		if (hero:GetAbsOrigin() - deadHeroPos):Length2D() > TEAM_MATE_AOE then return end

		mates[teammatePlayerID] = hero
		nPlayers = nPlayers + 1
	end)

	local killerGold, killerXP = totalGold, totalXP

	if nPlayers > 0 then
		local sharedGold = totalGold * GOLD_TO_TEAMMATES / 100
		local sharedXP = totalXP * GOLD_TO_TEAMMATES / 100

		killerGold = totalGold - sharedGold
		killerXP = totalXP - sharedXP

		for playerid, hero in pairs(mates) do
			GiveGoldTo(playerid, sharedGold / nPlayers, deadHero)
			GiveXPTo(hero, sharedXP / nPlayers)
		end
	end

	GiveGoldTo(killerPlayerID, killerGold, deadHero)
	GiveXPTo(PlayerResource:GetSelectedHeroEntity(killerPlayerID), killerXP)
end

function ComebackSystem:_Init()
	self.teamGolds = {}
end

ComebackSystem:_Init()
