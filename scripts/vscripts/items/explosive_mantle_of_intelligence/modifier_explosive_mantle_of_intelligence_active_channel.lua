modifier_explosive_mantle_of_intelligence_active_channel = class({})
--------------------------------------------------------------------------------
function modifier_explosive_mantle_of_intelligence_active_channel:IsHidden()
    return false
end

--------------------------------------------------------------------------------
function modifier_explosive_mantle_of_intelligence_active_channel:IsPurgable()
    return false
end

--------------------------------------------------------------------------------
function modifier_explosive_mantle_of_intelligence_active_channel:DestroyOnExpire()
    return true
end

--------------------------------------------------------------------------------
function modifier_explosive_mantle_of_intelligence_active_channel:IsDebuff()
    return false
end

--------------------------------------------------------------------------------
function modifier_explosive_mantle_of_intelligence_active_channel:RemoveOnDeath()
    return true
end

--------------------------------------------------------------------------------
function modifier_explosive_mantle_of_intelligence_active_channel:GetTexture()
    return "../items/center_of_peace_big"
end

--------------------------------------------------------------------------------
function modifier_explosive_mantle_of_intelligence_active_channel:GetEffectName()
    return "particles/center_of_peace/center_of_peace_channel.vpcf"
end