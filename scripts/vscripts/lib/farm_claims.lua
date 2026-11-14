if not IsServer() then return end

-- Бронь зон фарма на стадии стратегии (2026-11-14).
-- На карте в разделе "Командные предметы" (panorama strategy_farm.js) игрок тыкает в кемп -
-- кемп закрепляется за ним (портрет героя на споте), тиммейт этот кемп взять уже не может.
-- До FARM_MAX_CLAIMS кемпов на игрока, повторный клик по своему - снять. Чужая команда
-- брони не видит (клиент читает только ключ своей команды).
--
-- Кемпы - группы спавнеров из scripts/npc/creep_spawners.kv, стоящие ближе SPOT_MERGE друг
-- к другу (на арене кемпы тесные - иначе было бы полсотни точек вплотную).
--
-- Нет-таблица aa_farm:
--   "spots"      = { i = { id, x, y, type } }  x/y 0..1 по картинке карты (resource/overviews/new.txt)
--   "t<команда>" = { [spot id] = pid }
-- клиент -> сервер aa_farm_claim { spot }

FarmClaims = FarmClaims or {}

local F = FarmClaims

local FARM_MAX_CLAIMS = 3
-- Склейка спавнеров в одну точку - цепочкой (если до ЛЮБОГО члена группы ближе SPOT_MERGE).
local SPOT_MERGE = 500
-- Блок "5 кемпов" сверху у каждой стороны: спавнеры <SIDE>_SPAWNER_FIVE_* (hard, 2 med, 2 small).
-- Всегда одна точка по центру блока, и она занимает все слоты брони игрока.
local FIVE_PATTERN = "^(%u+)_SPAWNER_FIVE_"
-- границы картинки миникарты: resource/overviews/new.txt (pos_x -8192, pos_y 8192, scale 16)
local MAP_MIN, MAP_SIZE = -8192, 16384
-- "сильнейший" тип в группе - его и рисуем
local TYPE_RANK = { easy = 1, normal = 2, hard = 3, ancient = 4, necro = 5 }

F.spots = F.spots or nil
F.claims = F.claims or {} -- [team] = { [spot id] = pid }

function F:BuildSpots()
	if self.spots then return end

	local kv = LoadKeyValues("scripts/npc/creep_spawners.kv") or {}
	local pts = {}

	for name, info in pairs(kv) do
		local ent = Entities:FindByName(nil, name)

		if ent and type(info) == "table" then
			table.insert(pts, { pos = ent:GetAbsOrigin(), type = info.type or "easy", five = string.match(name, FIVE_PATTERN) })
		end
	end

	-- блок "5 кемпов" - группа по имени (сторона), в цепочную склейку не идёт
	local groups = {}
	local fiveOf = {}

	for _, p in ipairs(pts) do
		if p.five then
			local g = fiveOf[p.five]

			if not g then
				g = { five = true }
				fiveOf[p.five] = g
				table.insert(groups, g)
			end

			table.insert(g, p)
		end
	end

	-- цепочная склейка остальных: объединяем группы, пока есть пара точек ближе SPOT_MERGE
	for _, p in ipairs(pts) do
		if not p.five then
			local into = nil

			for gi = #groups, 1, -1 do
				local g = groups[gi]
				local near = false

				-- группа "пяти" своя, к ней не липнем
				if not g.five then
					for _, q in ipairs(g) do
						if (q.pos - p.pos):Length2D() <= SPOT_MERGE then
							near = true
							break
						end
					end
				end

				if near then
					if into then
						for _, q in ipairs(g) do table.insert(into, q) end

						table.remove(groups, gi)
					else
						table.insert(g, p)
						into = g
					end
				end
			end

			if not into then table.insert(groups, { p }) end
		end
	end

	for gi, g in ipairs(groups) do
		local sum = Vector(0, 0, 0)
		local best = "easy"

		for _, q in ipairs(g) do
			sum = sum + q.pos

			if (TYPE_RANK[q.type] or 0) > (TYPE_RANK[best] or 0) then best = q.type end
		end

		groups[gi] = { pos = sum / #g, type = best, n = #g, five = g.five }
	end

	self.spots = {}

	local out = {}

	for i, g in ipairs(groups) do
		local spot = {
			id = i,
			x = (g.pos.x - MAP_MIN) / MAP_SIZE,
			y = 1 - (g.pos.y - MAP_MIN) / MAP_SIZE,
			type = g.type,
			n = g.n,
			-- большая точка забирает все слоты: взял её - другие уже не взять
			w = g.five and FARM_MAX_CLAIMS or 1,
		}

		self.spots[i] = spot
		out[tostring(i)] = spot
	end

	CustomNetTables:SetTableValue("aa_farm", "spots", out)
	CustomNetTables:SetTableValue("aa_farm", "pois", self:CollectPOIs())

	print("[FarmClaims] споты: " .. #self.spots)
end

-- Ориентиры на карте стратегии: боссы, башни, аванпосты, шрайны, центр (бесконечные крипы).
-- Порталы и магазины убраны по просьбе владельца (2026-11-14).
-- Берём к началу пика, пока юниты-иконки с карты ещё на месте (lib/minimap_spots.lua убирает
-- оригиналы позже, уже в игре).
local POI_UNITS = {
	npc_aa_minimap_boss = "boss",
	npc_aa_minimap_icon_boss = "boss",
	npc_aa_minimap_cobold = "center",
}

local function MapXY(pos)
	return (pos.x - MAP_MIN) / MAP_SIZE, 1 - (pos.y - MAP_MIN) / MAP_SIZE
end

function F:CollectPOIs()
	local out = {}
	local n = 0

	local function add(kind, pos)
		local x, y = MapXY(pos)

		if x < 0 or x > 1 or y < 0 or y > 1 then return end

		n = n + 1
		out[tostring(n)] = { k = kind, x = x, y = y }
	end

	for _, cls in ipairs({ "npc_dota_building", "npc_dota_creature" }) do
		for _, u in pairs(Entities:FindAllByClassname(cls)) do
			local kind = u.GetUnitName and POI_UNITS[u:GetUnitName()]

			if kind then add(kind, u:GetAbsOrigin()) end
		end
	end

	for _, u in pairs(Entities:FindAllByClassname("npc_dota_tower")) do add("tower", u:GetAbsOrigin()) end
	for _, u in pairs(Entities:FindAllByClassname("npc_dota_watch_tower")) do add("outpost", u:GetAbsOrigin()) end
	for _, u in pairs(Entities:FindAllByClassname("npc_dota_healer")) do add("shrine", u:GetAbsOrigin()) end

	print("[FarmClaims] ориентиров: " .. n)

	return out
end

function F:Publish(team)
	local out = {}

	for spot, pid in pairs(self.claims[team] or {}) do out[tostring(spot)] = pid end

	CustomNetTables:SetTableValue("aa_farm", "t" .. team, out)
end

-- бронировать можно до начала игры (пик, стратегия, пре-гейм)
local function CanClaimNow()
	local s = GameRules:State_Get()

	return s >= DOTA_GAMERULES_STATE_HERO_SELECTION and s <= DOTA_GAMERULES_STATE_PRE_GAME
end

function F:OnClaim(data)
	local pid = tonumber(data.PlayerID)
	local spot = tonumber(data.spot)

	if pid == nil or spot == nil or not CanClaimNow() then return end

	self:BuildSpots()

	if not self.spots[spot] then return end

	local team = PlayerResource:GetTeam(pid)

	if team ~= DOTA_TEAM_GOODGUYS and team ~= DOTA_TEAM_BADGUYS then return end

	local claims = self.claims[team] or {}

	self.claims[team] = claims

	local owner = claims[spot]

	if owner == pid then
		claims[spot] = nil -- свой - снимаем
	elseif owner ~= nil then
		return -- уже взял тиммейт
	else
		-- занятые слоты: большая точка весит FARM_MAX_CLAIMS
		local mine = 0

		for s, p in pairs(claims) do
			if p == pid then mine = mine + (self.spots[s] and self.spots[s].w or 1) end
		end

		if mine + (self.spots[spot].w or 1) > FARM_MAX_CLAIMS then return end

		claims[spot] = pid
	end

	self:Publish(team)
end

CustomGameEventManager:RegisterListener("aa_farm_claim", function(_, data)
	local ok, err = pcall(F.OnClaim, F, data)

	if not ok then print("[FarmClaims] claim: " .. tostring(err)) end
end)

-- споты публикуем заранее, к началу пика: сущности карты уже есть
ListenToGameEvent("game_rules_state_change", function()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_HERO_SELECTION then
		local ok, err = pcall(F.BuildSpots, F)

		if not ok then print("[FarmClaims] spots: " .. tostring(err)) end
	end
end, nil)
