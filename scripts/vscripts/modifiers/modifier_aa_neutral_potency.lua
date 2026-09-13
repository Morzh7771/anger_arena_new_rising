-- Dormant Curio, "Скрытый потенциал": нейтралка, которой заменили курио при
-- крафте, сильнее на item_potency процентов - всё, кроме перезарядки, расхода
-- маны и дальности применения (так пишет сама дота в описании курио).
--
-- В доте это делает её же крафт, а у нас он свой (lib/neutral/madstone_system.lua),
-- поэтому усиление - модификатором на герое. ability модификатора - тот самый
-- новый предмет: так он известен и на клиенте, и тултип предмета показывает
-- уже усиленные числа. Процент лежит в стаках.

modifier_aa_neutral_potency = modifier_aa_neutral_potency or class({})

local SKIP = {
	AbilityCooldown          = true,
	AbilityManaCost          = true,
	AbilityCastRange         = true,
	AbilityChargeRestoreTime = true,
}

function modifier_aa_neutral_potency:IsHidden() return true end
function modifier_aa_neutral_potency:IsPurgable() return false end
function modifier_aa_neutral_potency:RemoveOnDeath() return false end
function modifier_aa_neutral_potency:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT end

function modifier_aa_neutral_potency:OnCreated(kv)
	if not IsServer() then return end

	self:SetStackCount(tonumber(kv.potency) or 0)
end

function modifier_aa_neutral_potency:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL,
		MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL_VALUE,
	}
end

local function IsBoosted(self, params)
	local item = self:GetAbility()

	if not item or item:IsNull() or params.ability ~= item then return false end

	local key = params.ability_special_value

	if not key or SKIP[key] then return false end

	local lower = string.lower(key)

	if string.find(lower, "cooldown", 1, true)
		or string.find(lower, "mana_cost", 1, true)
		or string.find(lower, "manacost", 1, true)
		or string.find(lower, "cast_range", 1, true) then
		return false
	end

	return true
end

function modifier_aa_neutral_potency:GetModifierOverrideAbilitySpecial(params)
	return IsBoosted(self, params) and 1 or 0
end

function modifier_aa_neutral_potency:GetModifierOverrideAbilitySpecialValue(params)
	local base = params.ability:GetLevelSpecialValueNoOverride(params.ability_special_value, params.ability_special_level)

	return base * (1 + self:GetStackCount() / 100)
end
