
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

function guardian_of_the_ancients_one_against_many_bonus:OnCreated()
    self.attack_speed_hero = self:GetAbility():GetSpecialValueFor("hero_bonus")
    self.attack_speed_creep = self:GetAbility():GetSpecialValueFor("creep_bonus")
    self.radius = self:GetAbility():GetSpecialValueFor("radius")
    self:StartIntervalThink(0.03)
end
if IsServer() then
    function guardian_of_the_ancients_one_against_many_bonus:OnIntervalThink()
        local caster = self:GetCaster()

        self.thirst_visioners = 0
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
            local hero_pct = hero:GetHealthPercent()

            if not self:GetCaster():PassivesDisabled() then
                if hero:IsRealHero() then
                    stacks = stacks + self.attack_speed_hero
                end
                if hero:IsCreep() or hero:IsIllusion() or hero:IsCreepHero() then
                    stacks = stacks + self.attack_speed_creep
                end
            end
        end
        self:SetStackCount(stacks)
    end
end

function guardian_of_the_ancients_one_against_many_bonus:GetModifierAttackSpeedBonus_Constant() return self:GetStackCount() end



