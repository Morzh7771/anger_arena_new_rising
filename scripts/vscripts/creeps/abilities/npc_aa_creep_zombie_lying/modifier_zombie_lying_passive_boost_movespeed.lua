modifier_zombie_lying_passive_boost_movespeed = class({})

--------------------------------------------------------------------------------
function modifier_zombie_lying_passive_boost_movespeed:IsHidden()
    return true
end

--------------------------------------------------------------------------------
function modifier_zombie_lying_passive_boost_movespeed:IsDebuff()
    return false
end

--------------------------------------------------------------------------------
function modifier_zombie_lying_passive_boost_movespeed:IsPurgable()
    return false
end

-----------------------------------------------------------------------------
function modifier_zombie_lying_passive_boost_movespeed:OnCreated(kv)
    if not self:GetAbility() then return end
    self.need_hp_pct = self:GetAbility():GetSpecialValueFor("need_hp_pct")
    self.bonus_movespeed_pct = self:GetAbility():GetSpecialValueFor("bonus_movespeed_pct")
    self.bonus = 0
end

-------------------------------------------------------------------------------
function modifier_zombie_lying_passive_boost_movespeed:DeclareFunctions()
    local funcs = {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
    }
    return funcs
end

-------------------------------------------------------------------------------
function modifier_zombie_lying_passive_boost_movespeed:GetModifierMoveSpeedBonus_Percentage(params)
    if self:GetParent():PassivesDisabled() then return 0 end
    if not self.need_hp_pct then return 0 end

    -- Раньше сервер на КАЖДЫЙ пересчёт скорости переписывал общую нет-таблицу
    -- heroes/skills_modifiers (ключ на каждого зомби за матч) и рассылал её
    -- всем, а клиент каждый раз её разбирал - лаги росли со временем.
    -- Здоровье и параметры способности клиент знает сам, считаем одинаково.
    local parent = self:GetParent()
    local bonus_speed = 0

    if parent:GetMaxHealth() / 100 * self.need_hp_pct >= parent:GetHealth() then
        bonus_speed = self.bonus_movespeed_pct
    end

    self.bonus = bonus_speed

    return bonus_speed
end

----------------------------------------------------------------------------