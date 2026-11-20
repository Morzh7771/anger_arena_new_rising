if not IsServer() then return end

--[[
	Бафф суммонов от характеристик хозяина (modifier_summon_power).
	Коэффициенты - scripts/npc/summon_power.kv, кто получает - SummonUtils:IsPowerTarget.

	Основной путь - способность summon_power_passive в файлах юнитов героев
	(scripts/npc/heroes/*/unit.txt): движок сам вешает модификатор при создании
	юнита, без таймеров и обходов карты.

	Здесь - запасной путь для суммонов, которых нет в файлах героев
	(предметы, крипы с подчинением при спавне и т.п.): при появлении юнита
	пробуем выдать бафф несколько кадров, пока у него не появится хозяин.
]]

require('lib/summon_utils')

SummonPower = SummonPower or {}

local MODIFIER = "modifier_summon_power"

function SummonPower:TryApply(unit)
	if not unit or unit:IsNull() then return true end
	if unit:HasModifier(MODIFIER) then return true end
	if not SummonUtils:IsPowerTarget(unit) then return false end

	local hero = SummonUtils:GetOwnerHero(unit)

	if not hero or hero:IsNull() then return false end

	unit:AddNewModifier(hero, nil, MODIFIER, {})

	return true
end

-- Выдать бафф сразу или ждать, пока у юнита появится хозяин (до 10 кадров).
-- Для крипов, которых приручили (Chen, Enchantress, Dominator), когда их
-- уже не спавнили: npc_spawned для них не приходит.
function SummonPower:ApplyWhenReady(unit)
	if SummonPower:TryApply(unit) then return end

	local tries = 0

	Timers:CreateTimer(FrameTime(), function()
		if SummonPower:TryApply(unit) then return nil end

		tries = tries + 1
		if tries >= 10 then return nil end

		return FrameTime()
	end)
end

if not SummonPower.listening then
	SummonPower.listening = true

	ListenToGameEvent("npc_spawned", function(event)
		local unit = event.entindex and EntIndexToHScript(event.entindex)

		if not unit or unit:IsNull() then return end
		if unit.IsRealHero and unit:IsRealHero() then return end
		if unit:HasModifier(MODIFIER) then return end

		if SummonPower:TryApply(unit) then return end

		local tries = 0

		Timers:CreateTimer(FrameTime(), function()
			if SummonPower:TryApply(unit) then return nil end

			tries = tries + 1
			if tries >= 10 then return nil end

			return FrameTime()
		end)
	end, nil)
end

-- Приручённые Enchantress (enchantress_enchant) и Chen не всегда проходят через
-- событие доминации: раз в секунду проверяем доминированных юнитов сами.
-- Бафф получает только тот, кому он положен (IsPowerTarget), остальных пропускаем.
SummonPower.SWEEP_INTERVAL = 1

function SummonPower:SweepDominated()
	for _, team in ipairs({ DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS, DOTA_TEAM_NEUTRALS }) do
		local units = FindUnitsInRadius(team, Vector(0, 0, 0), nil, FIND_UNITS_EVERYWHERE,
			DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_ALL, -- свои у каждой команды: без тройного прохода по всем юнитам
			DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS, FIND_ANY_ORDER, false)

		for _, unit in ipairs(units) do
			if unit:IsDominated() and not unit:HasModifier(MODIFIER) then
				self:ApplyWhenReady(unit)
			end
		end
	end
end

if not SummonPower.sweeping then
	SummonPower.sweeping = true

	Timers:CreateTimer(SummonPower.SWEEP_INTERVAL, function()
		SummonPower:SweepDominated()
		return SummonPower.SWEEP_INTERVAL
	end)
end
