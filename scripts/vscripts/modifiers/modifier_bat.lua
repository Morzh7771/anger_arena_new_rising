local bat_dynamic = {
    --'bruda_talant_25',
    oracle_false_promise = 'shard_bat_bonus',
    --'3-ий снепки',
    --'ульт марси'
    modifier_sunshard_eat = 'bat_reduction'
}

local bat_constant = {
    modifier_troll_warlord_berserkers_rage = 'base_attack_time',
    modifier_alchemist_chemical_rage = 'base_attack_time',
    modifier_terrorblade_metamorphosis = 'base_attack_time',
}

modifier_bat = class({
    IsHidden = function (self) return true end,
    IsBuff = function (self) return true end,
    GetPriority = function(self) return 4 end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_BASE_ATTACK_TIME_CONSTANT,
        MODIFIER_EVENT_ON_ATTACK_LANDED
    } end
})

function modifier_bat:OnAttackLanded(params)
    --[[if not self:GetParent() == params.attacker then return end
    GameRules:SendCustomMessage(tostring(self:GetParent():GetBaseAttackTime()), 0, 0)]]
end

function modifier_bat:GetModifierBaseAttackTimeConstant()
    if not IsServer() then return end
    local delta = 0;
    local constant = 1.7;

    for name, value in pairs(bat_dynamic) do
        if (self:GetParent():HasModifier(name)) then
            local modifier = self:GetParent():FindModifierByName(name)
            local ability = modifier:GetAbility()
            local temp_value = ability:GetSpecialValueFor(value)

            --[[if (name == 'modifier_stackable_bat') then
                local stack_count = modifier:GetStackCount()

                temp_value = temp_value * stack_count
            end]]

            delta = delta + math.abs(temp_value)
        end
    end

    for name, value in pairs(bat_constant) do
        if (self:GetParent():HasModifier(name)) then
            local modifier = self:GetParent():FindModifierByName(name)
            local ability = modifier:GetAbility()
            local temp_value = ability:GetSpecialValueFor(value)

            if temp_value < constant then constant = temp_value end
        end
    end

    return constant - delta;
end

