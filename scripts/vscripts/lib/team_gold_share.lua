-- Командная делёжка золота.
--
-- Когда герой получает золото ЗА КРИПОВ, смотрим его тимейтов. Каждому, у кого нетворс
-- меньше хотя бы на RICHER_PCT (нетворс получателя >= нетворс тимейта * 1.4),
-- уходит SHARE_PCT от этого золота, и ровно столько получатель недополучает.
-- Богаче всех четверых - отдаёт по 10% каждому, 40% в сумме.
--
-- Мелкий доход (золото за тик - пара монет) по 10% округлялся бы в ноль,
-- поэтому доли копятся с дробной частью и выплачиваются целыми монетами.
--
-- Зовёт AngelArena:GoldFilter. Выплаты идут через AngelArena:GiveGold под
-- флагом _paying, и фильтр такое золото второй раз не делит.

TeamGoldShare = TeamGoldShare or {}

local RICHER_PCT = 40
local SHARE_PCT = 10

TeamGoldShare._owed = TeamGoldShare._owed or {}   -- [дающий][получающий] = дробный долг
TeamGoldShare._paying = false

-- Золото, которое делить нельзя: камбек, докладка из копилки в кошелёк.
-- Выдаём его через Bypass - фильтр видит флаг и пропускает делёжку.
TeamGoldShare._bypass = false

function TeamGoldShare:Bypass(fn, ...)
	local was = self._bypass
	self._bypass = true

	local ok, err = pcall(fn, ...)

	self._bypass = was

	if not ok then print("[TeamGoldShare] ошибка в Bypass: " .. tostring(err)) end
end

local function NetWorth(playerid)
	local nw = PlayerResource:GetNetWorth(playerid) or 0
	local bank = AngelArena and AngelArena.tPlayers and AngelArena.tPlayers[playerid]

	return nw + (bank and bank.gold or 0)
end

-- Пока делится ТОЛЬКО золото за убийство крипов (линейных и нейтральных).
-- Боссы, убийства героев, Midas, дуэль, пассивное золото и руны не делятся.
local SHARED_REASONS = {
	[DOTA_ModifyGold_CreepKill or 13]   = true,
	[DOTA_ModifyGold_NeutralKill or 14] = true,
}

-- Возвращает, сколько золота из gold остаётся самому получателю.
function TeamGoldShare:OnGold(playerid, gold, reason)
	if self._paying then return gold end
	if not SHARED_REASONS[reason] then return gold end
	if not gold or gold <= 0 then return gold end
	if not PlayerResource:IsValidPlayerID(playerid) then return gold end
	if IsAbadonedPlayerID and IsAbadonedPlayerID(playerid) then return gold end

	local team = PlayerResource:GetTeam(playerid)
	local myNw = NetWorth(playerid)
	local kept = gold
	local payouts = {}

	for mate = 0, (DOTA_MAX_PLAYERS or 24) - 1 do
		if mate ~= playerid
			and PlayerResource:IsValidPlayerID(mate)
			and PlayerResource:GetTeam(mate) == team
			and not (IsAbadonedPlayerID and IsAbadonedPlayerID(mate))
			and myNw >= NetWorth(mate) * (100 + RICHER_PCT) / 100
		then
			self._owed[playerid] = self._owed[playerid] or {}

			local owed = (self._owed[playerid][mate] or 0) + gold * SHARE_PCT / 100
			local whole = math.floor(owed)

			self._owed[playerid][mate] = owed - whole

			if whole > 0 then
				kept = kept - whole
				payouts[mate] = whole
			end
		end
	end

	-- выплаты - в следующем кадре: изнутри фильтра золота ModifyGold не зовём
	if next(payouts) then
		Timers:CreateTimer(0, function()
			self._paying = true

			for mate, amount in pairs(payouts) do
				local ok, err = pcall(AngelArena.GiveGold, AngelArena, mate, amount, false, DOTA_ModifyGold_SharedGold or 0)

				if not ok then print("[TeamGoldShare] выплата упала: " .. tostring(err)) end

				if ok and EndGameStats and EndGameStats.OnTeamShareGold then
					EndGameStats:OnTeamShareGold(mate, amount)
				end

				if ok and EndGameStats and EndGameStats.OnTeamShareGiven then
					EndGameStats:OnTeamShareGiven(playerid, amount)
				end
			end

			self._paying = false
		end)
	end

	return math.max(0, kept)
end

-- ---------------------------------------------------------------- для HUD
-- Кто кому сейчас отдаёт золото. Раз в секунду пересчитываем и пишем в
-- нет-таблицу team_gold_share только тем игрокам, у кого что-то поменялось:
-- [playerID] = { gives = "1|3", receives = "2" }. Рисует
-- panorama/scripts/custom_game/team_gold_share.js - значки под топбаром по Alt.
local PUBLISH_INTERVAL = 1.0

TeamGoldShare._published = TeamGoldShare._published or {}

function TeamGoldShare:_Publish()
	local ids = {}

	for id = 0, (DOTA_MAX_PLAYERS or 24) - 1 do
		if PlayerResource:IsValidPlayerID(id) and not (IsAbadonedPlayerID and IsAbadonedPlayerID(id)) then
			table.insert(ids, id)
		end
	end

	local gives, receives = {}, {}

	for _, id in ipairs(ids) do
		gives[id], receives[id] = {}, {}
	end

	for _, giver in ipairs(ids) do
		local team = PlayerResource:GetTeam(giver)
		local nw = NetWorth(giver)

		for _, mate in ipairs(ids) do
			if mate ~= giver and PlayerResource:GetTeam(mate) == team
				and nw >= NetWorth(mate) * (100 + RICHER_PCT) / 100 then
				table.insert(gives[giver], mate)
				table.insert(receives[mate], giver)
			end
		end
	end

	for _, id in ipairs(ids) do
		local row = { gives = table.concat(gives[id], "|"), receives = table.concat(receives[id], "|") }
		local key = row.gives .. "#" .. row.receives

		if self._published[id] ~= key then
			self._published[id] = key
			CustomNetTables:SetTableValue("team_gold_share", tostring(id), row)
		end
	end
end

if not TeamGoldShare._publishStarted then
	TeamGoldShare._publishStarted = true

	Timers:CreateTimer(PUBLISH_INTERVAL, function()
		local ok, err = pcall(TeamGoldShare._Publish, TeamGoldShare)

		if not ok then print("[TeamGoldShare] публикация упала: " .. tostring(err)) end

		return PUBLISH_INTERVAL
	end)
end
