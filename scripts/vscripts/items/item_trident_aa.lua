LinkLuaModifier( "modifier_item_trident_aa", "items/item_trident_aa.lua", LUA_MODIFIER_MOTION_NONE )
--Abilities
if item_trident_aa == nil then
	item_trident_aa = class({})
end
function item_trident_aa:GetIntrinsicModifierName()
	return "modifier_item_trident_aa"
end
---------------------------------------------------------------------
--Modifiers
if modifier_item_trident_aa == nil then
	modifier_item_trident_aa = class({})
end
function modifier_item_trident_aa:IsDebuff() return false end
function modifier_item_trident_aa:IsHidden() return false end
function modifier_item_trident_aa:IsPurgable() return false end

function modifier_item_trident_aa:OnCreated(params)
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
	     
	if IsServer() then
	end
end
function modifier_item_trident_aa:OnRefresh(params)
	if IsServer() then
	end
end
function modifier_item_trident_aa:OnDestroy()
	if IsServer() then
	end
end
function modifier_item_trident_aa:DeclareFunctions()
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
	}
end
function modifier_item_trident_aa:GetModifierStatusResistance()
	return self.bonus_status_res
end
function modifier_item_trident_aa:GetModifierBonusStats_Strength()
	return self.bonus_str
end
function modifier_item_trident_aa:GetModifierBonusStats_Agility()
	return self.bonus_agi
end
function modifier_item_trident_aa:GetModifierBonusStats_Intellect()
	return self.bonus_int
end
function modifier_item_trident_aa:GetModifierAttackSpeedBonus_Constant()
	return self.bonus_attack_speed
end
function modifier_item_trident_aa:GetModifierSpellAmplify_Percentage()
	return self.bonus_spell_amp
end
function modifier_item_trident_aa:GetModifierSpellLifestealRegenAmplify_Percentage()
	return  self.bonus_spell_lifesteal_amp_pct
end
function modifier_item_trident_aa:GetModifierHPRegenAmplify_Percentage()
	return  self.bonus_heal_amp_pct
end
function modifier_item_trident_aa:GetModifierMPRegenAmplify_Percentage()
	return self.bonus_mana_regen_amp
end
function modifier_item_trident_aa:GetModifierMoveSpeedBonus_Percentage()
	return self.bonus_ms
end
