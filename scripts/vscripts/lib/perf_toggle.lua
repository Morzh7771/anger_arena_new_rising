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
