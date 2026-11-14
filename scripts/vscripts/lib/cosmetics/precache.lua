-- Прекеш косметики по запросу. НЕ в Precache() карты: на старте 56 предметов по ~80 ресурсам
-- съедали FPS (замер владельца: 70-80 без прекеша, ~30 с прекешем).
--
-- Каждый предмет каталога имеет юнит npc_aa_cos_<id> (scripts/npc/cosmetic_precache_units.txt,
-- генерируется из catalog.lua). При экипировке (и на спавне для уже надетых) вызываем
-- PrecacheUnitByNameAsync один раз на предмет; колбэк применяет эффект.
-- Пока ресурсы не готовы, эффект этого предмета не создаётся (IsReady == false).

if not IsServer() then return end

CosmeticsLoader = CosmeticsLoader or {}

local L = CosmeticsLoader

L.ready = L.ready or {}    -- id -> true, ресурсы предмета прекешены
L.waiting = L.waiting or {} -- id -> { колбэки }, прекеш идёт

-- Предмет готов к показу (nil-предмет считаем готовым: там и так нечего показывать)
function L.IsReady(item)
	if not item or not item.id then return true end

	return L.ready[item.id] == true
end

-- Загрузить предмет и вызвать cb, когда ресурсы готовы. Повторные вызовы без запроса движку.
function L.Ensure(item, cb)
	if not item or not item.id then
		if cb then cb() end

		return
	end

	local id = item.id

	if L.ready[id] then
		if cb then cb() end

		return
	end

	local w = L.waiting[id]

	if w then
		if cb then w[#w + 1] = cb end

		return
	end

	w = {}

	if cb then w[1] = cb end

	L.waiting[id] = w

	local ok, err = pcall(PrecacheUnitByNameAsync, "npc_aa_cos_" .. id, function()
		L.ready[id] = true
		L.waiting[id] = nil

		print("[Cosmetics] precache " .. id)

		for _, f in ipairs(w) do pcall(f) end
	end)

	if not ok then
		L.waiting[id] = nil

		print("[Cosmetics] precache failed " .. id .. ": " .. tostring(err))
	end
end

-- Загрузить несколько предметов (список items, nil-элементы пропускаются), cb - когда все готовы
function L.EnsureAll(items, cb)
	local todo = {}
	local seen = {}

	for _, it in ipairs(items or {}) do
		if it and it.id and not seen[it.id] and not L.IsReady(it) then
			seen[it.id] = true
			todo[#todo + 1] = it
		end
	end

	if #todo == 0 then
		if cb then cb() end

		return
	end

	local left = #todo
	local function one()
		left = left - 1

		if left == 0 and cb then cb() end
	end

	for _, it in ipairs(todo) do L.Ensure(it, one) end
end

return L
