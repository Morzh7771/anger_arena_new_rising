-- Дополнение к ванильной врождёнке Сларка (slark_essence_shift).
-- Ванилла сама крадёт статы у героев, даёт стаки от Pounce и решает, когда кража становится
-- вечной. Здесь только то, чего в ванилле нет:
--   * атаки по крипам: стак на duration_creeps секунд, каждый стак даёт agi_gain ловкости
--     (модификатор modifier_slark_essence_shift_creeps_buff, на иконке число стаков и таймер);
--   * вечная кража за убийство героя: вместо ванильной +1 ловкости даёт +permanent_agi_pct %
--     ловкости навсегда, проценты копятся (modifier_slark_essence_shift_creeps_permanent,
--     на иконке - сколько %). Ванильный стак ловим по приросту счётчика
--     modifier_slark_essence_shift_permanent_buff и откатываем его обратно.

LinkLuaModifier("modifier_slark_essence_shift_creeps", "heroes/slark/slark_essence_shift_creeps", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_slark_essence_shift_creeps_buff", "heroes/slark/slark_essence_shift_creeps", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_slark_essence_shift_creeps_permanent", "heroes/slark/slark_essence_shift_creeps", LUA_MODIFIER_MOTION_NONE)

local VANILLA_ABILITY = "slark_essence_shift"
local VANILLA_PERMANENT = "modifier_slark_essence_shift_permanent_buff"

slark_essence_shift_creeps = class({})

function slark_essence_shift_creeps:GetIntrinsicModifierName()
	return "modifier_slark_essence_shift_creeps"
end

-- ловкость за стак: из ванильной способности, чтобы талант на agi_gain работал и тут.
-- Работает и на клиенте - тултип буффа считает так же.
local function GetAgiGain(parent, ability)
	local vanilla = parent:FindAbilityByName(VANILLA_ABILITY)

	if vanilla and vanilla:GetLevel() > 0 then
		return vanilla:GetSpecialValueFor("agi_gain")
	end

	return ability and ability:GetSpecialValueFor("agi_gain") or 0
end

--------------------------------------------------------------------------------
-- Скрытый постоянный модификатор: ловит удары по крипам и вечные стаки ванилы.
--------------------------------------------------------------------------------
modifier_slark_essence_shift_creeps = class({
	IsHidden = function() return true end,
	IsPurgable = function() return false end,
	RemoveOnDeath = function() return false end,
	IsPermanent = function() return true end,
	DeclareFunctions = function() return { MODIFIER_EVENT_ON_ATTACK_LANDED } end,
})

function modifier_slark_essence_shift_creeps:OnCreated()
	if not IsServer() then return end

	-- вечную ванильную кражу не используем вовсе (своя - в процентах), поэтому
	-- отсчёт всегда с нуля: любой появившийся ванильный стак конвертируется
	self.known_vanilla_stacks = 0
	self:StartIntervalThink(0.2)
end

function modifier_slark_essence_shift_creeps:OnIntervalThink()
	local parent = self:GetParent()
	local ability = self:GetAbility()

	if not ability or parent:IsIllusion() then return end

	local mod = parent:FindModifierByName(VANILLA_PERMANENT)
	local stacks = mod and mod:GetStackCount() or 0

	if stacks <= self.known_vanilla_stacks then
		self.known_vanilla_stacks = stacks
		return
	end

	local kills = stacks - self.known_vanilla_stacks

	-- ванильная +1 ловкость за стак не нужна: убираем её модификатор совсем
	-- (раньше счётчик откатывался, и на панели висела непонятная иконка с нулём)
	if self.known_vanilla_stacks > 0 then
		mod:SetStackCount(self.known_vanilla_stacks)
	else
		mod:Destroy()
	end

	local perm = parent:FindModifierByName("modifier_slark_essence_shift_creeps_permanent")
	if not perm then
		perm = parent:AddNewModifier(parent, ability, "modifier_slark_essence_shift_creeps_permanent", {})
	end

	if perm then
		perm:SetStackCount(perm:GetStackCount() + kills * ability:GetSpecialValueFor("permanent_agi_pct"))
		perm:Recalculate()
	end

	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_pudge/pudge_fleshheap_count.vpcf", PATTACH_OVERHEAD_FOLLOW, parent)
	ParticleManager:SetParticleControl(fx, 1, Vector(1, 0, 0))
	ParticleManager:ReleaseParticleIndex(fx)
end

function modifier_slark_essence_shift_creeps:OnAttackLanded(params)
	if not IsServer() then return end

	local parent = self:GetParent()
	local target = params.target

	if params.attacker ~= parent then return end
	if parent:IsIllusion() or parent:PassivesDisabled() then return end
	if not target or target:IsNull() or target:IsHero() or target:IsBuilding() or target:IsOther() then return end
	if target:GetTeamNumber() == parent:GetTeamNumber() then return end

	local ability = self:GetAbility()
	if not ability then return end

	local duration = ability:GetSpecialValueFor("duration_creeps")
	local buff = parent:FindModifierByName("modifier_slark_essence_shift_creeps_buff")

	if not buff then
		buff = parent:AddNewModifier(parent, ability, "modifier_slark_essence_shift_creeps_buff", { duration = duration })
	end

	if buff then buff:AddStack(duration) end
end

--------------------------------------------------------------------------------
-- Ловкость с крипов. Стаки = число ударов, каждый живёт duration_creeps.
-- Длительность модификатора тянется до самого свежего стака, поэтому таймер на иконке
-- показывает, когда спадёт последний.
--------------------------------------------------------------------------------
modifier_slark_essence_shift_creeps_buff = class({
	IsHidden = function() return false end,
	IsDebuff = function() return false end,
	IsPurgable = function() return false end,
	GetTexture = function() return "slark_essence_shift" end,
	DeclareFunctions = function() return { MODIFIER_PROPERTY_STATS_AGILITY_BONUS } end,
})

function modifier_slark_essence_shift_creeps_buff:GetModifierBonusStats_Agility()
	return self:GetStackCount() * GetAgiGain(self:GetParent(), self:GetAbility())
end

function modifier_slark_essence_shift_creeps_buff:OnCreated()
	if not IsServer() then return end

	self.expires = {}
	self:StartIntervalThink(0.1)
end

function modifier_slark_essence_shift_creeps_buff:AddStack(duration)
	if duration <= 0 then return end

	table.insert(self.expires, GameRules:GetGameTime() + duration)
	self:SetStackCount(#self.expires)
	self:SetDuration(duration, true)
	self:GetParent():CalculateStatBonus(true)
end

function modifier_slark_essence_shift_creeps_buff:OnIntervalThink()
	local now = GameRules:GetGameTime()
	local alive = {}

	for _, t in ipairs(self.expires) do
		if t > now then table.insert(alive, t) end
	end

	self.expires = alive

	if #alive == 0 then
		self:Destroy()
		return
	end

	if #alive ~= self:GetStackCount() then
		self:SetStackCount(#alive)
		self:GetParent():CalculateStatBonus(true)
	end
end

function modifier_slark_essence_shift_creeps_buff:OnDestroy()
	if IsServer() then self:GetParent():CalculateStatBonus(true) end
end

--------------------------------------------------------------------------------
-- Вечная ловкость за убийства: стаки = %, бонус = ловкость без этого бонуса * стаки / 100.
-- Бонус считается на сервере (GetAgility уже включает сам бонус, вычитаем его - без рекурсии)
-- и передаётся клиенту, чтобы тултип показывал то же число.
--------------------------------------------------------------------------------
modifier_slark_essence_shift_creeps_permanent = class({
	IsHidden = function() return false end,
	IsDebuff = function() return false end,
	IsPurgable = function() return false end,
	RemoveOnDeath = function() return false end,
	IsPermanent = function() return true end,
	GetTexture = function() return "slark_essence_shift" end,
	DeclareFunctions = function() return {
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_TOOLTIP,
	} end,
})

function modifier_slark_essence_shift_creeps_permanent:OnCreated()
	self.bonus = 0

	if not IsServer() then return end

	self:SetHasCustomTransmitterData(true)
	self:StartIntervalThink(0.5)
end

function modifier_slark_essence_shift_creeps_permanent:AddCustomTransmitterData()
	return { bonus = self.bonus }
end

function modifier_slark_essence_shift_creeps_permanent:HandleCustomTransmitterData(data)
	self.bonus = data.bonus or 0
end

function modifier_slark_essence_shift_creeps_permanent:Recalculate()
	local parent = self:GetParent()
	local base = parent:GetAgility() - (self.bonus or 0)
	local bonus = math.max(0, base) * self:GetStackCount() / 100

	if math.abs(bonus - (self.bonus or 0)) < 0.01 then return end

	self.bonus = bonus
	self:SendBuffRefreshToClients()
	parent:CalculateStatBonus(true)
end

function modifier_slark_essence_shift_creeps_permanent:OnIntervalThink()
	self:Recalculate()
end

function modifier_slark_essence_shift_creeps_permanent:GetModifierBonusStats_Agility()
	return self.bonus or 0
end

function modifier_slark_essence_shift_creeps_permanent:OnTooltip()
	return self:GetStackCount()
end
