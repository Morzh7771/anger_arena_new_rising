item_sunshard = class({
    GetIntrinsicModifierName = function (self) return 'modifier_sunshard' end
})
function item_sunshard:OnSpellStart()
    self.target = self:GetCursorTarget()
    if self.target:HasModifier("modifier_sunshard_eat") then 
        CustomGameEventManager:Send_ServerToPlayer(self:GetCaster():GetPlayerOwner(), "custom_dota_hud_error_message", {message = "бебебебебебе"}) 
        return end
        self.target:AddNewModifier(self:GetCaster(),self,"modifier_sunshard_eat",{duration = -1 , nigth = self:GetSpecialValueFor('consumed_bonus_night_vision') or 0 , as = self:GetSpecialValueFor('consumed_bonus') or 0 })
        self:Destroy()
end
LinkLuaModifier('modifier_sunshard', 'items/item_sunshard', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_sunshard_eat', 'items/item_sunshard', LUA_MODIFIER_MOTION_NONE)

-------------------------------------------

modifier_sunshard = class({
    IsHidden = function (self) return true end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_BONUS_NIGHT_VISION ,
    } end,
    GetModifierAttackSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor('bonus_attack_speed') end,
    GetBonusNightVision = function (self) return self:GetAbility():GetSpecialValueFor('bonus_night_vision') end,
})

modifier_sunshard_eat = class({
    IsHidden = function (self) return false end,
    RemoveOnDeath = function (self) return false end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_BONUS_NIGHT_VISION ,
    } end,
    GetModifierAttackSpeedBonus_Constant = function (self) return self.as end,
    GetBonusNightVision = function (self) return self.nigth end,
})
function modifier_sunshard_eat:OnCreated(kv)
    self.as = kv.as
    self.nigth = kv.night
end