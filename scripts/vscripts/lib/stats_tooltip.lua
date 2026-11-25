if not IsServer() then return end

--[[
	Серверная часть панели статов при наведении на портрет
	(panorama/layout/custom_game/stats_tooltip/). По мотивам мода 1х6.

	Клиент шлёт stats_tooltip_request {unit, request}, сервер отвечает
	stats_tooltip_data тем, чего клиент сам узнать не может: макс. ХП и мана,
	скорость атаки, снижение маны и перезарядки, бонус дальности каста,
	снижение урона от силы (modifiers/modifier_aa_hero.lua).
	Ивенты идут через lib/events_protector.lua.
]]

StatsTooltip = StatsTooltip or {}

local MIN_INTERVAL = 0.4

-- Доп. статы, которых движок не отдаёт: ищем по KV-ключам у предметов в
-- инвентаре и у пассивок героя (свои и ванильные одинаково читаются
-- через GetSpecialValueFor). Строка показывается, только если значение не 0.
-- { группа, ключ локализации, ключи KV, способ: sum / max, суффикс }
local EXTRA = {
	{ "attack", "aa_stats_crit_chance",    { "crit_chance" },                                        "max", "%" },
	{ "attack", "aa_stats_crit_damage",    { "crit_multiplier", "crit_damage_pct", "crit_damage" }, "max", "%" },
	{ "attack", "aa_stats_armor_pierce",   { "armor_ignore_pct", "armor_pierce_pct" },               "max", "%" },
	{ "attack", "aa_stats_armor_reduction",{ "corruption_armor", "armor_reduction", "minus_armor" }, "sum", "" },
	{ "attack", "aa_stats_pure_damage",    { "bonus_pure_damage", "pure_damage_per_attack" },        "sum", "" },
	{ "attack", "aa_stats_cleave",         { "cleave_damage_percent", "cleave_percent", "cleave_pct" }, "sum", "%" },
	{ "attack", "aa_stats_lifesteal",      { "lifesteal_percent", "lifesteal_pct" },                 "sum", "%" },
	{ "magic",  "aa_stats_spell_lifesteal",{ "spell_lifesteal", "spell_lifesteal_pct", "spell_lifesteal_percent" }, "sum", "%" },
	{ "magic",  "aa_stats_aoe_bonus",      { "aoe_bonus", "bonus_aoe", "bonus_aoe_radius" },         "sum", "" },
	{ "magic",  "aa_stats_magic_pierce",   { "magic_resist_reduction", "spell_pierce_pct" },         "sum", "%" },
}

local function CollectSources(unit)
	local list = {}
	for slot = 0, 5 do
		local item = unit:GetItemInSlot(slot)
		if item and not item:IsNull() then table.insert(list, item) end
	end
	local neutral = unit:GetItemInSlot(DOTA_ITEM_NEUTRAL_SLOT or 16)
	if neutral and not neutral:IsNull() then table.insert(list, neutral) end
	for i = 0, unit:GetAbilityCount() - 1 do
		local ability = unit:GetAbilityByIndex(i)
		if ability and not ability:IsNull() and ability:GetLevel() > 0
			and bit.band(ability:GetBehaviorInt(), DOTA_ABILITY_BEHAVIOR_PASSIVE) ~= 0 then
			table.insert(list, ability)
		end
	end
	return list
end

local function CollectExtra(unit)
	local sources = CollectSources(unit)
	local out = {}
	for _, row in ipairs(EXTRA) do
		local value = 0
		for _, source in ipairs(sources) do
			for _, key in ipairs(row[3]) do
				local ok, v = pcall(source.GetSpecialValueFor, source, key)
				if ok and type(v) == "number" and v ~= 0 then
					v = math.abs(v)
					if row[4] == "max" then value = math.max(value, v) else value = value + v end
					break
				end
			end
		end
		if value ~= 0 then
			table.insert(out, { group = row[1], name = row[2], value = (math.floor(value * 10 + 0.5) / 10) .. row[5] })
		end
	end
	return out
end

-- итоговое снижение входящего урона: сила (modifier_aa_hero) и все
-- Lua-модификаторы со снижением урона (Ancient Roots и т.п.), перемножением
local function TotalReduction(unit, from_strength)
	local mult = 1 - from_strength / 100
	for _, mod in pairs(unit:FindAllModifiers()) do
		if mod.GetModifierIncomingDamage_Percentage then
			local ok, value = pcall(mod.GetModifierIncomingDamage_Percentage, mod, {})
			if ok and type(value) == "number" and value < 0 then
				mult = mult * (1 + value / 100)
			end
		end
	end
	return (1 - math.max(0, mult)) * 100
end

function StatsTooltip:OnRequest(data)
	local id = data.PlayerID

	if id == nil or data.unit == nil then return end

	local player = PlayerResource:GetPlayer(id)
	local unit = EntIndexToHScript(tonumber(data.unit) or -1)

	if not player then return end
	if not unit or unit:IsNull() or not unit.IsBaseNPC or not unit:IsBaseNPC() then return end

	local time = Time()

	if player.aa_stats_tooltip_time and time - player.aa_stats_tooltip_time < MIN_INTERVAL then return end

	player.aa_stats_tooltip_time = time

	local mana_cost = 1

	for _, mod in pairs(unit:FindAllModifiers()) do
		if mod.GetModifierPercentageManacostStacking then
			-- вызов чужого модификатора с пустыми параметрами может упасть;
			-- раньше такое падение молча обрывало весь ответ панели
			local ok, value = pcall(mod.GetModifierPercentageManacostStacking, mod, {})
			if ok and type(value) == "number" then
				mana_cost = mana_cost * (1 - value / 100)
			end
		end
	end

	local reduction = 0

	if unit:IsHero() and AAHeroStatDamageReduction then
		local ok, value = pcall(AAHeroStatDamageReduction, unit:GetStrength())
		if ok and type(value) == "number" then reduction = value end
	end

	local ok_total, total = pcall(TotalReduction, unit, reduction)
	if ok_total then reduction = total end

	local ok_extra, extra = pcall(CollectExtra, unit)
	if not ok_extra then extra = {} end

	-- диагностика: видно, что запрос дошёл и ответ ушёл (раз в 10 сек на игрока)
	if not player.aa_stats_log_time or time - player.aa_stats_log_time > 10 then
		player.aa_stats_log_time = time
		print(string.format("[AA.stats_tooltip] ответ игроку %d: %s, снижение урона %.1f%%", id, unit:GetUnitName(), reduction))
	end

	CustomGameEventManager:Send_ServerToPlayer(player, "stats_tooltip_data", {
		request = data.request,
		cooldown = (1 - unit:GetCooldownReduction()) * 100,
		mana_cost = (mana_cost - 1) * 100,
		mana = unit:GetMaxMana(),
		mana_bonus = 0,
		health = unit:GetMaxHealth(),
		health_bonus = 0,
		attack_speed = unit:GetDisplayAttackSpeed(),
		attack_speed_bonus = 0,
		cast_range = unit:GetCastRangeBonus(),
		damage_reduction = reduction,
		extra = extra,
	})
end

if not StatsTooltip.listening then
	StatsTooltip.listening = true

	CustomGameEventManager:RegisterListener("stats_tooltip_request", function(_, data)
		local ok, err = pcall(StatsTooltip.OnRequest, StatsTooltip, data)
		if not ok then
			print("[AA.stats_tooltip] ошибка: " .. tostring(err))
		end
	end)
end
