-- Forgotten Hero: Echo Strike (врождённая). Каждая attacks_needed-я атака бьёт дважды:
-- сразу следом идёт эхо-удар с бонусом (bonus_damage_pct + damage_per_level × уровень)% урона.

forgotten_hero_echo_strike = class({})

LinkLuaModifier("modifier_forgotten_hero_echo_strike", "heroes/forgotten_hero/forgotten_hero_echo_strike", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_forgotten_hero_echo_strike_bonus", "heroes/forgotten_hero/forgotten_hero_echo_strike", LUA_MODIFIER_MOTION_NONE)

function forgotten_hero_echo_strike:GetIntrinsicModifierName()
	return "modifier_forgotten_hero_echo_strike"
end

modifier_forgotten_hero_echo_strike = class({})

function modifier_forgotten_hero_echo_strike:IsHidden() return self:GetStackCount() == 0 end
function modifier_forgotten_hero_echo_strike:IsPurgable() return false end
function modifier_forgotten_hero_echo_strike:RemoveOnDeath() return false end

function modifier_forgotten_hero_echo_strike:DeclareFunctions()
	return { MODIFIER_EVENT_ON_ATTACK_LANDED }
end

function modifier_forgotten_hero_echo_strike:OnAttackLanded(params)
	if not IsServer() then return end

	local parent = self:GetParent()
	local ability = self:GetAbility()
	local target = params.target

	if params.attacker ~= parent or self.echoing or not ability then return end
	if parent:PassivesDisabled() or parent:IsIllusion() then return end
	if not target or target:IsNull() or target:IsBuilding() or target:GetTeamNumber() == parent:GetTeamNumber() then return end

	self:IncrementStackCount()
	if self:GetStackCount() < ability:GetSpecialValueFor("attacks_needed") then return end
	self:SetStackCount(0)

	-- эхо-удар на следующем кадре, чтобы не вложиться в обработку текущей атаки
	Timers:CreateTimer(FrameTime(), function()
		if parent:IsNull() or not parent:IsAlive() or target:IsNull() or not target:IsAlive() then return end

		self.echoing = true
		local buff = parent:AddNewModifier(parent, ability, "modifier_forgotten_hero_echo_strike_bonus", { duration = 0.1 })
		parent:PerformAttack(target, true, true, true, true, false, false, true)
		if buff and not buff:IsNull() then buff:Destroy() end
		self.echoing = false

		local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_monkey_king/monkey_king_quad_tap_hit.vpcf", PATTACH_ABSORIGIN_FOLLOW, target)
		ParticleManager:ReleaseParticleIndex(pfx)
		target:EmitSound("Hero_MonkeyKing.IronCudgel")
	end)
end

--------------------------------------------------------------------------------

modifier_forgotten_hero_echo_strike_bonus = class({})

function modifier_forgotten_hero_echo_strike_bonus:IsHidden() return true end
function modifier_forgotten_hero_echo_strike_bonus:IsPurgable() return false end

function modifier_forgotten_hero_echo_strike_bonus:OnCreated()
	local ability = self:GetAbility()
	if not ability then self.bonus = 0 return end
	self.bonus = ability:GetSpecialValueFor("bonus_damage_pct") + ability:GetSpecialValueFor("damage_per_level") * self:GetParent():GetLevel()
end

function modifier_forgotten_hero_echo_strike_bonus:DeclareFunctions()
	return { MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE }
end

function modifier_forgotten_hero_echo_strike_bonus:GetModifierDamageOutgoing_Percentage()
	return self.bonus
end
