LinkLuaModifier('modifier_power_treads_3', 'items/item_power_treads_3', LUA_MODIFIER_MOTION_NONE)
local kastil = 0
item_power_treads_3 = class({
	GetIntrinsicModifierName = function (self) return 'modifier_power_treads_3' end,
	OnSpellStart = function (self)
		local stat = self:GetCaster():FindModifierByName("modifier_power_treads_3"):GetStackCount()
		if stat + 1 > 3 then
			stat = 0
		end
		self:GetCaster():FindModifierByName("modifier_power_treads_3"):SetStackCount(stat + 1)
	end,
	GetAbilityTextureName = function (self)
		return "pt" .. self:GetCaster():FindModifierByName("modifier_power_treads_3"):GetStackCount()
	end,
})


modifier_power_treads_3 = class({
	IsHidden = function (self) return false end,
	OnCreated = function (self) 
		if self:GetParent():IsIllusion() then
			self:SetStackCount(PlayerResource:GetSelectedHeroEntity( self:GetParent():GetPlayerOwnerID() ):FindModifierByName("modifier_power_treads_3"):GetStackCount())
		else
			if self:GetParent():GetPrimaryAttribute() == DOTA_ATTRIBUTE_STRENGTH  then
				self:SetStackCount(1) 
			elseif self:GetParent():GetPrimaryAttribute() == DOTA_ATTRIBUTE_AGILITY then
				self:SetStackCount(3) 
			elseif self:GetParent():GetPrimaryAttribute() == DOTA_ATTRIBUTE_INTELLECT  then
				self:SetStackCount(2) 
			else
				self:SetStackCount(1) 
			end
		end
		self:StartIntervalThink(0.1)
	end,
	OnIntervalThink = function (self)
		self:GetCaster():CalculateStatBonus(true)
	end,
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
		if self:GetStackCount() == 1 then
			return self:GetAbility():GetSpecialValueFor('bonus_stat')
		else
			return self:GetAbility():GetSpecialValueFor('bonus_stat')/2
		end
	end,
	GetModifierBonusStats_Agility = function (self) 
		if self:GetStackCount() == 3 then
			return self:GetAbility():GetSpecialValueFor('bonus_stat')
		else
			return self:GetAbility():GetSpecialValueFor('bonus_stat')/2
		end
	end,
	GetModifierBonusStats_Intellect = function (self)  
		if self:GetStackCount() == 2 then
			return self:GetAbility():GetSpecialValueFor('bonus_stat')
		else
			return self:GetAbility():GetSpecialValueFor('bonus_stat')/2
		end
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

