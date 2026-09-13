
BaseClass = class({})
charon_bottomless_vessel = BaseClass
LinkLuaModifier( "charon_bottomless_vessel_stacks", "heroes/charon/charon_bottomless_vessel", LUA_MODIFIER_MOTION_NONE)

function BaseClass:GetIntrinsicModifierName()
    return "charon_bottomless_vessel_stacks"
end


charon_bottomless_vessel_stacks = class({
    IsHidden                = function(self) return false end,
    IsPurgable              = function(self) return false end,
    IsDebuff                = function(self) return false end,
    IsBuff                  = function(self) return true end,
    RemoveOnDeath           = function(self) return true end,
    DeclareFunctions        = function(self) return {
        MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
    }end,
})

function charon_bottomless_vessel_stacks:CacheValues()
    local ability = self:GetAbility()

    if not ability then return end

    self.spell_amp_per_mana  = ability:GetSpecialValueFor("spell_amp_per_mana")
    self.mana_step           = ability:GetSpecialValueFor("mana_step")
    self.max_bonus_regen     = ability:GetSpecialValueFor("max_bonus_regen")
    self.check_interval      = ability:GetSpecialValueFor("check_interval")
end

function charon_bottomless_vessel_stacks:OnCreated()
    self:CacheValues()

    if IsServer() then
        self:SetStackCount(0)
        self:StartIntervalThink(self.check_interval or 0.25)
    end
end

function charon_bottomless_vessel_stacks:OnRefresh()
    self:CacheValues()
end

function charon_bottomless_vessel_stacks:OnUpgrade()
    self:CacheValues()

    if IsServer() then
        self:StartIntervalThink(self.check_interval or 0.25)
    end
end

if IsServer() then
    function charon_bottomless_vessel_stacks:OnIntervalThink()
        local caster = self:GetCaster()

        if not self.spell_amp_per_mana or not self.mana_step then
            self:CacheValues()
        end
        if not self.spell_amp_per_mana or not self.mana_step then
            return
        end

        if caster:PassivesDisabled() or not caster:IsAlive() then
            if self:GetStackCount() ~= 0 then
                self:SetStackCount(0)
            end
            return
        end

        local max_mana = caster:GetMaxMana()
        local spell_amp = (max_mana / self.mana_step) * self.spell_amp_per_mana

        local new_stack = math.floor(spell_amp * 100)
        if self:GetStackCount() ~= new_stack then
            self:SetStackCount(new_stack)
        end
    end
end

function charon_bottomless_vessel_stacks:GetModifierSpellAmplify_Percentage()
    local caster = self:GetCaster()

    if caster:PassivesDisabled() then return 0 end

    return self:GetStackCount() / 100
end

function charon_bottomless_vessel_stacks:GetModifierConstantManaRegen()
    local caster = self:GetCaster()

    if caster:PassivesDisabled() then return 0 end
    if not self.max_bonus_regen then return 0 end

    local max_mana = caster:GetMaxMana()
    local current_mana = caster:GetMana()

    if max_mana <= 0 then return 0 end

    local mana_deficit_pct = (max_mana - current_mana) / max_mana
    local bonus_regen = mana_deficit_pct * self.max_bonus_regen

    return bonus_regen
end
