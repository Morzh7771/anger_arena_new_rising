LinkLuaModifier('modifier_power_treads_3', 'items/item_power_treads_3', LUA_MODIFIER_MOTION_NONE)

item_power_treads_3 = class({
	GetIntrinsicModifierName = function (self) return 'modifier_power_treads_3' end,
	OnSpellStart = function (self)
		local stat = self:GetCaster():FindModifierByName("modifier_power_treads_3"):GetStackCount()
		if stat + 1 > 3 then
			stat = 0
		end
		self:GetCaster():FindModifierByName("modifier_power_treads_3"):SetStackCount(stat + 1)
		self:SetCurrentCharges(stat + 1)
		-- статы переключаются сразу, не дожидаясь планового пересчёта (раз в 0.5 с)
		self:GetCaster():CalculateStatBonus(true)
	end,
	GetAbilityTextureName = function (self)
		return "pt" ..  self:GetCurrentCharges()
	end,
})


modifier_power_treads_3 = class({
	IsHidden = function (self) return true end,
	OnCreated = function (self)
		-- GetPrimaryAttribute, заряды и CalculateStatBonus - серверные; стак и
		-- заряды клиенту приезжают сами. На клиенте тут падало при покупке.
		if not IsServer() then return end

		local parent = self:GetParent()
		-- у курьера и прочих не-героев (тред в сумке курьера) атрибута нет
		local primary = parent.GetPrimaryAttribute and parent:GetPrimaryAttribute() or nil
		local ownerHero = parent:IsIllusion() and PlayerResource:GetSelectedHeroEntity(parent:GetPlayerOwnerID()) or nil
		local ownerMod = ownerHero and ownerHero:FindModifierByName("modifier_power_treads_3") or nil

		if ownerMod then
			self:SetStackCount(ownerMod:GetStackCount())
		else
			if primary == DOTA_ATTRIBUTE_STRENGTH  then
				self:SetStackCount(1) 
				self:GetAbility():SetCurrentCharges(1)
			elseif primary == DOTA_ATTRIBUTE_AGILITY then
				self:SetStackCount(3)
				self:GetAbility():SetCurrentCharges(3)
			elseif primary == DOTA_ATTRIBUTE_INTELLECT  then
				self:SetStackCount(2) 
				self:GetAbility():SetCurrentCharges(2)
			else
				self:SetStackCount(1) 
				self:GetAbility():SetCurrentCharges(1)
			end
		end
		-- CalculateStatBonus - полный пересчёт статов героя, он дёргает все
		-- модификаторы героя. 10 раз в секунду у Gyrocopter в логе 2026-11-24
		-- совпало с "thinking for 15-70 ms". При переключении зовём сразу (OnSpellStart).
		self:StartIntervalThink(0.5)
	end,
	OnIntervalThink = function (self)
		local caster = self:GetCaster()
		if caster and caster.CalculateStatBonus then caster:CalculateStatBonus(true) end
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

