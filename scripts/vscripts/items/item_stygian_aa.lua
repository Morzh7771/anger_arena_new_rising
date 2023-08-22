item_stygian_aa = class({})
LinkLuaModifier("modifier_item_stygian_aa", "items/item_stygian_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_stygian_aa_disarmor", "items/item_stygian_aa", LUA_MODIFIER_MOTION_NONE)
function item_stygian_aa:GetIntrinsicModifierName()
    return "modifier_item_stygian_aa"
end

modifier_item_stygian_aa = class({
    IsHidden = function (self) return true end,
    IsBuff = function (self) return true end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
    }end,
    GetModifierPreAttack_BonusDamage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_dmg") end,
})

function modifier_item_stygian_aa:OnAttackLanded(kv)
    if not IsServer() then return end 
    if self:GetParent() ~= kv.attacker then return end 

    local disarmor = (kv.target:GetPhysicalArmorValue( false ) + kv.target:GetModifierStackCount("modifier_item_stygian_aa_disarmor",kv.attacker) + kv.target:GetModifierStackCount("modifier_rebels_sword_disarmor",kv.attacker)) * (self:GetAbility():GetSpecialValueFor("disarmor_pct")/100) 

    if kv.target:HasModifier("modifier_item_stygian_aa_disarmor") then 
        local modifier = kv.target:FindModifierByName("modifier_item_stygian_aa_disarmor")
        modifier:ForceRefresh() 
    else 
        kv.target:AddNewModifier(
            self:GetParent(),
            self:GetAbility(),
            "modifier_item_stygian_aa_disarmor",
            {duration = self:GetAbility():GetSpecialValueFor("duration")}
        )
    end
    kv.target:SetModifierStackCount("modifier_item_stygian_aa_disarmor",kv.attacker,disarmor)
end


modifier_item_stygian_aa_disarmor = class({
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return true end,
    DestroyOnExpire = function (self) return true end,
    GetAttributes = function (self) return (MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT) end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
    }end,
    GetModifierPhysicalArmorBonus = function (self) return -self:GetStackCount() end,
})