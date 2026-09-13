if not IsServer() then return end

-- Иконки рун и кемпов на миникарте "как в доте":
--   * на споте висит иконка того, что там должно лежать/стоять;
--   * команда, которая увидела спот пустым, иконку теряет - а у второй команды
--     она остаётся, пока та сама не посмотрит;
--   * на спавне (руны или крипов) иконка возвращается всем.
--
-- Всё на нативных иконках доты. Одна иконка на всех не знает, кто что видел,
-- поэтому на каждом споте у каждой команды свои невидимые юниты-иконки: их видит
-- только своя команда (NOT_ON_MINIMAP_FOR_ENEMIES), и гасим их по отдельности.
-- Режимы - стак modifier_hidden_from_map, см. modifiers/modifier_hidden_from_map.lua.
--
-- Кемпы: на карте из Hammer стоят нейтральные здания npc_aa_minimap_* - их
-- удаляем (у здания значок не спрятать) и ставим вместо них копии команд на
-- npc_aa_minimap_icon_*. Руны: юниты npc_aa_minimap_rune_* создаём сами,
-- иконки ванильные (minimap_rune_bounty / _xp / _unknown).
MinimapSpots = MinimapSpots or {}

local TEAMS = { DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS }
local TICK = 0.5

-- юниты-иконки кемпов: их берём под свой контроль, остальные (боссы, порталы)
-- так и живут обычными иконками
--
-- Значение - юнит-копия для команд с тем же значком. Копии на npc_dota_creature,
-- а не на здании, как оригинал: у зданий NOT_ON_MINIMAP значок не гасит, и
-- иконка кемпа не пропадала после фарма. Оригинал по той же причине не
-- спрятать - его удаляем.
local CAMP_ICON_UNITS = {
	npc_aa_minimap_neutral_stack = "npc_aa_minimap_icon_camp",
	npc_aa_minimap_mid           = "npc_aa_minimap_icon_camp_big",
	npc_aa_minimap_big_stack     = "npc_aa_minimap_icon_camp_mid",
	npc_aa_minimap_ancient_stack = "npc_aa_minimap_icon_camp_ancient",
	npc_aa_minimap_cobold        = "npc_aa_minimap_icon_death",
}

-- какая иконка у какой руны. На точках богатства попеременно лежат богатство и
-- мудрость, поэтому там стоят оба юнита и горит тот, чья руна сейчас.
-- Руна усиления случайного типа - как в доте, знак вопроса.
local RUNE_ICON_UNITS = {
	bounty = "npc_aa_minimap_rune_bounty",
	wisdom = "npc_aa_minimap_rune_xp",
	power  = "npc_aa_minimap_rune_unknown",
}

-- с какого расстояния спавнер крипов считается кемпом этой иконки
local CAMP_LINK_RADIUS = 700
-- в каком радиусе от точки ищем лежащую руну
local RUNE_RADIUS = 150

-- режимы объявлены в файле модификатора, но он грузится вместе со способностью
-- юнита - на случай, если к нам доберутся раньше, держим те же числа тут
MINIMAP_ICON_REPLACED = MINIMAP_ICON_REPLACED or 1
MINIMAP_ICON_TEAM_SHOWN = MINIMAP_ICON_TEAM_SHOWN or 2
MINIMAP_ICON_TEAM_HIDDEN = MINIMAP_ICON_TEAM_HIDDEN or 3

function MinimapSpots:Init()
	if self.inited then return end
	self.inited = true

	self.spots = {}

	self:_CollectCamps()
	self:_CollectRunes()

	if CreepSpawner and CreepSpawner.RegisterOnSpawnCallback then
		CreepSpawner:RegisterOnSpawnCallback(function(arg)
			local info = arg and arg.spawner_info
			if info then MinimapSpots:OnCampSpawn(info.name) end
		end)
	end

	local camps, runes = 0, 0
	for _, spot in pairs(self.spots) do
		if spot.kind == "camp" then camps = camps + 1 else runes = runes + 1 end
	end
	print("[AA] minimap spots: camps", camps, "runes", runes)

	Timers:CreateTimer(TICK, function()
		MinimapSpots:Tick()
		return TICK
	end)
end

local function IconModifier(unit, mode)
	local mod = unit:FindModifierByName("modifier_hidden_from_map")
		or unit:AddNewModifier(unit, nil, "modifier_hidden_from_map", {})

	if mod then mod:SetStackCount(mode) end

	return mod
end

-- variants: { [название варианта] = имя юнита }. На каждый вариант у каждой
-- команды свой юнит; горит тот, что совпадает со spot.icon.
local function NewSpot(kind, icon, pos, shown, variants)
	local spot = { kind = kind, icon = icon, pos = pos, shown = {}, icons = {} }

	for _, team in pairs(TEAMS) do
		spot.shown[team] = shown
		spot.icons[team] = {}

		for variant, unitname in pairs(variants) do
			local unit = CreateUnitByName(unitname, pos, false, nil, nil, team)

			if unit then
				spot.icons[team][variant] = IconModifier(unit, MINIMAP_ICON_TEAM_HIDDEN)
			end
		end
	end

	return spot
end

function MinimapSpots:_CollectCamps()
	local spawners = CreepSpawner and CreepSpawner._spawnerInfoByName or {}
	local icons = {}

	for _, unit in pairs(Entities:FindAllByClassname("npc_dota_building")) do
		local unitname = unit.GetUnitName and unit:GetUnitName() or ""

		if CAMP_ICON_UNITS[unitname] then
			table.insert(icons, { unit = unit, pos = unit:GetAbsOrigin(), linked = {} })
		end
	end

	-- Кемпы на арене стоят тесно: если брать все спавнеры в радиусе, к иконке
	-- липли соседние кемпы, и пока жив хоть один сосед, иконка не гасла. Поэтому
	-- каждый спавнер отдаём только ближайшей к нему иконке.
	for name, info in pairs(spawners) do
		local best, bestDist = nil, CAMP_LINK_RADIUS

		for _, icon in pairs(icons) do
			local dist = (info.pos - icon.pos):Length2D()

			if dist <= bestDist then
				best, bestDist = icon, dist
			end
		end

		if best then table.insert(best.linked, name) end
	end

	local single, multi = 0, 0

	for _, icon in pairs(icons) do
		-- иконка без кемпа рядом - не наша забота, пусть остаётся обычной
		if #icon.linked > 0 then
			local copyName = CAMP_ICON_UNITS[icon.unit:GetUnitName()]

			-- крипы стоят с первой секунды, так что иконку сразу видят все
			local spot = NewSpot("camp", "camp", icon.pos, true, { camp = copyName })
			spot.spawners = icon.linked

			-- оригинал - здание, его значок не спрятать; нужен он был только
			-- ради значка, так что просто убираем
			UTIL_Remove(icon.unit)
			table.insert(self.spots, spot)

			if #icon.linked == 1 then single = single + 1 else multi = multi + 1 end
		end
	end

	print("[AA] minimap camps: one camp", single, "several camps", multi)
end

function MinimapSpots:_CollectRunes()
	if not Bounty or not Bounty.GetRuneSpots then return end

	self.bountySpots = {}
	self.powerSpots = {}

	-- до первого спавна руны на споте нет - и иконки тоже
	for _, ent in ipairs(Bounty:GetRuneSpots("bounty")) do
		local spot = NewSpot("rune", "bounty", ent:GetAbsOrigin(), false, {
			bounty = RUNE_ICON_UNITS.bounty,
			wisdom = RUNE_ICON_UNITS.wisdom,
		})
		table.insert(self.spots, spot)
		table.insert(self.bountySpots, spot)
	end

	for _, ent in ipairs(Bounty:GetRuneSpots("power")) do
		local spot = NewSpot("rune", "power", ent:GetAbsOrigin(), false, {
			power = RUNE_ICON_UNITS.power,
		})
		table.insert(self.spots, spot)
		table.insert(self.powerSpots, spot)
	end
end

-- спавн: иконка возвращается всем; кто спот сейчас видит, получит правду на
-- ближайшем тике
local function Reset(spot)
	for _, team in pairs(TEAMS) do
		spot.shown[team] = true
	end
end

-- kind: "bounty" | "wisdom" | "power"
function MinimapSpots:OnRuneSpawn(kind)
	if not self.spots then return end

	if kind == "power" then
		for _, spot in pairs(self.powerSpots or {}) do
			Reset(spot)
		end
	else
		-- мудрость падает на те же точки, что и богатство - меняем иконку
		for _, spot in pairs(self.bountySpots or {}) do
			spot.icon = kind
			Reset(spot)
		end
	end
end

function MinimapSpots:OnCampSpawn(spawnerName)
	for _, spot in pairs(self.spots or {}) do
		if spot.kind == "camp" then
			for _, name in pairs(spot.spawners) do
				if name == spawnerName then
					Reset(spot)
					break
				end
			end
		end
	end
end

function MinimapSpots:_HasContent(spot)
	if spot.kind == "camp" then
		for _, name in pairs(spot.spawners) do
			if CreepSpawner:_GetCampPopulation(name) > 0 then return true end
		end

		return false
	end

	return #Entities:FindAllByClassnameWithin("dota_item_rune", spot.pos, RUNE_RADIUS) > 0
end

function MinimapSpots:Tick()
	for _, spot in pairs(self.spots) do
		local content = nil

		for _, team in pairs(TEAMS) do
			-- правду знает только тот, кто сейчас видит спот
			if IsLocationVisible(team, spot.pos) then
				if content == nil then content = self:_HasContent(spot) end
				spot.shown[team] = content
			end

			for variant, icon in pairs(spot.icons[team]) do
				if not icon:IsNull() then
					local lit = spot.shown[team] and variant == spot.icon
					local mode = lit and MINIMAP_ICON_TEAM_SHOWN or MINIMAP_ICON_TEAM_HIDDEN

					if icon:GetStackCount() ~= mode then icon:SetStackCount(mode) end
				end
			end
		end
	end
end
