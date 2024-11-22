LinkLuaModifier( "modifier_base_butterfly", "items/item_butterfly", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_burning_butterfly", "items/item_butterfly", LUA_MODIFIER_MOTION_NONE )

item_sacred_butterfly = class({
    GetIntrinsicModifierName = function (self) return "modifier_base_butterfly" end
})

item_burning_butterfly = item_sacred_butterfly
    
modifier_base_butterfly = class({
    DeclareFunctions = function (self)
        local funcs = {
            MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
            MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
            MODIFIER_PROPERTY_ATTACKSPEED_PERCENTAGE,
            MODIFIER_PROPERTY_EVASION_CONSTANT,
            MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        }
        if self:GetAbility():GetName() == "item_burning_butterfly" then table.insert(funcs, MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE ) end
        return funcs
    end,
    IsBuff = function (self) return true end,
    IsDebuff = function (self) return false end,
    IsHidden = function (self) return true end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end,
    GetModifierMoveSpeedBonus_Percentage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_mvspd_pct") end,
    GetModifierEvasion_Constant = function (self) return self:GetAbility():GetSpecialValueFor("bonus_evasion") end,
    GetModifierPreAttack_BonusDamage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_damage") end,
    GetModifierAttackSpeedPercentage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_attack_speed_pct") end,
    GetModifierBonusStats_Agility = function (self) return self:GetAbility():GetSpecialValueFor("bonus_agi") end,
    GetModifierIncomingDamage_Percentage = function (self)
        if RollPercentage(self:GetAbility():GetSpecialValueFor("absorb_chance")) then
            local backtrack_fx = ParticleManager:CreateParticle("particles/econ/items/faceless_void/faceless_void_bracers_of_aeons/fv_bracers_of_aeons_backtrack.vpcf", PATTACH_ABSORIGIN, self:GetCaster())
            ParticleManager:SetParticleControl(backtrack_fx, 0, self:GetCaster():GetAbsOrigin())
            ParticleManager:ReleaseParticleIndex(backtrack_fx)
            SendOverheadEventMessage(nil, OVERHEAD_ALERT_EVADE, self:GetCaster(), 0,nil)
            return -100
        end
    end,
})