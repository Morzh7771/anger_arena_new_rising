if not IsServer() then return end

--[[
	Итоговая статистика матча и выбор MVP для финального экрана
	(panorama/layout/custom_game/end_screen.xml).

	Счётчики копятся по ходу игры хуками в существующих системах:
	  урон                    - AngelArena:DamageFilter
	  серии, первая кровь,
	  курьеры, момент смерти  - AngelArena:OnEntityKilled
	  время мёртвым, герои    - AngelArena:OnNPCSpawned
	  руны                    - AngelArena:OnRuneActivate
	  точки захвата           - CapturePoints:OnCaptured
	  командные предметы      - AngelArena:OnPlayerBuyItem
	  боссы                   - BossClass:OnDeath
	  дуэли                   - DuelLibrary:DeathListener, DuelController:_OnDuelEnd
	  безумруды               - MadstoneSystem:_Grant / OnCraftRequest
	  мидас                   - items/item_midas.lua
	  камбэк                  - ComebackSystem (GiveGoldTo)
	  томы уровня             - tome.lua
	То, что движок считает сам (K/D/A, GPM, XPM, лечение, станы, нетворс),
	забираем из PlayerResource в момент конца игры.

	Публикуется один раз, из GameEnder:_OnEnd до SetGameWinner, в нет-таблицу
	end_game_stats: ключ "match" - общее по матчу, ключ player_id - игрок.

	Каждый хук обёрнут в pcall: статистика не должна ронять геймплей.
]]

EndGameStats = EndGameStats or {}

local NET_TABLE = "end_game_stats"

-- Предметы, которые покупают на команду. В MVP идёт потраченное на них
-- золото, а не штуки: иначе пачка дешёвых сентри перевесит гем.
local TEAM_ITEMS = {
	item_ward_observer   = true,
	item_ward_sentry     = true,
	item_ward_dispenser  = true,
	item_smoke_of_deceit = true,
	item_dust            = true,
	item_gem             = true,
}

local WARD_ITEMS = {
	item_ward_observer  = true,
	item_ward_sentry    = true,
	item_ward_dispenser = true,
}

-- MVP обычно из победившей команды, но монстр из проигравшей всё ещё может
-- забрать титул
local WINNER_MULTIPLIER = 1.1

local MVP_PLACES       = 3 -- лучший и два претендента
local MVP_MAX_PER_TEAM = 2
local MVP_REASONS      = 3 -- сколько категорий "за что" показывать

-- удар больше этого - почти наверняка баг процентного урона, в рекорд не идёт
local MAX_HIT_SANITY = 10000000

local SLOT_NEUTRAL     = DOTA_ITEM_NEUTRAL_ACTIVE_SLOT or 16
local SLOT_ENHANCEMENT = DOTA_ITEM_NEUTRAL_PASSIVE_SLOT or 17

-- Веса MVP, в сумме 100. Каждое значение сначала делится на лучшее в матче
-- (доля 0..1) - иначе GPM в тысячах задавит варды в штуках. inverse - чем
-- меньше, тем лучше: доля = 1 - значение / худшее.
local MVP_WEIGHTS = {
	-- бой (45)
	{ key = "duel_kills",         weight = 13 },
	{ key = "kills",              weight = 12 },
	{ key = "kill_participation", weight = 8 },
	{ key = "hero_damage",        weight = 8 },
	{ key = "deaths",             weight = 4, inverse = true },
	-- цели (22)
	{ key = "boss_kills",         weight = 8 },
	{ key = "boss_damage",        weight = 5 },
	{ key = "damage_taken",       weight = 5 },
	{ key = "madstones_earned",   weight = 4 },
	-- команда (33)
	{ key = "gpm",                weight = 10 },
	{ key = "team_items_gold",    weight = 10 },
	{ key = "runes",              weight = 10 },
	{ key = "healing",            weight = 3 },
}

-- категории "лучший в матче" для значков на экране
local LEADER_KEYS = {
	"kills", "duel_kills", "hero_damage", "damage_taken", "healing", "stuns",
	"boss_kills", "boss_damage", "gpm", "networth", "runes", "team_items_gold",
	"madstones_earned", "max_hit", "best_streak",
}

local function NewStats()
	return {
		hero_damage = 0, damage_taken = 0, boss_damage = 0,
		max_hit = 0, max_hit_victim = "",
		duel_kills = 0, duel_deaths = 0,
		boss_kills = 0, boss_last_hits = 0,
		runes_bounty = 0, runes_wisdom = 0, runes_power = 0, captures = 0,
		team_items_gold = 0, wards = 0, support_items = 0,
		madstones_earned = 0, madstones_spent = 0, crafts = 0, rerolls = 0,
		midas = 0, comeback_gold = 0, team_share_gold = 0, team_share_given = 0, tome_level = 0,
		streak = 0, best_streak = 0, first_blood = 0,
		time_dead = 0, couriers = 0,
		heroes = {},
	}
end

local function OwnerID(unit)
	if not unit or unit:IsNull() or not unit.GetPlayerOwnerID then return -1 end

	return unit:GetPlayerOwnerID() or -1
end

local function TeamOf(unit)
	if not unit or unit:IsNull() or not unit.GetTeamNumber then return nil end

	return unit:GetTeamNumber()
end

-- Сам герой игрока, а не темпест дабл, клон мипо или иллюзия
local function IsMainHero(unit)
	if not unit or unit:IsNull() or not unit.IsRealHero or not unit:IsRealHero() then return false end

	local id = OwnerID(unit)

	return id >= 0 and PlayerResource:GetSelectedHeroEntity(id) == unit
end

-- Движковый счётчик. Если метода в этой версии API нет - 0, а не падение
-- всей финализации
local function Engine(method, id)
	local fn = PlayerResource[method]

	if not fn then return 0 end

	local ok, value = pcall(fn, PlayerResource, id)

	return ok and tonumber(value) or 0
end

function EndGameStats:_Get(playerID)
	if self.finalized then return nil end
	if not playerID or playerID < 0 then return nil end
	if not PlayerResource:IsValidPlayerID(playerID) then return nil end

	self.players = self.players or {}

	local s = self.players[playerID]

	if not s then
		s = NewStats()
		self.players[playerID] = s
	end

	return s
end

function EndGameStats:_TeamAdd(key, team, count)
	if team ~= DOTA_TEAM_GOODGUYS and team ~= DOTA_TEAM_BADGUYS then return end

	self.teams = self.teams or {}
	self.teams[team] = self.teams[team] or {}
	self.teams[team][key] = (self.teams[team][key] or 0) + (count or 1)
end

function EndGameStats:_RememberHero(id, npc)
	if not IsValidEntity(npc) or PlayerResource:GetSelectedHeroEntity(id) ~= npc then return end

	local s = self:_Get(id)

	if not s then return end

	local name = npc:GetUnitName()

	for _, known in ipairs(s.heroes) do
		if known == name then return end
	end

	table.insert(s.heroes, name)
end

--------------------------------------------------------------------------------
-- ХУКИ
--------------------------------------------------------------------------------

local hooks = {}

function hooks.OnDamage(self, attacker, victim, damage)
	if not damage or damage ~= damage or damage <= 0 then return end

	local victimTeam = TeamOf(victim)
	local attackerTeam = TeamOf(attacker)

	if not victimTeam or not attackerTeam or victimTeam == attackerTeam then return end

	-- без оверкилла: удар на 50к по герою с 300 хп - это 300 урона
	local dealt = math.min(damage, victim:GetHealth())
	local victimIsHero = victim.IsRealHero and victim:IsRealHero()

	if victimIsHero then
		local taken = self:_Get(OwnerID(victim))

		if taken then taken.damage_taken = taken.damage_taken + dealt end
	end

	-- урон призванных существ засчитывается хозяину
	local s = self:_Get(OwnerID(attacker))

	if not s then return end

	if victimIsHero then
		s.hero_damage = s.hero_damage + dealt

		if damage > s.max_hit and damage < MAX_HIT_SANITY then
			s.max_hit = damage
			s.max_hit_victim = victim:GetUnitName()
		end
	elseif victim.IsAngelArenaBoss then
		s.boss_damage = s.boss_damage + dealt
	end
end

function hooks.OnEntityKilled(self, killed, killer)
	if not killed or killed:IsNull() then return end

	local killerID = OwnerID(killer)

	if killed.IsCourier and killed:IsCourier() then
		local s = self:_Get(killerID)

		if s and TeamOf(killer) ~= TeamOf(killed) then s.couriers = s.couriers + 1 end

		return
	end

	if not IsMainHero(killed) or killed:IsReincarnating() then return end

	local victim = self:_Get(OwnerID(killed))

	if victim then
		victim.streak = 0
		victim.dead_since = GameRules:GetGameTime()
	end

	if TeamOf(killer) == nil or TeamOf(killer) == TeamOf(killed) then return end

	local s = self:_Get(killerID)

	if not s then return end

	s.streak = s.streak + 1

	if s.streak > s.best_streak then s.best_streak = s.streak end

	if not self.first_blood then
		self.first_blood = killerID
		s.first_blood = 1
	end
end

function hooks.OnHeroSpawned(self, npc)
	if not npc or npc:IsNull() or not npc.IsRealHero or not npc:IsRealHero() then return end

	local id = OwnerID(npc)
	local s = self:_Get(id)

	if not s then return end

	if s.dead_since and PlayerResource:GetSelectedHeroEntity(id) == npc then
		s.time_dead = s.time_dead + math.max(0, GameRules:GetGameTime() - s.dead_since)
		s.dead_since = nil
	end

	-- при репике выбранный герой переключается чуть позже спавна
	Timers:CreateTimer(0.1, function()
		self:_RememberHero(id, npc)
	end)
end

-- Участие в захвате круга - все герои, стоявшие в нём. Саму руну из круга
-- получает тот, кто первым зашёл и остался: его бутылка её активирует, и
-- руна приходит в OnRune ниже с его PlayerID, как обычная поднятая руна.
function hooks.OnCapture(self, units)
	local seen = {}
	local team

	for _, unit in ipairs(units or {}) do
		local id = OwnerID(unit)

		if id >= 0 and not seen[id] then
			seen[id] = true
			team = team or TeamOf(unit)

			local s = self:_Get(id)

			if s then s.captures = s.captures + 1 end
		end
	end

	self:_TeamAdd("captures", team)
end

-- Руна действует на всю команду, но очки получает тот, кто её поднял:
-- взять руну - это и есть командное действие
function hooks.OnRune(self, playerID, rune)
	local key = "runes_power"

	if rune == DOTA_RUNE_BOUNTY then
		key = "runes_bounty"
	elseif rune == DOTA_RUNE_XP then
		key = "runes_wisdom"
	end

	local s = self:_Get(playerID)

	if s then s[key] = s[key] + 1 end
end

function hooks.OnItemPurchased(self, playerID, itemName, cost)
	if not TEAM_ITEMS[itemName] then return end

	local s = self:_Get(playerID)

	if not s then return end

	cost = tonumber(cost) or GetItemCost(itemName) or 0

	s.team_items_gold = s.team_items_gold + cost

	if WARD_ITEMS[itemName] then
		s.wards = s.wards + 1
	else
		s.support_items = s.support_items + 1
	end
end

-- Боссов считаем по участию, а не по добиванию: ластхит на боссе крадётся.
-- units - герои в радиусе награды босса (BossClass:OnDeath).
function hooks.OnBossKilled(self, killer, killerTeam, units)
	local seen = {}
	local killerID = OwnerID(killer)
	local s = self:_Get(killerID)

	if s then
		s.boss_last_hits = s.boss_last_hits + 1
		s.boss_kills = s.boss_kills + 1
		seen[killerID] = true
	end

	for _, unit in ipairs(units or {}) do
		if unit and not unit:IsNull() and unit:IsRealHero() and TeamOf(unit) == killerTeam then
			local id = OwnerID(unit)

			if id >= 0 and not seen[id] then
				seen[id] = true

				local p = self:_Get(id)

				if p then p.boss_kills = p.boss_kills + 1 end
			end
		end
	end

	self:_TeamAdd("bosses", killerTeam)
end

-- Зовётся из DuelLibrary:DeathListener до того, как дуэль закроется: иначе
-- решающий фраг дуэли пришёл бы уже после сброса duelActive и потерялся
function hooks.OnDuelKill(self, killed, killer)
	if not IsMainHero(killed) then return end

	local victim = self:_Get(OwnerID(killed))

	if victim then victim.duel_deaths = victim.duel_deaths + 1 end

	if TeamOf(killer) == nil or TeamOf(killer) == TeamOf(killed) then return end

	local s = self:_Get(OwnerID(killer))

	if s then s.duel_kills = s.duel_kills + 1 end
end

function hooks.OnDuelEnd(self, winnerTeam)
	self:_TeamAdd("duels", winnerTeam)
end

function hooks.OnMadstonesGranted(self, playerID, amount)
	local s = self:_Get(playerID)

	if s then s.madstones_earned = s.madstones_earned + amount end
end

function hooks.OnMadstoneCraft(self, playerID, cost, isReroll)
	local s = self:_Get(playerID)

	if not s then return end

	s.madstones_spent = s.madstones_spent + cost

	if isReroll then
		s.rerolls = s.rerolls + 1
	else
		s.crafts = s.crafts + 1
	end
end

function hooks.OnMidas(self, hero)
	local s = self:_Get(OwnerID(hero))

	if s then s.midas = s.midas + 1 end
end

function hooks.OnComebackGold(self, playerID, gold)
	local s = self:_Get(playerID)

	if s then s.comeback_gold = s.comeback_gold + (tonumber(gold) or 0) end
end

-- золото, которое богатый тимейт отдал этому игроку (lib/team_gold_share.lua)
function hooks.OnTeamShareGold(self, playerID, gold)
	local s = self:_Get(playerID)

	if s then s.team_share_gold = s.team_share_gold + (tonumber(gold) or 0) end
end

-- золото, которое этот игрок отдал отстающим тимейтам (lib/team_gold_share.lua)
function hooks.OnTeamShareGiven(self, playerID, gold)
	local s = self:_Get(playerID)

	if s then s.team_share_given = s.team_share_given + (tonumber(gold) or 0) end
end

function hooks.OnLevelTome(self, hero)
	local s = self:_Get(OwnerID(hero))

	if s then s.tome_level = s.tome_level + 1 end
end

for name, fn in pairs(hooks) do
	EndGameStats[name] = function(self, ...)
		local ok, err = pcall(fn, self, ...)

		if not ok then
			print("[AA] end_game_stats " .. name .. ": " .. tostring(err))
		end
	end
end

--------------------------------------------------------------------------------
-- ФИНАЛ
--------------------------------------------------------------------------------

function EndGameStats:Finalize(winnerTeam)
	if self.finalized then return end

	local ok, err = pcall(self._Finalize, self, winnerTeam)

	if not ok then
		print("[AA] end_game_stats Finalize: " .. tostring(err))
	end

	-- после конца игры урон и убийства больше не копятся
	self.finalized = true
end

function EndGameStats:_FillEngineStats(id, s, now)
	s.kills     = Engine("GetKills", id)
	s.deaths    = Engine("GetDeaths", id)
	s.assists   = Engine("GetAssists", id)
	s.last_hits = Engine("GetLastHits", id)
	s.gpm       = math.floor(Engine("GetGoldPerMin", id) + 0.5)
	s.xpm       = math.floor(Engine("GetXPPerMin", id) + 0.5)
	s.healing   = math.floor(Engine("GetHealing", id))
	s.stuns     = math.floor(Engine("GetStuns", id) * 10 + 0.5) / 10

	-- золото сверх 50000 мод держит в копилке (AngelArena:SaveGoldForPlayerId),
	-- движок про него не знает
	local bank = AngelArena and AngelArena.tPlayers and AngelArena.tPlayers[id]

	s.networth = Engine("GetNetWorth", id) + (bank and bank.gold or 0)

	s.abandoned = PlayerResource:GetConnectionState(id) == DOTA_CONNECTION_STATE_ABANDONED and 1 or 0

	if s.dead_since then
		s.time_dead = s.time_dead + math.max(0, now - s.dead_since)
		s.dead_since = nil
	end

	local hero = PlayerResource:GetSelectedHeroEntity(id)

	s.hero  = ""
	s.level = 0
	s.items = ""
	s.neutral = ""
	s.enhancement = ""
	s.tome_str, s.tome_agi, s.tome_int = 0, 0, 0

	if not hero or hero:IsNull() then return end

	s.hero  = hero:GetUnitName()
	s.level = hero:GetLevel()

	self:_RememberHero(id, hero)

	local function ItemIn(slot)
		local item = hero:GetItemInSlot(slot)

		return item and item:GetAbilityName() or ""
	end

	local items = {}

	for slot = 0, 5 do
		items[#items + 1] = ItemIn(slot)
	end

	s.items = table.concat(items, "|")
	s.neutral = ItemIn(SLOT_NEUTRAL)
	s.enhancement = ItemIn(SLOT_ENHANCEMENT)

	-- стаки модификаторов томов - это ровно полученные с томов атрибуты
	-- (tome.lua кладёт в стаки столько же, сколько даёт ModifyStrength)
	local function Stacks(name)
		local mod = hero:FindModifierByName(name)

		return mod and mod:GetStackCount() or 0
	end

	s.tome_str = Stacks("bonus_str_tome")
	s.tome_agi = Stacks("bonus_agi_tome")
	s.tome_int = Stacks("bonus_int_tome")
end

function EndGameStats:_CalcMVP(rows, winnerTeam)
	local eligible = {}

	-- ливнувшие не участвуют: по долям они выглядят эффективными просто
	-- потому, что не успели умереть
	for _, row in ipairs(rows) do
		if row.stats.abandoned == 0 then
			table.insert(eligible, row)
		end
	end

	local best = {}

	for _, w in ipairs(MVP_WEIGHTS) do
		local b = 0

		for _, row in ipairs(eligible) do
			b = math.max(b, row.stats[w.key] or 0)
		end

		best[w.key] = b
	end

	for _, row in ipairs(eligible) do
		local score = 0
		local parts = {}

		for _, w in ipairs(MVP_WEIGHTS) do
			local v = row.stats[w.key] or 0
			local b = best[w.key]
			local share

			if w.inverse then
				share = b > 0 and (1 - v / b) or 1
			else
				share = b > 0 and (v / b) or 0
			end

			score = score + share * w.weight

			-- "за что" - там, где игрок ближе всего к лучшему в матче
			if not w.inverse and share > 0 then
				table.insert(parts, { key = w.key, share = share, weight = w.weight })
			end
		end

		if row.stats.team == winnerTeam then
			score = score * WINNER_MULTIPLIER
		end

		row.score = score
		row.stats.mvp_score = math.floor(score * 10 + 0.5) / 10

		table.sort(parts, function(a, b)
			if a.share ~= b.share then return a.share > b.share end
			return a.weight > b.weight
		end)

		local reasons = {}

		for i = 1, math.min(MVP_REASONS, #parts) do
			reasons[i] = parts[i].key
		end

		row.stats.mvp_reasons = table.concat(reasons, "|")
	end

	-- детерминированный тай-брейк: иначе при равных очках MVP прыгает
	table.sort(eligible, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		if a.stats.kills ~= b.stats.kills then return a.stats.kills > b.stats.kills end
		if a.stats.deaths ~= b.stats.deaths then return a.stats.deaths < b.stats.deaths end
		return a.id < b.id
	end)

	-- лучший - всегда абсолютно первый; из одной команды не больше двух
	local places, perTeam = {}, {}

	for _, row in ipairs(eligible) do
		local team = row.stats.team

		if (perTeam[team] or 0) < MVP_MAX_PER_TEAM then
			perTeam[team] = (perTeam[team] or 0) + 1
			table.insert(places, row.id)
			row.stats.mvp_place = #places

			if #places >= MVP_PLACES then break end
		end
	end

	return places
end

function EndGameStats:_CalcLeaders(rows)
	local leaders = {}

	for _, key in ipairs(LEADER_KEYS) do
		local bestRow

		for _, row in ipairs(rows) do
			local v = row.stats[key] or 0

			if v > 0 and (not bestRow or v > (bestRow.stats[key] or 0)) then
				bestRow = row
			end
		end

		if bestRow then leaders[key] = bestRow.id end
	end

	return leaders
end

-- в нет-таблицу уходят только числа и строки; списки склеиваем через "|"
function EndGameStats:_Serialize(s)
	local out = {}

	for key, value in pairs(s) do
		local t = type(value)

		if t == "number" then
			-- сотые, а не десятые: участие в убийствах 0.47 иначе стало бы 50%
			out[key] = value == math.floor(value) and value or math.floor(value * 100 + 0.5) / 100
		elseif t == "string" then
			out[key] = value
		end
	end

	out.heroes = table.concat(s.heroes or {}, "|")

	-- служебные поля экрану не нужны
	out.streak = nil

	-- урон дробный из-за резистов - экрану нужны целые
	for _, key in ipairs({ "hero_damage", "damage_taken", "boss_damage", "max_hit", "time_dead", "comeback_gold", "team_share_gold", "team_share_given", "team_items_gold" }) do
		out[key] = math.floor(out[key] or 0)
	end

	return out
end

function EndGameStats:_Finalize(winnerTeam)
	local now = GameRules:GetGameTime()
	local rows = {}

	for id = 0, 23 do
		if PlayerResource:IsValidPlayerID(id) then
			local team = PlayerResource:GetTeam(id)

			if team == DOTA_TEAM_GOODGUYS or team == DOTA_TEAM_BADGUYS then
				local s = self:_Get(id)

				self:_FillEngineStats(id, s, now)
				s.team = team

				table.insert(rows, { id = id, stats = s })
			end
		end
	end

	-- участие в убийствах - доля фрагов своей команды, где игрок убил или помог
	local teamKills = {}

	for _, row in ipairs(rows) do
		teamKills[row.stats.team] = (teamKills[row.stats.team] or 0) + row.stats.kills
	end

	for _, row in ipairs(rows) do
		local s = row.stats
		local tk = teamKills[s.team] or 0

		s.kill_participation = tk > 0 and math.min(1, (s.kills + s.assists) / tk) or 0
		s.runes = s.runes_bounty + s.runes_wisdom

		self:_TeamAdd("runes", s.team, s.runes_bounty + s.runes_wisdom)
	end

	local places = self:_CalcMVP(rows, winnerTeam)
	local leaders = self:_CalcLeaders(rows)

	for _, row in ipairs(rows) do
		CustomNetTables:SetTableValue(NET_TABLE, tostring(row.id), self:_Serialize(row.stats))
	end

	local teams = {}

	for _, team in ipairs({ DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS }) do
		local t = (self.teams and self.teams[team]) or {}

		teams[tostring(team)] = {
			kills    = (_G.Kills and _G.Kills[team]) or teamKills[team] or 0,
			duels    = t.duels or 0,
			bosses   = t.bosses or 0,
			captures = t.captures or 0,
		}
	end

	CustomNetTables:SetTableValue(NET_TABLE, "match", {
		winner      = winnerTeam,
		duration    = math.floor(GameRules:GetDOTATime(false, false)),
		mvp         = table.concat(places, "|"),
		leaders     = leaders,
		first_blood = self.first_blood or -1,
		teams       = teams,
	})

	print("[AA] end_game_stats: матч закрыт, победитель " .. tostring(winnerTeam) .. ", MVP " .. table.concat(places, ", "))

	for _, row in ipairs(rows) do
		print(string.format("[AA]   player %d: score %.1f, %s", row.id, row.stats.mvp_score or 0, row.stats.mvp_reasons or ""))
	end
end
