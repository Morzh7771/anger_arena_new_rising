LinkLuaModifier("modifier_item_bracer_custom", "items/item_bracer_custom", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_bracer_custom_heal", "/items/item_bracer_custom", LUA_MODIFIER_MOTION_NONE)

item_bracer_custom = class({
    GetIntrinsicModifierName = function (self) return "modifier_item_bracer_custom" end,
    OnSpellStart = function (self) 
        self:GetParent():EmitSound("DOTA_Item.TranquilBoots.Activate")
        self:GetParent():AddNewModifier(self:GetParent(), self, "modifier_item_bracer_custom_heal", {duration = self:GetSpecialValueFor("duration")})
    end
})

modifier_item_bracer_custom = class({
    IsHidden = function (self) return true end,
    IsPurgable = function (self) return false end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
        MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
    } end,
    GetModifierBonusStats_Strength = function (self) if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("str") * math.floor(GameRules:GetGameTime() / 600) end end,
    GetModifierBonusStats_Intellect = function (self) if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("int") * math.floor(GameRules:GetGameTime() / 600) end end,
    GetModifierBonusStats_Agility = function (self) if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("agi") * math.floor(GameRules:GetGameTime() / 600) end end,
    GetModifierPreAttack_BonusDamage = function (self) if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("damage") * math.floor(GameRules:GetGameTime() / 600) end end,
    GetModifierConstantHealthRegen = function (self) if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("regen") * math.floor(GameRules:GetGameTime() / 600) end end,
})

modifier_item_bracer_custom_heal = class({
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return true end,
    GetEffectName = function (self) return "particles/items2_fx/tranquil_boots.vpcf" end,
    DeclareFunctions = function (self) return {MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT} end,
    GetModifierConstantHealthRegen = function (self) return self.heal*self:GetStackCount() end,
    OnCreated = function (self) 
        self.heal = self:GetAbility():GetSpecialValueFor("heal")/self:GetAbility():GetSpecialValueFor("duration") * math.floor(GameRules:GetGameTime() / 600)

        if not IsServer() then return end

        for _,mod in pairs(self:GetParent():FindAllModifiers()) do 
            if mod:GetName() == "modifier_item_bracer_custom" then 
                self:IncrementStackCount()
            end
        end
    end,
})

