if not IsServer() then return end

--[[
	Книги: покупка с зажатым Shift и книги из дропа крипов.

	1) Купил книгу, держа Shift, - она сразу применяется, как если бы её
	   купили и тут же нажали.
	2) Книга, выпавшая с крипа, не падает на землю, а сразу применяется к
	   тому, кто убил (зовёт lib/dropbox.lua через GiveTome).

	Касается всех предметов из scripts/npc/items/book_of_stats.txt, которые
	при использовании зовут tome.lua: статы, книга богов, книга героев,
	медицинский трактат.

	КАК ПРИМЕНЯЕМ.
	Делаем то же, что OnSpellStart из KV: зовём ту же функцию tome.lua с теми
	же ключами. Так 5 надёжных + 5 ненадёжных статов и всё остальное остаются
	ровно как при нажатии книги руками.

	SHIFT.
	Нажат ли он, знает только клиент: panorama/scripts/custom_game/shift_buy.js
	шлёт сюда каждую смену состояния. Сама покупка идёт через движок как
	обычно - списание золота, сток и событие покупки (на нём перенос золота
	сверх 50к) не трогаем. После покупки находим книгу у героя, применяем и
	снимаем один заряд, как SpendCharge. Мёртвому герою купленная книга
	приходит обычным предметом: трактат вешает модификатор, а на мёртвого он
	может и не встать - книга сгорела бы зря.
]]

require('lib/timers')
require('tome')

ShiftBuy = ShiftBuy or {}

local TOMES_FILE = "scripts/npc/items/book_of_stats.txt"
local TOME_SCRIPT = "tome.lua"

-- ключи RunScript, которые разбирает сам движок, в функцию они не идут
local RUNSCRIPT_SERVICE_KEYS = { Target = true, ScriptFile = true, Function = true }

function ShiftBuy:Init()
	if self._inited then return end
	self._inited = true

	self._shift = {}
	self:_GetTomes()

	CustomGameEventManager:RegisterListener("aa_shift_state", function(_, event)
		ShiftBuy:_OnShiftState(event)
	end)

	ListenToGameEvent("dota_item_purchased", function(event)
		ShiftBuy:_OnPurchased(event)
	end, nil)
end

-- Книга из дропа крипа достаётся hero сразу, без предмета на земле.
-- true - применили, ронять её не надо; false - не книга или не вышло, пусть
-- падает как раньше.
function ShiftBuy:GiveTome(hero, itemName, count)
	local tome = self:_GetTomes()[itemName]

	if not tome or not IsValidEntity(hero) or not hero:IsRealHero() then return false end

	-- функции tome.lua читают из предмета цену - нужен сам предмет, хоть и
	-- на мгновение
	local item = CreateItem(itemName, hero, hero)
	if not item then return false end

	local given = 0

	for _ = 1, math.max(1, tonumber(count) or 1) do
		if not self:_Apply(hero, itemName, tome, item) then break end
		given = given + 1
	end

	UTIL_Remove(item)

	return given > 0
end

-- Что считается книгой и что звать при использовании, берём прямо из KV:
-- числа и функции живут в одном месте, и новая книга в том же файле сразу
-- заработает и с Shift, и из дропа.
function ShiftBuy:_GetTomes()
	if self._tomes then return self._tomes end

	local tomes = {}

	for itemName, data in pairs(LoadKeyValues(TOMES_FILE) or {}) do
		local onSpell = type(data) == "table" and data.OnSpellStart
		local run = type(onSpell) == "table" and onSpell.RunScript

		if type(run) == "table" and run.ScriptFile == TOME_SCRIPT and run.Function then
			local params = {}

			for key, value in pairs(run) do
				if not RUNSCRIPT_SERVICE_KEYS[key] then params[key] = value end
			end

			tomes[itemName] = { func = run.Function, params = params }
		end
	end

	self._tomes = tomes

	return tomes
end

function ShiftBuy:_Apply(hero, itemName, tome, item)
	local func = _G[tome.func]

	if type(func) ~= "function" then
		print("[AA] shift_buy: нет функции " .. tostring(tome.func) .. " для " .. itemName)
		return false
	end

	local keys = { caster = hero, target = hero, ability = item }
	for key, value in pairs(tome.params) do keys[key] = value end

	local ok, err = pcall(func, keys)

	if not ok then
		print("[AA] shift_buy: " .. itemName .. " не применилась: " .. tostring(err))
	end

	return ok
end

function ShiftBuy:_OnShiftState(event)
	local playerId = event and event.PlayerID
	if playerId == nil then return end

	local down = tonumber(event.down) == 1

	-- ВРЕМЕННАЯ диагностика (2026-11-16, книги с Shift перестали применяться) - убрать после проверки в игре.
	-- Только смена состояния: клиент повторяет его раз в 2 с.
	if self._shift[playerId] ~= down then
		print(string.format("[AA.shift] сервер получил pid=%s shift=%s", tostring(playerId), tostring(down)))
	end

	self._shift[playerId] = down
end

function ShiftBuy:_OnPurchased(event)
	local playerId = event and event.PlayerID
	local itemName = event and event.itemname
	local tome = itemName and self:_GetTomes()[itemName]

	-- ВРЕМЕННАЯ диагностика (2026-11-16, книги с Shift перестали применяться) - убрать после проверки в игре
	if tome then
		print(string.format("[AA.shift] покупка %s pid=%s shift=%s", tostring(itemName), tostring(playerId), tostring(self._shift[playerId])))
	end

	if playerId == nil or not tome or not self._shift[playerId] then return end

	-- книга может ещё не лечь в слот к моменту события - берём её тиком позже
	Timers:CreateTimer(0, function()
		ShiftBuy:_UseBought(playerId, itemName, tome)
	end)
end

function ShiftBuy:_UseBought(playerId, itemName, tome)
	local hero = PlayerResource:GetSelectedHeroEntity(playerId)
	if not hero or hero:IsNull() or not hero:IsAlive() then return end

	local item = self:_FindBought(hero, itemName)
	if not item then
		-- ВРЕМЕННАЯ диагностика (2026-11-16) - убрать после проверки в игре
		print("[AA.shift] купленная книга не найдена у героя: " .. tostring(itemName))
		return
	end

	-- не вышло - книга остаётся у героя, её можно нажать руками
	if not self:_Apply(hero, itemName, tome, item) then return end

	-- ВРЕМЕННАЯ диагностика (2026-11-16) - убрать после проверки в игре
	print("[AA.shift] книга применена сразу: " .. tostring(itemName) .. " pid=" .. tostring(playerId))

	-- То же, что SpendCharge в KV: минус заряд, последний - вместе с предметом.
	-- Функции tome.lua съедают стак целиком и оставляют один заряд, так что
	-- обычно предмет уходит весь.
	local charges = item:GetCurrentCharges()

	if charges > 1 then
		item:SetCurrentCharges(charges - 1)
	else
		hero:RemoveItem(item)
	end
end

-- Купленная книга лежит в инвентаре (у лавки) или в тайнике (вдали от неё).
-- Если такие книги у героя уже были, покупка легла к ним в стак - он
-- применится весь, как при нажатии руками (tome.lua съедает стак целиком).
-- Книги, купленные союзником, не трогаем.
function ShiftBuy:_FindBought(hero, itemName)
	for slot = DOTA_ITEM_SLOT_1, DOTA_STASH_SLOT_6 do
		local item = hero:GetItemInSlot(slot)

		if item and not item:IsNull() and item:GetAbilityName() == itemName and item:GetPurchaser() == hero then
			return item
		end
	end

	return nil
end
