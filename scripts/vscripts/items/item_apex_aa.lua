item_apex_aa = ({})
LinkLuaModifier( "modifier_item_apex_aa", "items/item_apex_aa.lua", LUA_MODIFIER_MOTION_NONE )
function item_apex_aa:GetIntrinsicModifierName()
    return 'modifier_item_apex_aa'
end

modifier_item_apex_aa = ({
    IsHidden = function(self) return true end,
    DeclareFunctions = function(self) return {
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
    } end,
})
function modifier_item_apex_aa:OnCreated()
    self.primary_attribute_pct = self:GetAbility():GetSpecialValueFor("primary_attribute_pct")
    self.str_bonus = 0
    self.agi_bonus = 0
    self.int_bonus = 0
    if not IsServer() then return end
    self:StartIntervalThink(0.1)
end

function modifier_item_apex_aa:OnIntervalThink()
    if not IsServer() then return end
    self.str_bonus = 0
    self.str_bonus = self:GetParent():GetStrength() / 100 * self.primary_attribute_pct
    self.agi_bonus = 0
    self.agi_bonus = self:GetParent():GetAgility() / 100 * self.primary_attribute_pct
    self.int_bonus = 0
    self.int_bonus = self:GetParent():GetIntellect() / 100 * self.primary_attribute_pct
    self:GetParent():CalculateStatBonus(true)
end

function modifier_item_apex_aa:GetModifierBonusStats_Strength(params)
    if self:GetParent():GetPrimaryAttribute() == DOTA_ATTRIBUTE_STRENGTH then
        return self.str_bonus + self:GetAbility():GetSpecialValueFor("primary_attribute")
    elseif self:GetParent():GetPrimaryAttribute() == DOTA_ATTRIBUTE_ALL then
        return (self.str_bonus+ self:GetAbility():GetSpecialValueFor("primary_attribute"))/self:GetAbility():GetSpecialValueFor("atribute_all_minus")
    end
end
function modifier_item_apex_aa:GetModifierBonusStats_Agility(params)
    if self:GetParent():GetPrimaryAttribute() == DOTA_ATTRIBUTE_AGILITY  then
        return self.agi_bonus + self:GetAbility():GetSpecialValueFor("primary_attribute")
    elseif self:GetParent():GetPrimaryAttribute() == DOTA_ATTRIBUTE_ALL then
        return (self.agi_bonus + self:GetAbility():GetSpecialValueFor("primary_attribute"))/self:GetAbility():GetSpecialValueFor("atribute_all_minus")
    end
end
function modifier_item_apex_aa:GetModifierBonusStats_Intellect(params)
    if self:GetParent():GetPrimaryAttribute() == DOTA_ATTRIBUTE_INTELLECT  then
        return self.int_bonus + self:GetAbility():GetSpecialValueFor("primary_attribute")
    elseif self:GetParent():GetPrimaryAttribute() == DOTA_ATTRIBUTE_ALL then
        return (self.int_bonus + self:GetAbility():GetSpecialValueFor("primary_attribute"))/self:GetAbility():GetSpecialValueFor("atribute_all_minus") 
    end
end