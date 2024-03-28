require('items.funcs.cleave')
DOTA_DAMAGE_FLAG_TRISULA = 524288

local forbidden_modifiers = {
	--"modifier_pangolier_swashbuckle_stunned",
	--"modifier_pangolier_swashbuckle",
	--"modifier_pangolier_swashbuckle_attack",
	--"modifier_monkey_king_boundless_strike_crit",
}

LinkLuaModifier( "modifier_item_trisula", "items/item_trisula.lua", LUA_MODIFIER_MOTION_NONE )
--Abilities
if item_trisula == nil then
	item_trisula = class({})
end
function item_trisula:GetIntrinsicModifierName()
	return "modifier_item_trisula"
end

function item_trisula:OnSpellStart()
	local target   = self:GetCursorPosition()

	if target then
		GridNav:DestroyTreesAroundPoint(target, self:GetSpecialValueFor("chop_tree_radius"), true)
	end
end

function item_trisula:GetAOERadius()
	return self:GetSpecialValueFor("chop_tree_radius")
end
---------------------------------------------------------------------
--Modifiers
if modifier_item_trisula == nil then
	modifier_item_trisula = class({})
end
function modifier_item_trisula:IsDebuff() return false end
function modifier_item_trisula:IsHidden() return true end
function modifier_item_trisula:IsPurgable() return false end

function modifier_item_trisula:OnCreated(params)
	self.bonus_all_stats 				= self:GetAbility():GetSpecialValueFor("bonus_all_stats")
	self.bonus_attack_speed 			= self:GetAbility():GetSpecialValueFor("bonus_attack_speed")
	self.bonus_status_res 				= self:GetAbility():GetSpecialValueFor("bonus_status_res") 
	self.bonus_mana_regen_amp 			= self:GetAbility():GetSpecialValueFor("bonus_mana_regen_amp")
	self.bonus_ms 						= self:GetAbility():GetSpecialValueFor("bonus_ms")
	self.bonus_spell_amp 				= self:GetAbility():GetSpecialValueFor("bonus_spell_amp")
	self.bonus_spell_lifesteal_amp_pct 	= self:GetAbility():GetSpecialValueFor("bonus_spell_lifesteal_amp_pct")
	self.bonus_heal_amp_pct 			= self:GetAbility():GetSpecialValueFor("bonus_heal_amp_pct")

	self.cleave_damage_creep 			= self:GetAbility():GetSpecialValueFor('cleave_damage_creep')
	self.cleave_damage_hero 			= self:GetAbility():GetSpecialValueFor('cleave_damage_hero')
	self.cleave_range 					= self:GetAbility():GetSpecialValueFor('cleave_range')
	self.cleave_damage_illusion 		= self:GetAbility():GetSpecialValueFor('cleave_damage_illusion')
	self.cleave_illusion_pure 			= self:GetAbility():GetSpecialValueFor('cleave_illusion_pure')

	if IsServer() then
	end
end
function modifier_item_trisula:OnRefresh(params)
	if IsServer() then
	end
end
function modifier_item_trisula:OnDestroy()
	if IsServer() then
	end
end

function modifier_item_trisula:OnAttackLanded(params)
	if params.attacker ~= self:GetParent() then return end
	if not IsServer() then return end
	if params.damage_flags and Util:testflag(params.damage_flags, DOTA_DAMAGE_FLAG_TRISULA) then return end

	local caster = params.attacker
	local target = params.target
	local radius = self.cleave_range

	if not caster or not target then return end
	if not params.ranged_attack and caster:IsRangedAttacker() then return end
	if caster and caster:IsIllusion() then return end

	if not IsValidEntity(caster) or not IsValidEntity(target) then return end
	if not target:IsCreep() and not target:IsHero() then return end

	for _, modifier_name in pairs(forbidden_modifiers) do
		if caster:HasModifier(modifier_name) then return end
	end

	local team = caster:GetTeamNumber()
	local position = target:GetAbsOrigin()

	local units_in_radius = FindUnitsInRadius(
			team,
			position,
			nil,
			radius,
			DOTA_UNIT_TARGET_TEAM_ENEMY,
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_CREEP,
			DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
			0,
			false)

	if not units_in_radius then return end

	CreateParticleForCleave("particles/econ/items/faceless_void/faceless_void_weapon_bfury/faceless_void_weapon_bfury_cleave_c.vpcf", radius, target)

    print()

	for _,x in pairs(units_in_radius) do
		if x ~= params.target or x:IsIllusion() then
		    local dmg = 0
		    local cleave_physical_pierce = self:GetAbility():GetSpecialValueFor('cleave_physical_pierce')
		    local result_armor = target:GetPhysicalArmorValue(false) / 100 * (100 - cleave_physical_pierce)
		    local dmg_ref = params.original_damage * Util:ArmorDamageReductionByNumber(result_armor)

			if x:IsCreep() then
				dmg = dmg_ref / 100 * self.cleave_damage_creep
			end
			if x:IsIllusion() then
				dmg = dmg_ref / 100 * self.cleave_damage_illusion -- / 100 * self.cleave_illusion_pure

				ApplyDamage({ victim = x,
							  attacker = caster,
							  damage = dmg,
							  damage_type = DAMAGE_TYPE_PHYSICAL,
							  damage_flags = DOTA_DAMAGE_FLAG_IGNORES_PHYSICAL_ARMOR + DOTA_DAMAGE_FLAG_TRISULA,
							  ability = params.ability}) --deal damage

				dmg = dmg_ref / 100 * self.cleave_damage_illusion -- / 100 * (100 - self.cleave_illusion_pure)
			end
			if x:IsHero() then
				dmg = dmg_ref / 100 * self.cleave_damage_hero
			end
			if x:GetUnitName() == "npc_tree_thinker" then
				return
			end
			ApplyDamage({ victim = x,
						  attacker = caster,
						  damage = dmg,
						  damage_type = DAMAGE_TYPE_PHYSICAL,
						  damage_flags = DOTA_DAMAGE_FLAG_IGNORES_PHYSICAL_ARMOR + DOTA_DAMAGE_FLAG_TRISULA,
						  ability = params.ability}) --deal damage
		end
	end

	--'particles/units/heroes/hero_sven/sven_spell_great_cleave.vpcf'
end

function modifier_item_trisula:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_ATTACK_RANGE_BONUS_UNIQUE,
		MODIFIER_PROPERTY_STATUS_RESISTANCE,
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
		MODIFIER_PROPERTY_SPELL_LIFESTEAL_AMPLIFY_PERCENTAGE ,
		MODIFIER_PROPERTY_HP_REGEN_AMPLIFY_PERCENTAGE,
		MODIFIER_PROPERTY_MP_REGEN_AMPLIFY_PERCENTAGE,
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
		MODIFIER_PROPERTY_BASEATTACK_BONUSDAMAGE
	}
end
function modifier_item_trisula:GetModifierStatusResistance()
	return self.bonus_status_res
end
function modifier_item_trisula:GetModifierBonusStats_Strength()
	return self.bonus_all_stats
end
function modifier_item_trisula:GetModifierBonusStats_Agility()
	return self.bonus_all_stats
end
function modifier_item_trisula:GetModifierBonusStats_Intellect()
	return self.bonus_all_stats
end
function modifier_item_trisula:GetModifierAttackSpeedBonus_Constant()
	return self.bonus_attack_speed
end
function modifier_item_trisula:GetModifierSpellAmplify_Percentage()
	return self.bonus_spell_amp
end
function modifier_item_trisula:GetModifierSpellLifestealRegenAmplify_Percentage()
	return  self.bonus_spell_lifesteal_amp_pct
end
function modifier_item_trisula:GetModifierHPRegenAmplify_Percentage()
	return  self.bonus_heal_amp_pct
end
function modifier_item_trisula:GetModifierMPRegenAmplify_Percentage()
	return self.bonus_mana_regen_amp
end
function modifier_item_trisula:GetModifierMoveSpeedBonus_Percentage()
	return self.bonus_ms
end
function modifier_item_trisula:GetModifierBaseAttack_BonusDamage()
	return self.bonus_damage
end
function modifier_item_trisula:GetModifierAttackRangeBonusUnique()
	if self:GetParent():IsRangedAttacker() then
		return self:GetAbility():GetSpecialValueFor("bonus_range")
	else
		return 0
	end
end
