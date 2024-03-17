LinkLuaModifier('modifier_power_treads_3', 'items/item_power_treads_3', LUA_MODIFIER_MOTION_NONE)

item_power_treads_3 = class({
	GetIntrinsicModifierName = function (self) return 'modifier_power_treads_3' end
})

modifier_power_treads_3 = class({
	IsHidden = 			function (self) return true end,
	DeclareFunctions =	function (self) return
	{
		MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,	
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT
	}
	end,
	GetModifierBonusStats_Strength = function (self) 
		return self:GetAbility():GetSpecialValueFor('bonus_stat')
	end,
	GetModifierBonusStats_Agility = function (self) 
		return self:GetAbility():GetSpecialValueFor('bonus_stat')
	end,
	GetModifierBonusStats_Intellect = function (self)  
		return self:GetAbility():GetSpecialValueFor('bonus_stat')
	end,
	GetModifierMoveSpeedBonus_Constant = function (self)
		if self:GetCaster():IsRangedAttacker() then 
			return self:GetAbility():GetSpecialValueFor('bonus_movement_speed_ranged')
		else 
			return self:GetAbility():GetSpecialValueFor('bonus_movement_speed_melee')
		end
	end,
	GetModifierAttackSpeedBonus_Constant = function (self)
		return self:GetAbility():GetSpecialValueFor('bonus_attack_speed')
	end
})

