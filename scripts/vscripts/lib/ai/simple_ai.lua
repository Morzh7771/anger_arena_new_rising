require('lib/timers')
require('lib/ai/ai_helpers')
require('lib/ai/ai_actions')

SimpleAI = SimpleAI or class({})

-- тик простоя: никого в зоне и босс стоит на точке спавна
local IDLE_TICK = 0.3

function SimpleAI:OnTick()
	if not self:IsValid() then return nil end
	
	if not self:CanThink() then return self.tickTime end

	-- Свой канал (Dismember, еда Пуджа) не трогаем: Attack делает Stop() и
	-- сбивал его на первом же тике. Канал телепорта ротации - тоже.
	local unit = self.unit
	if unit:IsChanneling() or unit:HasModifier("modifier_boss_rotation") then return self.tickTime end

	local spawnPos = self.spawnPos
	local caster = self.unit

	if spawnPos == nil then
		spawnPos = caster:GetAbsOrigin()
		self.spawnPos = spawnPos 
	end

	local baseAoi = self.baseAoi

	local enemies = AIHelpers:GetEnemiesNear(caster, caster:GetAbsOrigin(), caster:GetTeamNumber(), baseAoi)

	-- Босс один дома и рядом никого: все действия свелись бы к Back, который
	-- у точки спавна ничего не делает. Такой простой опрашиваем реже, чем бой
	-- (0.1 с x все боссы весь матч были главной статьёй Lua в [AA.perf]).
	-- Полное здоровье и без стана: часть способностей (Interception, Heal)
	-- срабатывает по здоровью и без врагов, их тик не трогаем.
	if #enemies == 0 and caster:GetHealth() >= caster:GetMaxHealth() and not caster:IsStunned()
		and (caster:GetAbsOrigin() - spawnPos):Length() <= 50 then
		return math.max(self.tickTime, IDLE_TICK)
	end

	for _, action in pairs(self.actions) do

		if action:Do(enemies, spawnPos, baseAoi) then
			return self.tickTime
		end
	end

	return self.tickTime
end 

function SimpleAI:IsValid()
	local unit = self.unit

	if not unit or unit:IsNull() or not unit:IsAlive() or unit:IsDominated() or unit:IsIllusion() then return false end

	return true
end

function SimpleAI:CanThink()
	for _, action in pairs(self.actions) do
		if action:ForbiddenThink() then return false end
	end

	return true
end

function SimpleAI:Make( unit, tickTime, aoi, actions)
	local ai = SimpleAI() 

	ai.baseAoi 	= aoi
	ai.tickTime = tickTime
	ai.unit 	= unit
	ai.actions  = actions

	-- спавнер боссов двигает точку возврата при ротации (lib/boss/boss_spawner.lua)
	unit.aa_simple_ai = ai

	Timers:CreateTimer(ai.tickTime, function() return ai:OnTick() end )
end