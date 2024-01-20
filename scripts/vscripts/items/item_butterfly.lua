item_sacred_butterfly = class({
    GetIntrinsicModifierName = function (self) return "modifier_sacred_butterfly" end
})
item_burning_butterfly = class({
    GetIntrinsicModifierName = function (self) return "modifier_burning_butterfly" end
})
LinkLuaModifier( "modifier_sacred_butterfly", "items/item_butterfly", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_burning_butterfly", "items/item_butterfly", LUA_MODIFIER_MOTION_NONE )
modifier_sacred_butterfly = class({
    DeclareFunctions = function (self)
        return {
            MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
            MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
            MODIFIER_PROPERTY_ATTACKSPEED_PERCENTAGE,
            MODIFIER_PROPERTY_EVASION_CONSTANT,
            MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        }
    end,
    IsBuff = function (self) return true end,
    IsDebuff = function (self) return false end,
    IsHidden = function (self) return true end,
    GetAttributes = function (self) return  MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end,
    GetModifierMoveSpeedBonus_Percentage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_mvspd_pct") end,
    GetModifierEvasion_Constant = function (self) return self:GetAbility():GetSpecialValueFor("bonus_evasion") end,
    GetModifierPreAttack_BonusDamage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_damage") end,
    GetModifierAttackSpeedPercentage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_attack_speed_pct") end,
    GetModifierBonusStats_Agility = function (self) return self:GetAbility():GetSpecialValueFor("bonus_agi") end,
})
modifier_burning_butterfly = class({
    DeclareFunctions = function (self)
        return {
            MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
            MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
            MODIFIER_PROPERTY_ATTACKSPEED_PERCENTAGE,
            MODIFIER_PROPERTY_EVASION_CONSTANT,
            MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
            MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
        }
    end,
    IsBuff = function (self) return true end,
    IsDebuff = function (self) return false end,
    IsHidden = function (self) return true end,
    GetAttributes = function (self) return  MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end,
    GetModifierMoveSpeedBonus_Percentage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_mvspd_pct") end,
    GetModifierEvasion_Constant = function (self) return self:GetAbility():GetSpecialValueFor("bonus_evasion") end,
    GetModifierPreAttack_BonusDamage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_damage") end,
    GetModifierAttackSpeedPercentage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_attack_speed_pct") end,
    GetModifierBonusStats_Agility = function (self) return self:GetAbility():GetSpecialValueFor("bonus_agi") end,
})

function modifier_burning_butterfly:GetModifierIncomingDamage_Percentage()
	local caster	=	self:GetCaster()
		if RollPercentage(self:GetAbility():GetSpecialValueFor("absorb_chance")) then
			local backtrack_fx = ParticleManager:CreateParticle("particles/units/heroes/hero_faceless_void/faceless_void_backtrack.vpcf", PATTACH_ABSORIGIN, caster)
			ParticleManager:SetParticleControl(backtrack_fx, 0, caster:GetAbsOrigin())
			ParticleManager:ReleaseParticleIndex(backtrack_fx)
			return -100
		end
end