LinkLuaModifier("modifier_item_mask_of_madness_aa", "items/item_mask_of_madness", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_mask_of_madness_aa_active", "items/item_mask_of_madness", LUA_MODIFIER_MOTION_NONE)

item_mask_of_madness_aa = class({
    GetIntrinsicModifierName = function(self) return 'modifier_item_mask_of_madness_aa' end,
    OnSpellStart = function (self)
        EmitSoundOn("DOTA_Item.MaskOfMadness.Activate", self:GetCaster())
        self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_item_mask_of_madness_aa_active", {duration = self:GetSpecialValueFor("berserk_duration")})
    end
})

item_mask_of_madness_aa_1 = item_mask_of_madness_aa
item_mask_of_madness_aa_2 = item_mask_of_madness_aa
item_mask_of_madness_aa_3 = item_mask_of_madness_aa

modifier_item_mask_of_madness_aa = class({
    IsHidden = function(self) return true end,
    IsPurgable = function(self) return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
    DeclareFunctions = function(self) return {
            MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
            MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
            MODIFIER_EVENT_ON_ATTACK_LANDED,
        }end,
    GetModifierPhysicalArmorBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_armor") end,
    GetModifierPreAttack_BonusDamage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_damage") end,
     OnAttackLanded = function (self,keys) 
        if self:GetCaster():GetTeamNumber() ~= self:GetParent():GetTeamNumber() then return end
        if keys.attacker == self:GetParent() then
            local dmg_ref = keys.original_damage * Util:ArmorDamageReductionByNumber(keys.target:GetPhysicalArmorValue(false))
            print(dmg_ref)
            local vampirism_pct = self:GetAbility():GetSpecialValueFor("bonus_lifesteal")
            local damage = dmg_ref * vampirism_pct / 100
            self:GetParent():Heal(damage, self:GetAbility())

            local particle = ParticleManager:CreateParticle("particles/generic_gameplay/generic_lifesteal.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
            ParticleManager:SetParticleControl(particle, 0, self:GetParent():GetAbsOrigin())
            ParticleManager:ReleaseParticleIndex(particle)
        end
    end,
})

modifier_item_mask_of_madness_aa_active = class({
    IsHidden = function(self) return false end,
    IsPurgable = function(self) return true end,
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
    DeclareFunctions = function(self) return {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
    }end,
    OnCreated = function (self,kv) 
        if not IsServer() then return end
        self.pfx = ParticleManager:CreateParticle("particles/items2_fx/mask_of_madness.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
    end,
    OnDestroy = function (self,kv) 
        if not IsServer() then return end
        ParticleManager:DestroyParticle(self.pfx, true)
    end,
    GetModifierPhysicalArmorBonus = function (self) return - self:GetAbility():GetSpecialValueFor("berserk_armor_reduction") end,
    GetModifierAttackSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("berserk_bonus_attack_speed") end,
    GetModifierMoveSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("berserk_bonus_movement_speed") end,
})