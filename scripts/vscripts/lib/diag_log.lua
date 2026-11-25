-- Диагностика в console.log: чтобы после лагов и крашей было что читать.
--
-- Лог пишет сама дота, если запускать с -condebug. Параметр -conclearlog
-- из запуска надо убрать: он стирает лог при каждом старте, и после краша
-- от упавшей сессии не остаётся ничего.
--
-- Что пишем, все строки с префиксом [AA.<тег> <игровое время>]:
--   [AA.state]    - смена стадии игры;
--   [AA.particle] - первое использование каждой частицы из Lua. Если дальше
--                   движок пишет "Attempting to use invalid particle", виновник -
--                   последняя новая частица перед этой строкой;
--   [AA.perf]     - раз в минуту: таймеры, сущности, память Lua, медленные
--                   кадры и какие таймеры (по месту создания) съели больше всего.
--
-- Частицы из KV (эффекты модификаторов, KV-способности) мимо Lua не идут и
-- сюда не попадают.

DiagLog = DiagLog or {}
DiagLog._orig = DiagLog._orig or {}

local SUMMARY_INTERVAL = 60
local TOP_TIMERS = 6

local seenParticles = {}
local newParticles = 0

local function Stamp()
	local t = 0

	if GameRules and GameRules.GetDOTATime then
		t = GameRules:GetDOTATime(false, true)
	end

	local sign = t < 0 and "-" or ""

	t = math.abs(t)

	return string.format("%s%02d:%02d", sign, math.floor(t / 60), math.floor(t % 60))
end

function DiagLog:Print(tag, fmt, ...)
	print(string.format("[AA.%s %s] ", tag, Stamp()) .. string.format(fmt, ...))
end

-- ------------------------------------------------------------ частицы

local function WrapParticleMethod(method)
	local orig = DiagLog._orig[method] or ParticleManager[method]

	if type(orig) ~= "function" then return false end

	DiagLog._orig[method] = orig

	ParticleManager[method] = function(self, name, ...)
		if name and not seenParticles[name] then
			seenParticles[name] = true
			newParticles = newParticles + 1
			DiagLog:Print("particle", "первый раз: %s", tostring(name))
		end

		return orig(self, name, ...)
	end

	return true
end

local function WrapParticles()
	local methods = { "CreateParticle", "CreateParticleForTeam", "CreateParticleForPlayer" }

	for _, method in ipairs(methods) do
		local ok, res = pcall(WrapParticleMethod, method)

		if not ok or not res then
			print("[AA.diag] не удалось обернуть ParticleManager." .. method .. ": " .. tostring(res))
		end
	end
end

-- ------------------------------------------------------------ сводка

local function CountTable(t)
	local n = 0

	for _ in pairs(t or {}) do n = n + 1 end

	return n
end

local function CountEntities()
	local n = 0
	local ent = Entities:First()

	while ent do
		n = n + 1
		ent = Entities:Next(ent)
	end

	return n
end

local function CountClass(classname)
	return #Entities:FindAllByClassname(classname)
end

function DiagLog:Summary()
	local stats = Timers._stats or {}
	local slowFrames = Timers._slowFrames or 0
	local slowMs = Timers._slowMs or 0

	Timers._stats = {}
	Timers._slowFrames = 0
	Timers._slowMs = 0

	local total = 0
	local list = {}

	for src, st in pairs(stats) do
		total = total + st.ms
		list[#list + 1] = { src = src, ms = st.ms, n = st.n, max = st.max }
	end

	table.sort(list, function(a, b) return a.ms > b.ms end)

	self:Print("perf", "таймеров %d | сущностей %d (нейтралов %d, предметов на земле %d) | Lua %.1f MB | новых частиц %d",
		CountTable(Timers.timers),
		CountEntities(),
		CountClass("npc_dota_creep_neutral"),
		CountClass("dota_item_drop"),
		collectgarbage("count") / 1024,
		newParticles)

	if CampSleep and CampSleep.GetHibernatedStats then
		local hibCamps, hibUnits = CampSleep:GetHibernatedStats()

		self:Print("perf", "спрятано лагерей %d, крипов в них %d", hibCamps, hibUnits)
	end

	-- проверка общего слушателя замахов (modifiers/modifier_aa_creep_telegraph.lua):
	-- хабов должно быть 1, замахи и докасты растут вместе
	if TelegraphHub and TelegraphHub.stats then
		local t = TelegraphHub.stats
		self:Print("perf", "замахи крипов: хабов %d, событий %d, замахов %d, докастов %d, сорвано %d",
			t.hubs, t.events, t.windups, t.recasts, t.cancels)
	end

	self:Print("perf", "колбэки таймеров за минуту: %.0f ms | медленных кадров (>%.0f ms): %d, в сумме %.0f ms",
		total, Timers._timeLimit or 0, slowFrames, slowMs)

	for i = 1, math.min(TOP_TIMERS, #list) do
		local e = list[i]

		self:Print("perf", "  %6.1f ms  x%-5d max %5.1f ms  %s", e.ms, e.n, e.max, e.src)
	end

	newParticles = 0
end

-- ------------------------------------------------------------ запуск

local function OnStateChange()
	DiagLog:Print("state", "%d", GameRules:State_Get())
end

if not DiagLog._started then
	DiagLog._started = true

	print(string.format("[AA.diag] сессия %s %s, tools=%s",
		GetSystemDate and GetSystemDate() or "?",
		GetSystemTime and GetSystemTime() or "?",
		tostring(IsInToolsMode())))

	ListenToGameEvent("game_rules_state_change", OnStateChange, nil)

	Timers:CreateTimer({
		useGameTime = false,
		endTime = SUMMARY_INTERVAL,
		callback = function()
			local ok, err = pcall(DiagLog.Summary, DiagLog)

			if not ok then print("[AA.diag] сводка упала: " .. tostring(err)) end

			return SUMMARY_INTERVAL
		end,
	})
end

WrapParticles()
