-- Прекеш предметов в момент, когда они появляются у игрока.
--
-- Частицы на старте карты не грузим (лимит движка в 32767 ресурсов, см.
-- Precache в addon_game_mode.lua), а у способностей их подтягивает прекеш
-- героя. Предметы же покупают и собирают посреди игры, и их Precache/KV
-- "precache" движок сам не вызывает - частицы оставались не загруженными
-- ("Attempting to use invalid particle definition", например молния
-- Мьёльнира), а такой спам стоял и перед крашем клиента.
--
-- Поэтому на каждое новое имя предмета один раз зовём PrecacheItemByNameAsync.
-- Самое первое срабатывание эффекта до окончания загрузки может пропасть.

ItemPrecache = ItemPrecache or {}
ItemPrecache._done = ItemPrecache._done or {}

function ItemPrecache:Ensure(itemName)
	if type(itemName) ~= "string" or itemName == "" then return end
	if self._done[itemName] then return end

	self._done[itemName] = true

	-- рецепты сами ничего не рисуют
	if itemName:find("^item_recipe_") then return end

	PrecacheItemByNameAsync(itemName, function()
		print("[AA.precache] предмет загружен: " .. itemName)
	end)
end

local function OnItemEvent(event)
	ItemPrecache:Ensure(event.itemname or event.item_name)
end

if not ItemPrecache._listening then
	ItemPrecache._listening = true

	ListenToGameEvent("dota_item_purchased", OnItemEvent, nil)
	ListenToGameEvent("dota_inventory_item_added", OnItemEvent, nil)
	ListenToGameEvent("dota_item_picked_up", OnItemEvent, nil)
	ListenToGameEvent("dota_item_combined", OnItemEvent, nil)
end
