item_bkb_aa_1 = class({
	GetIntrinsicModifierName = function (self) return "modifier_item_bkb_aa" end
})
item_bkb_aa_2 = item_bkb_aa_1
item_bkb_aa_3 = item_bkb_aa_1

LinkLuaModifier( "modifier_item_bkb_aa", "items/item_bkb_aa.lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_generic_debuff_immune", "modifiers/modifier_generic_debuff_immune.lua", LUA_MODIFIER_MOTION_NONE )

function item_bkb_aa_1:OnSpellStart()
	self.caster = self:GetCaster()
	self.duration = self:GetSpecialValueFor("duration")
	self.caster:AddNewModifier(self.caster, self, "modifier_generic_debuff_immune", {effect = 1 , duration = self.duration})
	self.caster:Purge( false, true, false, false, false )
end

modifier_item_bkb_aa = class({
	IsHidden = function (self) return true end,
	DeclareFunctions = function (self) return {
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE 
	} end,
	GetModifierBonusStats_Strength = function (self) return self:GetAbility():GetSpecialValueFor("bonus_strength") end,
	GetModifierPreAttack_BonusDamage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_damage") end,
})
