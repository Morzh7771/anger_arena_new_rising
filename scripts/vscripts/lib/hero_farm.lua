if not IsServer() then return end

-- Фарм героев (2026-11-22): вешает modifier_aa_hero_farm (эффекты "против крипов"
-- у ванильных способностей) на героев из конфига и медведя Лон Друида.
-- Плюс выдаёт бесплатный 0-й уровень ультам с "нулевым уровнем" (Coup de Grace).

HeroFarm = HeroFarm or {}

local MODIFIER = "modifier_aa_hero_farm"

-- ульты, у которых 1-й уровень выдаётся с рождения (в KV MaxLevel на 1 больше,
-- RequiredLevel 0 - следующий уровень по-прежнему на 6-м)
local FREE_FIRST_LEVEL = {
	npc_dota_hero_phantom_assassin = "phantom_assassin_coup_de_grace",
}

function HeroFarm:OnSpawned(unit)
	if not unit or unit:IsNull() or not unit.GetUnitName then return end
	local name = unit:GetUnitName()
	local is_bear = string.find(name, "npc_dota_lone_druid_bear", 1, true) ~= nil
	if not is_bear and not (unit.IsRealHero and (unit:IsRealHero() or unit:IsTempestDouble())) then return end
	if unit:IsIllusion() then return end

	if not unit:HasModifier(MODIFIER) then
		unit:AddNewModifier(unit, nil, MODIFIER, {})
	end

	local free = FREE_FIRST_LEVEL[name]
	if free then
		local ab = unit:FindAbilityByName(free)
		if ab and ab:GetLevel() == 0 then ab:SetLevel(1) end
	end
end

ListenToGameEvent("npc_spawned", function(event)
	local unit = EntIndexToHScript(event.entindex)
	-- способности героя появляются кадром позже
	Timers:CreateTimer(FrameTime(), function()
		local ok, err = pcall(HeroFarm.OnSpawned, HeroFarm, unit)
		if not ok then print("[HeroFarm] " .. tostring(err)) end
	end)
end, nil)
