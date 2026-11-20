if not IsServer() then return end

-- Простой ИИ для наших кастомных активок нейтралов (neutral_*_active).
-- Думает раз в THINK секунд, и только когда крип в бою (есть aggro-цель-враг).
-- Выключен у приручённых (IsDominated) - тогда способности доступны игроку как обычно.
-- Ванильные активки (в т.ч. древних) - общий каст по типу цели, плюс движковый neutral_chance_to_cast.
CreepActiveAI = CreepActiveAI or {}

local THINK = 0.5
local MODIFIER = "modifier_neutral_creep_active"

-- порядок проверки: одна попытка за тик
local ABILITIES = {
	"neutral_centaur_stun_active",
	"neutral_satyr_purge_active",
	"neutral_bird_tornado_active",
	"neutral_ogre_armor_active",
}

local tracked = {}
local started = false

local function IsEnemyNear(unit, radius)
	local found = FindUnitsInRadius(unit:GetTeamNumber(), unit:GetAbsOrigin(), nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	return #found > 0
end

local function InRange(ability, unit, target)
	local range = ability:GetCastRange(target:GetAbsOrigin(), target)
	if range <= 0 then range = 600 end
	return (target:GetAbsOrigin() - unit:GetAbsOrigin()):Length2D() <= range
end

-- возвращает true, если кастанули
local function TryCast(unit, ability, name, aggro)
	if name == "neutral_centaur_stun_active" then
		if IsEnemyNear(unit, ability:GetSpecialValueFor("aoe")) then
			unit:CastAbilityNoTarget(ability, -1)
			return true
		end
	elseif name == "neutral_satyr_purge_active" then
		if aggro:IsHero() and InRange(ability, unit, aggro) then
			unit:CastAbilityOnTarget(aggro, ability, -1)
			return true
		end
	elseif name == "neutral_bird_tornado_active" then
		if InRange(ability, unit, aggro) then
			unit:CastAbilityOnPosition(aggro:GetAbsOrigin(), ability, -1)
			return true
		end
	elseif name == "neutral_ogre_armor_active" then
		if not unit:HasModifier(MODIFIER) then
			unit:CastAbilityOnTarget(unit, ability, -1)
			return true
		end
	end
	return false
end

local CUSTOM = {}
for _, n in ipairs(ABILITIES) do CUSTOM[n] = true end

-- ванильная активка: смотрим поведение и команду цели
local function GenericCast(unit, ability, aggro)
	if CUSTOM[ability:GetAbilityName()] then return false end
	local b = ability:GetBehaviorInt()
	local team = ability:GetAbilityTargetTeam()
	local friendly = team == DOTA_UNIT_TARGET_TEAM_FRIENDLY
	if bit.band(b, DOTA_ABILITY_BEHAVIOR_NO_TARGET) ~= 0 then
		local r = ability:GetSpecialValueFor("radius")
		if r <= 0 then r = ability:GetCastRange(unit:GetAbsOrigin(), nil) end
		if r <= 0 then r = 350 end
		if friendly or IsEnemyNear(unit, r) then
			unit:CastAbilityNoTarget(ability, -1)
			return true
		end
	elseif bit.band(b, DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) ~= 0 then
		local target = friendly and unit or aggro
		if friendly or InRange(ability, unit, aggro) then
			unit:CastAbilityOnTarget(target, ability, -1)
			return true
		end
	elseif bit.band(b, DOTA_ABILITY_BEHAVIOR_POINT) ~= 0 then
		if InRange(ability, unit, aggro) then
			unit:CastAbilityOnPosition(aggro:GetAbsOrigin(), ability, -1)
			return true
		end
	end
	return false
end

local function ThinkUnit(unit)
	if not unit or unit:IsNull() or not unit:IsAlive() then return false end
	if unit:IsDominated() or unit:IsIllusion() or unit:IsChanneling() then return false end

	-- вне боя не кастуем вообще
	local aggro = unit:GetAggroTarget()
	if not aggro or aggro:IsNull() or not aggro:IsAlive() then return false end
	if aggro:GetTeamNumber() == unit:GetTeamNumber() then return false end

	for _, name in ipairs(ABILITIES) do
		local ability = unit:FindAbilityByName(name)
		if ability and ability:IsTrained() and ability:IsFullyCastable() then
			if TryCast(unit, ability, name, aggro) then return true end
		end
	end

	-- Любая другая готовая активка (ванильные крипы и древние): каст по типу цели.
	for i = 0, unit:GetAbilityCount() - 1 do
		local ability = unit:GetAbilityByIndex(i)
		if ability and not ability:IsNull() and ability:IsTrained() and not ability:IsPassive()
			and not ability:IsToggle() and not ability:IsHidden() and ability:IsFullyCastable() then
			if GenericCast(unit, ability, aggro) then return true end
		end
	end
	return false
end

local function HasActive(creep)
	for i = 0, creep:GetAbilityCount() - 1 do
		local ability = creep:GetAbilityByIndex(i)
		if ability and not ability:IsPassive() and not ability:IsToggle() then return true end
	end
	return false
end

function CreepActiveAI:OnSpawn(arg)
	local creep = arg and arg.creep
	if not creep or creep:IsNull() then return end
	if HasActive(creep) then
		tracked[creep:GetEntityIndex()] = creep
	end
end

function CreepActiveAI:Start()
	if started then return end
	started = true

	Timers:CreateTimer("CreepActiveAI", {
		useGameTime = true,
		endTime = THINK,
		callback = function()
			for idx, unit in pairs(tracked) do
				if not unit or unit:IsNull() or not unit:IsAlive() then
					tracked[idx] = nil
				else
					ThinkUnit(unit)
				end
			end
			return THINK
		end,
	})
end
