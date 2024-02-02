LinkLuaModifier("modifier_item_ranged_cleave", "items/item_ranged_cleave", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_ranged_cleave_reduced_damage", "items/item_ranged_cleave", LUA_MODIFIER_MOTION_NONE)

item_ranged_cleave = class({
	GetIntrinsicModifierName = function (self) return "modifier_item_ranged_cleave" end,
})
item_ranged_cleave2 = item_ranged_cleave


modifier_item_ranged_cleave = class({
	IsDebuff = function (self) return false end,
	IsHidden = function (self) return true end,
	IsPurgable = function (self) return false end,
	GetAttributes = function (self) return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE end,
	DeclareFunctions = function (self) return {
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_ATTACK_RANGE_BONUS_UNIQUE,
		MODIFIER_EVENT_ON_ATTACK,
		MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE
	} end,
	GetModifierBonusStats_Agility = function (self) return self:GetAbility():GetSpecialValueFor("bonus_agi") end,
	GetModifierBonusStats_Strength = function (self) return self:GetAbility():GetSpecialValueFor("bonus_str") end,
	GetModifierPreAttack_BonusDamage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_dmg") end,
	GetModifierAttackRangeBonusUnique = function (self) 
		if self:GetParent():IsRangedAttacker() then
			return self:GetAbility():GetSpecialValueFor("bonus_range")
		else
			return 0
		end 
	end,
	GetModifierDamageOutgoing_Percentage = function (self) 
		if not IsServer() then return end
	
		if self.bSplitShot then
			return self:GetAbility():GetSpecialValueFor("split_shot_damage")
		else
			return 0
		end
	end,
})


function modifier_item_ranged_cleave:OnAttack(keys)
	if not IsServer() then return end
    
	if keys.attacker == self:GetParent() and self:GetParent():IsRangedAttacker() and keys.target and keys.target:GetTeamNumber() ~= self:GetParent():GetTeamNumber() and not keys.no_attack_cooldown then	
		
		if not self:GetParent():IsIllusion() then
			local enemies = FindUnitsInRadius(
			self:GetParent():GetTeamNumber(),
			keys.target:GetAbsOrigin(), 
			keys.target, 
			self:GetAbility():GetSpecialValueFor("radius"), 
			DOTA_UNIT_TARGET_TEAM_ENEMY, 
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_CREEP, 
			DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_NO_INVIS, 
			0,
			false)
			local nTargetNumber = 0		
			for _, hEnemy in pairs(enemies) do
				if hEnemy ~= keys.target then
					self:GetParent():AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_item_ranged_cleave_reduced_damage", {})				
					self:GetParent():PerformAttack (hEnemy,true,false,true,false,true,false,false)	
					
					nTargetNumber = nTargetNumber + 1
					
					if nTargetNumber >= self:GetAbility():GetSpecialValueFor("max_target") then
						break
					end
				end
			end
		end
	end
end


modifier_item_ranged_cleave_reduced_damage = class({
	IsDebuff = function (self) return false end,
	IsHidden = function (self) return true end,
	IsPurgable = function (self) return false end,
	GetAttributes = function (self) return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE end,
	DeclareFunctions = function (self) return {
		MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE,
		MODIFIER_EVENT_ON_ATTACK_LANDED
	} end,
	OnAttackLanded = function (self) return{
		self:GetParent():RemoveModifierByName("modifier_item_ranged_cleave_reduced_damage")
	}end,
	GetModifierDamageOutgoing_Percentage = function (self) return -1*(100 - self:GetAbility():GetSpecialValueFor("split_shot_damage")) end,
})
