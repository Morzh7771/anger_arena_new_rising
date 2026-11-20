-- Лидер лобби на экране выбора команд (стадия DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP).
--
-- 2026-11-14: лидер - случайный премиум, без премиумов - случайный игрок. Стадия идёт
-- 15 с без остановок (TimerTick), "Начать" сокращает до 5 с; в начале всех раскидывает
-- по командам по рейтингу, по нулю неопределившиеся уходят в команды, где есть место.
--
-- Лидер - всегда случайный подключённый реальный игрок (не бот и не server host), даже
-- если у кого-то есть права хоста. Раньше: игра хостится лобби-ботом, поэтому ни один реальный игрок не имеет прав хоста:
-- некому нажать "Начать", перемешать или распределить игроков. Если настоящего
-- хоста нет, сервер назначает лидера - ему панель показывает три кнопки
-- (panorama/layout/custom_game/team_select.xml). Если хост есть - ничего не меняем,
-- работает ванильная логика.
--
-- Связь с панелью:
--   клиент -> сервер: "lobby_host_report" {host} - один раз при загрузке панели;
--                     "lobby_leader_action" {action} - нажатие кнопки лидера;
--   сервер -> клиенты: CustomNetTables "aa_lobby", ключ "leader" = {pid};
--                      pid = -1, если лидера нет.
--
-- Ивенты идут через защищённый RegisterListener (lib/events_protector.lua),
-- поэтому модуль подключается из addon_game_mode.lua после него.

if not IsServer() then return end
if _G.LobbyLeader then return end

LobbyLeader = {
	leader = nil,            -- pid текущего лидера или nil
	published = nil,         -- последнее значение, записанное в CustomNetTables
	host_reports = {},       -- [pid] = true, если клиент сообщил о правах хоста
	ever_host = false,       -- хоть раз реальный игрок сообщил host=1 (для IsBotHosted)
	mmr_provider = nil,      -- функция(pid) -> число или nil; пока не задана
	setup_elapsed = 0,       -- сколько секунд прошло в стадии выбора команд
	team_locked = false,     -- после "Начать" команды уже не меняем
	last_action_time = {},   -- [pid] = время последнего действия, для лимита 1/с
	-- только для тулзов: считать лобби ботовым даже если хост есть (проверка лидера у себя)
	DEBUG_FORCE = false,
	last_log = nil,          -- последнее напечатанное решение, чтобы не спамить каждый тик
	ticks = 0,               -- сколько раз прошёл тик таймера (видно в диагностике панели)
	deadline = nil,          -- setup_elapsed, на котором стартуем (15 с, после "Начать" - 5 с)
	balanced = false,        -- первичная раскидка по рейтингу уже была
	placed = {},             -- [pid] = true: игрока уже ставили в команду автоматически
	finished = false,
}

local POLL_INTERVAL = 0.5
-- сколько ждём отчёты клиентов о правах хоста, прежде чем назначить лидера
local HOST_CHECK_DELAY = 3
local ACTION_COOLDOWN = 0.25 -- было 1 с: "Отмена" -> "Начать" подряд второе нажатие молча терялось
local COUNTDOWN_SECONDS = 5   -- лидер успевает нажать "Отмена"
-- Общий таймер стадии: идёт всегда, кто вышел или не выбрал команду - не останавливает.
-- По нулю неопределившиеся раскидываются по командам, где есть место, и игра стартует.
local SETUP_SECONDS = 15 -- обязательные 15 с после раскидки, "Начать" - 5 с (владелец 2026-11-16)
-- Раскидка по рейтингу: рейтинг запрашивается ещё на загрузке (lib/match_tracker.lua,
-- LobbyLookupTick), поэтому обычно раскидываем в первый же тик стадии. Если бэкенд
-- тормозит - ждём не дольше BALANCE_AT секунд и раскидываем с тем, что есть.
local BALANCE_AT = 2

-- команды, которые могут быть на карте; реально используемые отбираем по максимуму игроков
local CANDIDATE_TEAMS = {
	DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS,
	DOTA_TEAM_CUSTOM_1, DOTA_TEAM_CUSTOM_2, DOTA_TEAM_CUSTOM_3, DOTA_TEAM_CUSTOM_4,
	DOTA_TEAM_CUSTOM_5, DOTA_TEAM_CUSTOM_6, DOTA_TEAM_CUSTOM_7, DOTA_TEAM_CUSTOM_8,
}

---------------------------------------------------------------------
-- Вспомогательные функции
---------------------------------------------------------------------

-- Лобби-бот и его имя не считаем реальным игроком.
-- Раньше шаблон был "^server%-host" (только дефис): имя "Server host" с пробелом
-- проходило как реальный игрок и могло получить звезду лидера.
local function IsBotName(name)
	if name == nil then return true end

	local lower = string.lower(name)

	return lower == "bot" or string.find(lower, "^server[ %-_]?host") ~= nil
end

-- Лог решения: печатаем только при изменении, иначе каждые 0.5 с спам
function LobbyLeader:Log(msg)
	if msg == self.last_log then return end

	self.last_log = msg
	print("[LobbyLeader] " .. msg)
end

local function ShuffleList(list)
	for i = #list, 2, -1 do
		local j = RandomInt(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

-- Команда с наименьшим числом игроков, где ещё есть место; при равенстве - случайная
local function PlaceLeastLoaded(teams, counts, max)
	local candidates = {}
	local best_count = math.huge

	for _, team in ipairs(teams) do
		if counts[team] < max[team] then
			if counts[team] < best_count then
				best_count = counts[team]
				candidates = { team }
			elseif counts[team] == best_count then
				table.insert(candidates, team)
			end
		end
	end

	if #candidates == 0 then return nil end

	return candidates[RandomInt(1, #candidates)]
end

---------------------------------------------------------------------
-- Игроки и команды
---------------------------------------------------------------------

function LobbyLeader:IsRealPlayer(pid)
	if pid == nil or pid < 0 or not PlayerResource:IsValidPlayerID(pid) then
		return false
	end

	if PlayerResource:GetConnectionState(pid) ~= DOTA_CONNECTION_STATE_CONNECTED then
		return false
	end

	return not IsBotName(PlayerResource:GetPlayerName(pid))
end

function LobbyLeader:GetRealPlayers()
	local result = {}

	for pid = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if self:IsRealPlayer(pid) then
			table.insert(result, pid)
		end
	end

	return result
end

-- Серверная проверка прав хоста: GameRules:PlayerHasCustomGameHostPrivileges по всем
-- подключённым реальным игрокам. Клиент подделать её не может.
-- Возвращает true/false, или nil, если API нет или вызов упал (тогда - отчёты клиентов).
function LobbyLeader:ServerHostCheck()
	if self.host_api == nil then
		local f = nil

		pcall(function() f = GameRules.PlayerHasCustomGameHostPrivileges end)

		self.host_api = (type(f) == "function")
	end

	if not self.host_api then return nil end

	for _, pid in ipairs(self:GetRealPlayers()) do
		local ok, v = pcall(function()
			return GameRules:PlayerHasCustomGameHostPrivileges(PlayerResource:GetPlayer(pid))
		end)

		if not ok then return nil end
		if v then return true end
	end

	return false
end

-- "server" - права проверяет сервер, "client" - по отчётам панелей
function LobbyLeader:HostCheckMode()
	if self:ServerHostCheck() ~= nil then return "server" end

	return "client"
end

-- Игру хостит лобби-бот: ни один реальный игрок не имеет прав хоста.
-- Если серверного API нет, то никто не сообщил host=1 (отчёты клиентов).
-- Флаг липкий: раз хост был, игра не считается ботовой.
function LobbyLeader:IsBotHosted()
	if self:ServerHostCheck() == true then self.ever_host = true end

	return not self.ever_host
end

-- Есть ли хост: сервер (если API есть), иначе отчёты клиентов
function LobbyLeader:HasRealHost()
	-- тестовый режим в тулзах: делаем вид, что хоста нет
	if self.DEBUG_FORCE and IsInToolsMode() then
		return false
	end

	local server = self:ServerHostCheck()

	if server ~= nil then return server end

	for _, pid in ipairs(self:GetRealPlayers()) do
		if self.host_reports[pid] then
			return true
		end
	end

	return false
end

-- Что видит сервер: пишем в CustomNetTables "aa_lobby" ключ "dbg". Клиентская панель
-- печатает это через $.Msg в свой console.log, так что решение на Valve-сервере
-- видно локально, без серверных логов.
function LobbyLeader:PublishDebug(info)
	-- пишем только когда что-то поменялось (счётчики тиков не в подписи)
	local parts = { tostring(info.state), tostring(info.host_check), tostring(info.host_real), tostring(info.leader) }

	for pid, name in pairs(info.players) do
		parts[#parts + 1] = pid .. "=" .. name
	end

	table.sort(parts)

	local sig = table.concat(parts, "|")

	if sig == self.last_dbg_sig then return end

	self.last_dbg_sig = sig

	local ok = pcall(function()
		CustomNetTables:SetTableValue("aa_lobby", "dbg", info)
	end)

	if not ok then
		print("[LobbyLeader] CustomNetTables dbg: SetTableValue failed")
	end
end

-- Команды, у которых на карте задан максимум игроков
function LobbyLeader:GetMapTeams()
	local teams = {}

	for _, team in ipairs(CANDIDATE_TEAMS) do
		if GameRules:GetCustomGameTeamMaxPlayers(team) > 0 then
			table.insert(teams, team)
		end
	end

	return teams
end

function LobbyLeader:GetMaxPlayers(teams)
	local max = {}

	for _, team in ipairs(teams) do
		max[team] = GameRules:GetCustomGameTeamMaxPlayers(team)
	end

	return max
end

-- Сколько игроков уже сидит в командах карты, не считая тех, кого переставляем.
-- Отключившиеся тоже занимают место, их не трогаем.
function LobbyLeader:CountFixed(teams, moving)
	local counts = {}

	for _, team in ipairs(teams) do
		counts[team] = 0
	end

	for pid = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(pid) and not moving[pid] then
			local team = PlayerResource:GetTeam(pid)

			if counts[team] ~= nil then
				counts[team] = counts[team] + 1
			end
		end
	end

	return counts
end

---------------------------------------------------------------------
-- Лидер
---------------------------------------------------------------------

-- Премиум тянется с бэкенда асинхронно (CosmeticsCore), поэтому не кэшируем
function LobbyLeader:IsPremium(pid)
	if CosmeticsCore == nil or type(CosmeticsCore.IsPremium) ~= "function" then return false end

	local ok, v = pcall(CosmeticsCore.IsPremium, CosmeticsCore, pid)

	return ok and v == true
end

function LobbyLeader:SetMMRProvider(fn)
	self.mmr_provider = fn
end

-- С MMR - самый высокий, без него или если данных нет - случайный из подключённых
function LobbyLeader:PickLeader(candidates)
	if #candidates == 0 then return nil end

	-- 2026-11-14: лидером в первую очередь премиум, если их несколько - случайный из них
	local prem = {}

	for _, pid in ipairs(candidates) do
		if self:IsPremium(pid) then table.insert(prem, pid) end
	end

	if #prem > 0 then return prem[RandomInt(1, #prem)] end

	-- 2026-11-12: лидер всегда случайный (владелец). Выбор по MMR выключен.
	if false and self.mmr_provider then
		local best_pid = nil
		local best_mmr = nil

		for _, pid in ipairs(candidates) do
			local ok, mmr = pcall(self.mmr_provider, pid)

			if ok and type(mmr) == "number" and (best_mmr == nil or mmr > best_mmr) then
				best_pid = pid
				best_mmr = mmr
			end
		end

		if best_pid ~= nil then return best_pid end
	end

	return candidates[RandomInt(1, #candidates)]
end

function LobbyLeader:Publish()
	local pid = self.leader or -1

	if self.published == pid then return end

	self.published = pid
	CustomNetTables:SetTableValue("aa_lobby", "leader", { pid = pid })
end

-- Диагностика для клиента: кто реальный, кто хост, кто лидер
function LobbyLeader:DebugSnapshot(host_real)
	local names = {}
	local hostflags = {}

	for pid = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(pid) then
			names[tostring(pid)] = tostring(PlayerResource:GetPlayerName(pid))
				.. (self:IsRealPlayer(pid) and " [real]" or " [skip]")
			hostflags[tostring(pid)] = self.host_reports[pid] and 1 or 0
		end
	end

	return {
		state = GameRules:State_Get(),
		host_api = self.host_api and 1 or 0,
		host_check = tostring(self:ServerHostCheck()),
		host_real = host_real and 1 or 0,
		debug_force = self.DEBUG_FORCE and 1 or 0,
		leader = self.leader or -1,
		setup_elapsed = math.floor(self.setup_elapsed),
		ticks = self.ticks,
		players = names,
		client_host = hostflags,
	}
end

-- Пересчитывает лидера. Вызывается по таймеру и при каждом отчёте клиента.
function LobbyLeader:Refresh()
	if self.team_locked then return end
	if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then return end

	-- лидер ушёл с сервера - выбираем заново
	if self.leader ~= nil and not self:IsRealPlayer(self.leader) then
		self.leader = nil
		self:Log("лидер вышел с сервера, выбираем заново")
	end

	local host_real = self:HasRealHost()

	-- 2026-11-12: лидер ВСЕГДА случайный подключённый игрок, есть настоящий хост или нет
	-- (server host - бот по имени, лидером не станет, см. IsBotName).
	-- Права хоста больше ничего не решают, HasRealHost остаётся только для диагностики.
	if self.leader == nil and self.setup_elapsed < 1 then
		self:PublishDebug(self:DebugSnapshot(host_real))
		return
	end

	-- премиум подтянулся позже, а лидер без премиума - отдаём лидерство премиуму
	if self.leader ~= nil and not self:IsPremium(self.leader) then
		for _, pid in ipairs(self:GetRealPlayers()) do
			if self:IsPremium(pid) then
				self:Log("лидер без премиума, а премиум в лобби есть - выбираем заново")
				self.leader = nil
				break
			end
		end
	end

	if self.leader == nil then
		self.leader = self:PickLeader(self:GetRealPlayers())

		if self.leader ~= nil then
			self:Log(string.format("лидер pid=%d (%s), режим проверки: %s",
				self.leader, tostring(PlayerResource:GetPlayerName(self.leader)), self:HostCheckMode()))
		else
			self:Log("бот-хост, но реальных подключённых игроков нет - лидера нет")
		end
	end

	self:Publish()
	self:PublishDebug(self:DebugSnapshot(false))
end

-- Тик таймера: в стадии выбора команд пересчитываем лидера, после неё - гасим
local function LobbyLeaderTick()
	local state = GameRules:State_Get()

	if state > DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
		if LobbyLeader.leader ~= nil then
			LobbyLeader.leader = nil
			LobbyLeader:Publish()
		end

		return nil
	end

	if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
		-- Время стадии - по настоящим часам, а не "+0.5 за вызов". lib/timers.lua после подвисания
		-- сервера (загрузка игроков, прекеш на выделенном сервере) догоняет пропущенное -
		-- вызывает таймер каждый кадр подряд, и "+0.5" за вызов съедало все 15 с за доли
		-- секунды: в настоящем лобби игра стартовала моментально, в тулзах - нет (2026-11-16).
		local now = Time()

		if not LobbyLeader.setup_started then LobbyLeader.setup_started = now end

		LobbyLeader.setup_elapsed = now - LobbyLeader.setup_started
		LobbyLeader.ticks = LobbyLeader.ticks + 1
		LobbyLeader:Refresh()
		pcall(LobbyLeader.TimerTick, LobbyLeader)
	end

	return POLL_INTERVAL
end

---------------------------------------------------------------------
-- Действия лидера
---------------------------------------------------------------------

-- Неопределившихся раскладываем в команды с наименьшим числом игроков
function LobbyLeader:AssignUnassigned()
	local teams = self:GetMapTeams()
	local max = self:GetMaxPlayers(teams)

	local movers = {}
	local moving = {}

	for _, pid in ipairs(self:GetRealPlayers()) do
		if PlayerResource:GetTeam(pid) == DOTA_TEAM_NOTEAM then
			table.insert(movers, pid)
			moving[pid] = true
		end
	end

	-- через раскидку блоками: пати уже в команде - к своим, остальные туда, где меньше
	-- игроков / ниже рейтинг (BalanceByRating с only)
	if #movers > 0 then self:BalanceByRating(movers) end
end

---------------------------------------------------------------------
-- Пати (2026-11-14): игроки одной пати всегда играют вместе, независимо от рейтинга.
-- В раскидках по рейтингу при входе, опоздавших и неопределившихся по таймеру ("Перемешать" - нет)
-- двигаем не игроков, а блоки: пати целиком или одиночка.
---------------------------------------------------------------------

-- id пати игрока или nil (без пати). GetPartyID - 64-битное, сравниваем строкой.
local function PartyKey(pid)
	local ok, id = pcall(function() return PlayerResource:GetPartyID(pid) end)

	if not ok or id == nil then return nil end

	local key = tostring(id)

	if key == "0" or key == "" or key == "nil" then return nil end

	return key
end

-- список игроков -> блоки { pids = {...}, party = key|nil }
local function MakeBlocks(pids)
	local blocks = {}
	local byParty = {}

	for _, pid in ipairs(pids) do
		local key = PartyKey(pid)

		if key and byParty[key] then
			table.insert(byParty[key].pids, pid)
		else
			local b = { pids = { pid }, party = key }

			if key then byParty[key] = b end

			table.insert(blocks, b)
		end
	end

	return blocks
end

-- Команда, где уже сидит кто-то из пати этого блока (из тех, кого не двигаем)
function LobbyLeader:PartyTeam(block, moving)
	if not block.party then return nil end

	for _, pid in ipairs(self:GetRealPlayers()) do
		if not moving[pid] and PartyKey(pid) == block.party then
			local team = PlayerResource:GetTeam(pid)

			if team ~= DOTA_TEAM_NOTEAM then return team end
		end
	end

	return nil
end

-- Ставит блок в команду; пати не влезает целиком нигде - раскладываем по одному
function LobbyLeader:PlaceBlock(block, team, counts, sums, mmr)
	for _, pid in ipairs(block.pids) do
		PlayerResource:SetCustomTeamAssignment(pid, team)
		counts[team] = counts[team] + 1

		if sums then sums[team] = sums[team] + (mmr[pid] or 0) end

		self.placed[pid] = true
	end
end

-- Лучшая команда для блока: влезает целиком, меньше игроков, при равенстве меньше сумма MMR
local function BestTeam(teams, counts, max, sums, size)
	local best = nil

	for _, team in ipairs(teams) do
		if counts[team] + size <= max[team] then
			if best == nil or counts[team] < counts[best]
				or (sums and counts[team] == counts[best] and sums[team] < sums[best]) then
				best = team
			end
		end
	end

	return best
end

-- Пати не влезает целиком ни в одну команду (6 человек при командах по 5): кладём сколько
-- влезет в команду с наибольшим числом свободных мест, остаток - так же в следующую.
-- Так пати остаётся максимально вместе, а не расходится по одному.
function LobbyLeader:PlaceSplit(block, teams, counts, max, sums, mmr)
	local rest = {}

	for _, pid in ipairs(block.pids) do table.insert(rest, pid) end

	while #rest > 0 do
		local best, bestFree = nil, 0

		for _, team in ipairs(teams) do
			local free = max[team] - counts[team]

			if free > bestFree then best, bestFree = team, free end
		end

		if not best then break end

		local part = {}

		for _ = 1, math.min(bestFree, #rest) do table.insert(part, table.remove(rest, 1)) end

		self:PlaceBlock({ pids = part }, best, counts, sums, mmr or {})
	end
end

-- Перемешивает всех подключённых по командам карты с учётом максимума. Просто случайно:
-- пати и рейтинг тут НЕ учитываются (так задумано владельцем) - их держит только
-- автораскидка при входе (BalanceByRating).
function LobbyLeader:Shuffle()
	local teams = self:GetMapTeams()
	local max = self:GetMaxPlayers(teams)

	local movers = self:GetRealPlayers()
	local moving = {}

	for _, pid in ipairs(movers) do
		moving[pid] = true
	end

	local counts = self:CountFixed(teams, moving)

	ShuffleList(movers)

	for _, pid in ipairs(movers) do
		local team = PlaceLeastLoaded(teams, counts, max) or DOTA_TEAM_NOTEAM

		PlayerResource:SetCustomTeamAssignment(pid, team)

		if team ~= DOTA_TEAM_NOTEAM then
			counts[team] = counts[team] + 1
		end
	end
end

-- Раскидывает всех подключённых по командам так, чтобы средний MMR был близок.
-- Двигаем блоки (пати целиком или одиночка): крупные первыми, дальше по убыванию суммы MMR;
-- каждый блок - в команду, где меньше игроков, при равенстве - где сумма MMR меньше.
-- Нет рейтинга - считаем средним по известным (или 1000).
-- only - список опоздавших: ставим только их, остальных не трогаем; если их пати уже
-- сидит в команде - туда же.
function LobbyLeader:BalanceByRating(only)
	local teams = self:GetMapTeams()
	local max = self:GetMaxPlayers(teams)
	local movers = only or self:GetRealPlayers()
	local moving = {}
	local mmr = {}
	local known, sum = 0, 0

	for _, pid in ipairs(movers) do
		moving[pid] = true

		local ok, v = false, nil

		if self.mmr_provider then ok, v = pcall(self.mmr_provider, pid) end

		if ok and type(v) == "number" then
			mmr[pid] = v
			known = known + 1
			sum = sum + v
		end
	end

	local avg = known > 0 and sum / known or 1000

	for _, pid in ipairs(movers) do
		if mmr[pid] == nil then mmr[pid] = avg end
	end

	local counts = self:CountFixed(teams, moving)
	local sums = {}

	for _, team in ipairs(teams) do sums[team] = 0 end

	-- уже сидящие в командах тоже весят (важно для опоздавших)
	for _, pid in ipairs(self:GetRealPlayers()) do
		local team = PlayerResource:GetTeam(pid)

		if not moving[pid] and sums[team] ~= nil then
			local ok, v = false, nil

			if self.mmr_provider then ok, v = pcall(self.mmr_provider, pid) end

			sums[team] = sums[team] + ((ok and type(v) == "number") and v or avg)
		end
	end

	local blocks = MakeBlocks(movers)

	for _, b in ipairs(blocks) do
		b.mmr = 0

		for _, pid in ipairs(b.pids) do b.mmr = b.mmr + mmr[pid] end
	end

	ShuffleList(blocks) -- равные - в случайном порядке
	table.sort(blocks, function(x, y)
		if #x.pids ~= #y.pids then return #x.pids > #y.pids end

		return x.mmr > y.mmr
	end)

	local parties = 0

	for _, block in ipairs(blocks) do
		if #block.pids > 1 then parties = parties + 1 end

		-- пати уже есть в команде (опоздавший из пати) - к своим, если есть место
		local team = self:PartyTeam(block, moving)

		if team and counts[team] ~= nil and counts[team] + #block.pids > max[team] then team = nil end

		team = team or BestTeam(teams, counts, max, sums, #block.pids)

		if team then
			self:PlaceBlock(block, team, counts, sums, mmr)
		else
			-- пати не влезает целиком ни в одну команду - сколько влезет вместе
			self:PlaceSplit(block, teams, counts, max, sums, mmr)
		end
	end

	self:Log(string.format("раскидка по рейтингу: %d игроков, пати %d, рейтинг известен у %d", #movers, parties, known))
end

-- У всех подключённых рейтинг уже есть (или бэкенд ответил, что его нет)
function LobbyLeader:RatingsKnown()
	if not self.mmr_provider then return false end

	for _, pid in ipairs(self:GetRealPlayers()) do
		local ok, v = pcall(self.mmr_provider, pid)

		if not (ok and type(v) == "number") and not (AATrackerLobbyLooked and AATrackerLobbyLooked(pid)) then
			return false
		end
	end

	return true
end

-- Ответ бэкенда с рейтингом (зовёт lib/match_tracker.lua): раскидка без ожидания тика
function LobbyLeader:OnRatingsArrived()
	if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then return end

	self:Refresh() -- заодно премиум-лидер
	self:TryBalance()
end

function LobbyLeader:TryBalance()
	if self.finished or self.team_locked then return end
	-- таймер стадии ещё не выставлен движку - рано (см. TimerTick)
	if self.pushed == nil then return end

	if not self.balanced then
		if self.setup_elapsed >= BALANCE_AT or self:RatingsKnown() then
			self.balanced = true
			self:BalanceByRating()

			-- обязательные SETUP_SECONDS считаем от раскидки, а не от входа в стадию
			if self.deadline ~= false then self.deadline = self.setup_elapsed + SETUP_SECONDS end
		end

		return
	end

	-- опоздавшие: подключились после раскидки - сразу в команду по рейтингу
	local late = {}

	for _, pid in ipairs(self:GetRealPlayers()) do
		if not self.placed[pid] and PlayerResource:GetTeam(pid) == DOTA_TEAM_NOTEAM then
			table.insert(late, pid)
		end
	end

	if #late > 0 then self:BalanceByRating(late) end
end

-- Общий таймер стадии (раз в POLL_INTERVAL): первичная раскидка, обратный отсчёт в UI,
-- по нулю - неопределившихся в команды и старт. Ничто его не останавливает.
function LobbyLeader:TimerTick()
	if self.finished then return end

	if self.deadline == nil then self.deadline = SETUP_SECONDS end

	-- раскидка - ПОСЛЕ того, как движку выставлен таймер (ниже): иначе при полном лобби
	-- все сразу оказывались в командах, а своего срока у движка ещё не было - он стартовал
	-- игру за секунду (2026-11-15)
	if self.pushed ~= nil then self:TryBalance() end

	-- Таймер ведёт ТОЛЬКО сервер, движку время отдаём лишь когда наш срок поменялся
	-- (старт стадии, "Начать", "Отмена"). Раньше писали каждые 0.5 с, а ванильные кнопки
	-- хоста в team_select.js ставили своё (4 с / выкл) - цифры на экране прыгали 10 -> 7 -> 3.
	-- Плюс раз в целую секунду переотправляем остаток: движок сам тормозит свой отсчёт, когда
	-- игроки скачут по командам/в неопределившиеся, а наш срок идёт ровно. Значение то же, что
	-- должно быть на экране, поэтому цифра не прыгает.
	local sec = self.deadline ~= false and math.max(1, math.ceil(self.deadline - self.setup_elapsed)) or -1

	if self.deadline ~= self.pushed or sec ~= self.pushedSec then
		self.pushed = self.deadline
		self.pushedSec = sec
		GameRules:SetCustomGameSetupRemainingTime(sec)
	end

	-- "Отмена": отсчёт выключен до следующего "Начать"
	if self.deadline == false then return end

	if self.deadline - self.setup_elapsed <= 0 then
		self.finished = true
		self:AssignUnassigned()
		GameRules:LockCustomGameSetupTeamAssignment(true)
		GameRules:FinishCustomGameSetup()
	end
end

-- Отмена старта лидером
function LobbyLeader:Unlock()
	self.team_locked = false

	GameRules:LockCustomGameSetupTeamAssignment(false)
	-- отмена выключает отсчёт совсем, до следующего "Начать" (движку отдаст TimerTick)
	self.deadline = false
	self:TimerTick()
	CustomNetTables:SetTableValue("aa_lobby", "locked", { v = 0 })
end

-- Блокирует смену команд и запускает обратный отсчёт до старта игры
function LobbyLeader:LockAndCountdown()
	self.team_locked = true

	GameRules:LockCustomGameSetupTeamAssignment(true)
	-- "Начать": до старта ровно COUNTDOWN_SECONDS (движку отдаст TimerTick сразу)
	self.deadline = self.setup_elapsed + COUNTDOWN_SECONDS
	self:TimerTick()
	CustomNetTables:SetTableValue("aa_lobby", "locked", { v = 1 })
end

---------------------------------------------------------------------
-- Обработчики ивентов панели
---------------------------------------------------------------------

function LobbyLeader:OnHostReport(data)
	local pid = data.PlayerID

	if pid == nil or not PlayerResource:IsValidPlayerID(pid) then return end

	self.host_reports[pid] = (data.host == 1)

	-- при серверной проверке отчёт клиента не решает: флаг ставит сервер (IsBotHosted)
	if self.host_reports[pid] and self:IsRealPlayer(pid) and self:ServerHostCheck() == nil then
		self.ever_host = true
	end
	self:Refresh()
end

function LobbyLeader:OnLeaderAction(data)
	local pid = data.PlayerID

	self:Log(string.format("действие %s от pid=%s, лидер=%s, locked=%s", tostring(data.action), tostring(pid), tostring(self.leader), tostring(self.team_locked)))

	-- действие принимаем от текущего лидера или от хоста лобби (ванильные кнопки хоста
	-- в team_select.js теперь тоже идут сюда, а не ставят время сами)
	local isHost = false

	if pid ~= nil then
		pcall(function() isHost = GameRules:PlayerHasCustomGameHostPrivileges(PlayerResource:GetPlayer(pid)) == true end)
	end

	if pid == nil or not (isHost or (self.leader ~= nil and pid == self.leader)) then return end

	local now = Time()

	if self.last_action_time[pid] ~= nil and now - self.last_action_time[pid] < ACTION_COOLDOWN then
		return
	end

	self.last_action_time[pid] = now

	if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then return end

	local action = data.action

	-- отмена старта: снимаем блокировку и останавливаем отсчёт (у лидера раньше отмены не было)
	if action == "cancel" then
		if self.team_locked then self:Unlock() end

		return
	end

	if self.team_locked then return end

	if action == "start" then
		self:AssignUnassigned()
		self:LockAndCountdown()
	elseif action == "shuffle" then
		self:Shuffle()
	elseif action == "assign" then
		self:AssignUnassigned()
	end
end

---------------------------------------------------------------------
-- Запуск
---------------------------------------------------------------------

-- Таймер на реальном времени: игровое время в стадии выбора команд может не идти
-- Свой автостарт движка - заведомо позже нашего срока: стадию заканчивает TimerTick
-- (FinishCustomGameSetup). Без этого при полном лобби (все сразу в командах) движок
-- запускал игру через секунду, не дав хосту ни перемешать, ни отменить.
pcall(function()
	GameRules:SetCustomGameSetupAutoLaunchDelay(SETUP_SECONDS + 30)
	GameRules:SetCustomGameSetupRemainingTime(SETUP_SECONDS + 30)
end)

Timers:CreateTimer({
	endTime = POLL_INTERVAL,
	useGameTime = false,
	callback = LobbyLeaderTick,
})

CustomGameEventManager:RegisterListener("lobby_host_report", function(_, data)
	LobbyLeader:OnHostReport(data)
end)

CustomGameEventManager:RegisterListener("lobby_leader_action", function(_, data)
	LobbyLeader:OnLeaderAction(data)
end)
