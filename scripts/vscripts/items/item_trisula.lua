LinkLuaModifier( "modifier_item_trisula", "items/item_trisula.lua", LUA_MODIFIER_MOTION_NONE )
--Abilities
if item_trisula == nil then
	item_trisula = class({})
end
function item_trisula:GetIntrinsicModifierName()
	return "modifier_item_trisula"
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
	self.bonus_str = self:GetAbility():GetSpecialValueFor("bonus_str")
	self.bonus_agi = self:GetAbility():GetSpecialValueFor("bonus_agi") 
	self.bonus_int = self:GetAbility():GetSpecialValueFor("bonus_int")
	self.bonus_attack_speed = self:GetAbility():GetSpecialValueFor("bonus_attack_speed")
	self.bonus_status_res = self:GetAbility():GetSpecialValueFor("bonus_status_res") 
	self.bonus_mana_regen_amp = self:GetAbility():GetSpecialValueFor("bonus_mana_regen_amp")
	self.bonus_ms = self:GetAbility():GetSpecialValueFor("bonus_ms")
	self.bonus_spell_amp = self:GetAbility():GetSpecialValueFor("bonus_spell_amp")
	self.bonus_spell_lifesteal_amp_pct = self:GetAbility():GetSpecialValueFor("bonus_spell_lifesteal_amp_pct")
	self.bonus_heal_amp_pct = self:GetAbility():GetSpecialValueFor("bonus_heal_amp_pct")

	self.cleave_damage_creep = self:GetAbility():GetSpecialValueFor('cleave_damage_creep')
	self.cleave_damage_hero = self:GetAbility():GetSpecialValueFor('cleave_damage_hero')
	self.cleave_range = self:GetAbility():GetSpecialValueFor('cleave_range')

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
	if params.attacker == self.caster then return end
	if params.ranged_attack then return end

	if params.target:IsCreep() then
		cleave_damage = params.damage / 100 * self.cleave_damage_creep
	else
		cleave_damage = params.damage / 100 * self.cleave_damage_hero
	end

	DoCleaveAttack(
			params.attacker,
			params.target,
			nil,
			cleave_damage,
			150,
			360,
			self.cleave_range,
			'particles/units/heroes/hero_sven/sven_spell_great_cleave.vpcf'
	)
end

function modifier_item_trisula:DeclareFunctions()
	return {
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
	return self.bonus_str
end
function modifier_item_trisula:GetModifierBonusStats_Agility()
	return self.bonus_agi
end
function modifier_item_trisula:GetModifierBonusStats_Intellect()
	return self.bonus_int
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
