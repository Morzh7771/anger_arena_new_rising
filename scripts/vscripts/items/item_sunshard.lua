item_sunshard = class({
    GetIntrinsicModifierName = function (self) return 'modifier_sunshard' end
})

LinkLuaModifier('modifier_sunshard', 'items/item_sunshard', LUA_MODIFIER_MOTION_NONE)

-------------------------------------------

modifier_sunshard = class({
    IsHidden = function (self) return true end,
    IsBuff = function (self) return true end,
    GetPriority = function(self) return 4 end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT
    } end,
    GetModifierAttackSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor('bonus_attack_speed') end
})