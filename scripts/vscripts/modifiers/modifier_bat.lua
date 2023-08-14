bat_dynamic = {
    --'bruda_talant_25',
    --'chemical_rage',
    --'Ульт Оракла',
    --'Первый тролля',
    --'Мета террора',
    --'Ульт лондруида',
    --'3-ий снепки',
    --'Талант, который я кинул выше',
    --'ульт марси'
    modifier_sunshard = 0.3
}

bat_constant = {
    modifier_alchemist_chemical_rage = 1.3
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
    if not self:GetParent() == params.attacker then return end
    GameRules:SendCustomMessage(tostring(self:GetParent():GetBaseAttackTime()), 0, 0);
end

function modifier_bat:GetModifierBaseAttackTimeConstant()
    local bat = 1.7;
    local constant = 1.7;

    for name, value in pairs(bat_dynamic) do
        print('dynamic name');
        print(name);
        print('dynamic value');
        print(value);
        if (self:GetParent():HasModifier(name)) then
            bat = bat - value
        end
    end

    for name, value in pairs(bat_constant) do
        print('constant name');
        print(name);
        print('constant value');
        print(value);
        if (self:GetParent():HasModifier(name)) then
            if value < constant then constant = value end
        end
    end

    if constant < bat then bat = constant end

    return bat;
end

