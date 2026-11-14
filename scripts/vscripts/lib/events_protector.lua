-- Защита кастомных ивентов между панорамой и сервером
-- (пара к panorama/scripts/custom_game/events_protector.js).
--
-- При загрузке интерфейс шлёт "ok" со своим случайным ключом, сервер отвечает
-- своим. Дальше:
--   клиент -> сервер: в каждом ивенте ключ клиента, без него сервер ивент
--     выбрасывает - фейковый запрос из консоли или чужого скрипта не пройдёт;
--   сервер -> клиент: в каждом ивенте ключ сервера, клиент без него ивент
--     выбрасывает - локально подсунутый ивент (открыть меню и т.п.) не сработает.
--
-- Подключать раньше всех модулей: обёртка действует только на слушателей,
-- зарегистрированных после неё.
--
-- Ивенты движка (game_rules_state_change, player_connect и т.п.) идут мимо,
-- на клиенте их слушают обычным GameEvents.Subscribe.

if not IsServer() then return end
if _G.EventsProtector then return end

-- Только из addon_game_mode.lua: в addon_init.lua CustomGameEventManager ещё nil,
-- а require запоминает модуль, и второй раз он бы уже не выполнился.
if not CustomGameEventManager then
	print("[EventsProtector] CustomGameEventManager is nil, protection NOT enabled")
	return
end

EventsProtector = {
	client_keys = {},
	server_keys = {},
	load_listeners = {},
}

local allow_keys_reload = IsInToolsMode()

local client_keys = EventsProtector.client_keys
local server_keys = EventsProtector.server_keys
local load_listeners = EventsProtector.load_listeners

CustomGameEventManager.RegisterListener_old = CustomGameEventManager.RegisterListener
CustomGameEventManager.Send_ServerToPlayer_old = CustomGameEventManager.Send_ServerToPlayer

-- Переподключившийся игрок грузит интерфейс заново с новым ключом. Старые
-- ключи надо забыть, иначе сервер откажет в новом рукопожатии и у игрока
-- до конца игры не будет работать ни одна панель.
local function ForgetPlayer(playerID)
	if playerID == nil or playerID < 0 then return end

	client_keys[playerID] = nil
	server_keys[playerID] = nil
end

local function PlayerIDFromEvent(data)
	if data.PlayerID ~= nil then return data.PlayerID end
	if data.player_id ~= nil then return data.player_id end
end

-- player_connect_full сюда не берём: при первом входе он может прийти уже
-- после рукопожатия и стёр бы ключи, а клиент второй раз не спросит
for _, name in ipairs({ "player_disconnect", "player_reconnected" }) do
	ListenToGameEvent(name, function(data)
		local ok, playerID = pcall(PlayerIDFromEvent, data)

		if ok then ForgetPlayer(playerID) end
	end, nil)
end

function RegisterLoadListener(listener)
	table.insert(load_listeners, listener)

	for playerID, _ in pairs(server_keys) do
		local player = PlayerResource:GetPlayer(tonumber(playerID))

		if player ~= nil then
			listener(player, playerID)
		end
	end
end

CustomGameEventManager:RegisterListener_old("ok", function(_, data)
	local playerID = data.PlayerID

	if playerID == nil or type(data.n) ~= "number" then
		return
	end

	local player = PlayerResource:GetPlayer(playerID)

	if player == nil then
		return
	end

	local server_key = server_keys[playerID]
	local trigger_load = false

	if server_key ~= nil then
		-- Клиент переспрашивает ключ раз в несколько секунд (так он переживает
		-- сброс ключей при переподключении). Тому же клиенту просто отвечаем
		-- ещё раз. Чужому ключу - отказ, иначе любой получил бы свой ключ из
		-- консоли. Исключение - тулзы, там панорама перезагружается.
		if data.n ~= client_keys[playerID] and not allow_keys_reload then
			return
		end
	else
		server_key = RandomInt(1, 2^30)
		server_keys[playerID] = server_key
		trigger_load = true
	end

	client_keys[playerID] = data.n

	CustomGameEventManager:Send_ServerToPlayer_old(player, "ok", {
		n = data.n,
		k = server_key,
	})

	if trigger_load then
		for _, listener in ipairs(load_listeners) do
			listener(player, playerID)
		end
	end
end)

CustomGameEventManager.RegisterListener = function(self, name, listener)
	return self:RegisterListener_old(name, function(player, data)
		if data.PlayerID == nil or client_keys[data.PlayerID] == nil or data.n ~= client_keys[data.PlayerID] then
			return
		end

		-- ключ дальше не нужен и не должен утечь в обработчики
		data.n = nil

		return listener(player, data)
	end)
end

CustomGameEventManager.Send_ServerToPlayer = function(self, player, name, data)
	if player == nil then
		return
	end

	data = data or {}

	local server_key = server_keys[player:GetPlayerID()]

	if server_key ~= nil then
		data.n = server_key
		self:Send_ServerToPlayer_old(player, name, data)
	end

	data.n = nil
end

CustomGameEventManager.Send_ServerToAllClients = function(self, name, data)
	data = data or {}

	for playerID, server_key in pairs(server_keys) do
		local player = PlayerResource:GetPlayer(tonumber(playerID))

		if player ~= nil then
			data.n = server_key
			self:Send_ServerToPlayer_old(player, name, data)
		end
	end

	data.n = nil
end

CustomGameEventManager.Send_ServerToTeam = function(self, team, name, data)
	data = data or {}

	for playerID, server_key in pairs(server_keys) do
		local player = PlayerResource:GetPlayer(tonumber(playerID))

		if player ~= nil and player:GetTeam() == team then
			data.n = server_key
			self:Send_ServerToPlayer_old(player, name, data)
		end
	end

	data.n = nil
end
