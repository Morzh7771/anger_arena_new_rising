LinkLuaModifier("modifier_item_dark_edge", "items/item_dark_edge", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_dark_edge_debuff", "items/item_dark_edge", LUA_MODIFIER_MOTION_NONE)

item_dark_edge = class({
    GetIntrinsicModifierName = function(self) return 'modifier_item_dark_edge' end,
    OnSpellStart = function (self)
        EmitSoundOn("DOTA_Item.MaskOfMadness.Activate", self:GetCaster())
        self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_item_silver_edge_windwalk", {duration = self:GetSpecialValueFor("windwalk_duration")})
    end
})

modifier_item_dark_edge = class({
    IsHidden = function(self) return true end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
    DeclareFunctions = function(self) return {
            MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
            MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
            MODIFIER_EVENT_ON_ATTACK_LANDED,
            MODIFIER_PROPERTY_STATS_STRENGTH_BONUS, -- GetModifierBonusStats_Strength
            MODIFIER_PROPERTY_STATS_AGILITY_BONUS, -- GetModifierBonusStats_Agility
            MODIFIER_PROPERTY_STATS_INTELLECT_BONUS, -- GetModifierBonusStats_Intellect
            MODIFIER_PROPERTY_HEALTH_BONUS,
            MODIFIER_PROPERTY_MANA_BONUS,
            MODIFIER_EVENT_ON_ATTACK_LANDED,
        }end,
    GetModifierPreAttack_BonusDamage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_damage") end,
    GetModifierAttackSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("bonus_attack_speed") end,
    GetModifierBonusStats_Strength = function (self) return self:GetAbility():GetSpecialValueFor("bonus_all_stats") end,
    GetModifierBonusStats_Agility = function (self) return self:GetAbility():GetSpecialValueFor("bonus_all_stats") end,
    GetModifierBonusStats_Intellect = function (self) return self:GetAbility():GetSpecialValueFor("bonus_all_stats") end,
    GetModifierHealthBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_health") end,
    GetModifierManaBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_mana") end,
    OnAttackLanded = function (self,keys) 
        if keys.attacker == self:GetParent() then
            keys.target:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_item_skadi_slow", {duration = self:GetAbility():GetSpecialValueFor("cold_duration")})
        end
    end,
})