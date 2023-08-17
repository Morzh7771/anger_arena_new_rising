item_sunshard = class({
    GetIntrinsicModifierName = function (self) return 'modifier_bat' end
    --GetIntrinsicModifierName = function (self) return 'modifier_sunshard' end
})

LinkLuaModifier('modifier_sunshard', 'items/item_sunshard', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_sunshard', 'items/item_sunshard', LUA_MODIFIER_MOTION_NONE)

-------------------------------------------

modifier_sunshard = class({
    IsHidden = function (self) return true end,
    IsBuff = function (self) return true end,
    GetPriority = function(self) return 4 end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_ATTACKSPEED_PERCENTAGE,
    } end,
    GetModifierAttackSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor('bonus_attack_speed') end,
    GetModifierAttackSpeedPercentage = function (self) return 400 end,
})