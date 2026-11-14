-- Настоящее время респавна боссов для премиум-игроков (2026-11-12).
-- Всем видна только серая дуга с "окном" респавна (CampRespawnRing); точное время знает сервер.
-- Шлём его ТОЛЬКО премиумам событием (не нет-таблицей - её читают все клиенты):
--   сервер -> клиент  aa_boss_timer { name, x, y, z, at }   at - GameTime появления, -1 = стоит/сброс
--   клиент -> сервер  aa_boss_timer_req {}                  перезагрузка UI / переподключение
-- Клиент (panorama boss_timers.js) по Alt рисует над точкой "через m:ss".

if not IsServer() then return end
if AABossTimers ~= nil then return end

AABossTimers = { list = {} }   -- name -> { x, y, z, at }

local T = AABossTimers

local function IsPremium(pid)
	return CosmeticsCore ~= nil and CosmeticsCore.IsPremium ~= nil and CosmeticsCore:IsPremium(pid)
end

local function SendOne(pid, name, e)
	local player = PlayerResource:GetPlayer(pid)

	if player and IsPremium(pid) then
		CustomGameEventManager:Send_ServerToPlayer(player, "aa_boss_timer", { name = name, x = e.x, y = e.y, z = e.z, at = e.at })
	end
end

local function Broadcast(name)
	local e = T.list[name]

	for pid = 0, 23 do
		if PlayerResource:IsValidPlayerID(pid) then SendOne(pid, name, e) end
	end
end

-- boss_spawner.lua: босс появится через delay секунд в точке point
function T:Scheduled(name, point, delay)
	self.list[name] = { x = point.x, y = point.y, z = point.z, at = GameRules:GetGameTime() + delay }
	Broadcast(name)
end

-- босс встал
function T:Spawned(name)
	local e = self.list[name]

	if not e then return end

	e.at = -1
	Broadcast(name)
end

CustomGameEventManager:RegisterListener("aa_boss_timer_req", function(_, data)
	local pid = data and data.PlayerID

	if pid == nil then return end

	for name, e in pairs(T.list) do SendOne(pid, name, e) end
end)

return T
