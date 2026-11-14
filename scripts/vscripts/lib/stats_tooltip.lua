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
