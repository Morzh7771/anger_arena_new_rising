modifier_demon_archer_runaway_effect = class({})

--------------------------------------------------------------------------------
function modifier_demon_archer_runaway_effect:IsHidden()
    return false
end

--------------------------------------------------------------------------------
function modifier_demon_archer_runaway_effect:IsDebuff()
    return false
end

--------------------------------------------------------------------------------
function modifier_demon_archer_runaway_effect:IsPurgable()
    return true
end

--------------------------------------------------------------------------------
-- Бонус приходит в kv только на сервере. До клиента он раньше ехал через
-- общую нет-таблицу, которую переписывали на каждый пересчёт скорости;
-- теперь через стаки модификатора - они реплицируются сами.
function modifier_demon_archer_runaway_effect:OnCreated(kv)
    if IsServer() then
        self:SetStackCount(kv.bonus_movespeed or 0)
    end
end

--------------------------------------------------------------------------------
function modifier_demon_archer_runaway_effect:DeclareFunctions()
    local funcs = {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
    }
    return funcs
end

--------------------------------------------------------------------------------
function modifier_demon_archer_runaway_effect:GetModifierMoveSpeedBonus_Constant(params)
    if self:GetParent():PassivesDisabled() then return 0 end

    return self:GetStackCount()
end

--------------------------------------------------------------------------------

