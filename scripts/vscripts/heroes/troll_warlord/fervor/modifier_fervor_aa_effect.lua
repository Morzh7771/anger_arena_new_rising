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

-- Fervor - врождёнка (2026-11-22): значение 1-го уровня из KV (с талантом)
-- растёт до *_knee к knee_level уровню героя (как раньше 7-й уровень скилла),
-- потом медленнее до *_max к hero_level_cap.
local function ScaledByHeroLevel(ability, key)
    local base = ability:GetSpecialValueFor(key)
    local caster = ability:GetCaster()
    if not caster then return base end
    local raw = ability:GetLevelSpecialValueNoOverride(key, 0)
    local knee_lvl = ability:GetSpecialValueFor("knee_level")
    local cap = ability:GetSpecialValueFor("hero_level_cap")
    local knee = ability:GetSpecialValueFor(key .. "_knee")
    local top = ability:GetSpecialValueFor(key .. "_max")
    local lvl = math.min(caster:GetLevel(), cap)
    if knee_lvl <= 1 or cap <= knee_lvl then return base end
    if lvl <= knee_lvl then
        return base + (knee - raw) * (lvl - 1) / (knee_lvl - 1)
    end
    return base + (knee - raw) + (top - knee) * (lvl - knee_lvl) / (cap - knee_lvl)
end

function modifier_fervor_aa_effect:OnCreated( kv )
    self.damage = ScaledByHeroLevel(self:GetAbility(), "damage")
    self.attack_speed = ScaledByHeroLevel(self:GetAbility(), "attack_speed")
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