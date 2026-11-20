-- Проверка "спелл заблокирован Линкой (или аналогом)" для проков на момент каста
-- (Manaflare Lens, Khanda, Phylactery). OnSpellTargetReady срабатывает ДО того,
-- как спелл вызывает TriggerSpellAbsorb, поэтому сразу узнать нельзя.
-- Делаем снимок: какие предметы и способности цели сейчас готовы. Через кадр,
-- если что-то из них ушло в КД (Линка, Mirror Shield, щиты боссов и т.п.) -
-- спелл поглощён, прок не срабатывает.

if SpellBlockCheck then return end

local function ReadyList(target)
	local list = {}

	for i = 0, 16 do
		local item = target:GetItemInSlot(i)
		if item and not item:IsNull() and item:IsCooldownReady() then table.insert(list, item) end
	end

	for i = 0, target:GetAbilityCount() - 1 do
		local ability = target:GetAbilityByIndex(i)
		if ability and not ability:IsNull() and ability:GetLevel() > 0 and ability:IsCooldownReady() then
			table.insert(list, ability)
		end
	end

	return list
end

-- Блокеры, готовые принять спелл прямо сейчас. Нужны для спеллов со снарядом:
-- Линка у них срабатывает, когда снаряд долетит, а не в кадр каста.
local BLOCK_ITEMS = { item_sphere = true, item_sphere_2 = true, item_mirror_shield_aa = true }

local function HasReadyBlocker(target)
	if target:HasModifier("modifier_item_sphere_target") then return true end

	for i = 0, 5 do
		local item = target:GetItemInSlot(i)
		if item and not item:IsNull() and BLOCK_ITEMS[item:GetAbilityName()] and item:IsCooldownReady() then
			return true
		end
	end

	return false
end

-- Служебные спеллы, на которые проки "на каст" не срабатывают: захват вотчера
-- (канал по фонарю) и т.п. Плюс любые цели-фонари/точки захвата.
local IGNORED_SPELLS = { ability_lamp_use = true }
local IGNORED_TARGETS = { npc_dota_lantern = true, npc_aa_capture_point = true }

function IsProcIgnoredSpell(params)
	local ability = params and params.ability
	if ability and not ability:IsNull() and IGNORED_SPELLS[ability:GetAbilityName()] then return true end

	local target = params and params.target
	if not target or target:IsNull() then return true end
	if IGNORED_TARGETS[target:GetUnitName()] or target:GetClassname() == "npc_dota_lantern" then return true end

	return false
end

-- callback() вызывается через кадр, только если спелл не был поглощён
function SpellBlockCheck(target, callback)
	if not target or target:IsNull() then return end

	-- у цели готова Линка (или аналог) - спелл будет заблокирован, прока нет
	if HasReadyBlocker(target) then return end

	local ready = ReadyList(target)
	-- Линка, переданная союзнику: свой предмет без КД, баф пропадает при блоке
	local had_sphere_buff = target:HasModifier("modifier_item_sphere_target")

	Timers:CreateTimer(FrameTime(), function()
		if not target or target:IsNull() then return end

		if had_sphere_buff and not target:HasModifier("modifier_item_sphere_target") then return end

		for _, thing in ipairs(ready) do
			if not thing:IsNull() and not thing:IsCooldownReady() then return end
		end

		callback()
	end)
end
