-- Усиления нейтралок, которые в доте делает её собственный крафт. У нас крафт
-- свой (lib/neutral/madstone_system.lua), поэтому - модификаторами на герое.
--
--   modifier_aa_neutral_potency - Dormant Curio, "Скрытый потенциал":
--     артефакт, которым заменили курио, получает item_potency процентов к
--     свойствам с флагом apply_curio_bonus в его KV - какие именно, решает
--     сама дота этим флагом. ability - сам артефакт, процент - в стаках.
--     Список ключей сервер кладёт в custom_entity_values предмета
--     ("curio_keys"), чтобы знал и клиент.
--
--   modifier_aa_enchanters_bauble - Enchanter's Bauble, "Enchant": чары
--     нейтралки сильнее на enchantment_bonus_base плюс
--     enchantment_bonus_growth за каждое повторное создание безделушки.
--     ability - сама безделушка, процент - в стаках. Усиливается та чара,
--     что сейчас в слоте, а current_bonus в тултипе безделушки показывает
--     этот процент.
--
-- Линкуются в addon_init.lua - он грузится и на сервере, и на клиенте. Из
-- серверного lib-файла клиент модификатор не узнаёт ("unknown modifier type"
-- в консоли), и тултипы показывают старые числа.

local ENHANCEMENT_SLOT = DOTA_ITEM_NEUTRAL_PASSIVE_SLOT or 17

local function BaseValue(params)
	return params.ability:GetLevelSpecialValueNoOverride(params.ability_special_value, params.ability_special_level)
end

--------------------------------------------------------------------------------
-- Dormant Curio
--------------------------------------------------------------------------------

modifier_aa_neutral_potency = modifier_aa_neutral_potency or class({})

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

-- ключи с apply_curio_bonus; на клиент приходят нет-таблицей и могут
-- опоздать, поэтому кэшируем только непустой список
function modifier_aa_neutral_potency:_Keys()
	if self.keys then return self.keys end

	local item = self:GetAbility()

	if not item or item:IsNull() or not item.GetNetworkableEntityInfo then return nil end

	local raw = item:GetNetworkableEntityInfo("curio_keys")

	if not raw or raw == "" then return nil end

	local keys = {}

	for key in string.gmatch(raw, "[^;]+") do
		keys[key] = true
	end

	self.keys = keys

	return keys
end

function modifier_aa_neutral_potency:GetModifierOverrideAbilitySpecial(params)
	local item = self:GetAbility()

	if not item or item:IsNull() or params.ability ~= item then return 0 end

	local keys = self:_Keys()

	return (keys and keys[params.ability_special_value]) and 1 or 0
end

function modifier_aa_neutral_potency:GetModifierOverrideAbilitySpecialValue(params)
	return BaseValue(params) * (1 + self:GetStackCount() / 100)
end

--------------------------------------------------------------------------------
-- Enchanter's Bauble
--------------------------------------------------------------------------------

modifier_aa_enchanters_bauble = modifier_aa_enchanters_bauble or class({})

function modifier_aa_enchanters_bauble:IsHidden() return true end
function modifier_aa_enchanters_bauble:IsPurgable() return false end
function modifier_aa_enchanters_bauble:RemoveOnDeath() return false end
function modifier_aa_enchanters_bauble:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT end

function modifier_aa_enchanters_bauble:OnCreated(kv)
	if not IsServer() then return end

	self:SetStackCount(tonumber(kv.potency) or 0)
end

function modifier_aa_enchanters_bauble:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL,
		MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL_VALUE,
	}
end

-- чара, что сейчас в слоте нейтралки
function modifier_aa_enchanters_bauble:_Enhancement()
	local parent = self:GetParent()

	if not parent or parent:IsNull() or not parent.GetItemInSlot then return nil end

	return parent:GetItemInSlot(ENHANCEMENT_SLOT)
end

function modifier_aa_enchanters_bauble:GetModifierOverrideAbilitySpecial(params)
	local bauble = self:GetAbility()

	if not bauble or bauble:IsNull() then return 0 end

	-- в тултипе безделушки - текущее увеличение
	if params.ability == bauble then
		return params.ability_special_value == "current_bonus" and 1 or 0
	end

	local enhancement = self:_Enhancement()

	return (enhancement and params.ability == enhancement) and 1 or 0
end

function modifier_aa_enchanters_bauble:GetModifierOverrideAbilitySpecialValue(params)
	if params.ability == self:GetAbility() then
		return self:GetStackCount()
	end

	return BaseValue(params) * (1 + self:GetStackCount() / 100)
end
