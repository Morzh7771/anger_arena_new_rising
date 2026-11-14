-- Таблица рейтинга для вкладки "Рейтинг" меню (premium_hub_test.js -> rating).
--
-- Подписанный POST /api/leaderboard (бэкенд leaderboard_api.py) через AATrackerLobbyPost
-- (lib/match_tracker.lua), тело { steam_ids = [игроки лобби] }.
-- Запрос: при входе в выбор героя / PRE_GAME и дальше раз в REFRESH секунд.
--
-- Нет-таблица aa_leaderboard:
--   "meta"         = { state = "loading" | "ok" | "fail", total, t }
--   "top1".."top4" = { ["1"] = { p, s, n, m, h, w, l }, ... }  по 25 строк (место, steam_id, ник, mmr, лучший герой, W, L)
--   "<pid>"        = { place (0 - калибровка), mmr, cd, ct, h }  своя строка игрока

if not IsServer() then return end
if AALeaderboard ~= nil then return end

AALeaderboard = { inflight = false, started = false, has_data = false }

local L = AALeaderboard
local NT = "aa_leaderboard"
local CHUNK = 25
local CHUNKS = 4
local REFRESH = 300

local function SteamIdOf(pid)
	if CosmeticsCore and CosmeticsCore.SteamIdOf then
		local ok, sid = pcall(CosmeticsCore.SteamIdOf, CosmeticsCore, pid)

		if ok and sid and sid ~= "" and sid ~= "76561197960265728" then return tostring(sid) end
	end

	return nil
end

local function Meta(state, total)
	CustomNetTables:SetTableValue(NT, "meta", { state = state, total = total or 0, t = math.floor(GameRules:GetGameTime()) })
end

local function Apply(resp, pids)
	local top = type(resp.top) == "table" and resp.top or {}
	local chunks = {}

	for c = 1, CHUNKS do chunks[c] = {} end

	for i, r in ipairs(top) do
		local c = math.floor((i - 1) / CHUNK) + 1

		if c > CHUNKS then break end

		chunks[c][tostring(i)] = {
			p = tonumber(r.place) or i,
			s = tostring(r.steam_id or ""),
			n = string.sub(tostring(r.name or ""), 1, 64),
			m = tonumber(r.mmr) or 0,
			h = type(r.best_hero) == "string" and r.best_hero or "",
			w = tonumber(r.wins) or 0,
			l = tonumber(r.losses) or 0,
		}
	end

	for c = 1, CHUNKS do CustomNetTables:SetTableValue(NT, "top" .. c, chunks[c]) end

	local me = type(resp.me) == "table" and resp.me or {}

	for pid, sid in pairs(pids) do
		local r = me[sid]

		if type(r) == "table" then
			CustomNetTables:SetTableValue(NT, tostring(pid), {
				place = tonumber(r.place) or 0,
				mmr = tonumber(r.mmr) or 0,
				cd = tonumber(r.calib_done) or 0,
				ct = tonumber(r.calib_total) or 5,
				h = type(r.best_hero) == "string" and r.best_hero or "",
			})
		end
	end

	L.has_data = true
	Meta("ok", tonumber(resp.total) or #top)
end

function L:Request()
	if self.inflight or not AATrackerLobbyPost then return end

	local pids, sids = {}, {}

	for pid = 0, 23 do
		if PlayerResource:IsValidPlayerID(pid) and not PlayerResource:IsFakeClient(pid) then
			local sid = SteamIdOf(pid)

			if sid then
				pids[pid] = sid
				table.insert(sids, sid)
			end
		end
	end

	if not self.has_data then Meta("loading") end

	self.inflight = true

	AATrackerLobbyPost("/api/leaderboard", { steam_ids = sids }, function(ok, resp)
		L.inflight = false

		if not ok or type(resp) ~= "table" then
			print("[Leaderboard] сервер не ответил")
			-- старый список оставляем, панель покажет "не ответил" только если данных не было
			if not L.has_data then Meta("fail") end

			return
		end

		local okA, err = pcall(Apply, resp, pids)

		if not okA then
			print("[Leaderboard] apply failed: " .. tostring(err))
			if not L.has_data then Meta("fail") end
		end
	end)
end

function L:Start()
	if self.started then return end

	self.started = true

	Timers:CreateTimer(0, function()
		local ok, err = pcall(L.Request, L)

		if not ok then
			L.inflight = false
			print("[Leaderboard] request failed: " .. tostring(err))
		end

		return REFRESH
	end)
end

ListenToGameEvent("game_rules_state_change", function()
	local s = GameRules:State_Get()

	if s >= DOTA_GAMERULES_STATE_HERO_SELECTION and s < DOTA_GAMERULES_STATE_POST_GAME then
		local ok, err = pcall(L.Start, L)

		if not ok then print("[Leaderboard] start failed: " .. tostring(err)) end
	end
end, nil)

return L
