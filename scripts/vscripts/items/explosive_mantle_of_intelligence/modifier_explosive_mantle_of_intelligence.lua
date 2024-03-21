modifier_explosive_mantle_of_intelligence = class({})

function modifier_explosive_mantle_of_intelligence:IsHidden() return true end
function modifier_explosive_mantle_of_intelligence:IsPurgable() return false end
function modifier_explosive_mantle_of_intelligence:DestroyOnExpire() return false end

function modifier_explosive_mantle_of_intelligence:OnCreated(kv)
    self.bonus_int = self:GetAbility():GetSpecialValueFor("bonus_int")
end

function modifier_explosive_mantle_of_intelligence:GetAttributes()
    return MODIFIER_ATTRIBUTE_PERMANENT
end

function modifier_explosive_mantle_of_intelligence:DeclareFunctions()
    local funcs = {
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS
    }
    return funcs
end

function modifier_explosive_mantle_of_intelligence:GetModifierBonusStats_Intellect(kv) return self.bonus_int; end