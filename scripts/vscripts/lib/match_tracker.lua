-- Телеметрия матча на наш бэкенд (почти реальное время).
--
-- Только наблюдение: ни один хук ничего не меняет в геймплее, все вызовы
-- обёрнуты в pcall, так что сбой телеметрии не может уронить игру.
--
-- Что шлём:
--   POST /api/match/start   - один раз, когда игра пошла (состав, команды, герои)
--   POST /api/match/events  - раз в 5 с: покупки, золото, урон (сводкой),
--                             убийства, смена героя, heartbeat раз в 30 с
--   POST /api/match/end     - один раз, при победе; в ответе рейтинг игроков
--   GET  /api/time          - без подписи, нужен для временной метки
--
-- Подпись каждого POST:
--   X-AA-Sig = sha256_hex(key .. "\n" .. match_id .. "\n" .. seq .. "\n" .. ts .. "\n" .. body)
-- ts = floor(Time() + offset), где offset = server_time - Time() из ответа бэкенда.
-- SHA-256 написан на арифметике (без библиотеки bit): в VScript её может не быть.
--
-- Рейтинг уходит клиентам в нет-таблицу aa_rating, ключ "result" (формат у ApplyRatings)
-- и MMR до игры - ключ "mmr" (с лобби и из /match/start)

if not IsServer() then return end

MatchTracker = MatchTracker or {}

local BASE_URL          = "https://vps.pablo-semikashev.design/andey"
local KEY_NAME          = "aa1"
local FLUSH_INTERVAL    = 5     -- сек между отправками событий
local HEARTBEAT_TICKS   = 6     -- каждый 6-й тик по 5 с = heartbeat раз в 30 с
local MAX_TRIES         = 5     -- сколько раз повторяем один и тот же пакет
local END_TRIES         = 10    -- у /api/match/end попыток больше
local RETRY_DELAY       = 2     -- сек перед повтором
local END_RETRY_DELAY   = 3     -- сек перед повтором /api/match/end
local HTTP_TIMEOUT_MS   = 8000
local ASSIST_WINDOW     = 10    -- сек: кто бил героя, тот и в ассистах

-- причины золота движка -> имя источника; нет в таблице - "other"
-- Метка источника для золота, которое выдаётся прямым ModifyGold с причиной 0
-- (руна, мидас, gpm, курьер, перенос из запаса...). Только телеметрия: f вызывается как есть.
--   AATagGold("rune", function() unit:ModifyGold(gold, false, 0) end)
function AATagGold(src, f)
	local mt = MatchTelemetry
	local prev = mt and mt.goldSource

	if mt then mt.goldSource = src end

	local ok, err = pcall(f)

	if mt then mt.goldSource = prev end

	if not ok then error(err, 0) end
end

-- (до 2026-11-14 таблица была пустой: крипы, руны и прочее уходили в "other" - половина золота без метки)
local SOURCE_BY_REASON = {}

for name, src in pairs({
	DOTA_ModifyGold_CreepKill = "creep",
	DOTA_ModifyGold_NeutralKill = "neutral",
	DOTA_ModifyGold_BountyRune = "rune",
	DOTA_ModifyGold_Building = "building",
	DOTA_ModifyGold_RoshanKill = "boss",
	DOTA_ModifyGold_CourierKill = "courier",
	DOTA_ModifyGold_HeroKill = "hero_kill",
	DOTA_ModifyGold_AbilityGold = "ability",
	DOTA_ModifyGold_SellItem = "sell",
	DOTA_ModifyGold_GameTick = "tick",
	DOTA_ModifyGold_SharedGold = "shared",
}) do
	local r = _G[name]

	if r ~= nil then SOURCE_BY_REASON[r] = src end
end

-- ------------------------------------------------------------------ битовые операции
-- Без библиотеки bit: 32-битные числа как double, операции по нибблам через таблицы 16x16.

local XOR4, AND4, OR4 = {}, {}, {}

local function NibbleBit(a, b, op)
	local r = 0
	for i = 0, 3 do
		local p = 2 ^ i
		local ba = math.floor(a / p) % 2
		local bb = math.floor(b / p) % 2
		local v

		if op == "x" then
			v = (ba ~= bb) and 1 or 0
		elseif op == "a" then
			v = ba * bb
		else
			v = (ba + bb > 0) and 1 or 0
		end

		r = r + v * p
	end

	return r
end

for a = 0, 15 do
	for b = 0, 15 do
		local k = a * 16 + b

		XOR4[k] = NibbleBit(a, b, "x")
		AND4[k] = NibbleBit(a, b, "a")
		OR4[k]  = NibbleBit(a, b, "o")
	end
end

local function Nibbles(T, a, b)
	local r, p = 0, 1

	for _ = 1, 8 do
		local na, nb = a % 16, b % 16

		r = r + T[na * 16 + nb] * p
		a = (a - na) / 16
		b = (b - nb) / 16
		p = p * 16
	end

	return r
end

local function BXor(a, b) return Nibbles(XOR4, a, b) end
local function BAnd(a, b) return Nibbles(AND4, a, b) end
local function BNot(a) return 4294967295 - a end
local function RotR(x, n) return math.floor(x / 2 ^ n) + (x * 2 ^ (32 - n)) % 4294967296 end
local function ShR(x, n) return math.floor(x / 2 ^ n) end

-- ------------------------------------------------------------------ SHA-256

local K = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local H0 = {
	0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
}

local function Sha256Words(msg)
	local bitlen = #msg * 8
	local hi = math.floor(bitlen / 4294967296)
	local lo = bitlen % 4294967296

	msg = msg .. "\128"
	while #msg % 64 ~= 56 do
		msg = msg .. "\0"
	end

	msg = msg .. string.char(
		math.floor(hi / 16777216) % 256, math.floor(hi / 65536) % 256, math.floor(hi / 256) % 256, hi % 256,
		math.floor(lo / 16777216) % 256, math.floor(lo / 65536) % 256, math.floor(lo / 256) % 256, lo % 256
	)

	local H = { H0[1], H0[2], H0[3], H0[4], H0[5], H0[6], H0[7], H0[8] }
	local W = {}

	for chunk = 1, #msg, 64 do
		for i = 0, 15 do
			local b1, b2, b3, b4 = string.byte(msg, chunk + i * 4, chunk + i * 4 + 3)

			W[i] = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
		end

		for i = 16, 63 do
			local w15, w2 = W[i - 15], W[i - 2]
			local s0 = BXor(BXor(RotR(w15, 7), RotR(w15, 18)), ShR(w15, 3))
			local s1 = BXor(BXor(RotR(w2, 17), RotR(w2, 19)), ShR(w2, 10))

			W[i] = (W[i - 16] + s0 + W[i - 7] + s1) % 4294967296
		end

		local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]

		for i = 0, 63 do
			local S1 = BXor(BXor(RotR(e, 6), RotR(e, 11)), RotR(e, 25))
			local ch = BXor(BAnd(e, f), BAnd(BNot(e), g))
			local t1 = (h + S1 + ch + K[i + 1] + W[i]) % 4294967296
			local S0 = BXor(BXor(RotR(a, 2), RotR(a, 13)), RotR(a, 22))
			local maj = BXor(BXor(BAnd(a, b), BAnd(a, c)), BAnd(b, c))
			local t2 = (S0 + maj) % 4294967296

			h = g
			g = f
			f = e
			e = (d + t1) % 4294967296
			d = c
			c = b
			b = a
			a = (t1 + t2) % 4294967296
		end

		H[1] = (H[1] + a) % 4294967296
		H[2] = (H[2] + b) % 4294967296
		H[3] = (H[3] + c) % 4294967296
		H[4] = (H[4] + d) % 4294967296
		H[5] = (H[5] + e) % 4294967296
		H[6] = (H[6] + f) % 4294967296
		H[7] = (H[7] + g) % 4294967296
		H[8] = (H[8] + h) % 4294967296
	end

	return H
end

local function Hex32(w)
	return string.format("%02x%02x%02x%02x",
		math.floor(w / 16777216) % 256, math.floor(w / 65536) % 256, math.floor(w / 256) % 256, w % 256)
end

-- сырой дайджест (32 байта) и hex
local function Sha256Bin(msg)
	local H = Sha256Words(msg)
	local out = {}

	for i = 1, 8 do
		local w = H[i]

		out[i] = string.char(math.floor(w / 16777216) % 256, math.floor(w / 65536) % 256,
			math.floor(w / 256) % 256, w % 256)
	end

	return table.concat(out)
end

local function HexOf(bin)
	local t = {}

	for i = 1, #bin do
		t[i] = string.format("%02x", string.byte(bin, i))
	end

	return table.concat(t)
end

local function sha256_hex(msg)
	return HexOf(Sha256Bin(msg))
end

-- HMAC-SHA256 (RFC 2104): блок 64 байта, ключ длиннее блока сначала хэшируем
local function HmacSha256Hex(key, msg)
	if #key > 64 then key = Sha256Bin(key) end

	key = key .. string.rep("\0", 64 - #key)

	local ipad, opad = {}, {}

	for i = 1, 64 do
		local b = string.byte(key, i)

		ipad[i] = string.char(BXor(b, 0x36))
		opad[i] = string.char(BXor(b, 0x5c))
	end

	local inner = Sha256Bin(table.concat(ipad) .. msg)

	return HexOf(Sha256Bin(table.concat(opad) .. inner))
end

-- Проверка на известных векторах. Вызывается при загрузке, результат в лог.
function MatchTracker.SelfTest()
	local okAbc = sha256_hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
	local okEmpty = sha256_hex("") == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
	-- RFC 4231, тест 2
	local okHmac2 = HmacSha256Hex("Jefe", "what do ya want for nothing?")
		== "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
	-- RFC 4231, тест 6: ключ длиннее блока
	local okHmac6 = HmacSha256Hex(string.rep("\170", 131), "Test Using Larger Than Block-Size Key - Hash Key First")
		== "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54"

	if not (okAbc and okEmpty and okHmac2 and okHmac6) then
		print("[MatchTracker] SHA-256 self-test FAILED")
	end

	return okAbc and okEmpty
end

-- ------------------------------------------------------------------ JSON

local function JsonEscape(s)
	local escaped = s:gsub('[%c"\\]', function(c)
		local map = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }

		return map[c] or string.format("\\u%04x", string.byte(c))
	end)

	return '"' .. escaped .. '"'
end

-- Таблица без нечисловых ключей - массив (пустая тоже массив)
local function IsArray(t)
	for k in pairs(t) do
		if type(k) ~= "number" then return false end
	end

	return true
end

local function JsonEncode(v)
	local t = type(v)

	if v == nil then
		return "null"
	elseif t == "boolean" then
		return v and "true" or "false"
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "null" end
		if math.floor(v) == v and math.abs(v) < 1e15 then return string.format("%.0f", v) end

		return string.format("%.10g", v)
	elseif t == "string" then
		return JsonEscape(v)
	elseif t == "table" then
		local parts = {}

		if IsArray(v) then
			for i = 1, #v do parts[i] = JsonEncode(v[i]) end

			return "[" .. table.concat(parts, ",") .. "]"
		end

		local keys, orig = {}, {}

		for k in pairs(v) do local sk = tostring(k); keys[#keys + 1] = sk; orig[sk] = k end
		table.sort(keys)

		for i, k in ipairs(keys) do
			parts[i] = JsonEscape(k) .. ":" .. JsonEncode(v[orig[k]])
		end

		return "{" .. table.concat(parts, ",") .. "}"
	end

	return "null"
end

local function JsonDecode(str)
	local pos = 1

	local function Ws()
		pos = str:find("[^ \t\r\n]", pos) or (#str + 1)
	end

	local ParseValue

	local function ParseString()
		local out = {}
		local i = pos + 1

		while true do
			local c = str:sub(i, i)

			if c == "" then error("unterminated string") end

			if c == '"' then
				pos = i + 1

				return table.concat(out)
			end

			if c == "\\" then
				local e = str:sub(i + 1, i + 1)

				if e == "u" then
					local code = tonumber(str:sub(i + 2, i + 5), 16) or 63

					out[#out + 1] = code < 128 and string.char(code) or "?"
					i = i + 6
				else
					local map = { n = "\n", r = "\r", t = "\t", b = "\b", f = "\f" }

					out[#out + 1] = map[e] or e
					i = i + 2
				end
			else
				out[#out + 1] = c
				i = i + 1
			end
		end
	end

	ParseValue = function()
		Ws()

		local c = str:sub(pos, pos)

		if c == "{" then
			local obj = {}

			pos = pos + 1
			Ws()

			if str:sub(pos, pos) == "}" then
				pos = pos + 1

				return obj
			end

			while true do
				Ws()

				local k = ParseString()

				Ws()
				pos = pos + 1 -- двоеточие
				obj[k] = ParseValue()
				Ws()

				local d = str:sub(pos, pos)

				pos = pos + 1

				if d == "}" then return obj end
			end
		elseif c == "[" then
			local arr = {}

			pos = pos + 1
			Ws()

			if str:sub(pos, pos) == "]" then
				pos = pos + 1

				return arr
			end

			while true do
				arr[#arr + 1] = ParseValue()
				Ws()

				local d = str:sub(pos, pos)

				pos = pos + 1

				if d == "]" then return arr end
			end
		elseif c == '"' then
			return ParseString()
		elseif str:sub(pos, pos + 3) == "true" then
			pos = pos + 4

			return true
		elseif str:sub(pos, pos + 4) == "false" then
			pos = pos + 5

			return false
		elseif str:sub(pos, pos + 3) == "null" then
			pos = pos + 4

			return nil
		end

		local s, e = str:find("^%-?%d+%.?%d*[eE]?[%-+]?%d*", pos)

		if not s then error("bad json at " .. pos) end

		pos = e + 1

		local raw = str:sub(s, e)

		-- длинные целые (steam_id 7656...) в double теряют точность, и tostring
		-- даёт "7.6561198e+16" - игрок не находится в steam_to_pid и в итогах
		-- матча пишется "рейтинг недоступен". Такие числа оставляем строкой.
		if #raw > 15 and raw:match("^%-?%d+$") then return raw end

		return tonumber(raw)
	end

	return ParseValue()
end

-- ------------------------------------------------------------------ состояние

local st = {
	started     = false,
	ended       = false,
	match_id    = "0",
	key         = "",
	seq         = 0,
	offset      = nil,   -- server_time - Time()
	queue       = {},    -- запросы по порядку; головной уходит первым
	inflight    = false,
	pending     = {},    -- события без агрегации (покупки, смена героя, ...)
	dmg         = {},    -- сводка урона: "pid|ability|target" -> {...}
	gold        = {},    -- сводка золота: "pid|source" -> {...}
	last_hit    = {},    -- entindex героя -> { pid -> время последнего удара }
	steam_to_pid = {},
	tick        = 0,
	conn        = {},   -- последнее состояние подключения: pid -> state
	pinfo       = {},   -- pid -> { conn, left_t, dc_total, nw_peak }
	t0          = nil,  -- GetGameTime() в момент GAME_IN_PROGRESS: ноль match-времени
	all_left_sent = false,
	team_gone_t = {},  -- команда (2/3) -> Gt(), когда в ней не осталось подключённых людей; nil - есть кто-то
}

local CONN_POLL = 2 -- сек: опрос состояний подключения
local END_GRACE = 35 -- сек: выход в отсчёте конца не ливер

-- match-время: от горна (GAME_IN_PROGRESS), до него 0
local function Gt()
	if st.t0 == nil then return 0 end

	local t = GameRules:GetGameTime() - st.t0

	return t > 0 and t or 0
end

local function FixT0()
	if st.t0 ~= nil then return end

	pcall(function()
		if GameRules:State_Get() >= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
			st.t0 = GameRules:GetGameTime()
		end
	end)
end

-- нетворс с копилкой золота сверх 50000 (AngelArena.tPlayers[pid].gold, addon_game_mode.lua)
local function NetWorthOf(pid)
	local nw = 0

	pcall(function() nw = PlayerResource:GetNetWorth(pid) or 0 end)

	pcall(function()
		local p = AngelArena and AngelArena.tPlayers and AngelArena.tPlayers[pid]

		if p and tonumber(p.gold) then nw = nw + tonumber(p.gold) end
	end)

	return nw
end

MatchTracker.NetWorthOf = NetWorthOf

-- ------------------------------------------------------------------ планировщик
-- Свой think на GameModeEntity по реальному времени (Time()): Timers:_Think
-- останавливается в POST_GAME, а /api/match/end уходит как раз тогда.
local SCHED_CTX = "aa_match_tracker_sched"
local sched = { tasks = {}, think = false, post_logged = false }

local function SchedThink()
	if not sched.post_logged then
		pcall(function()
			if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
				sched.post_logged = true
				print("[MatchTracker] scheduler alive in POST_GAME, tasks " .. #sched.tasks)
			end
		end)
	end

	local now = Time()
	local due = {}

	for i = #sched.tasks, 1, -1 do
		local t = sched.tasks[i]

		if t.at <= now then
			table.remove(sched.tasks, i)
			due[#due + 1] = t
		end
	end

	for i = #due, 1, -1 do
		local t = due[i]
		local ok, nextDelay = pcall(t.fn)

		if not ok then
			print("[MatchTracker] sched error: " .. tostring(nextDelay))
		elseif type(nextDelay) == "number" then
			t.at = Time() + nextDelay
			sched.tasks[#sched.tasks + 1] = t
		end
	end

	return 0.1
end

local function SchedEnsure()
	if sched.think then return true end

	local ok = pcall(function()
		local ent = GameRules:GetGameModeEntity()

		if not ent then error("no game mode entity") end

		ent:SetContextThink(SCHED_CTX, function()
			local ok2, r = pcall(SchedThink)

			return (ok2 and r) or 0.1
		end, 0)
	end)

	sched.think = ok

	return ok
end

-- fn() возвращает следующую задержку (сек) или nil. false - think недоступен
local function SchedAfter(delay, fn)
	if not SchedEnsure() then return false end

	sched.tasks[#sched.tasks + 1] = { at = Time() + delay, fn = fn }

	return true
end

local function PidOk(pid)
	return type(pid) == "number" and pid >= 0 and pid < 24 and PlayerResource:IsValidPlayerID(pid)
end

-- живой игрок со Steam-аккаунтом: боты (нулевой аккаунт) в состав матча не идут
local function IsHumanPid(pid)
	if not PidOk(pid) then return false end
	local okF, fake = pcall(function() return PlayerResource:IsFakeClient(pid) end)
	if okF and fake then return false end
	local okA, acc = pcall(function() return PlayerResource:GetSteamAccountID(pid) end)
	return okA and tonumber(acc) ~= nil and tonumber(acc) > 0
end

-- Безопасный вызов PlayerResource: нет метода или ошибка - значение по умолчанию
local function PR(method, pid, default)
	local f = PlayerResource[method]

	if not f then return default end

	local ok, v = pcall(f, PlayerResource, pid)

	if ok and v ~= nil then return v end

	return default
end

-- Steam ID собираем из 32-битного номера аккаунта строкой: прямой 64-битный
-- SteamID в double теряет младшие биты (ulp при 7.6e16 равен 8).
local function SteamIdOf(pid)
	local acc = math.floor(PR("GetSteamAccountID", pid, 0))
	-- 76561197960265728 = 76561197 * 1e9 + 960265728; числа держим в пределах
	-- точности double, склеиваем строкой
	local x = 960265728 + acc
	local q = math.floor(x / 1000000000)
	local r = x - q * 1000000000

	return tostring(76561197 + q) .. string.format("%09d", r)
end

local function ConnState(pid)
	return PR("GetConnectionState", pid, -1)
end

-- ушёл из игры: бросил или отключился
local function ConnGone(pid)
	local s = ConnState(pid)

	return (DOTA_CONNECTION_STATE_ABANDONED ~= nil and s == DOTA_CONNECTION_STATE_ABANDONED)
		or (DOTA_CONNECTION_STATE_DISCONNECTED ~= nil and s == DOTA_CONNECTION_STATE_DISCONNECTED)
end

local function ConnConnected(pid)
	return DOTA_CONNECTION_STATE_CONNECTED ~= nil and ConnState(pid) == DOTA_CONNECTION_STATE_CONNECTED
end

local function ReadMatchId()
	local ok, id = pcall(function() return GameRules:Script_GetMatchID() end)
	local s = (ok and id ~= nil) and tostring(id) or "0"

	if s == "0" or s == "" then
		s = "local-" .. RandomInt(1, 1000000000)
	end

	return s
end

-- ------------------------------------------------------------------ сеть

local function ParseResponse(res)
	if not res or res.StatusCode == nil or res.StatusCode < 200 or res.StatusCode >= 300 then
		return false, nil
	end

	local ok, data = pcall(JsonDecode, res.Body or "")

	if not ok or type(data) ~= "table" then
		return true, {}
	end

	return true, data
end

local function SyncTime(serverTime)
	st.offset = serverTime - Time()
end

-- X-AA-Sig = hex HMAC-SHA256(key, match_id "\n" seq "\n" ts "\n" body)
local function Sign(seq, ts, body)
	return HmacSha256Hex(st.key, st.match_id .. "\n" .. tostring(seq) .. "\n" .. tostring(ts) .. "\n" .. body)
end

-- Рейтинг из ответа /api/match/end: players[] с steam_id -> pid.
-- Нет-таблица aa_rating, ключ "result":
--   [pid (строкой)] = { mmr_before, mmr_after, delta, rated (0/1), reason }
--   ["match"]       = { rated (0/1), reason } - статус матча целиком
-- "match" есть всегда, даже если игроков не сопоставили: таблица не пустая,
-- клиент отличает "ответ пришёл" от "ответа ещё нет".
local function ApplyRatings(data)
	local rated = data.rated == true or data.status == "finished"
	local reason = tostring(data.unrated_reason or "")
	local out = {}

	for _, p in ipairs(type(data.players) == "table" and data.players or {}) do
		local pid = type(p) == "table" and st.steam_to_pid[tostring(p.steam_id)] or nil

		if pid ~= nil then
			out[tostring(pid)] = {
				mmr_before = tonumber(p.mmr_before) or 0,
				mmr_after  = tonumber(p.mmr_after) or 0,
				delta      = tonumber(p.delta) or 0,
				rated      = rated and 1 or 0,
				reason     = reason,
				-- калибровка: {done, total} от бэкенда, пока игрок её не прошёл
				calib_done  = type(p.calibration) == "table" and tonumber(p.calibration.done) or 0,
				calib_total = type(p.calibration) == "table" and tonumber(p.calibration.total) or 0,
			}
		end
	end

	out.match = { rated = rated and 1 or 0, reason = reason }

	CustomNetTables:SetTableValue("aa_rating", "result", out)
end

-- Ответ сервера так и не пришёл (все повторы исчерпаны): клиент покажет
-- "Рейтинг недоступен", а не будет ждать вечно
local function PublishRatingFailed()
	CustomNetTables:SetTableValue("aa_rating", "result", {
		match = { rated = 0, reason = "сервер не ответил", failed = 1 },
	})
end

-- Пишет "mmr" в aa_rating: rows[pid] = { mmr, games }
local function PublishMmrRows(rows)
	local out = {}

	for pid, r in pairs(rows) do
		out[tostring(pid)] = {
			mmr   = tonumber(r.mmr) or 0,
			games = tonumber(r.games) or 0,
		}
	end

	CustomNetTables:SetTableValue("aa_rating", "mmr", out)
end

-- MMR и число игр из ответа /api/match/start (и из поиска в лобби)
local function PublishMmr(data)
	-- премиум и экипировка косметики (lib/cosmetics/core.lua)
	if CosmeticsCore and CosmeticsCore.OnPlayersInfo then pcall(CosmeticsCore.OnPlayersInfo, CosmeticsCore, data.players) end

	local rows = {}

	for _, p in ipairs(type(data.players) == "table" and data.players or {}) do
		local pid = type(p) == "table" and st.steam_to_pid[tostring(p.steam_id)] or nil

		if pid ~= nil then
			rows[pid] = { mmr = p.mmr, games = p.games }
		end
	end

	PublishMmrRows(rows)
end

-- Bootstrap: один раз на запуск сервера, без подписи, ошибки игнорируем
local bootstrapSent = false

-- Ключ подписи. На серверах Valve - GetDedicatedServerKeyV2. В тулзах - dev-ключ
-- из scripts/vscripts/aa_dev_key.lua (только у владельца, в мастерскую не
-- заливать): сервер принимает его, но такие матчи всегда без рейтинга (DEV).
-- 2026-11-12, решение владельца: основной ключ - Valve (и в bootstrap, и в подписи).
-- Запасной путь - второй (dev) ключ: если Valve-ключ пустой/Invalid или сервер отвечает
-- ошибкой авторизации (4xx до первого успешного ответа), трекер до конца игры переходит на
-- dev-ключ и повторяет тот же запрос (AAFallbackKey, Fallback ниже). Так игры пишутся на сервер,
-- даже если ключ Valve снова не принят. DEV-матчи сервер считает без рейтинга.
-- Когда Valve-ключ стабильно принят: DEV_KEY_FALLBACK = false и сменить dev-ключ
-- (admin.py rotate-dev-key) - он лежит в мастерской открыто.
local DEV_KEY_FALLBACK = true

-- aa_dev_key.lua хранит запасной ключ не строкой, а закодированным (соль + байты): так его не
-- найти поиском по файлам мастерской. Это не настоящая защита - код ниже его всё равно читает.
-- Перекодировать: scratchpad-скрипт, формула та же (LCG 48271 mod 2^31-1, зерно из имени аддона).
local function DevKey()
	local ok, data = pcall(require, "aa_dev_key")

	if not ok then return nil end
	if type(data) == "string" then return data ~= "" and data or nil end
	if type(data) ~= "table" or #data < 2 then return nil end

	local M = 2147483647
	local seed = 0

	for i = 1, #"anger_arena_new_rising" do
		seed = (seed * 31 + string.byte("anger_arena_new_rising", i)) % M
	end

	local st = (seed + data[1]) % M
	local out = {}

	for i = 2, #data do
		st = (st * 48271) % M
		out[#out + 1] = string.char((data[i] - (st % 251) + 256) % 256)
	end

	return table.concat(out)
end

-- запасной ключ (nil - запасного нет или уже на нём)
function AAFallbackKey(current)
	if not DEV_KEY_FALLBACK then return nil end

	local dev = DevKey()

	if dev == nil or dev == current then return nil end

	return dev
end

-- Ключи Valve. На хостах лобби есть все три версии (V1, V2, V3 - по словам хостера, к одному
-- алгоритму), какая из них доходит до нас - проверяем на живом сервере. Берём первую валидную
-- в порядке V2, V3, V1; в bootstrap уходят ВСЕ валидные по отдельности (поле variant) -
-- на VPS принимаем ту, что пришла (admin.py list-pending / accept).
local function KeyVariants()
	local out = {}

	local function try(name, fn)
		local ok, k = pcall(fn)
		k = ok and k and tostring(k) or ""

		local valid = k ~= "" and string.sub(k, 1, 7) ~= "Invalid"

		print(string.format("[MatchTracker] ключ %s: %s", name,
			valid and ("есть, " .. #k .. " симв., начало " .. string.sub(k, 1, 4) .. "...") or ("нет (" .. (k == "" and "пусто" or k) .. ")")))

		if valid then out[#out + 1] = { name = name, key = k } end
	end

	try("v2", function() return GetDedicatedServerKeyV2(KEY_NAME) end)
	try("v3", function() return GetDedicatedServerKeyV3(KEY_NAME) end)
	try("v1", function() return GetDedicatedServerKey(KEY_NAME) end)

	return out
end

local valveVariants = nil

local function ValveKey()
	if valveVariants == nil then valveVariants = KeyVariants() end

	return valveVariants[1] and valveVariants[1].key or ""
end

function AAServerKey()
	if IsInToolsMode() then
		local dev = DevKey()
		if dev then return dev, true end
	end

	local ok, k = pcall(ValveKey)
	k = ok and k and tostring(k) or ""

	-- Valve-ключа нет - сразу запасной
	if (k == "" or string.sub(k, 1, 7) == "Invalid") and AAFallbackKey(k) then
		print("[MatchTracker] ключ Valve недоступен, подпись запасным ключом")
		return AAFallbackKey(k), true
	end

	return k
end

local function SendBootstrap()
	if bootstrapSent then return end

	-- в тулзах ключ dev или пустой - отправлять нечего
	if IsInToolsMode() then return end

	if valveVariants == nil then valveVariants = KeyVariants() end

	if #valveVariants == 0 then
		print("[MatchTracker] bootstrap: ни одного ключа Valve нет - матчи пойдут запасным ключом")
		return
	end

	bootstrapSent = true

	local matchId = st.match_id
	if not matchId then
		local ok, id = pcall(function() return tostring(GameRules:Script_GetMatchID()) end)
		matchId = ok and id or "unknown"
	end

	-- каждый вариант отдельным запросом: принимаем на VPS тот, что пришёл
	for _, v in ipairs(valveVariants) do
		pcall(function()
			local req = CreateHTTPRequestScriptVM("POST", BASE_URL .. "/api/bootstrap/key")

			if not req then return end

			pcall(function() req:SetHTTPRequestAbsoluteTimeoutMS(HTTP_TIMEOUT_MS) end)
			req:SetHTTPRequestRawPostBody("application/json", JsonEncode({ key = v.key, match_id = matchId, variant = v.name }))
			req:Send(function(res)
				print("[MatchTracker] bootstrap " .. v.name .. ": HTTP " .. tostring(res and res.StatusCode))
			end)
		end)
	end
end

-- через 5 с после загрузки скриптов (стадия выбора команд)
if Timers then
	Timers:CreateTimer({ useGameTime = false, endTime = 5, callback = function() pcall(SendBootstrap) end })
end

local Pump

-- запасной путь без think: повтор сразу (из HTTP-колбэка), с потолком
local fallbackRetries = 0
local FALLBACK_RETRY_MAX = 30

local function Retry(delay)
	local ok = SchedAfter(delay or RETRY_DELAY, function()
		pcall(Pump)

		return nil
	end)

	if not ok then
		fallbackRetries = fallbackRetries + 1

		if fallbackRetries <= FALLBACK_RETRY_MAX then
			print("[MatchTracker] think недоступен, повтор сразу (" .. fallbackRetries .. ")")
			pcall(Pump)
		end
	end
end

local function LogHttpFail(what, res)
	local code = res and res.StatusCode
	local body = res and res.Body and tostring(res.Body) or ""

	print("[MatchTracker] HTTP fail " .. tostring(what) .. ": code " .. tostring(code) .. ", body: " .. string.sub(body, 1, 200))
end

local function OnReply(head, ok, data)
	st.inflight = false

	if ok and data and type(data.server_time) == "number" then
		SyncTime(data.server_time)
	end

	if ok then
		if st.queue[1] == head then table.remove(st.queue, 1) end

		if head.kind == "end" and data then
			ApplyRatings(data)
		elseif head.kind == "start" and data then
			PublishMmr(data)
		end

		pcall(Pump)

		return
	end

	head.tries = head.tries + 1

	if head.tries >= (head.max_tries or MAX_TRIES) then
		print("[MatchTracker] give up on " .. head.path .. " seq " .. tostring(head.seq))

		if head.kind == "end" then pcall(PublishRatingFailed) end

		if st.queue[1] == head then table.remove(st.queue, 1) end

		pcall(Pump)
	else
		Retry(head.kind == "end" and END_RETRY_DELAY or RETRY_DELAY)
	end
end

Pump = function()
	if st.inflight or st.hold_pump or #st.queue == 0 then return end

	-- сначала берём время: без него подпись не собрать
	if st.offset == nil then
		st.inflight = true

		local req = CreateHTTPRequestScriptVM("GET", BASE_URL .. "/api/time")

		if not req then
			st.inflight = false
			Retry()

			return
		end

		pcall(function() req:SetHTTPRequestAbsoluteTimeoutMS(HTTP_TIMEOUT_MS) end)

		req:Send(function(res)
			st.inflight = false

			local ok, data = ParseResponse(res)

			if ok and data and type(data.server_time) == "number" then
				SyncTime(data.server_time)
			else
				LogHttpFail("/api/time", res)
				Retry()

				return
			end

			pcall(Pump)
		end)

		return
	end

	local head = st.queue[1]

	-- номер присваиваем при первой отправке, повтор идёт с тем же номером
	if not head.seq then
		st.seq = st.seq + 1
		head.seq = st.seq
	end

	local ts = math.floor(Time() + st.offset)
	local req = CreateHTTPRequestScriptVM("POST", BASE_URL .. head.path)

	if not req then
		Retry()

		return
	end

	pcall(function() req:SetHTTPRequestAbsoluteTimeoutMS(HTTP_TIMEOUT_MS) end)
	req:SetHTTPRequestRawPostBody("application/json", head.body)
	req:SetHTTPRequestHeaderValue("X-AA-Match", st.match_id)
	req:SetHTTPRequestHeaderValue("X-AA-Seq", tostring(head.seq))
	req:SetHTTPRequestHeaderValue("X-AA-Ts", tostring(ts))
	req:SetHTTPRequestHeaderValue("X-AA-Sig", Sign(head.seq, ts, head.body))

	st.inflight = true

	req:Send(function(res)
		local ok, data = ParseResponse(res)
		local code = res and res.StatusCode or 0

		if not ok then LogHttpFail(head.path .. " seq " .. tostring(head.seq) .. " try " .. tostring(head.tries + 1), res) end

		-- ключ не принят (4xx, а успешных ответов ещё не было) - переходим на запасной и повторяем
		if not ok and code >= 400 and code < 500 and not st.any_ok then
			local fb = AAFallbackKey(st.key)

			if fb then
				print("[MatchTracker] сервер не принял ключ (" .. code .. "), переход на запасной ключ")
				st.key = fb
				if AATrackerLobbyFallback then pcall(AATrackerLobbyFallback, fb) end
				st.inflight = false
				pcall(Pump)

				return
			end
		end

		if ok then st.any_ok = true end

		OnReply(head, ok, data)
	end)
end

local function Enqueue(path, payload, kind)
	local item = {
		path  = path,
		body  = JsonEncode(payload),
		tries = 0,
		seq   = nil,
		kind  = kind,
	}

	if kind == "end" then
		item.max_tries = END_TRIES
	elseif st.ended or st.ending then
		-- пакеты после конца игры - одна попытка, /end не держат
		item.max_tries = 1
	end

	table.insert(st.queue, item)

	pcall(Pump)

	return item
end

-- ------------------------------------------------------------------ события

local function AddEvent(kind, pid, data)
	st.pending[#st.pending + 1] = {
		type = kind,
		pid  = pid,
		t    = math.floor(Gt()),
		data = data,
	}
end

-- Сводки золота и урона уходят одним куском на каждый флаш
local function FlushEvents()
	local list = {}

	for _, e in ipairs(st.pending) do list[#list + 1] = e end

	st.pending = {}

	for _, a in pairs(st.dmg) do
		list[#list + 1] = {
			type = "damage",
			pid  = a.pid,
			t    = a.t,
			data = { ability = a.ability, target = a.target, amount = math.floor(a.amount) },
		}
	end

	st.dmg = {}

	for _, g in pairs(st.gold) do
		list[#list + 1] = {
			type = "gold",
			pid  = g.pid,
			t    = g.t,
			data = { source = g.source, amount = math.floor(g.amount) },
		}
	end

	st.gold = {}

	if #list > 0 then
		Enqueue("/api/match/events", { match_id = st.match_id, events = list }, "events")
	end
end

-- team_gone_t для JSON: { ["2"] = t, ["3"] = t }. Пустую таблицу JsonEncode отдаёт как [],
-- поэтому если ни одна команда не опустела - поля нет (nil)
local function TeamGoneOut()
	local out = {}

	for _, team in ipairs({ DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS }) do
		local t = st.team_gone_t[team]

		if t ~= nil then out[tostring(team)] = t end
	end

	if next(out) == nil then return nil end

	return out
end

local function PlayerSnapshot(pid)
	local snap = {
		pid        = pid,
		level      = PR("GetLevel", pid, 0),
		gold       = PR("GetGold", pid, 0),
		net_worth  = NetWorthOf(pid),
		kills      = PR("GetKills", pid, 0),
		deaths     = PR("GetDeaths", pid, 0),
		assists    = PR("GetAssists", pid, 0),
		lh         = PR("GetLastHits", pid, 0),
		connected  = ConnConnected(pid),
	}

	local pi = st.pinfo[pid]

	if pi then
		snap.conn     = pi.conn
		snap.left_t   = pi.left_t
		snap.dc_total = math.floor(pi.dc_total)
		snap.nw_peak  = pi.nw_peak
	end

	-- доп. поля heartbeat: MatchTracker.HeartbeatExtra (lib/match_telemetry.lua)
	if MatchTracker.HeartbeatExtra then
		local ok, extra = pcall(MatchTracker.HeartbeatExtra, pid)

		if ok and type(extra) == "table" then
			for k, v in pairs(extra) do snap[k] = v end
		end
	end

	return snap
end

local function Heartbeat()
	local players = {}

	for pid = 0, 23 do
		if PidOk(pid) then players[#players + 1] = PlayerSnapshot(pid) end
	end

	st.pending[#st.pending + 1] = {
		type = "heartbeat",
		t    = math.floor(Gt()),
		data = { players = players, team_gone_t = TeamGoneOut() },
	}
end

-- Немедленный heartbeat (не в пачке) - уходит сразу при смене подключения
local function SendHeartbeatNow(allLeft)
	local players = {}

	for pid = 0, 23 do
		if PidOk(pid) then players[#players + 1] = PlayerSnapshot(pid) end
	end

	local data = { players = players, team_gone_t = TeamGoneOut() }

	if allLeft then data.all_left = true end

	Enqueue("/api/match/events", {
		match_id = st.match_id,
		events   = { { type = "heartbeat", t = math.floor(Gt()), data = data } },
	}, "events")
end

local function ConnName(pid)
	local s = ConnState(pid)

	if DOTA_CONNECTION_STATE_ABANDONED ~= nil and s == DOTA_CONNECTION_STATE_ABANDONED then return "abandoned" end
	if DOTA_CONNECTION_STATE_CONNECTED ~= nil and s == DOTA_CONNECTION_STATE_CONNECTED then return "connected" end

	return "disconnected"
end

-- сколько людей подключено: всего и по командам. exclPid - не считать (уже вышел, см. CheckConnections)
local function ConnectedHumans(exclPid)
	local total, byTeam = 0, {}

	for pid = 0, 23 do
		if pid ~= exclPid and IsHumanPid(pid) and ConnConnected(pid) then
			total = total + 1

			local team = PR("GetTeam", pid, 0)

			byTeam[team] = (byTeam[team] or 0) + 1
		end
	end

	return total, byTeam
end

-- Все вышли: победитель - команда, которая опустела ПОЗЖЕ (опустевшая первой проигрывает).
-- Нет отметки у одной из команд или разница не больше 3 с - 0 (не определить)
local function AllLeftWinner()
	local g = st.team_gone_t[DOTA_TEAM_GOODGUYS]
	local b = st.team_gone_t[DOTA_TEAM_BADGUYS]

	if g == nil or b == nil then return 0 end
	if math.abs(g - b) <= 3 then return 0 end

	return g > b and DOTA_TEAM_GOODGUYS or DOTA_TEAM_BADGUYS
end

-- Проверка подключений: таймер (CONN_POLL) и движковые события player_*.
-- Если у кого-то состояние сменилось, шлём heartbeat сразу.
-- По игроку ведём conn, left_t (последний уход), dc_total (сек вне игры), nw_peak.
-- exclPid - игрок из player_disconnect: движок может ещё не обновить его состояние, считаем отключённым.
local function CheckConnections(exclPid)
	if not st.started or st.ended then return end

	FixT0()

	local changed = false
	local humanTeams = {} -- команды, в которых в матче есть люди
	local now = Gt()
	local dt = st.last_poll_t and (now - st.last_poll_t) or 0

	if dt < 0 then dt = 0 end

	st.last_poll_t = now

	for pid = 0, 23 do
		if PidOk(pid) then
			local s = ConnState(pid)

			if st.conn[pid] ~= nil and st.conn[pid] ~= s then changed = true end

			st.conn[pid] = s

			if IsHumanPid(pid) then
				humanTeams[PR("GetTeam", pid, 0)] = true

				local pi = st.pinfo[pid]

				if not pi then
					pi = { conn = "connected", left_t = nil, dc_total = 0, nw_peak = 0 }
					st.pinfo[pid] = pi
				end

				local name = ConnName(pid)

				if name ~= "connected" then
					if pi.conn == "connected" then pi.left_t = math.floor(now) end

					pi.dc_total = pi.dc_total + dt
				end

				pi.conn = name

				if name == "abandoned" and pi.abandon_t == nil then
					pi.abandon_t = Gt()
				end

				local nw = NetWorthOf(pid)

				if nw > pi.nw_peak then pi.nw_peak = nw end
			end
		end
	end

	local total, byTeam = ConnectedHumans(exclPid)

	-- опустевшая команда: время первого опроса без её людей; кто-то вернулся - сброс
	for _, team in ipairs({ DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS }) do
		if humanTeams[team] then
			local n = byTeam[team] or 0

			if n == 0 and st.team_gone_t[team] == nil then
				st.team_gone_t[team] = math.floor(now)
				print("[MatchTracker] team " .. tostring(team) .. " gone at " .. tostring(st.team_gone_t[team]))
			elseif n > 0 and st.team_gone_t[team] ~= nil then
				st.team_gone_t[team] = nil
				print("[MatchTracker] team " .. tostring(team) .. " back, reset")
			end
		end
	end

	-- никого не осталось (после горна): конец матча сразу. Опустевшие команды уже отмечены выше.
	-- all_left_sent - heartbeat уходит один раз; OnGameEnd сам защищён от повтора (st.ending)
	if total == 0 and st.t0 ~= nil then
		if not st.all_left_sent then
			st.all_left_sent = true
			print("[MatchTracker] все игроки вышли, heartbeat all_left")
			SendHeartbeatNow(true)
		end

		local w = AllLeftWinner()

		print("[MatchTracker] all left -> winner " .. tostring(w))
		pcall(MatchTracker.OnGameEnd, MatchTracker, w)

		return
	elseif total > 0 then
		st.all_left_sent = false
	end

	if changed then SendHeartbeatNow() end
end

local function Tick()
	-- замер FPS: aa_perf telemetry 0 (lib/perf_toggle.lua)
	if AA_PERF_OFF and AA_PERF_OFF.telemetry then return FLUSH_INTERVAL end

	if st.ended then return nil end

	st.tick = st.tick + 1

	if st.tick % HEARTBEAT_TICKS == 0 then Heartbeat() end

	FlushEvents()

	return FLUSH_INTERVAL
end

-- ------------------------------------------------------------------ публичные хуки

-- Как проверяются права хоста: "server" (GameRules API) или "client" (отчёты панелей)
local function HostCheckOf()
	local mode = "client"

	pcall(function()
		if LobbyLeader and LobbyLeader:HostCheckMode() == "server" then mode = "server" end
	end)

	return mode
end

-- Лобби: хостит ли игру бот, реальные игроки, читы и режим тулзов
local function LobbyInfo()
	local bot_hosted = true
	local real = 0
	local cheats = false
	local tools = false

	if LobbyLeader then
		pcall(function() bot_hosted = LobbyLeader:IsBotHosted() and true or false end)
		pcall(function() real = #LobbyLeader:GetRealPlayers() end)
	end

	pcall(function() cheats = GameRules:IsCheatMode() and true or false end)
	pcall(function() tools = IsInToolsMode() and true or false end)

	return {
		bot_hosted = bot_hosted,
		cheats = cheats,
		tools = tools,
		real_players = real,
		host_check = HostCheckOf(),
	}
end

-- Поиск MMR в стадии выбора команд: подписанный POST /api/players/lookup
-- с match_id "lobby-<matchid>". Бэкенд для таких id не проверяет seq.
local lobby = { key = nil, match_id = nil, seq = 0, inflight = false, cache = {}, provider_set = false }

-- основной канал перешёл на запасной ключ - лобби-запросы тоже
function AATrackerLobbyFallback(key)
	lobby.key = key
end

local function LobbyPrepare()
	if lobby.key ~= nil then return end

	local ok, key = pcall(AAServerKey)

	lobby.key = (ok and key) and tostring(key) or ""
	lobby.match_id = "lobby-" .. ReadMatchId()
end

-- onDone(ok, data) вызывается после ответа; время синхронизируем при необходимости
local function LobbySend(path, body, onDone)
	lobby.inflight = true

	local function Fail()
		lobby.inflight = false

		if onDone then pcall(onDone, false, nil) end
	end

	local function Post()
		lobby.seq = lobby.seq + 1

		local seq = lobby.seq
		local ts = math.floor(Time() + st.offset)
		local req = CreateHTTPRequestScriptVM("POST", BASE_URL .. path)

		if not req then return Fail() end

		pcall(function() req:SetHTTPRequestAbsoluteTimeoutMS(HTTP_TIMEOUT_MS) end)
		req:SetHTTPRequestRawPostBody("application/json", body)
		req:SetHTTPRequestHeaderValue("X-AA-Match", lobby.match_id)
		req:SetHTTPRequestHeaderValue("X-AA-Seq", tostring(seq))
		req:SetHTTPRequestHeaderValue("X-AA-Ts", tostring(ts))
		req:SetHTTPRequestHeaderValue("X-AA-Sig", HmacSha256Hex(lobby.key,
			lobby.match_id .. "\n" .. tostring(seq) .. "\n" .. tostring(ts) .. "\n" .. body))

		req:Send(function(res)
			local ok, data = ParseResponse(res)
			local code = res and res.StatusCode or 0

			-- ключ не принят - запасной ключ и тот же запрос ещё раз (без onDone)
			if not ok and code >= 400 and code < 500 and not lobby.any_ok then
				local fb = AAFallbackKey(lobby.key)

				if fb then
					print("[MatchTracker] лобби: сервер не принял ключ (" .. code .. "), запасной ключ")
					lobby.key = fb
					st.key = (st.key == nil or st.key == "" or not st.any_ok) and fb or st.key
					lobby.inflight = false
					pcall(LobbySend, path, body, onDone)

					return
				end
			end

			if ok then lobby.any_ok = true end

			if ok and data and type(data.server_time) == "number" then
				SyncTime(data.server_time)
			end

			lobby.inflight = false

			if onDone then pcall(onDone, ok, data) end
		end)
	end

	if st.offset ~= nil then return Post() end

	local req = CreateHTTPRequestScriptVM("GET", BASE_URL .. "/api/time")

	if not req then return Fail() end

	req:Send(function(res)
		local ok, data = ParseResponse(res)

		if ok and data and type(data.server_time) == "number" then
			SyncTime(data.server_time)
			Post()
		else
			Fail()
		end
	end)
end

-- Подписанный запрос для других модулей (lib/progression.lua): лобби-id, работает и в матче.
-- onDone(ok, data). Запросы не ставим в очередь матча - это действия игрока, а не телеметрия.
function AATrackerLobbyPost(path, tbl, onDone)
	LobbyPrepare()

	if lobby.key == nil or lobby.key == "" then
		if onDone then pcall(onDone, false, nil) end

		return
	end

	LobbySend(path, JsonEncode(tbl), onDone)
end

local function LobbyLookupTick()
	if st.started or lobby.inflight then return end
	-- 2026-11-14: ищем уже на загрузке (steam id игроков лобби известны до подключения),
	-- чтобы к началу выбора команд рейтинг и премиум были на руках и раскидка шла сразу
	if GameRules:State_Get() > DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then return end

	LobbyPrepare()

	if lobby.key == "" or string.sub(lobby.key, 1, 7) == "Invalid" then return end

	local sids = {}

	for pid = 0, 23 do
		-- не только подключённые: грузящиеся тоже; у ботов steam id 0
		if PlayerResource:IsValidPlayerID(pid) and PR("GetSteamAccountID", pid, 0) > 0 then
			local sid = SteamIdOf(pid)

			st.steam_to_pid[sid] = pid

			if lobby.cache[pid] == nil then sids[#sids + 1] = sid end
		end
	end

	if #sids == 0 then return end

	LobbySend("/api/players/lookup", JsonEncode({ steam_ids = sids }), function(ok, data)
		if not ok or not data or type(data.players) ~= "table" then return end

		for _, p in ipairs(data.players) do
			local pid = type(p) == "table" and st.steam_to_pid[tostring(p.steam_id)] or nil

			if pid ~= nil then
				lobby.cache[pid] = { mmr = tonumber(p.mmr) or 0, games = tonumber(p.games) or 0 }
			end
		end

		-- кого бэкенд не знает (новичок) - помечаем "без рейтинга", чтобы не спрашивать каждую секунду
		for _, sid in ipairs(sids) do
			local pid = st.steam_to_pid[sid]

			if pid ~= nil and lobby.cache[pid] == nil then lobby.cache[pid] = { games = 0 } end
		end

		-- MMR в лобби сразу в aa_rating/mmr, чтобы другие панели могли его показать
		pcall(PublishMmrRows, lobby.cache)

		-- премиум и экипировка косметики (lib/cosmetics/core.lua)
		if CosmeticsCore and CosmeticsCore.OnPlayersInfo then pcall(CosmeticsCore.OnPlayersInfo, CosmeticsCore, data.players) end

		-- рейтинг пришёл - лобби может раскидать команды прямо сейчас
		if LobbyLeader and LobbyLeader.OnRatingsArrived then pcall(LobbyLeader.OnRatingsArrived, LobbyLeader) end
	end)
end

-- Провайдер MMR для LobbyLeader: сначала aa_rating/mmr, потом результат поиска
local function LobbyMMR(pid)
	local t = CustomNetTables:GetTableValue("aa_rating", "mmr")
	local e = t and t[tostring(pid)]

	if e and e.mmr ~= nil then return e.mmr end

	local c = lobby.cache[pid]

	return c and c.mmr or nil
end

-- Бэкенд по этому игроку уже ответил (рейтинг есть или его нет совсем) - для LobbyLeader:RatingsKnown
function AATrackerLobbyLooked(pid)
	return lobby.cache[pid] ~= nil
end

local function PlayersForStart()
	local list = {}

	for pid = 0, 23 do
		if IsHumanPid(pid) then
			local sid = SteamIdOf(pid)

			st.steam_to_pid[sid] = pid
			list[#list + 1] = {
				steam_id  = sid,
				player_id = pid,
				name     = PR("GetPlayerName", pid, "") or "",
				team     = PR("GetTeam", pid, 0),
				hero     = PR("GetSelectedHeroName", pid, "") or "",
			}
		end
	end

	return list
end

local function PlayersForEnd()
	local list = {}

	for pid = 0, 23 do
		if IsHumanPid(pid) then
			local sid = SteamIdOf(pid)

			st.steam_to_pid[sid] = pid
			list[#list + 1] = {
				steam_id  = sid,
				name      = PR("GetPlayerName", pid, "") or "",
				team      = PR("GetTeam", pid, 0),
				hero      = PR("GetSelectedHeroName", pid, "") or "",
				kills     = PR("GetKills", pid, 0),
				deaths    = PR("GetDeaths", pid, 0),
				assists   = PR("GetAssists", pid, 0),
				net_worth = NetWorthOf(pid),
			}

			local pi = st.pinfo[pid]
			local row = list[#list]

			row.conn     = pi and pi.conn or ConnName(pid)
			row.left_t   = pi and pi.left_t or nil
			row.dc_total = pi and math.floor(pi.dc_total) or 0
			row.nw_peak  = math.max(pi and pi.nw_peak or 0, row.net_worth or 0)
			row.abandon_t = pi and pi.abandon_t or nil
			row.abandoned = row.abandon_t ~= nil and row.abandon_t < Gt() - END_GRACE
		end
	end

	return list
end

-- карта (dev/new/map_5x5...) и формат команд, например "5x2"
function AATrackerMapName()
	local ok, m = pcall(GetMapName)
	return ok and tostring(m or "") or ""
end

function AATrackerModeName()
	local teams, size = 0, 0
	for team = DOTA_TEAM_FIRST, DOTA_TEAM_CUSTOM_MAX do
		local ok, n = pcall(function() return GameRules:GetCustomGameTeamMaxPlayers(team) end)
		if ok and n and n > 0 then
			teams = teams + 1
			if n > size then size = n end
		end
	end
	if teams == 0 then return "" end
	return size .. "x" .. teams
end

function MatchTracker:OnGameStarted()
	if st.started or st.ended then return end

	st.started = true
	st.match_id = st.pre_match_id or ReadMatchId()

	FixT0()

	local pollFn = function()
		if st.ended then return nil end

		pcall(CheckConnections)

		return CONN_POLL
	end

	if not SchedAfter(CONN_POLL, pollFn) and Timers then
		Timers:CreateTimer(CONN_POLL, pollFn)
	end

	local ok, key = pcall(AAServerKey)

	st.key = (ok and key) and tostring(key) or ""

	SendBootstrap()

	st.lobby = LobbyInfo()

	Enqueue("/api/match/start", {
		map      = AATrackerMapName(),
		mode     = AATrackerModeName(),
		match_id = st.match_id,
		players  = PlayersForStart(),
		lobby    = st.lobby,
		time_base = "match",
	}, "start")

	local tickFn = function()
		local ok2, nextDelay = pcall(Tick)

		if ok2 then return nextDelay end

		print("[MatchTracker] tick error: " .. tostring(nextDelay))

		return FLUSH_INTERVAL
	end

	if not SchedAfter(FLUSH_INTERVAL, tickFn) and Timers then
		Timers:CreateTimer(FLUSH_INTERVAL, tickFn)
	end
end

function MatchTracker:OnGold(pid, gold, reason, internal)
	if not st.started or st.ended or internal then return end
	if not PidOk(pid) or type(gold) ~= "number" or gold == 0 then return end

	-- источник, который проставила обёртка выдачи (lib/match_telemetry.lua), иначе по причине движка
	local tagged = MatchTelemetry and MatchTelemetry.goldSource
	local source = tagged or SOURCE_BY_REASON[reason] or "other"
	local key = pid .. "|" .. source
	local g = st.gold[key]

	if not g then
		g = { pid = pid, t = math.floor(Gt()), source = source, amount = 0 }
		st.gold[key] = g
	end

	g.amount = g.amount + gold
end

function MatchTracker:OnDamage(attacker, victim, damage, skillName)
	if not st.started or st.ended then return end
	if not attacker or not victim or type(damage) ~= "number" or damage <= 0 then return end

	local pid = attacker:GetPlayerOwnerID()

	if not PidOk(pid) then return end

	local target = "other"

	if victim:IsHero() then
		target = "hero"
	elseif victim:IsCreep() then
		target = "creep"
	elseif victim:IsBuilding() then
		target = "building"
	end

	local ability = (skillName and skillName ~= "") and skillName or "attack"
	local key = pid .. "|" .. ability .. "|" .. target
	local a = st.dmg[key]

	if not a then
		a = { pid = pid, t = math.floor(Gt()), ability = ability, target = target, amount = 0 }
		st.dmg[key] = a
	end

	a.amount = a.amount + damage

	-- для ассистов: кто бил героя в последние ASSIST_WINDOW секунд
	if victim:IsRealHero() then
		local vi = victim:entindex()

		st.last_hit[vi] = st.last_hit[vi] or {}
		st.last_hit[vi][pid] = Gt()
	end
end

function MatchTracker:OnKill(killed, attacker)
	if not st.started or st.ended or not killed or not killed:IsRealHero() then return end

	local victim = killed:GetPlayerOwnerID()

	if not PidOk(victim) then return end

	local killer = (attacker and attacker:IsRealHero()) and attacker:GetPlayerOwnerID() or -1
	local assists = {}
	local now = Gt()

	for pid, t in pairs(st.last_hit[killed:entindex()] or {}) do
		if pid ~= killer and now - t <= ASSIST_WINDOW then
			assists[#assists + 1] = pid
		end
	end

	table.sort(assists)
	AddEvent("kill", killer, { victim_pid = victim, assists = assists })
end

function MatchTracker:OnItemPurchased(pid, item, cost)
	if not st.started or st.ended or not PidOk(pid) then return end

	AddEvent("item_purchase", pid, { item = item, cost = cost })
end

function MatchTracker:OnHeroChanged(player, heroName)
	if not st.started or st.ended or not player then return end

	local pid = player:GetPlayerID()

	if not PidOk(pid) then return end

	-- событие "hero" (с prev_hero и reason) шлёт lib/match_telemetry.lua, здесь его нет
end

-- Конец игры: сначала выгребаем события, потом шлём итог
-- Причина конца: all_left / team_left / kill_limit
local function EndReasonOf(winnerTeam)
	local total, byTeam = ConnectedHumans()

	if (winnerTeam ~= DOTA_TEAM_GOODGUYS and winnerTeam ~= DOTA_TEAM_BADGUYS) or total == 0 then
		return "all_left"
	end

	local loser = winnerTeam == DOTA_TEAM_GOODGUYS and DOTA_TEAM_BADGUYS or DOTA_TEAM_GOODGUYS

	if (byTeam[loser] or 0) == 0 then return "team_left" end

	return "kill_limit"
end

-- Конец игры: итог сразу за запросом в полёте, хвост событий - после него
function MatchTracker:OnGameEnd(winnerTeam)
	if not st.started or st.ended or st.ending then return end

	st.ending = true
	st.hold_pump = true

	print("[MatchTracker] game end, winner " .. tostring(winnerTeam))

	FixT0()

	local okBody, body = pcall(function()
		local reason = "kill_limit"
		pcall(function() reason = EndReasonOf(winnerTeam) end)

		return {
			match_id       = st.match_id,
			winner_team    = winnerTeam,
			duration       = math.floor(Gt()),
			players        = PlayersForEnd(),
			lobby          = st.lobby or LobbyInfo(),
			unrated_reason = st.unrated_reason,
			end_reason     = reason,
			team_gone_t    = TeamGoneOut(),
			time_base      = "match",
		}
	end)

	if not okBody or type(body) ~= "table" then
		print("[MatchTracker] end body error: " .. tostring(body) .. ", минимальное тело")
		body = { match_id = st.match_id, winner_team = winnerTeam, duration = math.floor(Gt()) }
	end

	local before = #st.queue

	local okE, endItem = pcall(Enqueue, "/api/match/end", body, "end")

	if not okE or not endItem then
		-- JsonEncode упал на полном теле - минимальное
		print("[MatchTracker] end enqueue error: " .. tostring(endItem))
		while #st.queue > before do table.remove(st.queue) end
		okE, endItem = pcall(Enqueue, "/api/match/end",
			{ match_id = st.match_id, winner_team = winnerTeam, duration = math.floor(Gt()) }, "end")
	end

	-- /end вынимаем и ставим сразу за запросом в полёте (или в голову)
	if okE and endItem then
		for i = #st.queue, 1, -1 do
			if st.queue[i] == endItem then table.remove(st.queue, i) break end
		end

		local at = st.inflight and 2 or 1

		if at > #st.queue + 1 then at = #st.queue + 1 end

		table.insert(st.queue, at, endItem)
	end

	-- всё, что не /start и не /end, после конца - одна попытка
	for i, item in ipairs(st.queue) do
		if item.kind ~= "end" and item.kind ~= "start" then
			item.max_tries = math.min(item.max_tries or MAX_TRIES, math.max(1, item.tries + 1))
		end
	end

	-- хвост событий - в конец очереди, за /end
	pcall(FlushEvents)

	st.ended = true
	st.hold_pump = false

	pcall(Pump)
end

-- Игра не идёт в рейтинг (например, админ включил читы). Флаг уйдёт в /match/end,
-- и сразу - событие "unrated" в поток событий.
function MatchTracker:MarkUnrated(reason)
	st.unrated_reason = tostring(reason or "unspecified")

	if not st.started or st.ended then return end

	Enqueue("/api/match/events", {
		match_id = st.match_id,
		events   = { { type = "unrated", t = math.floor(Gt()), data = { reason = st.unrated_reason } } },
	}, "events")
end

-- Золото и урон пишем только тогда, когда фильтр их пропустил (вернул true).
-- Значения берём уже после правок фильтра (ev.gold / ev.damage).
function MatchTracker:OnGoldApplied(ev)
	-- командная выплата (_paying) - в gold_src из lib/match_telemetry.lua, здесь её нет
	if TeamGoldShare and TeamGoldShare._paying then return end

	-- перенос из запаса без метки (_bypass, докладка в кошелёк) - не новое золото.
	-- С меткой (камбэк) - пишем: выдача идёт через Bypass, но золото новое
	local tagged = MatchTelemetry and MatchTelemetry.goldSource

	if TeamGoldShare and TeamGoldShare._bypass and not tagged then return end

	self:OnGold(ev.player_id_const, ev.gold, ev.reason_const, false)
end

function MatchTracker:OnDamageApplied(ev)
	local attacker = ev.entindex_attacker_const and EntIndexToHScript(ev.entindex_attacker_const) or nil
	local victim = ev.entindex_victim_const and EntIndexToHScript(ev.entindex_victim_const) or nil
	local skill = ""

	if ev.entindex_inflictor_const then
		local inflictor = EntIndexToHScript(ev.entindex_inflictor_const)

		if inflictor then skill = inflictor:GetName() or "" end
	end

	-- доп. урон от divine_intervention -> "<настоящий источник>#bonus" (addon_game_mode.lua)
	if AA_DamageKey then skill = AA_DamageKey(skill, ev) end

	-- журнал урона премиум-игрокам (lib/damage_log.lua), только наблюдение
	if DamageLog then pcall(DamageLog.OnApplied, DamageLog, ev) end

	self:OnDamage(attacker, victim, ev.damage, skill)
end

-- Ставит обёртки на методы режима. Вызывать до SetDamageFilter/SetModifyGoldFilter.
function MatchTracker:WrapFilters(mode)
	if st.wrapped or not mode then return end

	st.wrapped = true

	local origGold = mode.GoldFilter
	local origDamage = mode.DamageFilter

	if origGold then
		mode.GoldFilter = function(self_, ev, ...)
			local r = origGold(self_, ev, ...)

			if r == true and not (AA_PERF_OFF and AA_PERF_OFF.telemetry) then pcall(MatchTracker.OnGoldApplied, MatchTracker, ev) end

			return r
		end
	end

	if origDamage then
		mode.DamageFilter = function(self_, ev, ...)
			local r = origDamage(self_, ev, ...)

			if r == true and not (AA_PERF_OFF and AA_PERF_OFF.telemetry) then pcall(MatchTracker.OnDamageApplied, MatchTracker, ev) end

			return r
		end
	end
end

-- ------------------------------------------------------------------ подписки

local function MapReason(constName, source)
	local c = _G[constName]

	if c ~= nil then SOURCE_BY_REASON[c] = source end
end

MapReason("DOTA_ModifyGold_CreepKill", "creep")
MapReason("DOTA_ModifyGold_HeroKill", "hero_kill")
MapReason("DOTA_ModifyGold_Building", "building")
MapReason("DOTA_ModifyGold_GameTick", "passive")
MapReason("DOTA_ModifyGold_Rune", "bounty_rune")
MapReason("DOTA_ModifyGold_Unspecified", "other")

ListenToGameEvent("dota_item_purchased", function(event)
	pcall(MatchTracker.OnItemPurchased, MatchTracker, event.PlayerID, event.itemname, event.itemcost)
end, nil)

ListenToGameEvent("entity_killed", function(event)
	pcall(function()
		local killed = EntIndexToHScript(event.entindex_killed)
		local attacker = event.entindex_attacker and EntIndexToHScript(event.entindex_attacker) or nil

		MatchTracker:OnKill(killed, attacker)
	end)
end, nil)

ListenToGameEvent("game_rules_state_change", function()
	local ok, err = pcall(function()
		FixT0()

		if GameRules:State_Get() >= DOTA_GAMERULES_STATE_PRE_GAME and GameRules:State_Get() <= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
			print("[MatchTracker] game started, sending start")
			MatchTracker:OnGameStarted()
		end
	end)
	if not ok then print("[MatchTracker] start error: " .. tostring(err)) end
end, nil)

-- Подключения: событие сразу пишет conn и запускает внеочередную проверку (CheckConnections).
-- Таймер не трогаем: он один, со стартом матча (OnGameStarted).
local CONN_EVENT_STATE = {
	player_disconnect   = "disconnect",
	player_reconnected  = "reconnect",
	player_connect_full = "connect",
}

local function OnConnEvent(eventName, keys)
	if not st.started or st.ended then return end

	local state = CONN_EVENT_STATE[eventName]
	local pid = nil

	if type(keys) == "table" and keys.PlayerID ~= nil then pid = tonumber(keys.PlayerID) end
	if not PidOk(pid) then pid = nil end

	-- у player_disconnect игрока считаем отключённым уже сейчас, даже если движок не обновил состояние
	local exclPid = (state == "disconnect") and pid or nil
	local human = pid ~= nil and IsHumanPid(pid)

	AddEvent("conn", pid, {
		steam_id = human and SteamIdOf(pid) or nil,
		team     = pid ~= nil and PR("GetTeam", pid, nil) or nil,
		state    = state,
		reason   = type(keys) == "table" and keys.reason or nil,
	})

	local total = ConnectedHumans(exclPid)

	print("[MatchTracker] conn " .. tostring(state) .. " pid " .. tostring(pid) .. " connected " .. tostring(total))

	CheckConnections(exclPid)
end

for name in pairs(CONN_EVENT_STATE) do
	ListenToGameEvent(name, function(keys)
		pcall(OnConnEvent, name, keys)
	end, nil)
end

-- старт матча - сразу после пика (предыгра, пауза в начале), не на горне.
-- Игра могла начаться до загрузки модуля
pcall(function()
	FixT0()

	if GameRules:State_Get() >= DOTA_GAMERULES_STATE_PRE_GAME and GameRules:State_Get() <= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		MatchTracker:OnGameStarted()
	end
end)

-- Лобби: поиск MMR и провайдер LobbyLeader. LobbyLeader грузится после этого модуля,
-- поэтому провайдер ставим из таймера, когда LobbyLeader уже есть.
-- Реальное время и шаг 1 с с самого старта: на загрузке игровое время стоит,
-- а раньше первый запрос уходил только через 5 с.
Timers:CreateTimer({ endTime = 0.1, useGameTime = false, callback = function()
	if st.started or GameRules:State_Get() > DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then return nil end

	if LobbyLeader and not lobby.provider_set then
		pcall(function() LobbyLeader:SetMMRProvider(LobbyMMR) end)
		lobby.provider_set = true
	end

	pcall(LobbyLookupTick)

	return 1
end })

pcall(MatchTracker.SelfTest)

-- Подписанный POST для других модулей (косметика, lib/cosmetics/core.lua).
-- Матч идёт - в очередь телеметрии (kind "cosmetics", ответ не разбираем);
-- до старта - тем же путём, что поиск MMR в лобби. onDone(ok) - необязательно.
-- id текущего матча до старта (жетоны рейтинга, lib/progression.lua): тот же id уйдёт в /api/match/start
function MatchTracker:MatchId()
	if st.started and st.match_id ~= "0" then return st.match_id end

	st.pre_match_id = st.pre_match_id or ReadMatchId()

	return st.pre_match_id
end

function MatchTracker:SignedPost(path, payload, onDone)
	if st.ended then return end

	if st.started then
		Enqueue(path, payload, "cosmetics")

		return
	end

	LobbyPrepare()

	if lobby.key == "" or string.sub(lobby.key, 1, 7) == "Invalid" then return end

	LobbySend(path, JsonEncode(payload), function(ok)
		if onDone then pcall(onDone, ok) end
	end)
end

-- ------------------------------------------------------------------ публичный Push
-- Для lib/match_telemetry.lua: свои события уходят в тот же пакет, что и штатные
-- (t = игровое время в момент вызова). До старта матча копим в буфере не больше
-- PRE_START_MAX событий, при старте переливаем в очередь событий.
local PRE_START_MAX = 200
local preStart = {}
local preStartPoll = false

local function FlushPreStart()
	if not st.started then return end

	for _, e in ipairs(preStart) do st.pending[#st.pending + 1] = e end

	preStart = {}
end

function MatchTracker:Push(etype, pid, data)
	if st.ended then return end

	local e = { type = etype, pid = pid, t = math.floor(Gt()), data = data }

	if st.started then
		FlushPreStart()
		st.pending[#st.pending + 1] = e

		return
	end

	if #preStart >= PRE_START_MAX then return end

	preStart[#preStart + 1] = e

	-- буфер сливаем таймером, пока матч не стартовал (до первого Push его может не быть)
	if not preStartPoll then
		preStartPoll = true

		Timers:CreateTimer(1, function()
			if st.ended then return nil end

			if st.started then
				FlushPreStart()

				return nil
			end

			return 1
		end)
	end
end
