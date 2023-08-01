item_chest_of_midas = class({})
LinkLuaModifier("modifier_item_chest_of_midas", "items/item_chest_of_midas", LUA_MODIFIER_MOTION_NONE)
function item_chest_of_midas:GetIntrinsicModifierName()
	return "modifier_item_chest_of_midas"
end

modifier_item_chest_of_midas = class({})
function modifier_item_chest_of_midas:IsDebuff() return false end
function modifier_item_chest_of_midas:IsHidden() return false end
function modifier_item_chest_of_midas:IsPurgable() return false end
function modifier_item_chest_of_midas:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end
function modifier_item_chest_of_midas:OnCreated()
    self.bonus_armor = self:GetAbility():GetSpecialValueFor("bonus_armor")
    self.xp = self:GetAbility():GetSpecialValueFor("xp")
    self.gold = self:GetAbility():GetSpecialValueFor("gold")
end
function modifier_item_chest_of_midas:DeclareFunctions()
    local func = {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
    }
    return func
end
function modifier_item_chest_of_midas:GetModifierPhysicalArmorBonus()
    return self.bonus_armor
end
function modifier_item_chest_of_midas:OnAttackLanded(params)
    if not params.target:IsRealHero() then return end
    if params.attacker == self:GetParent() then return end
    if params.target ~= self:GetParent() then return end
    if not params.attacker:IsRealHero() then return end
    self:GetAbility():UseResources(false,false,false,true)
    self:GetParent():AddExperience(self.xp, 0, true, true) 
    self:GetParent():ModifyGold(self.gold, true, 0) 
end