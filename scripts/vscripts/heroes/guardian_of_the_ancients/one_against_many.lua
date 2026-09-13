
BaseClass = class({})
guardian_of_the_ancients_one_against_many = BaseClass
LinkLuaModifier( "guardian_of_the_ancients_one_against_many_bonus", "heroes/guardian_of_the_ancients/one_against_many", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier( "guardian_of_the_ancients_one_against_many_bonus_as", "heroes/guardian_of_the_ancients/one_against_many", LUA_MODIFIER_MOTION_NONE)
function BaseClass:GetIntrinsicModifierName()
    return "guardian_of_the_ancients_one_against_many_bonus"
end
function BaseClass:GetCastRange()
    return self:GetSpecialValueFor("radius")
end


guardian_of_the_ancients_one_against_many_bonus = class({
    IsHidden                = function(self) return false end,
    IsPurgable              = function(self) return false end,
    IsDebuff                = function(self) return false end,
    IsBuff                  = function(self) return true end,
    RemoveOnDeath           = function(self) return true end,
    DeclareFunctions        = function(self) return {
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
    }end,
})

-- 0.03 - это 33 поиска юнитов в секунду на пустом месте, бонус атакспида такой
-- частоты не требует
local ONE_AGAINST_MANY_INTERVAL = 0.25

function guardian_of_the_ancients_one_against_many_bonus:OnCreated()
    self:CacheValues()
    self:StartIntervalThink(ONE_AGAINST_MANY_INTERVAL)
end
function guardian_of_the_ancients_one_against_many_bonus:OnRefresh()
    self:CacheValues()
end
function guardian_of_the_ancients_one_against_many_bonus:OnUpgrade()
    self:CacheValues()
    self:StartIntervalThink(ONE_AGAINST_MANY_INTERVAL)
end
function guardian_of_the_ancients_one_against_many_bonus:CacheValues()
    local ability = self:GetAbility()

    if not ability then return end

    self.radius      = ability:GetSpecialValueFor("radius")
    self.hero_bonus  = ability:GetSpecialValueFor("hero_bonus")
    self.creep_bonus = ability:GetSpecialValueFor("creep_bonus")
end
if IsServer() then
    function guardian_of_the_ancients_one_against_many_bonus:OnIntervalThink()
        local caster = self:GetCaster()

        if not self.radius then self:CacheValues() end
        if not self.radius then return end

        self.thirst_visioners = 0

        -- от юнитов не зависит, проверяем один раз, а не на каждого найденного
        if caster:PassivesDisabled() then
            if self:GetStackCount() ~= 0 then self:SetStackCount(0) end
            return
        end

        local stacks = 0
        local all = FindUnitsInRadius(
        caster:GetTeamNumber(),
        caster:GetAbsOrigin(),
        nil,
        self.radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        0,
        0,
        false)

        for _, hero in pairs(all) do
            if hero:IsRealHero() then
                stacks = stacks + self.hero_bonus
            end
            if hero:IsCreep() or hero:IsIllusion() or hero:IsCreepHero() then
                stacks = stacks + self.creep_bonus
            end
        end

        -- SetStackCount рассылается клиентам, поэтому только при изменении
        if self:GetStackCount() ~= stacks then
            self:SetStackCount(stacks)
        end
    end
end

function guardian_of_the_ancients_one_against_many_bonus:GetModifierAttackSpeedBonus_Constant() return self:GetStackCount() end



