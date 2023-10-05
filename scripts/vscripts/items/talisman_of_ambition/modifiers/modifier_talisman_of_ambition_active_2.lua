modifier_talisman_of_ambition_active_2 = class({
	IsHidden = function (self) return false end,
	RemoveOnDeath = function (self) return true end,
	IsDebuff = function (self) return false end,
	IsPurgable = function (self) return true end,
	DestroyOnExpire = function (self) return true end,
	GetStatusEffectName = function (self) return "particles/status_fx/status_effect_blur.vpcf" end,
	GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
	DeclareFunctions = function (self) return {
		MODIFIER_PROPERTY_EVASION_CONSTANT,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_PHYSICAL_CONSTANT_BLOCK,
	}end,
	GetModifierEvasion_Constant = function (self) return self:GetAbility():GetSpecialValueFor("evasion") end,
	GetModifierAttackSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("attack_speed_active") end,
	GetModifierPhysical_ConstantBlock = function (self) return self:GetAbility():GetSpecialValueFor("block_damage") end,
})
