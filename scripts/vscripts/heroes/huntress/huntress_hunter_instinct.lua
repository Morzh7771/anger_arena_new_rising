
BaseClass = class({})
huntress_hunter_instinct = BaseClass
LinkLuaModifier("huntress_hunter_instinct_modifier", "heroes/huntress/huntress_hunter_instinct", LUA_MODIFIER_MOTION_NONE)

function BaseClass:GetIntrinsicModifierName()
    return "huntress_hunter_instinct_modifier"
end


huntress_hunter_instinct_modifier = class({
    IsHidden                = function(self) return false end,
    IsPurgable              = function(self) return false end,
    IsDebuff                = function(self) return false end,
    IsBuff                  = function(self) return true end,
    RemoveOnDeath           = function(self) return true end,
    DeclareFunctions        = function(self) return {
        MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE,
    }end,
})

function huntress_hunter_instinct_modifier:CacheValues()
    local ability = self:GetAbility()

    if not ability then return end

    self.isolation_radius    = ability:GetSpecialValueFor("isolation_radius")
    self.isolated_damage_pct = ability:GetSpecialValueFor("isolated_damage_pct")
    self.alone_damage_pct    = ability:GetSpecialValueFor("alone_damage_pct")
end

function huntress_hunter_instinct_modifier:OnCreated()
    self:CacheValues()
end

function huntress_hunter_instinct_modifier:OnRefresh()
    self:CacheValues()
end

function huntress_hunter_instinct_modifier:OnUpgrade()
    self:CacheValues()
end

function huntress_hunter_instinct_modifier:GetModifierTotalDamageOutgoing_Percentage(params)
    if not IsServer() then return 0 end

    local caster = self:GetCaster()
    local target = params.target

    if not caster or not target then return 0 end
    if caster:PassivesDisabled() then return 0 end
    if not self.isolation_radius then self:CacheValues() end
    if not self.isolated_damage_pct then return 0 end

    -- Only apply to enemy heroes
    if target:GetTeamNumber() == caster:GetTeamNumber() then return 0 end
    if not target:IsHero() then return 0 end

    -- Find enemy heroes around target
    local nearby_enemies = FindUnitsInRadius(
        caster:GetTeamNumber(),
        target:GetAbsOrigin(),
        nil,
        self.isolation_radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    -- If only target or no enemies in radius, apply bonus
    -- This means the target is isolated from their team
    if #nearby_enemies <= 1 then
        return self.alone_damage_pct
    end

    return 0
end
