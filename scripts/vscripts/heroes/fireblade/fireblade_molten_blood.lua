
BaseClass = class({})
fireblade_molten_blood = BaseClass
LinkLuaModifier( "fireblade_molten_blood_stacks", "heroes/fireblade/fireblade_molten_blood", LUA_MODIFIER_MOTION_NONE)

function BaseClass:GetIntrinsicModifierName()
    return "fireblade_molten_blood_stacks"
end


fireblade_molten_blood_stacks = class({
    IsHidden                = function(self) return false end,
    IsPurgable              = function(self) return false end,
    IsDebuff                = function(self) return false end,
    IsBuff                  = function(self) return true end,
    RemoveOnDeath           = function(self) return true end,
    DeclareFunctions        = function(self) return {
        MODIFIER_PROPERTY_BASEDAMAGEOUTGOING_PERCENTAGE,
        MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
    }end,
})

function fireblade_molten_blood_stacks:CacheValues()
    local ability = self:GetAbility()

    if not ability then return end

    -- потолки растут с уровнем героя
    local level = self:GetParent():GetLevel()
    self.max_bonus_damage_pct   = ability:GetSpecialValueFor("max_bonus_damage_pct") + ability:GetSpecialValueFor("damage_per_level") * level
    self.max_spell_amp          = ability:GetSpecialValueFor("max_spell_amp") + ability:GetSpecialValueFor("spell_amp_per_level") * level
    self.check_interval         = ability:GetSpecialValueFor("check_interval")
end

function fireblade_molten_blood_stacks:OnCreated()
    self:CacheValues()

    if IsServer() then
        self:SetStackCount(0)
        self:StartIntervalThink(self.check_interval or 0.25)
    end
end

function fireblade_molten_blood_stacks:OnRefresh()
    self:CacheValues()
end

function fireblade_molten_blood_stacks:OnUpgrade()
    self:CacheValues()

    if IsServer() then
        self:StartIntervalThink(self.check_interval or 0.25)
    end
end

if IsServer() then
    function fireblade_molten_blood_stacks:OnIntervalThink()
        local caster = self:GetCaster()

        if not self.max_bonus_damage_pct or not self.max_spell_amp then
            self:CacheValues()
        end
        if not self.max_bonus_damage_pct or not self.max_spell_amp then
            return
        end

        if caster:PassivesDisabled() or not caster:IsAlive() then
            if self:GetStackCount() ~= 0 then
                self:SetStackCount(0)
            end
            return
        end

        local max_hp = caster:GetMaxHealth()
        local current_hp = caster:GetHealth()

        if max_hp <= 0 then return end

        local hp_deficit_pct = (max_hp - current_hp) / max_hp

        local damage_bonus = hp_deficit_pct * self.max_bonus_damage_pct
        local spell_amp = hp_deficit_pct * self.max_spell_amp

        local combined_bonus = (damage_bonus * 100) + (spell_amp * 100)
        local new_stack = math.floor(combined_bonus)

        if self:GetStackCount() ~= new_stack then
            self:SetStackCount(new_stack)
        end
    end
end

function fireblade_molten_blood_stacks:GetModifierBaseDamageOutgoing_Percentage()
    local caster = self:GetCaster()

    if caster:PassivesDisabled() then return 0 end
    self:CacheValues()
    if not self.max_bonus_damage_pct or not self.max_spell_amp then return 0 end

    local max_hp = caster:GetMaxHealth()
    local current_hp = caster:GetHealth()

    if max_hp <= 0 then return 0 end

    local hp_deficit_pct = (max_hp - current_hp) / max_hp
    return hp_deficit_pct * self.max_bonus_damage_pct
end

function fireblade_molten_blood_stacks:GetModifierSpellAmplify_Percentage()
    local caster = self:GetCaster()

    if caster:PassivesDisabled() then return 0 end
    self:CacheValues()
    if not self.max_bonus_damage_pct or not self.max_spell_amp then return 0 end

    local max_hp = caster:GetMaxHealth()
    local current_hp = caster:GetHealth()

    if max_hp <= 0 then return 0 end

    local hp_deficit_pct = (max_hp - current_hp) / max_hp
    return hp_deficit_pct * self.max_spell_amp
end
