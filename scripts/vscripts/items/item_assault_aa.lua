LinkLuaModifier("modifier_assault_aa", "items/item_assault_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_assault_aa_aura_friend", "items/item_assault_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_assault_aa_aura_enemy_finder", "items/item_assault_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_assault_aa_aura_enemy", "items/item_assault_aa", LUA_MODIFIER_MOTION_NONE)

item_assault_3 = class({
    GetIntrinsicModifierName = function (self) return "modifier_assault_aa" end
})


modifier_assault_aa = class({
    Precache = function (self, context) PrecacheResource("particle", "particles/generic_gameplay/generic_lifesteal.vpcf", context) end,
    IsHidden = function (self) return true end,
    IsAura = function (self) return true end,
    GetAuraRadius = function (self) return self:GetAbility():GetSpecialValueFor("aura_radius") end,
    GetAuraSearchTeam = function (self) return DOTA_UNIT_TARGET_TEAM_FRIENDLY end,
    GetAuraSearchType = function (self) return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end,
    GetAuraSearchFlags = function (self) return DOTA_UNIT_TARGET_FLAG_NONE end,
    GetModifierAura = function (self) return "modifier_assault_aa_aura_friend" end,
    DeclareFunctions= function (self)
    return{
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
    }end,
    GetModifierPhysicalArmorBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_armor")end,
    GetModifierAttackSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("bonus_attack_speed")end,
    OnCreated = function (self) 
        if IsServer() then
            self.modifier = self:GetCaster():AddNewModifier(self:GetCaster(), self:GetAbility(), "modifier_assault_aa_aura_enemy_finder", {})
            print(self.modifier, self:GetCaster(), self:GetAbility())
        end
    end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT end,
    OnDestroy = function (self)
        if IsServer() then
            if self.modifier and not self.modifier:IsNull() then
                self.modifier:Destroy()
            end
        end
    end
})

modifier_assault_aa_aura_enemy_finder = class({
    IsHidden = function (self) return true end,
    IsAura = function (self) return true end,
    GetAuraRadius = function (self) return self:GetAbility():GetSpecialValueFor("aura_radius") end,
    GetAuraSearchTeam = function (self) return DOTA_UNIT_TARGET_TEAM_ENEMY end,
    GetAuraSearchType = function (self) return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end,
    GetAuraSearchFlags = function (self) return DOTA_UNIT_TARGET_FLAG_NONE end,
    GetModifierAura = function (self) return "modifier_assault_aa_aura_enemy" end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT end
})

modifier_assault_aa_aura_friend = class({
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return false end,
    IsBuff = function (self) return true end,
    OnTooltip = function(self) return self:GetAbility():GetSpecialValueFor("lifesteal_aura") end,
    DeclareFunctions = function (self)
    return{
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
        MODIFIER_PROPERTY_BASEDAMAGEOUTGOING_PERCENTAGE,
        MODIFIER_PROPERTY_TOOLTIP,
    }end,
    GetModifierPhysicalArmorBonus = function (self) return self:GetAbility():GetSpecialValueFor("aura_positive_armor") end,
    GetModifierAttackSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("aura_attack_speed") end,
    GetModifierConstantManaRegen = function (self) return self:GetAbility():GetSpecialValueFor("mana_regen_aura") end,
    GetModifierBaseDamageOutgoing_Percentage = function (self) return self:GetAbility():GetSpecialValueFor("damage_aura") end,
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
    OnAttackLanded = function (self,keys) 
        if self:GetCaster():GetTeamNumber() ~= self:GetParent():GetTeamNumber() then return end
        if keys.attacker == self:GetParent() then
            local dmg_ref = keys.original_damage * Util:ArmorDamageReductionByNumber(keys.target:GetPhysicalArmorValue(false))
            print(dmg_ref)
            local vampirism_pct = self:GetAbility():GetSpecialValueFor("lifesteal_aura")
            local damage = dmg_ref * vampirism_pct / 100
            self:GetParent():Heal(damage, self:GetAbility())

            local particle = ParticleManager:CreateParticle("particles/generic_gameplay/generic_lifesteal.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
            ParticleManager:SetParticleControl(particle, 0, self:GetParent():GetAbsOrigin())
            ParticleManager:ReleaseParticleIndex(particle)
        end
    end,
    
})

modifier_assault_aa_aura_enemy = class({
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return false end,
    IsDebuff = function (self) return true end,
    DeclareFunctions= function (self)
        return{
            MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
    }end,
    GetModifierPhysicalArmorBonus = function (self) return self:GetAbility():GetSpecialValueFor("aura_negative_armor") end,
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
})


