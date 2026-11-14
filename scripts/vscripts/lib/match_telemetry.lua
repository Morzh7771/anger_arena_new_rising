-- Телеметрия матча: события сверх lib/match_tracker.lua.
--
-- Только наблюдение. Каждая обёртка сначала вызывает оригинал тем же способом
-- (возвращаемое значение и ошибки не меняются), потом пишет событие в pcall.
-- Все события уходят через MatchTracker:Push (lib/match_tracker.lua).
--
-- ЗОЛОТО - один путь, без двойного учёта:
--  * MatchTelemetry.goldSource - метка источника на время выдачи. Её ставят
--    обёртки (ScopeGold) вокруг функций, которые выдают золото. Трекер читает её
--    в OnGold и пишет обычное событие "gold" с этим источником.
--  * "gold_src" шлём ТОЛЬКО для золота, которое мимо фильтра золота движка
--    (AngelArena:GoldFilter, SetModifyGoldFilter) или которое трекер сам скрывает:
--      - запас сверх кошелька (self.tPlayers[pid].gold в AngelArena:GiveGold),
--        кошелёк его не видит;
--      - командные выплаты share_in (TeamGoldShare._paying, трекер их пропускает);
--      - доля, которую отдал богатый герой, share_out (фильтр оставляет только
--        долю получателя, трекер пишет её, а отданное нигде не учтено).

if not IsServer() then return end

MatchTelemetry = MatchTelemetry or {}

-- источник текущей выдачи золота (читает lib/match_tracker.lua в OnGold)
MatchTelemetry.goldSource = nil

local SLOT_NEUTRAL     = DOTA_ITEM_NEUTRAL_ACTIVE_SLOT or 16
local SLOT_ENHANCEMENT = DOTA_ITEM_NEUTRAL_PASSIVE_SLOT or 17
local GOLD_FLUSH       = 5    -- сек: сводки gold_src / damage_taken и проверка KILL_LIMIT
local JOB_TRIES        = 720  -- попыток обернуть модули, которые грузятся позже (по 5 с, около часа)

-- названия рун по их номеру из движка
local RUNE_NAMES = {}

for _, n in ipairs({
	"DOTA_RUNE_DOUBLEDAMAGE", "DOTA_RUNE_HASTE", "DOTA_RUNE_ILLUSION", "DOTA_RUNE_INVISIBILITY",
	"DOTA_RUNE_REGENERATION", "DOTA_RUNE_BOUNTY", "DOTA_RUNE_ARCANE",
}) do
	local v = _G[n]

	if v ~= nil then RUNE_NAMES[v] = string.lower(string.sub(n, 11)) end
end

-- ------------------------------------------------------------------ мелочи

local function Push(etype, pid, data)
	if not MatchTracker or not MatchTracker.Push then return end

	pcall(MatchTracker.Push, MatchTracker, etype, pid, data)
end

local function PidOk(pid)
	return type(pid) == "number" and pid >= 0 and pid < 24 and PlayerResource:IsValidPlayerID(pid)
end

local function Hero(pid)
	local ok, h = pcall(PlayerResource.GetSelectedHeroEntity, PlayerResource, pid)

	if ok and h and not h:IsNull() then return h end

	return nil
end

-- Обёртка для золота: на время вызова ставит MatchTelemetry.goldSource
local function ScopeGold(name, orig)
	return function(self, ...)
		local prev = MatchTelemetry.goldSource

		MatchTelemetry.goldSource = name

		local ok, r = pcall(orig, self, ...)

		MatchTelemetry.goldSource = prev

		if not ok then error(r, 0) end

		return r
	end
end

-- Источник для безумрудов и томов (не золото). onlyIfNil - не перебивать внешний
local madSource = nil

local function ScopeMad(name, orig, onlyIfNil)
	return function(self, ...)
		local prev = madSource

		if not (onlyIfNil and prev ~= nil) then madSource = name end

		local ok, r = pcall(orig, self, ...)

		madSource = prev

		if not ok then error(r, 0) end

		return r
	end
end

-- ------------------------------------------------------------------ сводка gold_src
-- Только золото вне фильтра: запас и командные переносы. Копим по "pid|источник"

local goldAgg = {}

local function GoldSrc(pid, gold, source)
	if not PidOk(pid) then return end

	local amount = math.floor(tonumber(gold) or 0)

	if amount <= 0 then return end

	local key = pid .. "|" .. source
	local g = goldAgg[key]

	if not g then
		g = { pid = pid, source = source, amount = 0 }
		goldAgg[key] = g
	end

	g.amount = g.amount + amount
end

-- Золото с крипов по типу кемпа (easy/normal/hard/ancient/necro, creep._aa_camp из
-- lib/spawners/creep_leveling.lua). Отдельное событие "camp_gold", в gold_by_source НЕ идёт:
-- там это золото уже есть как "creep"/"neutral". Сумма - баунти крипа до делёжки и множителей.
local campAgg = {}

local function CampGold(pid, camp, gold)
	if not PidOk(pid) or not camp then return end

	local key = pid .. "|" .. camp
	local g = campAgg[key]

	if not g then
		g = { pid = pid, camp = camp, amount = 0, kills = 0 }
		campAgg[key] = g
	end

	g.amount = g.amount + math.floor(tonumber(gold) or 0)
	g.kills = g.kills + 1
end

local function FlushGoldSrc()
	for _, g in pairs(goldAgg) do
		Push("gold_src", g.pid, { source = g.source, amount = g.amount })
	end

	goldAgg = {}

	for _, g in pairs(campAgg) do
		Push("camp_gold", g.pid, { camp = g.camp, amount = g.amount, kills = g.kills })
	end

	campAgg = {}
end

-- ------------------------------------------------------------------ урон, полученный героями
-- Вызывается только для урона, который прошёл DamageFilter (MatchTracker:OnDamageApplied).
-- Жертва - настоящий герой (не иллюзия). Источник: "hero" - герой игрока,
-- "boss" - юнит с modifier_boss_power (lib/boss), "creep" - прочие юниты,
-- "other" - без атакующего.

local dmgAgg = {} -- "pid|источник" -> { pid, source, amount }

local function DamageSourceOf(attacker)
	if not attacker then return "other" end

	local ok, kind = pcall(function()
		if attacker:IsRealHero() and not attacker:IsIllusion() then return "hero" end

		if attacker:HasModifier("modifier_boss_power") then return "boss" end

		return "creep"
	end)

	if ok then return kind end

	return "creep"
end

local function RecordDamageTaken(ev)
	local victim = ev.entindex_victim_const and EntIndexToHScript(ev.entindex_victim_const) or nil

	if not victim then return end

	local pid = -1

	pcall(function()
		if victim:IsRealHero() and not victim:IsIllusion() then pid = victim:GetPlayerOwnerID() end
	end)

	if not PidOk(pid) then return end

	local amount = math.floor(tonumber(ev.damage) or 0)

	if amount <= 0 then return end

	local attacker = ev.entindex_attacker_const and EntIndexToHScript(ev.entindex_attacker_const) or nil
	local source = DamageSourceOf(attacker)
	local key = pid .. "|" .. source
	local a = dmgAgg[key]

	if not a then
		a = { pid = pid, source = source, amount = 0 }
		dmgAgg[key] = a
	end

	a.amount = a.amount + amount
end

local function FlushDamageTaken()
	for _, a in pairs(dmgAgg) do
		Push("damage_taken", a.pid, { source = a.source, amount = a.amount })
	end

	dmgAgg = {}
end

-- ------------------------------------------------------------------ тома статов
-- Стаки bonus_*_tome меняются только в UpgradeStats (тома) и при штрафе за смерть.
-- Сравниваем с последним известным значением, разница - событие stats.

local lastTome = {} -- pid -> { str, agi, int }

local function StackOf(hero, name)
	local m = hero:FindModifierByName(name)

	return m and m:GetStackCount() or 0
end

local function Reconcile(hero, source, item)
	if not hero then return end

	local pid = hero:GetPlayerOwnerID()

	if not PidOk(pid) then return end

	local cur = {
		str = StackOf(hero, "bonus_str_tome"),
		agi = StackOf(hero, "bonus_agi_tome"),
		int = StackOf(hero, "bonus_int_tome"),
	}
	local prev = lastTome[pid]

	lastTome[pid] = cur

	-- первый замер - только база, событие не шлём
	if not prev then return end

	local dStr = cur.str - prev.str
	local dAgi = cur.agi - prev.agi
	local dInt = cur.int - prev.int

	if dStr == 0 and dAgi == 0 and dInt == 0 then return end

	Push("stats", pid, { str = dStr, agi = dAgi, int = dInt, source = source, item = item })
end

-- ------------------------------------------------------------------ нейтралки, безумруды

-- Книжка съедена (вызов из tome.lua: UpgradeStats / MedicalTractat).
-- amount - полный прирост стата (стаки bonus_*_tome - только половина).
-- Событие "tome" на каждый стат, накопленное - в heartbeat (tome_*).
local tomeTotals = {} -- pid -> { str, agi, int, tractate }

function MatchTelemetry.OnTome(hero, item, gains)
	if not hero or not hero.GetPlayerOwnerID then return end

	local pid = hero:GetPlayerOwnerID()

	if not PidOk(pid) then return end

	local tot = tomeTotals[pid]

	if not tot then
		tot = { str = 0, agi = 0, int = 0, tractate = 0 }
		tomeTotals[pid] = tot
	end

	local s, a, i = gains.str or 0, gains.agi or 0, gains.int or 0

	if s > 0 and s == a and a == i then
		Push("tome", pid, { item = item, stat = "all", amount = s })
	else
		for _, k in ipairs({ "str", "agi", "int" }) do
			if (gains[k] or 0) > 0 then Push("tome", pid, { item = item, stat = k, amount = gains[k] }) end
		end
	end

	if (gains.tractate or 0) > 0 then Push("tome", pid, { item = item, stat = "tractate", amount = gains.tractate }) end

	for k, v in pairs(gains) do
		if tot[k] then tot[k] = tot[k] + v end
	end
end

local function MadGet(sys, pid)
	local ok, v = pcall(sys.GetMadstones, sys, pid)

	return ok and tonumber(v) or nil
end

local function SlotItem(hero, slot)
	local it = hero:GetItemInSlot(slot)

	if not it then return nil end

	return { name = it:GetAbilityName(), level = it:GetLevel() }
end

-- состояние до крафта: что надето, сколько безумрудов, цена, тип страницы
local function CraftSnapshot(sys, event)
	local pid = event and event.PlayerID

	if not PidOk(pid) then return nil end

	local hero = Hero(pid)

	if not hero then return nil end

	local tier = sys:GetAllowedTier()

	return {
		pid      = pid,
		tier     = tier,
		m0       = MadGet(sys, pid),
		cost     = sys:GetPlayerCraftCost(pid, tier),
		reroll   = sys:IsReroll(pid, tier) and true or false,
		item     = SlotItem(hero, SLOT_NEUTRAL),
		enh      = SlotItem(hero, SLOT_ENHANCEMENT),
		itemTier = tonumber(event.item_tier) or tier,
		enhTier  = tonumber(event.enh_tier) or tier,
	}
end

-- после крафта: если безумрудов стало меньше - крафт прошёл, шлём трату и предметы
local function CraftReport(sys, s)
	local m1 = MadGet(sys, s.pid)

	if not s.m0 or not m1 or m1 >= s.m0 then return end

	Push("madstone", s.pid, { delta = m1 - s.m0, total = m1, source = "craft" })

	local hero = Hero(s.pid)

	if not hero then return end

	local function Report(kind, slot, before, tier, cost, skipKeep)
		local now = SlotItem(hero, slot)

		if not now then return end

		local same = before and before.name == now.name and before.level == now.level

		-- слот не менялся: для чар это не крафт, пропускаем; для предмета - "оставил своё"
		if same and skipKeep then return end

		local action = same and "keep" or (s.reroll and "reroll" or "craft")

		Push("neutral", s.pid, {
			item   = now.name,
			tier   = tier,
			kind   = kind,
			level  = now.level,
			action = action,
			cost   = cost,
		})
	end

	Report("trinket", SLOT_NEUTRAL, s.item, s.itemTier, s.cost, false)
	Report("enchant", SLOT_ENHANCEMENT, s.enh, s.enhTier, 0, true)
end

-- ------------------------------------------------------------------ дуэль

-- все герои команды (для награды: ApplyForHeroes в _OnDuelEnd берёт всех)
local function TeamPids(team)
	local list = {}

	pcall(function()
		TeamHelper:ApplyForHeroes(team, function(pid)
			if PidOk(pid) then list[#list + 1] = pid end
		end, true)
	end)

	table.sort(list)

	return list
end

-- бойцы текущей дуэли: DuelLibrary.currentWarriors выставляет DuelLibrary:StartDuel
-- (lib/duel/duel_lib.lua) после выбора; team - только бойцы этой команды
local function WarriorPids(team)
	local list = {}
	local cw = DuelLibrary and DuelLibrary.currentWarriors

	if type(cw) ~= "table" then return list end

	for hero in pairs(cw) do
		pcall(function()
			if team == nil or hero:GetTeamNumber() == team then
				local pid = hero:GetPlayerOwnerID()

				if PidOk(pid) then list[#list + 1] = pid end
			end
		end)
	end

	table.sort(list)

	return list
end

-- ------------------------------------------------------------------ обёртки

local wrapped = {}
local jobs = {}

-- owner - имя глобальной таблицы ("_G" для глобальных функций), key - поле
local function Wrap(owner, key, make)
	jobs[#jobs + 1] = { owner = owner, key = key, make = make, done = false }
end

-- Пробуем все необёрнутые; true - остались такие, у которых модуля ещё нет
local function TryJobs()
	local left = false

	for _, j in ipairs(jobs) do
		if not j.done then
			local t = _G[j.owner]

			if type(t) == "table" and type(t[j.key]) == "function" then
				j.done = true

				local id = j.owner .. "." .. j.key

				if not wrapped[id] then
					wrapped[id] = true

					local ok, err = pcall(function() t[j.key] = j.make(t[j.key]) end)

					if not ok then print("[MatchTelemetry] обёртка не встала: " .. id .. " " .. tostring(err)) end
				end
			else
				left = true
			end
		end
	end

	return left
end

-- Выдача золота AngelArena:GiveGold. Кошелёк пишет фильтр (трекер берёт метку
-- MatchTelemetry.goldSource), запас пишем здесь. Командная выплата (_paying)
-- трекер пропускает целиком, поэтому пишем её здесь целиком.
-- reason 0 приходит только из lib/admin_panel.lua:162 (выдача админа), см. отчёт.
Wrap("AngelArena", "GiveGold", function(orig)
	return function(self, playerid, gold, reliable, reason)
		local paying = TeamGoldShare and TeamGoldShare._paying and true or false
		local src = MatchTelemetry.goldSource

		if not src and reason == 0 then src = "admin" end

		local stashBefore = 0

		pcall(function()
			local tp = self.tPlayers

			if tp and tp[playerid] and tp[playerid].gold then stashBefore = tp[playerid].gold end
		end)

		local prev = MatchTelemetry.goldSource

		if not paying then MatchTelemetry.goldSource = src end

		local ok, err = pcall(orig, self, playerid, gold, reliable, reason)

		MatchTelemetry.goldSource = prev

		if not ok then error(err, 0) end

		if paying then
			pcall(GoldSrc, playerid, gold, "share_in")
			return
		end

		pcall(function()
			local tp = self.tPlayers
			local added = 0

			if tp and tp[playerid] and tp[playerid].gold then added = tp[playerid].gold - stashBefore end

			if added > 0 then GoldSrc(playerid, added, src or "other") end
		end)
	end
end)

-- камбэк: lib/comeback_system.lua, ComebackSystem:OnKill (вызов из addon_game_mode)
Wrap("ComebackSystem", "OnKill", function(orig) return ScopeGold("comeback", orig) end)

-- бонус за убийство героя: lib/hero_kill_bounty.lua
Wrap("HeroKillBounty", "OnEntityKilled", function(orig) return ScopeGold("hero_kill", orig) end)

-- командная делёжка: доля, которую отдал получатель (share_out)
Wrap("TeamGoldShare", "OnGold", function(orig)
	return function(self, playerid, gold, reason)
		local kept = orig(self, playerid, gold, reason)

		pcall(function()
			if type(kept) == "number" and type(gold) == "number" and kept < gold then
				GoldSrc(playerid, gold - kept, "share_out")
			end
		end)

		return kept
	end
end)

-- награда за босса: lib/boss/boss_class.lua, BossClass:OnDeath
Wrap("BossClass", "OnDeath", function(orig)
	local scoped = ScopeGold("boss", orig)

	return function(self, killerTeam, killer)
		local r = scoped(self, killerTeam, killer)

		pcall(function()
			local pid = -1

			if killer and not killer:IsNull() then pid = killer:GetPlayerOwnerID() end

			Push("boss_kill", PidOk(pid) and pid or -1, { boss = tostring(self.name or ""), team = killerTeam })
		end)

		return r
	end
end)

-- башня: захват даёт награду в tower_controller:OnAttacked (lib/tower/tower_base.lua:156).
-- Класс грузится только когда модификатор башни впервые применён, поэтому обёртка
-- ставится повторными попытками (см. JobsPoll).
Wrap("tower_controller", "OnAttacked", function(orig) return ScopeGold("tower", orig) end)

-- урон, прошедший фильтр: MatchTracker:OnDamageApplied вызывается только при r == true
Wrap("MatchTracker", "OnDamageApplied", function(orig)
	return function(self, ev)
		local r = orig(self, ev)

		pcall(RecordDamageTaken, ev)

		return r
	end
end)

-- Том статов: UpgradeStats (tome.lua) - глобальная функция, её вызывает предмет
Wrap("_G", "UpgradeStats", function(orig)
	return function(keys)
		local hero = keys and keys.caster or nil

		if hero then pcall(Reconcile, hero, "other", nil) end

		orig(keys)

		if hero then
			local item = nil

			pcall(function() item = keys.ability and keys.ability:GetAbilityName() or nil end)
			pcall(Reconcile, hero, "tome", item)
		end
	end
end)

-- безумруды: зачисление (_Grant) и трата при крафте (OnCraftRequest)
Wrap("MadstoneSystem", "_Grant", function(orig)
	return function(self, playerID, amount)
		local before = MadGet(self, playerID)

		orig(self, playerID, amount)

		local after = MadGet(self, playerID)

		if before and after and after ~= before and PidOk(playerID) then
			Push("madstone", playerID, { delta = after - before, total = after, source = madSource or "other" })
		end
	end
end)

Wrap("MadstoneSystem", "AddMadstones", function(orig) return ScopeMad("item", orig, true) end)
Wrap("MadstoneSystem", "OnMidasUsed", function(orig) return ScopeMad("midas", orig) end)
Wrap("MadstoneSystem", "OnCampClear", function(orig) return ScopeMad("camp_clear", orig) end)

Wrap("MadstoneSystem", "OnCraftRequest", function(orig)
	return function(self, event)
		local snap = nil

		pcall(function() snap = CraftSnapshot(self, event) end)

		orig(self, event)

		if snap then pcall(CraftReport, self, snap) end
	end
end)

-- дуэль: старт (DuelController:_StartDuel возвращает true, если дуэль пошла)
Wrap("DuelController", "_StartDuel", function(orig)
	return function(self)
		local r = orig(self)

		if r == true then
			pcall(function()
				local duelNo = DuelLibrary:GetDuelCount()
				local parts = WarriorPids(nil)

				if #parts > 0 then
					Push("duel_start", -1, { duel_no = duelNo, participants = parts })
				else
					-- бойцов не нашли: шлём всех героев обеих команд с пометкой
					local all = {}

					for _, team in ipairs({ DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS }) do
						for _, pid in ipairs(TeamPids(team)) do all[#all + 1] = pid end
					end

					Push("duel_start", -1, { duel_no = duelNo, participants = all, all_heroes = true })
				end
			end)
		end

		return r
	end
end)

-- дуэль: конец. Награда победителям идёт через PlayerResource:ModifyGold и
-- проходит через фильтр золота: трекер пишет её с меткой "duel" (ScopeGold).
-- Здесь только замеряем разницу кошелька для reward_gold.
Wrap("DuelController", "_OnDuelEnd", function(orig)
	local scoped = ScopeGold("duel", orig)

	return function(self, winnerTeam)
		local winners, losers, rewarded = {}, {}, {}
		local goldBefore = {}
		local duelNo = nil

		pcall(function()
			duelNo = DuelLibrary:GetDuelCount()

			if winnerTeam == DOTA_TEAM_GOODGUYS or winnerTeam == DOTA_TEAM_BADGUYS then
				local other = (winnerTeam == DOTA_TEAM_GOODGUYS) and DOTA_TEAM_BADGUYS or DOTA_TEAM_GOODGUYS

				winners = WarriorPids(winnerTeam)
				losers = WarriorPids(other)
				rewarded = TeamPids(winnerTeam)
			end

			for _, pid in ipairs(rewarded) do goldBefore[pid] = PlayerResource:GetGold(pid) end
		end)

		scoped(self, winnerTeam)

		pcall(function()
			local reward = 0

			for _, pid in ipairs(rewarded) do
				local d = PlayerResource:GetGold(pid) - (goldBefore[pid] or 0)

				if d > reward then reward = d end
			end

			Push("duel_end", -1, {
				duel_no     = duelNo,
				winner_team = winnerTeam,
				winners     = winners,
				losers      = losers,
				reward_gold = reward > 0 and math.floor(reward) or nil,
			})
		end)
	end
end)

-- смена героя: одно событие "hero" на каждый выбор (штатный из трекера убран)
local lastHero = {} -- pid -> имя текущего героя

Wrap("MatchTracker", "OnHeroChanged", function(orig)
	return function(self, player, heroName)
		local pid = -1

		pcall(function() pid = player:GetPlayerID() end)

		local prev = PidOk(pid) and lastHero[pid] or nil

		orig(self, player, heroName)

		if PidOk(pid) then
			lastHero[pid] = heroName

			pcall(Push, "hero", pid, {
				hero      = heroName,
				prev_hero = prev,
				reason    = prev and "repick" or "pick",
			})
		end
	end
end)

-- ------------------------------------------------------------------ события движка

-- уровень героя
ListenToGameEvent("dota_player_gained_level", function(event)
	pcall(function()
		local pid = event.player_id or event.PlayerID

		if PidOk(pid) then Push("level", pid, { level = event.level }) end
	end)
end, nil)

-- прокачка способности, в том числе талантов
ListenToGameEvent("dota_player_learned_ability", function(event)
	pcall(function()
		local pid = event.PlayerID or event.player_id
		local name = event.abilityname

		if not PidOk(pid) or not name then return end

		local hero = Hero(pid)
		local ab = hero and hero:FindAbilityByName(name) or nil

		Push("ability", pid, { ability = name, level = ab and ab:GetLevel() or nil })
	end)
end, nil)

-- руна
ListenToGameEvent("dota_rune_activated_server", function(event)
	pcall(function()
		local pid = event.PlayerID or event.player_id

		Push("rune", PidOk(pid) and pid or -1, { rune = RUNE_NAMES[event.rune] or tostring(event.rune) })
	end)
end, nil)

-- первый выбор героя: в момент первого появления героя (дальше только смены через OnHeroChanged)
ListenToGameEvent("npc_spawned", function(event)
	pcall(function()
		local u = event.entindex and EntIndexToHScript(event.entindex) or nil

		if not u or not u:IsRealHero() then return end

		local pid = u:GetPlayerOwnerID()

		if not PidOk(pid) or lastHero[pid] ~= nil then return end

		lastHero[pid] = u:GetUnitName()

		Push("hero", pid, { hero = lastHero[pid], reason = "pick" })
	end)
end, nil)

-- убийства: постройки и смерть героя (штраф за смерть снимает часть томов)
ListenToGameEvent("entity_killed", function(event)
	pcall(function()
		local killed = event.entindex_killed and EntIndexToHScript(event.entindex_killed) or nil

		if not killed then return end

		local apid = -1

		if event.entindex_attacker then
			pcall(function()
				local attacker = EntIndexToHScript(event.entindex_attacker)

				if attacker then apid = attacker:GetPlayerOwnerID() end
			end)
		end

		if killed._aa_camp then
			pcall(CampGold, apid, killed._aa_camp, killed:GetGoldBounty())
		elseif killed:IsBuilding() then
			Push("building_kill", PidOk(apid) and apid or -1, {
				building = killed:GetUnitName(),
				team     = killed:GetTeamNumber(),
			})
		elseif killed:IsRealHero() then
			-- через 0.5 с: штраф за смерть уже применён модификатором
			Timers:CreateTimer(0.5, function()
				pcall(Reconcile, killed, "death_penalty", nil)

				return nil
			end)
		end
	end)
end, nil)

-- сборка предмета: движок шлёт dota_item_combined (PlayerID, itemname, itemcost).
-- Компонентов в событии нет - сайт склеивает их по рецепту и предшествующим покупкам.
ListenToGameEvent("dota_item_combined", function(event)
	local ok, err = pcall(function()
		local pid = event.PlayerID or event.player_id

		if not PidOk(pid) or not event.itemname then return end

		Push("item_combined", pid, { item = event.itemname, cost = tonumber(event.itemcost) or nil })
	end)

	if not ok then print("[MatchTelemetry] item_combined: " .. tostring(err)) end
end, nil)

-- ------------------------------------------------------------------ сборка предметов по инвентарю
-- dota_item_combined в кастомке не приходит (за целый матч ни одного). Поэтому
-- смотрим на сами предметы: новая сущность в слотах героя (0-16, с рюкзаком,
-- тайником, ТП и нейтралкой), которую не купили только что, у которой покупатель
-- этот же герой и которая - результат рецепта, = собранный предмет.

local ITEM_SLOT_LAST = 16
local BUY_WINDOW     = 2    -- сек: предмет с таким именем купили только что - это покупка, не сборка
local recipeResult   = nil  -- имя предмета -> true, если его собирают по рецепту
local seenItems      = {}   -- pid -> { [entindex] = true }
local seenHero       = {}   -- pid -> entindex героя (после репика сканируем заново молча)
local recentBuys     = {}   -- pid -> { [имя] = время покупки }

local function RecipeResults()
	if recipeResult then return recipeResult end

	recipeResult = {}

	for _, path in ipairs({ "scripts/npc/items.txt", "scripts/npc/npc_items_custom.txt" }) do
		local ok, kv = pcall(LoadKeyValues, path)

		if ok and type(kv) == "table" then
			if type(kv.DOTAAbilities) == "table" then kv = kv.DOTAAbilities end

			for _, v in pairs(kv) do
				if type(v) == "table" and v.ItemResult and tostring(v.ItemRecipe or "0") == "1" then
					recipeResult[tostring(v.ItemResult)] = true
				end
			end
		end
	end

	return recipeResult
end

local function ScanItems(pid)
	local hero = Hero(pid)

	if not hero then return end

	local heroIdx = hero:entindex()
	local quiet = false

	if seenHero[pid] ~= heroIdx or not seenItems[pid] then
		seenHero[pid] = heroIdx
		seenItems[pid] = {}
		quiet = true -- первый проход по герою: запоминаем, что уже есть
	end

	local seen = seenItems[pid]
	local results = RecipeResults()
	local now = GameRules:GetGameTime()
	local buys = recentBuys[pid] or {}

	for slot = 0, ITEM_SLOT_LAST do
		local it = hero:GetItemInSlot(slot)

		if it and not it:IsNull() then
			local idx = it:entindex()

			if not seen[idx] then
				seen[idx] = true

				local name = it:GetAbilityName()
				local bought = buys[name]

				if not quiet and results[name] and not (bought and now - bought < BUY_WINDOW) then
					local okp, owner = pcall(it.GetPurchaser, it)

					if okp and owner == hero then
						local okc, cost = pcall(it.GetCost, it)

						Push("item_combined", pid, { item = name, cost = okc and cost or nil, src = "inv" })
					end
				end
			end
		end
	end
end

ListenToGameEvent("dota_item_purchased", function(event)
	pcall(function()
		local pid = event.PlayerID or event.player_id

		if not PidOk(pid) or not event.itemname then return end

		recentBuys[pid] = recentBuys[pid] or {}
		recentBuys[pid][event.itemname] = GameRules:GetGameTime()

		-- сборка случается сразу после покупки последнего компонента
		Timers:CreateTimer(0.1, function()
			pcall(ScanItems, pid)

			return nil
		end)
	end)
end, nil)

-- ------------------------------------------------------------------ контроль и стаки
-- Каждые CC_TICK сек смотрим на каждого живого героя: если он в стане / хексе /
-- руте / сайленсе, время засчитывается врагам-героям, чьи дебаффы на нём висят
-- (для стана - только модификаторам с IsStunDebuff, если такие есть). Без
-- виновника-героя (крипы, боссы) - на pid -1. Сводка "cc" раз в GOLD_FLUSH сек.
-- Стаки: раз в секунду запоминаем максимум GetStackCount по модификаторам на
-- герое, новое значение максимума уходит событием "stacks" раз в STACK_FLUSH сек.

local CC_TICK     = 0.25
local STACK_TICK  = 1
local STACK_FLUSH = 15
local ccAgg       = {} -- "caster|victim|kind|mod" -> { caster, victim, kind, mod, sec }
local stackMax    = {} -- "pid|mod" -> { pid, mod, max, caster, ability, dirty }

local function CcKind(h)
	if h:IsStunned() then return "stun" end
	if h:IsHexed() then return "hex" end
	if h:IsRooted() then return "root" end
	if h:IsSilenced() then return "silence" end

	return nil
end

local function ModInfo(m, h)
	local info = { caster = -1 }

	pcall(function()
		local c = m:GetCaster()

		if c and not c:IsNull() then
			info.enemy = c:GetTeamNumber() ~= h:GetTeamNumber()

			local cp = c:GetPlayerOwnerID()

			if PidOk(cp) then info.caster = cp end
		end
	end)

	pcall(function()
		local ab = m:GetAbility()

		if ab and not ab:IsNull() then info.ability = ab:GetAbilityName() end
	end)

	return info
end

local function CcAdd(caster, victim, kind, mod, sec)
	local key = caster .. "|" .. victim .. "|" .. kind .. "|" .. mod
	local a = ccAgg[key]

	if not a then
		a = { caster = caster, victim = victim, kind = kind, mod = mod, sec = 0 }
		ccAgg[key] = a
	end

	a.sec = a.sec + sec
end

local function CcTick()
	for pid = 0, 23 do
		if PidOk(pid) then
			local h = Hero(pid)

			if h and h:IsAlive() and not h:IsIllusion() then
				local kind = CcKind(h)

				if kind then
					local strict, loose = {}, {}

					for _, m in ipairs(h:FindAllModifiers()) do
						local okd, deb = pcall(m.IsDebuff, m)
						local info = ModInfo(m, h)

						if info.enemy and okd and deb then
							local name = m:GetName()

							loose[#loose + 1] = { info.caster, name }

							local oks, isStun = pcall(m.IsStunDebuff, m)

							if kind == "stun" and oks and isStun then strict[#strict + 1] = { info.caster, name } end
						end
					end

					local list = (#strict > 0) and strict or loose

					if #list == 0 then list = { { -1, "unknown" } } end

					-- одно и то же время делим поровну между виновниками
					local share = CC_TICK / #list

					for _, x in ipairs(list) do CcAdd(x[1], pid, kind, x[2], share) end
				end
			end
		end
	end
end

local function FlushCc()
	for _, a in pairs(ccAgg) do
		Push("cc", a.caster, { victim_pid = a.victim, kind = a.kind, mod = a.mod, sec = math.floor(a.sec * 100 + 0.5) / 100 })
	end

	ccAgg = {}
end

local function StackTick()
	for pid = 0, 23 do
		if PidOk(pid) then
			local h = Hero(pid)

			if h and h:IsAlive() and not h:IsIllusion() then
				for _, m in ipairs(h:FindAllModifiers()) do
					local okn, n = pcall(m.GetStackCount, m)
					local name = m:GetName()

					-- тома копят тысячи стаков, у них свое событие "tome"
					if okn and type(n) == "number" and n >= 2 and not string.find(name, "tome", 1, true) then
						local key = pid .. "|" .. name
						local s = stackMax[key]

						if not s or n > s.max then
							local info = ModInfo(m, h)

							stackMax[key] = { pid = pid, mod = name, max = n, caster = info.caster, ability = info.ability, enemy = info.enemy and true or false, dirty = true }
						end
					end
				end
			end
		end
	end
end

local function FlushStacks()
	for _, s in pairs(stackMax) do
		if s.dirty then
			s.dirty = false
			Push("stacks", s.pid, { mod = s.mod, max = s.max, caster_pid = s.caster, ability = s.ability, enemy = s.enemy })
		end
	end
end

Timers:CreateTimer(CC_TICK, function()
	local ok, err = pcall(CcTick)

	if not ok then print("[MatchTelemetry] cc: " .. tostring(err)) end

	return CC_TICK
end)

Timers:CreateTimer(STACK_TICK, function()
	local ok, err = pcall(StackTick)

	if not ok then print("[MatchTelemetry] stacks: " .. tostring(err)) end

	-- заодно добираем сборки, которые случились не от покупки (подбор компонента и т.п.)
	for pid = 0, 23 do
		if PidOk(pid) then pcall(ScanItems, pid) end
	end

	return STACK_TICK
end)

Timers:CreateTimer(STACK_FLUSH, function()
	pcall(FlushStacks)

	return STACK_FLUSH
end)

-- ------------------------------------------------------------------ heartbeat

-- Доп. поля снимка игрока в heartbeat: PlayerSnapshot в lib/match_tracker.lua сливает их в снимок
MatchTracker.HeartbeatExtra = function(pid)
	local hero = Hero(pid)
	local items = {}

	for slot = 0, 5 do
		local name = ""

		pcall(function()
			local it = hero and hero:GetItemInSlot(slot) or nil

			if it then name = it:GetAbilityName() end
		end)

		items[#items + 1] = name
	end

	local neutral = ""

	pcall(function()
		local it = hero and hero:GetItemInSlot(SLOT_NEUTRAL) or nil

		if it then neutral = it:GetAbilityName() end
	end)

	items[#items + 1] = neutral

	local alive = hero and hero:IsAlive() or false
	local respawn = 0

	if hero and not alive then
		pcall(function() respawn = hero:GetRespawnTime() or 0 end)
	end

	return {
		str       = hero and hero:GetStrength() or 0,
		agi       = hero and hero:GetAgility() or 0,
		int       = hero and hero:GetIntellect(false) or 0,
		xp        = hero and hero:GetCurrentXP() or 0,
		gold      = PlayerResource:GetGold(pid),
		net_worth = (MatchTracker and MatchTracker.NetWorthOf) and MatchTracker.NetWorthOf(pid) or PlayerResource:GetNetWorth(pid),
		items     = items,
		respawn   = respawn,
		alive     = alive,
		-- накопленное с книжек (MatchTelemetry.OnTome)
		tome_str      = tomeTotals[pid] and tomeTotals[pid].str or 0,
		tome_agi      = tomeTotals[pid] and tomeTotals[pid].agi or 0,
		tome_int      = tomeTotals[pid] and tomeTotals[pid].int or 0,
		tome_tractate = tomeTotals[pid] and tomeTotals[pid].tractate or 0,
	}
end

-- ------------------------------------------------------------------ фон

local lastKillLimit = nil

local function CheckKillLimit()
	local kl = rawget(_G, "KILL_LIMIT")

	if type(kl) == "number" and kl ~= lastKillLimit then
		lastKillLimit = kl
		Push("kill_limit", -1, { limit = kl })
	end
end

Timers:CreateTimer(GOLD_FLUSH, function()
	pcall(FlushGoldSrc)
	pcall(FlushDamageTaken)
	pcall(FlushCc)
	pcall(CheckKillLimit)

	return GOLD_FLUSH
end)

-- ------------------------------------------------------------------ установка обёрток

-- Модули грузятся до этого файла, башня - позже; повторяем попытку таймером
local tries = 0

local function JobsPoll()
	tries = tries + 1

	local left = TryJobs()

	if left and tries < JOB_TRIES then return GOLD_FLUSH end

	if left then print("[MatchTelemetry] часть модулей не загрузилась, их обёртки не стоят") end

	return nil
end

if TryJobs() then Timers:CreateTimer(GOLD_FLUSH, JobsPoll) end
