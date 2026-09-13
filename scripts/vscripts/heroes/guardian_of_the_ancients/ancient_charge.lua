
BaseClass = class({})
guardian_of_the_ancients_ancient_charge = BaseClass
LinkLuaModifier( "guardian_of_the_ancients_ancient_charge_stacks", "heroes/guardian_of_the_ancients/ancient_charge", LUA_MODIFIER_MOTION_NONE)

function BaseClass:GetIntrinsicModifierName()
    return "guardian_of_the_ancients_ancient_charge_stacks"
end


guardian_of_the_ancients_ancient_charge_stacks = class({
    IsHidden                = function(self) return false end,
    IsPurgable              = function(self) return false end,
    IsDebuff                = function(self) return false end,
    IsBuff                  = function(self) return true end,
    RemoveOnDeath           = function(self) return true end,
    DeclareFunctions        = function(self) return {
        MODIFIER_PROPERTY_BASEDAMAGEOUTGOING_PERCENTAGE,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
    }end,
})

function guardian_of_the_ancients_ancient_charge_stacks:CacheValues()
    local ability = self:GetAbility()

    if not ability then return end

    self.max_charges     = ability:GetSpecialValueFor("max_charges")
    self.damage_pct      = ability:GetSpecialValueFor("damage_pct")
    self.charge_interval = ability:GetSpecialValueFor("charge_interval")
end

function guardian_of_the_ancients_ancient_charge_stacks:OnCreated()
    self:CacheValues()

    if IsServer() then
        self:SetStackCount(0)
        self:StartIntervalThink(self.charge_interval or 5)
    end
end

function guardian_of_the_ancients_ancient_charge_stacks:OnRefresh()
    self:CacheValues()
end

function guardian_of_the_ancients_ancient_charge_stacks:OnUpgrade()
    self:CacheValues()

    if IsServer() then
        self:StartIntervalThink(self.charge_interval or 5)
    end
end

if IsServer() then
    -- заряд копится по таймеру и тратится по одному за тычку
    function guardian_of_the_ancients_ancient_charge_stacks:OnIntervalThink()
        local caster = self:GetCaster()

        if not self.max_charges then self:CacheValues() end
        if not self.max_charges then return end

        if caster:PassivesDisabled() or not caster:IsAlive() then
            if self:GetStackCount() ~= 0 then self:SetStackCount(0) end
            return
        end

        if self:GetStackCount() < self.max_charges then
            self:IncrementStackCount()
        end
    end

    function guardian_of_the_ancients_ancient_charge_stacks:OnAttackLanded(params)
        if params.attacker ~= self:GetParent() then return end
        if params.target and params.target:IsBuilding() then return end
        if self:GetStackCount() <= 0 then return end

        self:DecrementStackCount()
    end
end

function guardian_of_the_ancients_ancient_charge_stacks:GetModifierBaseDamageOutgoing_Percentage()
    local caster = self:GetCaster()

    if caster:PassivesDisabled() then return 0 end
    if not self.damage_pct then return 0 end

    return self:GetStackCount() * self.damage_pct
end
