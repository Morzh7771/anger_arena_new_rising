modifier_fervor_aa_effect = class({})

--------------------------------------------------------------------------------

function modifier_fervor_aa_effect:IsHidden()
    return false
end

--------------------------------------------------------------------------------

function modifier_fervor_aa_effect:DestroyOnExpire()
    return true
end

--------------------------------------------------------------------------------
function modifier_fervor_aa_effect:IsPurgable()
    return false
end

--------------------------------------------------------------------------------

function modifier_fervor_aa_effect:IsDebuff()
    return false
end

--------------------------------------------------------------------------------

function modifier_fervor_aa_effect:OnCreated( kv )
    self.damage = self:GetAbility():GetSpecialValueFor( "damage" )
    self.attack_speed = self:GetAbility():GetSpecialValueFor( "attack_speed" )
    self.armor = self:GetAbility():GetSpecialValueFor( "armor" )
end

--------------------------------------------------------------------------------
function modifier_fervor_aa_effect:OnRefresh(kv)
	self:OnCreated(kv)
end
-------------------------------------------------------------------------------

function modifier_fervor_aa_effect:DeclareFunctions()
    local funcs = {
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
    }
    return funcs
end

--------------------------------------------------------------------------------

function modifier_fervor_aa_effect:GetModifierPreAttack_BonusDamage( params )
    return self.damage * self:GetStackCount()
end

--------------------------------------------------------------------------------
function modifier_fervor_aa_effect:GetModifierAttackSpeedBonus_Constant( params )
    return self.attack_speed * self:GetStackCount()
end

--------------------------------------------------------------------------------
function modifier_fervor_aa_effect:GetModifierPhysicalArmorBonus( params )
    return self.armor * self:GetStackCount()
end