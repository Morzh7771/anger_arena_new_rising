if not IsServer() then return end

-- Свой килфид вместо ванильного (panorama/scripts/custom_game/kill_feed.js).
-- Ванильный показывает только то золото, которое посчитал движок, а у нас
-- награды свои: ассисты, камбэк, боссы, руны, дуэли. Сюда стекаются все
-- события мода, клиент рисует их строками.
--
-- Убийство героя собирается в строку по жертве:
--   движковое золото (убийце и копеечные ассисты, первая кровь) приходит в
--     GoldFilter раньше entity_killed и копится в bucket; строка при создании
--     забирает его себе - так две смерти подряд не делят золото между собой;
--   наши выплаты (hero_kill_bounty: убийце и героям рядом) и камбэк
--     (comeback_system) докладываются прямо в строку по жертве через
--     AddAssist / AddComeback; движковое золото за героя сейчас выключено
--     в GoldFilter, bucket остался на случай его возврата;
--   строка уходит клиенту через кадр, когда все обработчики отработали.

KillFeed = KillFeed or {}

local EVENT = "aa_feed"

-- движковое золото старше этого к смерти не относится
local BUCKET_MAX_AGE = 0.5

-- через сколько отправить строку убийства / руны
local FLUSH_DELAY = 0.1

function KillFeed:Send(kind, data)
	data = data or {}
	data.kind = kind

	CustomGameEventManager:Send_ServerToAllClients(EVENT, data)
end

local function HeroName(playerid)
	local hero = PlayerResource:GetSelectedHeroEntity(playerid)

	return hero and not hero:IsNull() and hero:GetUnitName() or ""
end

local function Now()
	return GameRules:GetGameTime()
end

-- ---------------------------------------------------------------------------
-- золото и опыт из фильтров
-- ---------------------------------------------------------------------------

-- isOurs - это наша выплата (камбэк, доплата ассистам): она докладывается в
-- строку напрямую, в движковый bucket её класть нельзя
function KillFeed:OnGold(playerid, gold, reason, isOurs)
	if not gold or gold <= 0 or isOurs or self.ourPayout then return end

	if reason == DOTA_ModifyGold_HeroKill then
		self:_Add(self.killBucket, playerid, gold)
	elseif reason == DOTA_ModifyGold_BountyRune then
		self:_Add(self.runeGoldBucket, playerid, gold)
	end
end

-- опыт от движковой руны мудрости: причина у него своя, не убийство, не
-- крипы и не наш AddExperience (у того 0)
local NOT_RUNE_XP = {}

function KillFeed:OnXp(playerid, xp, reason)
	if not xp or xp <= 0 or reason == nil then return end

	if NOT_RUNE_XP[reason] then return end

	self:_Add(self.runeXpBucket, playerid, xp)
end

function KillFeed:_Add(bucket, playerid, amount)
	local now = Now()

	if bucket.time and now - bucket.time > BUCKET_MAX_AGE then
		bucket.values = {}
	end

	bucket.time = now
	bucket.values[playerid] = (bucket.values[playerid] or 0) + amount
end

function KillFeed:_Take(bucket)
	local values = bucket.values

	if bucket.time and Now() - bucket.time > BUCKET_MAX_AGE then
		values = {}
	end

	bucket.values = {}
	bucket.time = nil

	return values
end

-- ---------------------------------------------------------------------------
-- убийство героя
-- ---------------------------------------------------------------------------

function KillFeed:_Row(victim)
	local index = victim:GetEntityIndex()
	local row = self.rows[index]

	if row then return row end

	row = {
		engine = self:_Take(self.killBucket),
		assists = {},
		comeback = {},
	}

	self.rows[index] = row

	Timers:CreateTimer(FLUSH_DELAY, function()
		self.rows[index] = nil

		local ok, err = pcall(self._FlushKill, self, row)

		if not ok then print("[KillFeed] " .. tostring(err)) end
	end)

	return row
end

function KillFeed:AddAssist(victim, playerid, gold)
	if not victim or victim:IsNull() then return end

	local row = self:_Row(victim)

	row.assists[playerid] = (row.assists[playerid] or 0) + gold
end

function KillFeed:AddComeback(victim, playerid, gold)
	if not victim or victim:IsNull() then return end

	local row = self:_Row(victim)

	row.comeback[playerid] = (row.comeback[playerid] or 0) + gold
end

-- обёртка для наших выплат, чтобы фильтр не посчитал их движковыми
function KillFeed:OurPayout(fn, ...)
	local was = self.ourPayout

	self.ourPayout = true

	local ok, err = pcall(fn, ...)

	self.ourPayout = was

	if not ok then print("[KillFeed] payout: " .. tostring(err)) end
end

function KillFeed:OnEntityKilled(event)
	local victim = event.entindex_killed and EntIndexToHScript(event.entindex_killed)
	local killer = event.entindex_attacker and EntIndexToHScript(event.entindex_attacker)

	if not victim or victim:IsNull() or not victim:IsRealHero() then return end
	if victim:IsReincarnating() then return end
	-- солдаты Wukong's Command / клоны - не убийство героя
	if victim:IsClone() or victim:IsTempestDouble() then return end
	if victim:HasModifier("modifier_monkey_king_fur_army_soldier")
		or victim:HasModifier("modifier_monkey_king_fur_army_soldier_hidden") then return end
	local victimMain = PlayerResource:GetSelectedHeroEntity(victim:GetPlayerOwnerID())
	if victimMain and victimMain ~= victim then return end

	local row = self:_Row(victim)

	row.victim_pid = victim:GetPlayerOwnerID()
	row.victim_hero = victim:GetUnitName()
	row.victim_team = victim:GetTeamNumber()
	row.killer_pid = -1
	row.killer_hero = ""
	row.killer_unit = ""
	row.killer_team = DOTA_TEAM_NEUTRALS
	row.kind = "hero_kill"

	if killer and not killer:IsNull() then
		row.killer_team = killer:GetTeamNumber()
		row.killer_pid = killer:GetPlayerOwnerID() or -1

		if killer:IsHero() then
			row.killer_hero = killer:GetUnitName()
		elseif row.killer_pid >= 0 then
			-- призыв или иллюзия - рисуем героя хозяина
			row.killer_hero = HeroName(row.killer_pid)
		else
			row.killer_unit = killer:GetUnitName()
		end
	end

	-- самоубийство (сам себя, фонтан, без убийцы), добивание союзником
	if not killer or killer:IsNull() or killer == victim or (row.killer_pid >= 0 and row.killer_pid == row.victim_pid) then
		row.kind = "suicide"
	elseif row.killer_team == row.victim_team then
		row.kind = "deny"
	end
end

function KillFeed:_FlushKill(row)
	if not row.kind then return end

	-- Камбэк отдельно не пишем: он просто прибавляется к золоту убийцы и
	-- ассистов - в фиде одна сумма, сколько герой получил за это убийство.
	local killerGold = (row.engine[row.killer_pid] or 0) + (row.assists[row.killer_pid] or 0) + (row.comeback[row.killer_pid] or 0)

	-- герои рядом: всё, что им заплачено за это убийство, без убийцы
	local assists = {}

	for pid, gold in pairs(row.engine) do
		if pid ~= row.killer_pid then assists[pid] = (assists[pid] or 0) + gold end
	end

	for pid, gold in pairs(row.assists) do
		if pid ~= row.killer_pid then assists[pid] = (assists[pid] or 0) + gold end
	end

	for pid, gold in pairs(row.comeback) do
		if pid ~= row.killer_pid then assists[pid] = (assists[pid] or 0) + gold end
	end

	-- как в ванили: сумма и на сколько героев
	local assistGold, assistCount = 0, 0

	for _, gold in pairs(assists) do
		gold = math.floor(gold)

		if gold > 0 then
			assistGold = assistGold + gold
			assistCount = assistCount + 1
		end
	end

	self:Send(row.kind, {
		victim_pid = row.victim_pid,
		victim_hero = row.victim_hero,
		killer_pid = row.killer_pid,
		killer_hero = row.killer_hero,
		killer_unit = row.killer_unit,
		killer_team = row.killer_team,
		victim_team = row.victim_team,
		gold = math.floor(killerGold),
		assist_gold = assistGold,
		assist_count = assistCount,
	})
end

function KillFeed:OnBuyback(event)
	local pid = event.player_id

	if pid == nil and event.entindex then
		local hero = EntIndexToHScript(event.entindex)
		pid = hero and hero:GetPlayerOwnerID()
	end

	if pid == nil then return end

	self:Send("buyback", { pid = pid, hero = HeroName(pid) })
end

-- ---------------------------------------------------------------------------
-- события мода
-- ---------------------------------------------------------------------------

function KillFeed:Boss(killer, bossUnitName, bossKind, killerTeam, killerGold, teamGold)
	local pid = killer and not killer:IsNull() and killer:GetPlayerOwnerID() or -1

	self:Send("boss", {
		pid = pid,
		hero = pid >= 0 and HeroName(pid) or "",
		team = killerTeam,
		boss = bossUnitName,
		boss_kind = bossKind or "",
		gold = math.floor(killerGold or 0),
		team_gold = math.floor(teamGold or 0),
	})
end

-- Руну захваченного круга активирует бутылка, поэтому её награду платит и
-- движок, и наш OnRuneActivate. В фиде, как в доте, база одному герою:
-- движковая часть (замер по активатору) + наша без бонусов предметов.
-- ourBase - наша база (золото или опыт).
function KillFeed:Rune(kind, playerid, team, ourBase)
	Timers:CreateTimer(FLUSH_DELAY, function()
		local bucket = kind == "wisdom" and self.runeXpBucket or self.runeGoldBucket
		local engine = self:_Take(bucket)[playerid] or 0

		self:Send("rune", {
			rune = kind,
			pid = playerid,
			hero = HeroName(playerid),
			team = team,
			amount = math.floor((ourBase or 0) + engine),
		})
	end)
end

function KillFeed:DuelStart() self:Send("duel_start") end
function KillFeed:DuelSkipped() self:Send("duel_skip") end
function KillFeed:DuelDraw() self:Send("duel_draw") end

function KillFeed:DuelWin(team, gold)
	self:Send("duel_win", { team = team, gold = math.floor(gold or 0) })
end

function KillFeed:LastDuel() self:Send("last_duel") end

function KillFeed:NeutralTier(tier) self:Send("neutral_tier", { tier = tier }) end

function KillFeed:Tower(playerid, team, gold)
	self:Send("tower", { pid = playerid, hero = HeroName(playerid), team = team, gold = math.floor(gold or 0) })
end

function KillFeed:Courier(playerid, gold)
	self:Send("courier", { pid = playerid, hero = HeroName(playerid), gold = math.floor(gold or 0) })
end

function KillFeed:Abandon(playerid)
	self:Send("abandon", { pid = playerid, hero = HeroName(playerid) })
end

function KillFeed:Init()
	if self._started then return end
	self._started = true

	self.rows = {}
	self.killBucket = { values = {} }
	self.runeGoldBucket = { values = {} }
	self.runeXpBucket = { values = {} }

	for _, name in ipairs({ "DOTA_ModifyXP_Unspecified", "DOTA_ModifyXP_HeroKill", "DOTA_ModifyXP_CreepKill", "DOTA_ModifyXP_RoshanKill", "DOTA_ModifyXP_HeroAbility" }) do
		if _G[name] ~= nil then NOT_RUNE_XP[_G[name]] = true end
	end

	local function Wrap(fn)
		return function(event)
			local ok, err = pcall(fn, KillFeed, event)
			if not ok then print("[KillFeed] " .. tostring(err)) end
		end
	end

	ListenToGameEvent("entity_killed", Wrap(KillFeed.OnEntityKilled), nil)
	ListenToGameEvent("dota_buyback", Wrap(KillFeed.OnBuyback), nil)
end

KillFeed:Init()
