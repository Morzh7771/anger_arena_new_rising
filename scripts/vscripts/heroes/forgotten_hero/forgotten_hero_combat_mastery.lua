-- Forgotten Hero: Combat Mastery. Порт из Angel Arena Global.
-- Пассивка: каждая атака снимает броню (стаки), каждая атака по герою даёт стак урона.

forgotten_hero_combat_mastery = class({})

LinkLuaModifier("modifier_forgotten_hero_combat_mastery", "heroes/forgotten_hero/forgotten_hero_combat_mastery", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_forgotten_hero_combat_mastery_disarmor", "heroes/forgotten_hero/forgotten_hero_combat_mastery", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_forgotten_hero_combat_mastery_damage", "heroes/forgotten_hero/forgotten_hero_combat_mastery", LUA_MODIFIER_MOTION_NONE)

function forgotten_hero_combat_mastery:Precache(context)
	PrecacheResource("particle", "particles/econ/items/phoenix/phoenix_solar_forge/phoenix_solar_forge_ambient.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/witch_doctor/wd_ti10_immortal_weapon_gold/wd_ti10_immortal_ambient_gold_haze.vpcf", context)
end

function forgotten_hero_combat_mastery:GetIntrinsicModifierName()
	return "modifier_forgotten_hero_combat_mastery"
end

--------------------------------------------------------------------------------

modifier_forgotten_hero_combat_mastery = class({})

function modifier_forgotten_hero_combat_mastery:IsHidden() return true end
function modifier_forgotten_hero_combat_mastery:IsPurgable() return false end

function modifier_forgotten_hero_combat_mastery:DeclareFunctions()
	return { MODIFIER_EVENT_ON_ATTACK_LANDED }
end

local function add_stack(unit, caster, ability, name, duration)
	local mod = unit:AddNewModifier(caster, ability, name, { duration = duration })
	if mod then mod:IncrementStackCount() end
end

function modifier_forgotten_hero_combat_mastery:OnAttackLanded(params)
	if not IsServer() then return end

	local parent = self:GetParent()
	if params.attacker ~= parent or parent:PassivesDisabled() then return end

	local target = params.target
	local ability = self:GetAbility()
	if not target or target:IsBuilding() or target:GetTeamNumber() == parent:GetTeamNumber() then return end

	if not parent:IsIllusion() then
		add_stack(target, parent, ability, "modifier_forgotten_hero_combat_mastery_disarmor", ability:GetSpecialValueFor("disarmor_duration"))
	end

	if target:IsHero() then
		add_stack(parent, parent, ability, "modifier_forgotten_hero_combat_mastery_damage", ability:GetSpecialValueFor("bonus_damage_duration"))
	end
end

--------------------------------------------------------------------------------

modifier_forgotten_hero_combat_mastery_disarmor = class({})

function modifier_forgotten_hero_combat_mastery_disarmor:IsHidden() return false end
function modifier_forgotten_hero_combat_mastery_disarmor:IsDebuff() return true end
function modifier_forgotten_hero_combat_mastery_disarmor:IsPurgable() return true end

function modifier_forgotten_hero_combat_mastery_disarmor:OnCreated()
	local ability = self:GetAbility()
	self.disarmor = ability and -ability:GetSpecialValueFor("disarmor") or 0
end

function modifier_forgotten_hero_combat_mastery_disarmor:DeclareFunctions()
	return { MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS }
end

function modifier_forgotten_hero_combat_mastery_disarmor:GetModifierPhysicalArmorBonus()
	return self.disarmor * self:GetStackCount()
end

function modifier_forgotten_hero_combat_mastery_disarmor:GetEffectName()
	return "particles/econ/items/phoenix/phoenix_solar_forge/phoenix_solar_forge_ambient.vpcf"
end

function modifier_forgotten_hero_combat_mastery_disarmor:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end

--------------------------------------------------------------------------------

modifier_forgotten_hero_combat_mastery_damage = class({})

function modifier_forgotten_hero_combat_mastery_damage:IsHidden() return false end
function modifier_forgotten_hero_combat_mastery_damage:IsPurgable() return false end

function modifier_forgotten_hero_combat_mastery_damage:OnCreated()
	local ability = self:GetAbility()
	self.damage = ability and (ability:GetSpecialValueFor("bonus_damage_per_hero") + ability:GetSpecialValueFor("damage_per_level") * self:GetParent():GetLevel()) or 0
end

function modifier_forgotten_hero_combat_mastery_damage:DeclareFunctions()
	return { MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE }
end

function modifier_forgotten_hero_combat_mastery_damage:GetModifierPreAttack_BonusDamage()
	return self.damage * self:GetStackCount()
end

function modifier_forgotten_hero_combat_mastery_damage:GetEffectName()
	return "particles/econ/items/witch_doctor/wd_ti10_immortal_weapon_gold/wd_ti10_immortal_ambient_gold_haze.vpcf"
end

function modifier_forgotten_hero_combat_mastery_damage:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end
