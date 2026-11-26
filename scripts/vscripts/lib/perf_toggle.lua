-- Замер FPS без перезапуска: консольная команда aa_perf <часть> <0|1>.
-- Части: telemetry (сбор и отправка статистики матча), ui (новые панели
-- интерфейса: чит-меню, косметика, колесо, смайлики, кнопки, логи урона),
-- all - всё сразу. 0 - выключить, 1 - включить обратно.
-- Работает только в тулзах или у владельца (Steam 960329385): обычным игрокам
-- команда недоступна.

AA_PERF_OFF = AA_PERF_OFF or {}

local OWNER_ACCOUNT = 960329385

local function Allowed()
	if IsInToolsMode() then return true end

	local player = Convars:GetCommandClient()

	if not player then return false end

	local ok, acc = pcall(function() return PlayerResource:GetSteamAccountID(player:GetPlayerID()) end)

	return ok and acc == OWNER_ACCOUNT
end

local function Apply(part, off)
	if part == "telemetry" or part == "all" then AA_PERF_OFF.telemetry = off end

	if part == "ui" or part == "all" then
		AA_PERF_OFF.ui = off
		CustomGameEventManager:Send_ServerToAllClients("aa_perf_ui", { off = off and 1 or 0 })
	end

	print(string.format("[AA.perf] %s -> %s (telemetry=%s ui=%s)", part, off and "выкл" or "вкл",
		tostring(AA_PERF_OFF.telemetry == true), tostring(AA_PERF_OFF.ui == true)))
end

Convars:RegisterCommand("aa_perf", function(_, part, value)
	if not Allowed() then return end

	part = tostring(part or "")

	if part ~= "telemetry" and part ~= "ui" and part ~= "all" then
		print("[AA.perf] использование: aa_perf <telemetry|ui|all> <0|1>")
		return
	end

	Apply(part, tostring(value) == "0")
end, "Замер FPS: aa_perf <telemetry|ui|all> <0|1>", 0)

-- Сводки фризов клиента (panorama perf_monitor.js) -> событие матча "client_perf"
if not AA_PERF_LISTENER then
	AA_PERF_LISTENER = CustomGameEventManager:RegisterListener("aa_client_perf", function(_, data)
		local pid = data and data.PlayerID
		if pid == nil or not MatchTracker or not MatchTracker.Push then return end
		local d = {}
		for _, k in ipairs({ "span", "frames", "fps", "h33", "h50", "h100", "worst" }) do
			d[k] = tonumber(data[k])
		end
		for _, k in ipairs({ "hitches", "nt", "nt_near", "prof", "period" }) do
			if type(data[k]) == "string" then d[k] = string.sub(data[k], 1, 2000) end
		end
		pcall(MatchTracker.Push, MatchTracker, "client_perf", pid, d)
	end)
end

-- ------------------------------------------------------------------
-- Профайлер серверного Lua вне Timers: aa_perf prof <0|1>.
-- Меряет: колбэки ListenToGameEvent, фильтры (урон, приказы, золото, опыт,
-- руны), клиентские custom events (RegisterListener) и методы модификаторов
-- (OnIntervalThink, OnTakeDamage, OnAttackLanded, OnCreated ...).
-- Выключен - обёртки событий/фильтров стоят, но делают одну проверку флага;
-- модификаторы оборачиваются только при включении и разворачиваются обратно.
-- Время - GetSystemTimeMS (debug.* на боевом сервере нет, не использовать).
-- Вывод: раз в минуту топ "[AA.prof]", плюс сразу "[AA.prof] slow" для вызова
-- дольше SLOW_MS.

AAProf = AAProf or { on = false, stats = {}, wrappedMods = {} }

local PROF_SLOW_MS = 4
local PROF_TOP = 12
local PROF_MOD_METHODS = { "OnIntervalThink", "OnTakeDamage", "OnAttackLanded", "OnAttack", "OnAttackStart",
	"OnDeath", "OnAbilityExecuted", "OnAbilityFullyCast", "OnCreated", "OnRefresh", "OnDestroy",
	"OnUnitMoved", "OnOrder", "OnHealReceived", "OnModifierAdded", "OnStackCountChanged" }

local function ProfNow() return GetSystemTimeMS and GetSystemTimeMS() or 0 end

function AAProf:Add(name, ms)
	local st = self.stats[name]
	if not st then st = { ms = 0, n = 0, max = 0 }; self.stats[name] = st end
	st.ms = st.ms + ms
	st.n = st.n + 1
	if ms > st.max then st.max = ms end
	if ms >= PROF_SLOW_MS then
		print(string.format("[AA.prof] slow %.1f ms  %s  (t=%.2f)", ms, name, GameRules and GameRules:GetGameTime() or 0))
	end
end

-- Обёртка, дешёвая при выключенном профайлере
function AAProf.Wrap(name, fn)
	if type(fn) ~= "function" then return fn end
	return function(...)
		if not AAProf.on then return fn(...) end
		local t0 = ProfNow()
		local r1, r2, r3 = fn(...)
		AAProf:Add(name, ProfNow() - t0)
		return r1, r2, r3
	end
end

function AAProf:WrapFilters(mt)
	if not mt or mt._aaProfWrapped then return end
	mt._aaProfWrapped = true
	for _, k in ipairs({ "DamageFilter", "ExecuteOrderFilterCustom", "GoldFilter", "ExperienceFilter", "ModifierRuneSpawn" }) do
		if type(mt[k]) == "function" then mt[k] = AAProf.Wrap("filter " .. k, mt[k]) end
	end
end

-- модификаторы: обходим глобальные классы (только при включении)
function AAProf:WrapModifiers()
	local count = 0
	for gname, cls in pairs(_G) do
		if type(gname) == "string" and type(cls) == "table" and not self.wrappedMods[gname] and gname:sub(1, 5) ~= "CDOTA"
			and (gname:sub(1, 9) == "modifier_" or rawget(cls, "OnIntervalThink")) then
			local saved = {}
			for _, m in ipairs(PROF_MOD_METHODS) do
				local f = rawget(cls, m)
				if type(f) == "function" then
					saved[m] = f
					local label = "mod " .. gname .. ":" .. m
					cls[m] = function(...)
						local t0 = ProfNow()
						local r1, r2, r3 = f(...)
						AAProf:Add(label, ProfNow() - t0)
						return r1, r2, r3
					end
				end
			end
			if next(saved) then
				self.wrappedMods[gname] = saved
				count = count + 1
			end
		end
	end
	return count
end

function AAProf:UnwrapModifiers()
	for gname, saved in pairs(self.wrappedMods) do
		local cls = _G[gname]
		if type(cls) == "table" then
			for m, f in pairs(saved) do cls[m] = f end
		end
	end
	self.wrappedMods = {}
end

function AAProf:Report()
	local list, total = {}, 0
	for name, st in pairs(self.stats) do
		total = total + st.ms
		list[#list + 1] = { name = name, ms = st.ms, n = st.n, max = st.max }
	end
	self.stats = {}
	table.sort(list, function(a, b) return a.ms > b.ms end)
	print(string.format("[AA.prof] за минуту: %.0f ms в событиях/фильтрах/модификаторах, точек %d", total, #list))
	for i = 1, math.min(PROF_TOP, #list) do
		local e = list[i]
		print(string.format("[AA.prof]   %7.1f ms  x%-6d max %5.1f ms  %s", e.ms, e.n, e.max, e.name))
	end
end

function AAProf:SetOn(on)
	self.on = on
	self.stats = {}
	if on then
		local n = self:WrapModifiers()
		print("[AA.prof] вкл, обёрнуто классов модификаторов: " .. n)
		if not self.timerStarted and Timers then
			self.timerStarted = true
			Timers:CreateTimer(60, function()
				if not AAProf.on then AAProf.timerStarted = false return nil end
				AAProf:WrapModifiers() -- подхватить классы, загруженные позже
				AAProf:Report()
				return 60
			end)
		end
	else
		self:UnwrapModifiers()
		print("[AA.prof] выкл")
	end
end

Convars:RegisterCommand("aa_prof", function(_, value)
	if not Allowed() then return end
	if tostring(value) == "report" then AAProf:Report() return end
	AAProf:SetOn(tostring(value) ~= "0")
end, "Профайлер Lua вне таймеров: aa_prof <1|0|report>", 0)
