-- Прогресс игрока: батл-пасс, осколки, сундуки, задания (2026-11-12).
--
-- Всё считает бэкенд (progression.py на VPS): награды за матч, роллы сундуков, задания.
-- Игра только передаёт действия игрока и показывает результат.
--
--   профиль приходит в ответе поиска игроков (match_tracker -> CosmeticsCore:OnPlayersInfo -> Set)
--   и после каждого действия;
--   нет-таблица aa_progress[pid] = профиль (season, xp, level, level_xp, shards, chests, quests,
--     claimed_free, claimed_prem, inventory) - читает меню (premium_hub.js);
--   клиент -> сервер  aa_prog_action { action, kind?, buy?, period?, slot?, levels? }
--     action: profile | claim_levels | open_chest | claim_quest | reroll_quest | buy_item | sell_item (item_id)
--   сервер -> клиент  aa_prog_result { ok, action, error?, item?, name?, rarity?, slot?, refund? }
--
-- Подписанный запрос - AATrackerLobbyPost (lib/match_tracker.lua), путь /api/progress/action.

if not IsServer() then return end
if AAProgression ~= nil then return end

AAProgression = { data = {}, busy = {} }

local P = AAProgression

local ACTIONS = { profile = true, claim_levels = true, open_chest = true, claim_quest = true, reroll_quest = true, buy_item = true, sell_item = true, buy_token = true, use_token = true, leaderboard = true }
local BUSY_TIMEOUT = 10

function P:Set(pid, prog)
	if type(prog) ~= "table" then return end

	self.data[pid] = prog

	CustomNetTables:SetTableValue("aa_progress", tostring(pid), prog)
end

local function Reply(pid, payload)
	local player = PlayerResource:GetPlayer(pid)

	if player then CustomGameEventManager:Send_ServerToPlayer(player, "aa_prog_result", payload) end
end

local function SteamIdOf(pid)
	if CosmeticsCore and CosmeticsCore.SteamIdOf then
		local ok, sid = pcall(CosmeticsCore.SteamIdOf, CosmeticsCore, pid)

		if ok and sid and sid ~= "" and sid ~= "0" then return tostring(sid) end
	end

	return nil
end

function P:OnAction(data)
	local pid = data and tonumber(data.PlayerID)

	if pid == nil or pid < 0 then return end

	local action = tostring(data.action or "")

	if not ACTIONS[action] then return end

	-- одно действие за раз на игрока: двойной клик по "Открыть" не откроет два сундука
	local now = GameRules:GetGameTime()

	if self.busy[pid] and now - self.busy[pid] < BUSY_TIMEOUT then
		return Reply(pid, { ok = 0, action = action, error = "busy" })
	end

	local sid = SteamIdOf(pid)

	if not sid or not AATrackerLobbyPost then
		return Reply(pid, { ok = 0, action = action, error = "no_server" })
	end

	local body = { steam_id = sid, action = action }

	if action == "open_chest" then
		body.kind = tostring(data.kind or "")
		body.buy = tonumber(data.buy) == 1
		-- цена, которую видел игрок: если остаток коллекции изменил цену - бэкенд вернёт price_changed
		if tonumber(data.expect_price) then body.expect_price = tonumber(data.expect_price) end
	elseif action == "buy_token" or action == "use_token" then
		body.kind = tostring(data.kind or "")

		if action == "use_token" then
			-- жетон - только до горна и только на этот матч
			if GameRules:State_Get() >= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
				return Reply(pid, { ok = 0, action = action, error = "too_late" })
			end

			if not MatchTracker or not MatchTracker.MatchId then
				return Reply(pid, { ok = 0, action = action, error = "no_server" })
			end

			body.match_id = MatchTracker:MatchId()
			body.buy = tonumber(data.buy) == 1
		end
	elseif action == "buy_item" or action == "sell_item" then
		body.item_id = tostring(data.item_id or "")
	elseif action == "claim_quest" or action == "reroll_quest" then
		body.period = tostring(data.period or "d")
		body.slot = tonumber(data.slot) or 0
	end

	self.busy[pid] = now

	AATrackerLobbyPost("/api/progress/action", body, function(ok, resp)
		self.busy[pid] = nil

		if not ok or type(resp) ~= "table" then
			return Reply(pid, { ok = 0, action = action, error = (type(resp) == "table" and resp.error) or "server" })
		end

		if type(resp.progress) == "table" then self:Set(pid, resp.progress) end

		-- купленная/выбитая/проданная фраза: сразу обновить замки в колесе и настройках
		if (action == "buy_item" or action == "sell_item" or action == "open_chest") and CosmeticsSocial and CosmeticsSocial.SendCatalog then
			pcall(CosmeticsSocial.SendCatalog, CosmeticsSocial, pid)
		end

		local out = { ok = 1, action = action }
		local res = type(resp.result) == "table" and resp.result or {}

		if type(res.chest) == "table" then
			out.item = res.chest.item or ""
			out.name = res.chest.name or ""
			out.rarity = res.chest.rarity or ""
			out.slot = res.chest.slot or ""
			out.refund = res.chest.refund or 0
		end

		-- таблица рейтинга: топ общий для всех (aa_progress["lb"]), своё место - в ответе игроку
		if type(res.leaderboard) == "table" then
			local lb = res.leaderboard
			local top = {}

			for i, r in ipairs(type(lb.top) == "table" and lb.top or {}) do
				top[tostring(i)] = { s = tostring(r.steam_id or ""), n = tostring(r.name or ""), m = tonumber(r.mmr) or 0,
					w = tonumber(r.wins) or 0, l = tonumber(r.losses) or 0, h = r.heroes or {} }
			end

			CustomNetTables:SetTableValue("aa_progress", "lb", { top = top, total = tonumber(lb.total) or 0, t = math.floor(GameRules:GetGameTime()) })

			if type(lb.me) == "table" then
				out.rank = tonumber(lb.me.rank) or 0
				out.mmr = tonumber(lb.me.mmr) or 0
				out.wins = tonumber(lb.me.wins) or 0
				out.losses = tonumber(lb.me.losses) or 0
				out.heroes = lb.me.heroes or {}
			end

			out.total = tonumber(lb.total) or 0
		end

		if type(res.token) == "table" then
			out.kind = res.token.kind or ""

			if action == "use_token" then
				self.active = self.active or {}
				self.active[pid] = self.active[pid] or {}
				self.active[pid][out.kind] = true
				CustomNetTables:SetTableValue("aa_progress", "tok" .. pid, self.active[pid])
			end
		end

		if type(res.shop) == "table" then
			out.item = res.shop.item or ""
			out.name = res.shop.name or ""
			out.rarity = res.shop.rarity or ""
			out.slot = res.shop.slot or ""
			out.price = res.shop.price or 0
			out.gain = res.shop.gain or 0
		end

		if action == "sell_item" and CosmeticsCore and CosmeticsCore.Publish then pcall(CosmeticsCore.Publish, CosmeticsCore, pid) end

		Reply(pid, out)
	end)
end

CustomGameEventManager:RegisterListener("aa_prog_action", function(_, data)
	local ok, err = pcall(P.OnAction, P, data)

	if not ok then print("[Progression] action failed: " .. tostring(err)) end
end)

return P
