item_greater_crit = class({
    GetIntrinsicModifierName = function (self) return 'modifier_greater_crit' end
})

item_greater_crit_2 = item_greater_crit

LinkLuaModifier('modifier_greater_crit', 'items/item_greater_crit', LUA_MODIFIER_MOTION_NONE)

-------------------------------------------------------------------

modifier_greater_crit = class({
    IsHidden = function (self) return true end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
        MODIFIER_PROPERTY_BASEATTACK_BONUSDAMAGE
    } end
})

function modifier_greater_crit:GetModifierPreAttack_CriticalStrike(params)
    if self:LegitimateAttack(params) then
        local chance = self:GetAbility():GetSpecialValueFor("crit_chance")

        local proc = RandomInt(1, 100)

        if proc <= chance then
            self.record = params.record
            return self:GetAbility():GetSpecialValueFor("crit_multiplier")
        end
    end
end

function modifier_greater_crit:GetModifierBaseAttack_BonusDamage() return self:GetAbility():GetSpecialValueFor('bonus_damage') end

function modifier_greater_crit:LegitimateAttack(params)
    local target = params.unit or params.target
    local hero = self:GetParent()

    if
    IsServer()
            and params.attacker == hero
            and target:GetTeamNumber() ~= hero:GetTeamNumber()
            and (not target:IsBuilding())
            and (not target:IsOther())
            and ((params.inflictor == nil) or (params.inflictor:GetAbilityName() == "item_bfury"))
    --and self.record and params.record == self.record
    then
        return true
    else
        return false
    end
end