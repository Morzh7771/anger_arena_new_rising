if not IsServer() then return end

-- Журнал урона для премиум-игроков (panorama/scripts/custom_game/damage_log.js).
-- Что получил и чем нанёс: по источникам, способностям и типам урона;
-- смерти с разбором урона за последние RING_SECONDS секунд.
--
-- Только наблюдение: MatchTracker:OnDamageApplied зовёт DamageLog:OnApplied
-- для урона, который прошёл DamageFilter. Непремиум-игроки отсекаются первой
-- проверкой, для них ничего не считается.
-- Данные уходят только тому, кто открыл панель: клиент сам опрашивает раз в 2 с
-- (aa_dlog_req), ответ aa_dlog_data адресный. Нет-таблиц и рассылки нет.
--
-- Агрегаты - вложенные таблицы, без строк на каждый удар:
--   tt / tl[источник][способность][тип]  урон получен: вся игра / эта жизнь
--   dt / dl[способность][вид цели][тип]  урон нанесён: вся игра / эта жизнь
--   ring - последние RING_SECONDS секунд входящих ударов (кольцо фиксированного размера)
--   deaths - последние DEATHS_KEEP смертей с разбором
--
-- Строки, которые уходят клиенту, - таблицы с именованными полями:
--   taken: { s = источник, a = способность, p, m, u = физ/маг/чистый, v = сумма }
--   dealt: { a = способность, t = вид цели, p, m, u, v }
--   deaths: { t = время, k = убийца, kk = вид убийцы, tot = урон за 10 с, rows = taken-строки }
--
-- Ключи источника/способности:
--   герой         - имя юнита (npc_dota_hero_*)
--   босс          - имя юнита
--   "@creep"      - крипы
--   "@tower"      - башня
--   "@building"   - прочие здания
--   "@attack"     - обычная атака героя/иллюзии (нет инфлектора)
--   "@summon"     - ВЕСЬ урон юнитов игрока, которые не герои (саммоны: варды Пугны, собаки
--                   Ликана, скелеты, варды Шамана...) - и атаки, и их способности, одной строкой
-- Суммы - урон ПОСЛЕ брони/маг. резиста (оценка по формуле, см. PassMul).
--   иначе         - имя способности или предмета (item_*)

DamageLog = DamageLog or {}

local D = DamageLog

D.st = D.st or {} -- pid -> состояние премиум-игрока

local RING_SIZE = 64
local RING_SECONDS = 10
local DEATHS_KEEP = 10
local DEATH_ROWS = 12
-- удар атакой считаем критом, если он больше средней атаки атакующего на столько
local CRIT_EPS = 1.2
-- Окна "1 минута / 3 минуты": урон копим корзинами по BUCKET_SEC секунд, держим
-- BUCKETS корзин (3 мин). Корзина - те же агрегаты, что и у "всей игры".
local BUCKET_SEC = 10
local BUCKETS = 18
local WINDOW_BUCKETS = { [2] = 6, [3] = 18 } -- режим запроса -> сколько последних корзин

-- тип урона движка: 1 физ, 2 маг, 4 чистый; прочее сводим к физ
local function NormType(t)
	if t == 2 or t == 4 then return t end

	return 1
end

-- Премиум ли игрок. CosmeticsCore тянет премиум с бэкенда асинхронно,
-- поэтому результат здесь не кэшируем.
local function IsPrem(pid)
	if pid == nil or pid < 0 or CosmeticsCore == nil then return false end

	return CosmeticsCore:IsPremium(pid) == true
end

local function State(pid)
	local s = D.st[pid]

	if s then return s end

	s = { tt = {}, tl = {}, dt = {}, dl = {}, ts = {}, tsl = {}, ds = {}, dsl = {}, ring = {}, rh = 0, rn = 0, deaths = {} }

	for i = 1, RING_SIZE do
		s.ring[i] = { t = 0, s = "", a = "", d = 1, v = 0 }
	end

	D.st[pid] = s

	return s
end

-- Добавляет урон в агрегат tbl[k1][k2][тип]
local function Add(tbl, k1, k2, dt, v)
	local b = tbl[k1]

	if b == nil then
		b = {}
		tbl[k1] = b
	end

	local c = b[k2]

	if c == nil then
		c = {}
		b[k2] = c
	end

	c[dt] = (c[dt] or 0) + v
end

-- Ключ источника и вид цели: hero / boss / creep / building
local function Classify(u)
	if u.IsAngelArenaBoss then return u:GetUnitName(), "boss" end

	if u:IsHero() then return u:GetUnitName(), "hero" end

	if u:IsBuilding() then
		if u:IsTower() then return "@tower", "building" end

		return "@building", "building"
	end

	return "@creep", "creep"
end

local function AbilityKey(ev)
	if ev.entindex_inflictor_const then
		local inf = EntIndexToHScript(ev.entindex_inflictor_const)
		local name = inf and inf:GetName() or ""

		-- доп. урон от divine_intervention (урон от статов) в игре показываем ВМЕСТЕ со скиллом:
		-- "<скилл>#bonus" -> "<скилл>". На сайт он идёт отдельно (lib/match_tracker.lua).
		if name ~= "" then
			local key = AA_DamageKey and AA_DamageKey(name, ev) or name

			return (key:gsub("#bonus$", ""))
		end
	end

	-- Без источника. Атака с руки бывает только физической: магический/чистый урон без
	-- источника - это способность, которой забыли передать ability (так было у Харона) -
	-- не "атака" и без проверки на крит.
	if ev.damagetype_const == 2 or ev.damagetype_const == 4 then return "@spell" end

	return "@attack"
end

-- Доля урона, которая проходит сквозь броню / маг. резист жертвы (чистый проходит весь).
-- Ванильная формула брони; прочие снижения урона (блок, % снижения) не учитываем.
local function PassMul(victim, dt)
	if dt == 1 then
		local a = victim:GetPhysicalArmorValue(false) or 0

		return 1 - 0.06 * a / (1 + 0.06 * math.abs(a))
	elseif dt == 2 then
		return 1 - (victim:GetMagicalArmorValue() or 0)
	end

	return 1
end

-- Сводка для шапки вкладки. Поля короткие - уходят клиенту как есть:
--   v всего (после резистов)   a атаки   c прибавка от критов   s способности   i предметы   m саммоны
--   r срезано бронёй/резистом  h ударов атакой   k из них критов   x самый сильный удар
--   kh/kc/kb/kd по видам цели/источника: герои / крипы / боссы / здания   pt/mt/ut по типам
local function AddSum(sm, kind, abil, dt, post, pre, isAtk, critPart, isCrit)
	sm.v = (sm.v or 0) + post
	sm.r = (sm.r or 0) + (pre - post)

	if abil == "@summon" then
		sm.m = (sm.m or 0) + post
	elseif isAtk then
		sm.a = (sm.a or 0) + post
		sm.h = (sm.h or 0) + 1

		if isCrit then
			sm.k = (sm.k or 0) + 1
			sm.c = (sm.c or 0) + critPart
		end
	elseif abil:sub(1, 5) == "item_" then
		sm.i = (sm.i or 0) + post
	else
		sm.s = (sm.s or 0) + post
	end

	if post > (sm.x or 0) then sm.x = post end

	local kk = kind == "hero" and "kh" or kind == "boss" and "kb" or kind == "building" and "kd" or "kc"

	sm[kk] = (sm[kk] or 0) + post

	local tk = dt == 2 and "mt" or dt == 4 and "ut" or "pt"

	sm[tk] = (sm[tk] or 0) + post
end

-- Агрегат -> массив строк с именованными полями: n1 = k1, n2 = k2, p/m/u = физ/маг/чистый, v = сумма
local function Rows(tbl, n1, n2)
	local out = {}

	for k1, b in pairs(tbl) do
		for k2, c in pairs(b) do
			local p, m, u = c[1] or 0, c[2] or 0, c[4] or 0
			local row = { p = p, m = m, u = u, v = p + m + u, c = c.c, h = c.h, k = c.k }

			row[n1] = k1
			row[n2] = k2
			out[#out + 1] = row
		end
	end

	return out
end

-- Текущая корзина игрока; устаревший слот кольца очищаем и переиспользуем
local function Bucket(st, now)
	local id = math.floor(now / BUCKET_SEC)

	st.bk = st.bk or {}

	local slot = id % BUCKETS + 1
	local b = st.bk[slot]

	if b == nil or b.id ~= id then
		b = { id = id, t = {}, d = {}, ts = {}, ds = {} }
		st.bk[slot] = b
	end

	return b
end

-- Складывает агрегат src (k1 -> k2 -> поля) в dst
local function Merge2(dst, src)
	for k1, b in pairs(src) do
		local db = dst[k1]

		if db == nil then
			db = {}
			dst[k1] = db
		end

		for k2, c in pairs(b) do
			local dc = db[k2]

			if dc == nil then
				dc = {}
				db[k2] = dc
			end

			for f, v in pairs(c) do dc[f] = (dc[f] or 0) + v end
		end
	end
end

-- Сводки складываем, кроме x (сильнейший удар) - он максимум
local function MergeSum(dst, src)
	for f, v in pairs(src) do
		if f == "x" then
			if v > (dst.x or 0) then dst.x = v end
		else
			dst[f] = (dst[f] or 0) + v
		end
	end
end

-- Вызывается из MatchTracker:OnDamageApplied для урона, прошедшего фильтр
function D:OnApplied(ev)
	local dmg = ev.damage


	if not dmg or dmg <= 0 or not ev.entindex_victim_const or not ev.entindex_attacker_const then return end

	local victim = EntIndexToHScript(ev.entindex_victim_const)
	local attacker = EntIndexToHScript(ev.entindex_attacker_const)

	if not victim or not attacker then return end

	local vpid = victim:GetPlayerOwnerID()
	local apid = attacker:GetPlayerOwnerID()
	local vp = IsPrem(vpid)
	local ap = IsPrem(apid)

	if not vp and not ap then return end

	local dt = NormType(ev.damagetype_const)
	local abil = AbilityKey(ev)
	local now = GameRules:GetGameTime()

	-- урон в фильтре - до брони и резиста; в журнал пишем то, что реально дошло
	local post = dmg * PassMul(victim, dt)

	if post < 0 then post = 0 end

	-- Саммоны: любой юнит игрока, кроме героя (иллюзии - герои, они в атаках). Весь их урон -
	-- одной строкой "@summon", в атаки и способности героя не идёт.
	if not attacker:IsHero() and attacker:GetPlayerOwnerID() >= 0 then abil = "@summon" end

	-- Атака: крит - удар заметно больше средней атаки атакующего (ловит криты любого источника).
	local isAtk = abil == "@attack"
	local isCrit, critPart = false, 0

	if isAtk then
		local avg = attacker.GetAverageTrueAttackDamage and attacker:GetAverageTrueAttackDamage(victim) or 0

		if avg > 0 and dmg > avg * CRIT_EPS then
			isCrit = true
			critPart = post * (1 - avg / dmg)
		end
	end

	if vp then
		local src, srcKind = Classify(attacker)
		local st = State(vpid)

		Add(st.tt, src, abil, dt, post)
		Add(st.tl, src, abil, dt, post)
		AddSum(st.ts, srcKind, abil, dt, post, dmg, isAtk, critPart, isCrit)
		AddSum(st.tsl, srcKind, abil, dt, post, dmg, isAtk, critPart, isCrit)

		local b = Bucket(st, now)

		Add(b.t, src, abil, dt, post)
		AddSum(b.ts, srcKind, abil, dt, post, dmg, isAtk, critPart, isCrit)

		-- кольцо последних ударов: слот переписываем, без новых таблиц
		local h = st.rh % RING_SIZE + 1
		local r = st.ring[h]

		st.rh = h
		r.t = now
		r.s = src
		r.a = abil
		r.d = dt
		r.v = post

		if st.rn < RING_SIZE then st.rn = st.rn + 1 end
	end

	if ap then
		local _, kind = Classify(victim)
		local st = State(apid)

		Add(st.dt, abil, kind, dt, post)
		Add(st.dl, abil, kind, dt, post)
		AddSum(st.ds, kind, abil, dt, post, dmg, isAtk, critPart, isCrit)
		AddSum(st.dsl, kind, abil, dt, post, dmg, isAtk, critPart, isCrit)

		local b = Bucket(st, now)

		Add(b.d, abil, kind, dt, post)
		AddSum(b.ds, kind, abil, dt, post, dmg, isAtk, critPart, isCrit)

		-- на строке атаки ещё число ударов, критов и крит-прибавка
		if isAtk then
			for _, c in ipairs({ st.dt[abil][kind], st.dl[abil][kind], b.d[abil][kind] }) do
				c.h = (c.h or 0) + 1

				if isCrit then
					c.k = (c.k or 0) + 1
					c.c = (c.c or 0) + critPart
				end
			end
		end
	end
end

-- Новая жизнь героя: сбрасываем счётчики "эта жизнь"
function D:OnSpawned(e)
	local u = e.entindex and EntIndexToHScript(e.entindex) or nil

	if not u or not u:IsRealHero() then return end

	local pid = u:GetPlayerOwnerID()

	if not IsPrem(pid) then return end

	local st = State(pid)

	st.tl = {}
	st.dl = {}
	st.tsl = {}
	st.dsl = {}
end

-- Смерть премиум-героя: разбор входящего урона за последние RING_SECONDS секунд
function D:OnKilled(e)
	local killed = e.entindex_killed and EntIndexToHScript(e.entindex_killed) or nil

	if not killed or not killed:IsRealHero() then return end

	local pid = killed:GetPlayerOwnerID()

	if not IsPrem(pid) then return end

	local st = State(pid)
	local now = GameRules:GetGameTime()
	local killerKey, killerKind = "@creep", "creep"
	local killer = e.entindex_attacker and EntIndexToHScript(e.entindex_attacker) or nil

	if killer then killerKey, killerKind = Classify(killer) end

	local g = {}
	local total = 0

	for i = 1, st.rn do
		local r = st.ring[i]

		if now - r.t <= RING_SECONDS then
			Add(g, r.s, r.a, r.d, r.v)
			total = total + r.v
		end
	end

	local rows = Rows(g, "s", "a")

	table.sort(rows, function(x, y) return x.v > y.v end)

	while #rows > DEATH_ROWS do table.remove(rows) end

	st.deaths[#st.deaths + 1] = { t = now, k = killerKey, kk = killerKind, tot = total, rows = rows }

	if #st.deaths > DEATHS_KEEP then table.remove(st.deaths, 1) end
end

-- Запрос панели: отвечаем только ей и только премиум-игроку
function D:OnRequest(data)
	local pid = tonumber(data.PlayerID)

	if not IsPrem(pid) then return end

	local player = PlayerResource:GetPlayer(pid)

	if not player then return end

	local st = State(pid)
	-- режим: 0 вся игра, 1 эта жизнь, 2 последняя минута, 3 последние 3 минуты
	local mode = tonumber(data.mode) or tonumber(data.life) or 0
	local t, d, ts, ds

	if WINDOW_BUCKETS[mode] then
		local cur = math.floor(GameRules:GetGameTime() / BUCKET_SEC)
		local from = cur - WINDOW_BUCKETS[mode] + 1

		t, d, ts, ds = {}, {}, {}, {}

		for _, b in pairs(st.bk or {}) do
			if b.id >= from and b.id <= cur then
				Merge2(t, b.t)
				Merge2(d, b.d)
				MergeSum(ts, b.ts)
				MergeSum(ds, b.ds)
			end
		end
	elseif mode == 1 then
		t, d, ts, ds = st.tl, st.dl, st.tsl, st.dsl
	else
		mode = 0
		t, d, ts, ds = st.tt, st.dt, st.ts, st.ds
	end

	CustomGameEventManager:Send_ServerToPlayer(player, "aa_dlog_data", {
		mode = mode,
		life = mode == 1 and 1 or 0,
		taken = Rows(t, "s", "a"),
		dealt = Rows(d, "a", "t"),
		tsum = ts,
		dsum = ds,
		deaths = st.deaths,
	})
end

ListenToGameEvent("npc_spawned", function(e)
	pcall(D.OnSpawned, D, e)
end, nil)

ListenToGameEvent("entity_killed", function(e)
	pcall(D.OnKilled, D, e)
end, nil)

CustomGameEventManager:RegisterListener("aa_dlog_req", function(_, data)
	local ok, err = pcall(D.OnRequest, D, data)

	if not ok then print("[DamageLog] request failed: " .. tostring(err)) end
end)
