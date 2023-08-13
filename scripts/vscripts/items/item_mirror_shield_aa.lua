LinkLuaModifier('modifier_mirror_shield_aa', 'items/item_mirror_shield_aa', LUA_MODIFIER_MOTION_NONE)

item_mirror_shield_aa = class({
	GetIntrinsicModifierName = function (self) return 'modifier_mirror_shield_aa' end
	})

modifier_mirror_shield_aa = class({
	IsHidden = 			function (self) return true end,
	DeclareFunctions =	function (self) return
	{
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
		MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_REFLECT_SPELL,
		MODIFIER_PROPERTY_ABSORB_SPELL,
		MODIFIER_PROPERTY_MANA_BONUS
	}
	end,
	GetModifierBonusStats_Strength = function (self) 
		return self:GetAbility():GetSpecialValueFor('bonus_all_stats')
	end,
	GetModifierBonusStats_Agility = function (self) 
		return self:GetAbility():GetSpecialValueFor('bonus_all_stats')
	end,
	GetModifierBonusStats_Intellect = function (self)  
		return self:GetAbility():GetSpecialValueFor('bonus_all_stats')
	end,
	GetModifierConstantHealthRegen = function (self) 
		return self:GetAbility():GetSpecialValueFor('bonus_health_regen')
	end,
	GetModifierConstantManaRegen = function (self) 
		return self:GetAbility():GetSpecialValueFor('bonus_mana_regen')
	end,
	GetModifierPreAttack_BonusDamage = function (self) 
		return self:GetAbility():GetSpecialValueFor('bonus_damage')
	end,
	GetModifierPhysicalArmorBonus = function (self) 
		return self:GetAbility():GetSpecialValueFor('bonus_armor')
	end,
	GetModifierManaBonus = function (self)	
		return self:GetAbility():GetSpecialValueFor('bonus_mana')
	end
	})

	function modifier_mirror_shield_aa:GetReflectSpell()

	end

	function modifier_mirror_shield_aa:GetAbsorbSpell()
		if not self:GetAbility():IsFullyCastable() then return 0 end
		self:GetAbility():UseResources(false, false, false, true)
		return 1
	end


