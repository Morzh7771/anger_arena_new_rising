LinkLuaModifier("modifier_item_chest_of_midas", "items/item_chest_of_midas", LUA_MODIFIER_MOTION_NONE)
item_chest_of_midas = class({
    GetIntrinsicModifierName = function (self) return "modifier_item_chest_of_midas" end
})

modifier_item_chest_of_midas = class({
    IsDebuff = function (self) return false end,
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return false end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end,
    GetIntrinsicModifierName = function (self) return "modifier_item_chest_of_midas" end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
    } end,
    GetModifierPhysicalArmorBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_armor") end,
    OnAttackLanded = function (self,params)
        if not params.target:IsRealHero() then return end
        if params.attacker == self:GetParent() then return end
        if params.target ~= self:GetParent() then return end
        if not params.attacker:IsRealHero() then return end
        if self:GetAbility():IsCooldownReady() == false then return end
        self:GetAbility():UseResources(false,false,false,true)
        self:GetParent():AddExperience(self:GetAbility():GetSpecialValueFor("xp"), 0, true, true) 
        self:GetParent():ModifyGold( self:GetAbility():GetSpecialValueFor("gold"), true, 0) 
    end
})
