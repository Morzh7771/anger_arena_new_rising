if not IsServer() then return end

--[[
	Дев-режим: ПКМ по нейтралке или чаре во вкладке "Нейтральные" магазина -
	выдать её себе (пара к panorama/scripts/custom_game/dev_neutral_give.js).

	Работает только при GameRules:IsCheatMode() (sv_cheats / -dev) или в тулзах.
	Список того, что можно выдать, берётся из разрядов крафта
	(lib/neutral/madstone_system.lua, tierItems / tierEnhancements):
	клиент получает его при загрузке и вешает ПКМ только на эти ячейки.

	Нейтралка ставится в слот артефакта, чара - в слот чары, на её
	максимальный уровень среди разрядов. Старое в слоте заменяется.
]]

DevNeutralGive = DevNeutralGive or {}

local SLOT_ITEM        = DOTA_ITEM_NEUTRAL_ACTIVE_SLOT or 16
local SLOT_ENHANCEMENT = DOTA_ITEM_NEUTRAL_PASSIVE_SLOT or 17

function DevNeutralGive:IsDev()
	return GameRules:IsCheatMode() or IsInToolsMode()
end

-- { items = { name = true }, enhancements = { name = maxLevel } }
function DevNeutralGive:_Catalog()
	if self.catalog then return self.catalog end

	local items, enhancements = {}, {}
	local ms = MadstoneSystem

	if ms then
		for _, list in pairs(ms.tierItems or {}) do
			for _, name in pairs(list) do items[name] = true end
		end

		for _, groups in pairs(ms.tierEnhancements or {}) do
			for _, list in pairs(groups) do
				for _, entry in pairs(list) do
					local name, level = entry[1], tonumber(entry[2]) or 1
					if not enhancements[name] or level > enhancements[name] then
						enhancements[name] = level
					end
				end
			end
		end
	end

	-- кешируем только непустой: крафт мог ещё не загрузить разряды
	if next(items) or next(enhancements) then self.catalog = { items = items, enhancements = enhancements } end

	return { items = items, enhancements = enhancements }
end

function DevNeutralGive:_SendList(playerID)
	if not self:IsDev() then return end

	local player = PlayerResource:GetPlayer(playerID)
	if not player then return end

	local catalog = self:_Catalog()
	local items, enhancements = {}, {}

	for name in pairs(catalog.items) do table.insert(items, name) end
	for name in pairs(catalog.enhancements) do table.insert(enhancements, name) end

	CustomGameEventManager:Send_ServerToPlayer(player, "aa_dev_neutral_list", {
		items = table.concat(items, "|"),
		enhancements = table.concat(enhancements, "|"),
	})
end

function DevNeutralGive:_OnGive(event)
	if not self:IsDev() then
		print("[DevNeutralGive] отказ: нет sv_cheats и не тулзы")
		return
	end

	local playerID = event.PlayerID
	local name = tostring(event.item or "")
	local hero = playerID and PlayerResource:GetSelectedHeroEntity(playerID)

	if not hero or hero:IsNull() or name == "" then
		print("[DevNeutralGive] отказ: нет героя или пустое имя (" .. name .. ")")
		return
	end
	if not MadstoneSystem or not MadstoneSystem._EquipNeutral then return end

	local catalog = self:_Catalog()

	if catalog.items[name] then
		MadstoneSystem:_EquipNeutral(hero, name, nil, SLOT_ITEM)
	elseif catalog.enhancements[name] then
		MadstoneSystem:_EquipNeutral(hero, name, catalog.enhancements[name], SLOT_ENHANCEMENT)
	else
		print("[DevNeutralGive] отказ: " .. name .. " нет в разрядах крафта")
		return
	end

	print("[DevNeutralGive] " .. tostring(PlayerResource:GetPlayerName(playerID)) .. " -> " .. name)
end

function DevNeutralGive:Init()
	if self._inited then return end
	self._inited = true

	CustomGameEventManager:RegisterListener("aa_dev_neutral_give", function(_, event)
		local ok, err = pcall(DevNeutralGive._OnGive, DevNeutralGive, event)
		if not ok then print("[DevNeutralGive] " .. tostring(err)) end
	end)

	-- клиент переспрашивает список (крафт мог догрузиться позже)
	CustomGameEventManager:RegisterListener("aa_dev_neutral_list_request", function(_, event)
		DevNeutralGive:_SendList(event.PlayerID)
	end)

	if RegisterLoadListener then
		RegisterLoadListener(function(_, playerID) DevNeutralGive:_SendList(playerID) end)
	end
end

DevNeutralGive:Init()
