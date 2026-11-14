require('lib/message_formatters')

GameEnder = GameEnder or class({})

local TIME_TO_END 		  = 30
local END_MESSAGE 		  = "#game_ends_on_30_sec"
local END_MINIMAP_MESSAGE = "#game_ends_on_time"

function GameEnder:_OnEnd(team)
	-- телеметрия: итог матча уходит первым делом, чтобы ошибка ниже его не съела
	-- (lib/match_tracker.lua, только наблюдение)
	if MatchTracker then
		local ok, err = pcall(MatchTracker.OnGameEnd, MatchTracker, team)
		if not ok then print("[GameEnder] tracker: " .. tostring(err)) end
	end

	if team == DOTA_TEAM_GOODGUYS then
	GameRules:SetCustomVictoryMessage("#aa_on_win_radiant_message")
	end 
	if team == DOTA_TEAM_BADGUYS then
		GameRules:SetCustomVictoryMessage("#aa_on_win_dire_message")
	end

	-- финальный экран читает статистику, как только движок объявит
	-- победителя, поэтому публикуем её до SetGameWinner
	if EndGameStats then EndGameStats:Finalize(team) end


	GameRules:SetGameWinner(team)
end

function GameEnder:ForceEnd(iTeamNumber)
	local timer = self.endTimer

	if timer then
		Timers:RemoveTimer(timer)
		self.endTimer = nil
	end

	self:_OnEnd(iTeamNumber)
end

function GameEnder:StartGameEnd(iTeamNumber)
	Attentions:SendAttentionText(END_MESSAGE, 10, 2)

	local func = function()
		if self:_OnTick() then return nil end

		return 1
	end

	self.nCountdown = TIME_TO_END + 1
	self.endTeam 	= iTeamNumber
	self.endTimer 	= Timers:CreateTimer(func(), func)
end

function GameEnder:_OnTick()
	local time = self.nCountdown - 1

	if time == -1 then
		self:_OnEnd(self.endTeam)
		return true
	else
		self.nCountdown = time
		self:_UpdateCountdownUI()
	end

	return false
end

function GameEnder:_UpdateCountdownUI()
	local timeStr = MessageFormaters:FormatTime(self.nCountdown)
	local color = "#FFFF00"

	Attentions:SetTextMinimapText( END_MINIMAP_MESSAGE, color, { ["time"] = timeStr } )
end