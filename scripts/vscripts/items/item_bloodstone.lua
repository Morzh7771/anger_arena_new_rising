item_bloodstone_1 = class({
    GetIntrinsicModifierName = function (self) return 'modifier_bloodstone' end
})

item_bloodstone_2 = item_bloodstone_1
item_bloodstone_3 = item_bloodstone_1

function item_bloodstone_1:OnSpellStart()
    local caster = self:GetCaster()
    local duration = self:GetSpecialValueFor("buff_duration")
    local force_cooldown = self:GetSpecialValueFor("force_cooldown")
    if not caster:HasModifier('modifier_bloodstone_cooldown') then
        caster:AddNewModifier(caster, self, "modifier_bloodstone_active", {duration = duration})
        caster:AddNewModifier(caster, self, "modifier_bloodstone_cooldown", {duration = force_cooldown * self:GetCaster():GetCooldownReduction()})
    end
end

LinkLuaModifier('modifier_bloodstone', 'items/item_bloodstone', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_bloodstone_active', 'items/item_bloodstone', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_bloodstone_cooldown', 'items/item_bloodstone', LUA_MODIFIER_MOTION_NONE)

-----------------------------------------------------------------------

modifier_bloodstone = class({
    IsHidden = function (self) return true end,
    DeclareFunctions = function (self)
        return {
            MODIFIER_PROPERTY_HEALTH_BONUS,
            MODIFIER_PROPERTY_MANA_BONUS,
            MODIFIER_EVENT_ON_TAKEDAMAGE,
            MODIFIER_PROPERTY_AOE_BONUS_CONSTANT,
        }
    end
})

function modifier_bloodstone:OnTakeDamage(params)
    if self:GetParent():IsIllusion() then return end
    if params.attacker ~= self:GetParent() then return end
    if params.unit == self:GetParent() then return end
    if not params.unit then return end
    --if not params.inflictor or params.inflictor:IsNull() then return end
    if bit.band(params.damage_flags, DOTA_DAMAGE_FLAG_REFLECTION) > 0 then return end
    if bit.band(params.damage_flags, DOTA_DAMAGE_FLAG_NO_SPELL_LIFESTEAL) > 0 then return end
    if bit.band(params.damage_flags, DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION) > 0 then return end
    if not self:GetParent():HasModifier("modifier_muerta_pierce_the_veil_buff") then 
        if params.damage_category == DOTA_DAMAGE_CATEGORY_ATTACK then return end
    end

    local heal = params.damage * self:GetAbility():GetSpecialValueFor( "spell_lifesteal" ) / 100

    heal = heal * (self:GetParent():HasModifier('modifier_bloodstone_active') and self:GetAbility():GetSpecialValueFor('lifesteal_multiplier') or 1)

    self:GetParent():Heal(heal, self:GetAbility())

    local particle = ParticleManager:CreateParticle("particles/items3_fx/octarine_core_lifesteal.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
    ParticleManager:SetParticleControl(particle, 0, self:GetParent():GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(particle)
end

function modifier_bloodstone:GetModifierHealthBonus() return self:GetAbility():GetSpecialValueFor('bonus_health') end
function modifier_bloodstone:GetModifierManaBonus() return self:GetAbility():GetSpecialValueFor('bonus_mana') end
function modifier_bloodstone:GetModifierAoEBonusConstant() return 700 end

-----------------------------------------------------------------------

modifier_bloodstone_active = class({
    IsHidden = function (self) return false end,
    DeclareFunctions = function (self)
        return {
            MODIFIER_EVENT_ON_TAKEDAMAGE
        }
    end
})

function modifier_bloodstone_active:OnTakeDamage(params)
    if params.attacker ~= self:GetParent() then return end
    if params.target == self:GetParent() then return end
    if not params.inflictor or params.inflictor:IsNull() then return end
    if bit.band(params.damage_flags, DOTA_DAMAGE_FLAG_REFLECTION) > 0 then return end
    if bit.band(params.damage_flags, DOTA_DAMAGE_FLAG_NO_SPELL_LIFESTEAL) > 0 then return end
    if bit.band(params.damage_flags, DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION) > 0 then return end

    self:GetParent():GiveMana(params.damage * self:GetAbility():GetSpecialValueFor('lifesteal_multiplier'))
end

function modifier_bloodstone_active:OnDestroy()

end

-----------------------------------------------------------------------

modifier_bloodstone_cooldown = class({
    IsHidden                = function (self) return false end,
    IsPurgable              = function(self) return false end,
    IsPurgeException        = function(self) return false end,
    IsDebuff                = function(self) return true end,
    IsBuff                  = function(self) return false end,
    RemoveOnDeath           = function(self) return false end
})