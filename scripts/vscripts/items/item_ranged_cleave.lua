
item_ranged_cleave = class({})
item_ranged_cleave2 = class({})
item_ranged_cleave3 = class({})

LinkLuaModifier("modifier_item_ranged_cleave", "items/item_ranged_cleave", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_ranged_cleave_reduced_damage", "items/item_ranged_cleave", LUA_MODIFIER_MOTION_NONE)


function item_ranged_cleave:GetIntrinsicModifierName()
	return "modifier_item_ranged_cleave"
end

function item_ranged_cleave2:GetIntrinsicModifierName()
	return "modifier_item_ranged_cleave"
end

function item_ranged_cleave3:GetIntrinsicModifierName()
	return "modifier_item_ranged_cleave"
end



modifier_item_ranged_cleave = class({})

function modifier_item_ranged_cleave:IsDebuff() return false end
function modifier_item_ranged_cleave:IsHidden() return true end
function modifier_item_ranged_cleave:IsPurgable() return false end
function modifier_item_ranged_cleave:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE end

function modifier_item_ranged_cleave:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_ATTACK_RANGE_BONUS_UNIQUE,
		MODIFIER_EVENT_ON_ATTACK,
		MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE
	}
	return funcs
end

function modifier_item_ranged_cleave:GetModifierBonusStats_Strength()
	return self:GetAbility():GetSpecialValueFor("bonus_str")
end

function modifier_item_ranged_cleave:GetModifierBonusStats_Agility()
	return self:GetAbility():GetSpecialValueFor("bonus_agi")
end

function modifier_item_ranged_cleave:GetModifierPreAttack_BonusDamage()
	return self:GetAbility():GetSpecialValueFor("bonus_dmg")
end

function modifier_item_ranged_cleave:GetModifierAttackRangeBonusUnique()
	if self:GetParent():IsRangedAttacker() then
		return self:GetAbility():GetSpecialValueFor("bonus_range")
	else
		return 0
	end
end

function modifier_item_ranged_cleave:GetModifierDamageOutgoing_Percentage()
	if not IsServer() then return end
	
	if self.bSplitShot then
		return self:GetAbility():GetSpecialValueFor("split_shot_damage")
	else
		return 0
	end
end


function modifier_item_ranged_cleave:OnAttack(keys)
	if not IsServer() then return end

    if keys.attacker == self:GetParent() then
       --PrintTable(keys)
    end
    
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


modifier_item_ranged_cleave_reduced_damage = class({})

function modifier_item_ranged_cleave_reduced_damage:IsDebuff() return false end
function modifier_item_ranged_cleave_reduced_damage:IsHidden() return true end
function modifier_item_ranged_cleave_reduced_damage:IsPurgable() return false end
function modifier_item_ranged_cleave_reduced_damage:GetAttributes() return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE end


function modifier_item_ranged_cleave_reduced_damage:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE,
		MODIFIER_EVENT_ON_ATTACK_LANDED
	}
	return funcs
end


function modifier_item_ranged_cleave_reduced_damage:OnAttackLanded()
	local funcs = {
		self:GetParent():RemoveModifierByName("modifier_item_ranged_cleave_reduced_damage")
	}
	return funcs
end




function modifier_item_ranged_cleave_reduced_damage:GetModifierDamageOutgoing_Percentage()

	return -1*(100 - self:GetAbility():GetSpecialValueFor("split_shot_damage"))

end
