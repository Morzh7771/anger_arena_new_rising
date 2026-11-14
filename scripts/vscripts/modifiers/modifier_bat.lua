--[[
	Единая точка BAT героя. Движок из нескольких BASE_ATTACK_TIME_CONSTANT берёт
	только один, поэтому все изменения BAT собираются здесь и стакаются:
	  bat_constant - модификаторы, которые ЗАДАЮТ BAT (берётся самый низкий);
	  bat_dynamic  - модификаторы, которые СНИЖАЮТ BAT (снижения складываются).
	Значение берётся из способности модификатора по ключу из таблицы.

	База - собственный BAT героя (запоминается при наложении), а не 1.7 для всех.
	Итог передаётся клиенту стаками (сотые доли), чтобы панель статов видела то же.
]]

local bat_dynamic = {
    --'bruda_talant_25',
    oracle_false_promise = 'shard_bat_bonus',
    --'3-ий снепки',
    --'ульт марси'
    modifier_sunshard_eat = 'bat_reduction',
    modifier_item_swift_blink_aa_active = 'bat_reduction',
}

local bat_constant = {
    modifier_troll_warlord_berserkers_rage = 'base_attack_time',
    modifier_alchemist_chemical_rage = 'base_attack_time',
    modifier_terrorblade_metamorphosis = 'base_attack_time',
}

local MIN_BAT = 0.4

modifier_bat = class({
    IsHidden = function (self) return true end,
    IsPurgable = function (self) return false end,
    RemoveOnDeath = function (self) return false end,
    GetPriority = function(self) return 4 end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_BASE_ATTACK_TIME_CONSTANT,
    } end
})

function modifier_bat:OnCreated()
    if not IsServer() then return end

    -- пока base == nil геттер молчит, поэтому тут читается чистый BAT героя
    self.base = nil
    self.base = self:GetParent():GetBaseAttackTime(false)

    if not self.base or self.base <= 0 then self.base = 1.7 end

    self:Recalc()
    self:StartIntervalThink(0.1)
end

function modifier_bat:OnIntervalThink()
    self:Recalc()
end

function modifier_bat:Recalc()
    local parent = self:GetParent()
    local constant = self.base
    local delta = 0

    for name, key in pairs(bat_constant) do
        local modifier = parent:FindModifierByName(name)
        local ability = modifier and modifier:GetAbility()

        if ability and not ability:IsNull() then
            local value = ability:GetSpecialValueFor(key)

            if value > 0 and value < constant then constant = value end
        end
    end

    for name, key in pairs(bat_dynamic) do
        for _, modifier in pairs(parent:FindAllModifiersByName(name)) do
            local ability = modifier:GetAbility()

            if ability and not ability:IsNull() then
                delta = delta + math.abs(ability:GetSpecialValueFor(key))
            end
        end
    end

    local stacks = math.floor(math.max(MIN_BAT, constant - delta) * 100 + 0.5)

    if stacks ~= self:GetStackCount() then
        self:SetStackCount(stacks)

        print(string.format("[modifier_bat] %s: база %.2f, задано %.2f, снижение %.2f -> BAT %.2f",
            parent:GetUnitName(), self.base, constant, delta, stacks / 100))
    end
end

function modifier_bat:GetModifierBaseAttackTimeConstant()
    local stacks = self:GetStackCount()

    if stacks <= 0 then return end

    return stacks / 100
end
