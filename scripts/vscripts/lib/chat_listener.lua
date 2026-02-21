if ChatListener == nil then
	print('[ChatListener] created ChatListener')
	ChatListener = {}
	ChatListener.__index = ChatListener
end

Commands = Commands or {}

local function safe_require(path)
	local ok, err = pcall(require, path)
	if not ok then
		print('[ChatListener] require failed:', path, err)
	end
	return ok
end

safe_require("lib/chat_commands/cheat_commands")
safe_require("lib/chat_commands/admin_commands")
safe_require("lib/chat_commands/main_commands")

function ChatListener:OnPlayerChat(keys)
	local player_id = keys.playerid
	local player = PlayerResource:GetPlayer(player_id)

	local text = tostring(keys.text or "")
	if text == "" then return end

	local args = {}
	for w in string.gmatch(text, "%S+") do
		args[#args + 1] = w
	end

	local command = args[1]
	if not command then return end
	if command:sub(1, 1) ~= "-" then return end

	table.remove(args, 1)
	local fixed_command = command:sub(2)

	-- безопасный вызов команды
	local fn = Commands and Commands[fixed_command]
	if type(fn) == "function" then
		local ok, err = pcall(fn, Commands, player, args)
		if not ok then
			print('[ChatListener] command failed:', fixed_command, err)
		end
	end
end