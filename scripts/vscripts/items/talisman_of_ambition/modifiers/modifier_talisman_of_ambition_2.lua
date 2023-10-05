modifier_talisman_of_ambition_2 = class({
	IsHidden = function (self) return true end,
	IsPurgable = function (self) return false end,
	DestroyOnExpire = function (self) return false end,
	GetAttributes = function (self) return MODIFIER_ATTRIBUTE_PERMANENT end,
	DeclareFunctions = function (self) return {
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
        MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
		MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
	}
	end,
	GetModifierPhysicalArmorBonus = function (self) return  self:GetAbility():GetSpecialValueFor("bonus_armor") end,
	GetModifierBonusStats_Strength = function (self) return self:GetAbility():GetSpecialValueFor("bonus_str") end,
    GetModifierBonusStats_Agility = function (self) return self:GetAbility():GetSpecialValueFor("bonus_agi")end,
    GetModifierBonusStats_Intellect = function (self) return self:GetAbility():GetSpecialValueFor("bonus_int")end,
	GetModifierMoveSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("bonus_movespeed") end,
	GetModifierAttackSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("attack_speed_pasive") end,
})