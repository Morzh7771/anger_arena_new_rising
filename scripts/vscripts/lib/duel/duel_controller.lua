require('lib/duel/duel_lib')
require('lib/attentions')
require('lib/team_helper')
require('lib/message_formatters')
LinkLuaModifier("modifier_duel_vision", 'modifiers/modifier_duel_vision', LUA_MODIFIER_MOTION_NONE)
local DUEL_INTERVAL = 360
local DUEL_INTERVAL_AFTER = 240
local DUEL_NOBODY_WINS = 150

local DUEL_FIRST_BONUS_GOLD = 450
local DUEL_FIRST_BONUS_EXP  = 450
local DUEL_WINNER_GOLD_MULTIPLER = 150
local DUEL_WINNER_EXP_MULTIPLER = 75
local DUEL_GOLD_PER_MINUTE = 30
local DUEL_GIVE_VISION_TIME = 30

DuelController = DuelController or class({})

function DuelController:GetTimeToDuel()
	if DuelLibrary:IsDuelActive() then return -1 end

	return self.nCountdown
end

function DuelController:GetTime()
	return self.nCountdown
end

function DuelController:GetFreezeTimer()
	return self.freeze
end

function DuelController:SetFreezeTimer(val)
	self.freeze = val
end

function DuelController:IsLastDuelTeam( val )
	return self.duelEndTeams[val] ~= nil
end

function DuelController:AddLastDuelTeam( val )
	if DuelLibrary:IsDuelActive() then
		table.insert( self.delayedLastDuel, val )
	else
		self.duelEndTeams[val] = 1
	end
end

function DuelController:SetTime(val)
	if val ~= nil and val >= 0 then
		self.nCountdown = val + 1
		self:_ForceTick( false, false )
		return true
	end

	return false
end

function DuelController:StartDuel()
	self.nCountdown = 0
	self:_StartDuelTimer( not self:_StartDuel() )
	self:_ForceTick(false, false)
end

function DuelController:StopDuel()
	self:_CancelDuels()
end

function DuelController:ToggleDuel()
	if DuelLibrary:IsDuelActive() then
		self:StopDuel()
	else
		self:StartDuel()
	end
end

function DuelController:SetDoorsState(state)
	DuelLibrary:SetDoorsState( state )
end

function DuelController:Precache(context)
	DuelLibrary:Precache(context)
end

function DuelController:OnGameStart(endCallback)
	self:_StartDuelTimer(true)
	self:SetDoorsState( true )

	self.endCallback = endCallback
end

function DuelController:_StartDuel()
	self:_CancelDuels()

	local radiantHeroes = TeamHelper:GetHeroes(DOTA_TEAM_GOODGUYS)
	local direHeroes 	= TeamHelper:GetHeroes(DOTA_TEAM_BADGUYS)

	local no_refresh_skill = {
		["faceless_void_chronosphere"] = true,
	}
	local refresher_shared = {
		["item_refresher"] = true, 
		}
		function RespawnHeroes(tbl)
			for _, hero in pairs(tbl) do
				hero:RespawnHero(false, false)
				for i = 0, hero:GetAbilityCount() - 1 do
					local ability = hero:GetAbilityByIndex( i )
					if ability and not no_refresh_skill[ ability:GetAbilityName() ] then
						ability:EndCooldown()
					end
				end
				for i = 0, 5 do
					local item = hero:GetItemInSlot( i )
					if item and not refresher_shared[item:GetName()] then
						item:EndCooldown()
					end
				end
			end
			
		end

		RespawnHeroes(radiantHeroes)
		RespawnHeroes(direHeroes)

	local nRadiants, nTotalRadiants, nDires, nTotalDires = DuelLibrary:GetMaximumHeroes( radiantHeroes, direHeroes, false )

	local nUnits = min(nTotalRadiants, nTotalDires)

	if nRadiants == 0 or nDires == 0 then
		Attentions:SendChatMessage("#duel_error")
		return false
	end

	Attentions:SendChatMessage("#duel_start") 

	DuelLibrary:StartDuel(radiantHeroes, direHeroes, nUnits, 
		function(winnerTeam) 
			self:_OnDuelEnd(winnerTeam)
		end)

	return true
end

function DuelController:_ForceTick( isEnd, wantFreeze )
	local wasFreeze = self.freeze

	self.freeze = wantFreeze

	self:_OnTick( isEnd )

	self.freeze = wasFreeze
end

function DuelController:_OnDuelEnd(winnerTeam)
	local duelCount = DuelLibrary:GetDuelCount()

	local allowedTeams = {
		[DOTA_TEAM_GOODGUYS] = "#duel_end_win_radiant",
		[DOTA_TEAM_BADGUYS]  = "#duel_end_win_demons"
	}

	local goldBonus
	local expBonus

	if duelCount == 1 then
		goldBonus = DUEL_FIRST_BONUS_GOLD
		expBonus = DUEL_NOBODY_WINS
	else
		local minute = GameRules:GetGameTime() / 60

		goldBonus = DUEL_WINNER_GOLD_MULTIPLER * duelCount + DUEL_GOLD_PER_MINUTE * minute
		expBonus  = DUEL_WINNER_EXP_MULTIPLER * minute
	end

	local message = allowedTeams[winnerTeam]

	if message ~= nil then
		if self.duelEndTeams[winnerTeam] then
			self.endCallback( winnerTeam )
		end

		Attentions:SendChatMessage(message)

		TeamHelper:ApplyForHeroes( winnerTeam, function(playerid, hero)
			PlayerResource:ModifyGold(playerid, goldBonus, true, 0)

			if hero and IsValidEntity(hero) and hero:IsRealHero() and not hero:IsNull() then
				hero:AddExperience(expBonus, 0, false, true)
			end
		end,
		true)
	else
		Attentions:SendChatMessage("#duel_end") 
	end

	self.nCountdown = 0

	for _, team in pairs(self.delayedLastDuel) do
		self.duelEndTeams[team] = 1
	end

	self:_ForceTick( true, false )
end

function DuelController:_CancelDuels()	
	if DuelLibrary:IsDuelActive() then
		DuelLibrary:EndDuel( DuelLibrary.DRAW_TEAM )
	end
end

function DuelController:_StartDuelTimer(toDuel)
	local interval
	local duelCount = DuelLibrary:GetDuelCount()
	if toDuel then
		if duelCount > 4 then
			interval = DUEL_INTERVAL_AFTER
		else
			interval = DUEL_INTERVAL
		end
	else
		interval = DUEL_NOBODY_WINS + 1
	end

	self.nCountdown = interval

	if self.duelTimer ~= nil then return end

	local function TimerFunc()
		self:_OnTick()
		return 1
	end

	self.duelTimer = Timers:CreateTimer(TimerFunc(), TimerFunc)
end

function DuelController:_OnTick( isEnd )
	local nCountdown = self.nCountdown - 1

	if self.freeze then
		nCountdown = nCountdown + 1
	end
	if nCountdown == DUEL_GIVE_VISION_TIME then
		if DuelLibrary:IsDuelActive() then 
			local radiantHeroes = TeamHelper:GetHeroes(DOTA_TEAM_GOODGUYS)
			local direHeroes 	= TeamHelper:GetHeroes(DOTA_TEAM_BADGUYS)

			function VisionHero(tbl)
				for _, hero in pairs(tbl) do
					hero:AddNewModifier(nil,nil,"modifier_duel_vision", {duration = DUEL_GIVE_VISION_TIME })
				end
			end
			VisionHero(radiantHeroes)
			VisionHero(direHeroes)
		end
	end

	if nCountdown == -1 then
		if DuelLibrary:IsDuelActive() or isEnd then
			self:_CancelDuels()
			self:_StartDuelTimer( true )
		else
			self:_StartDuelTimer( not self:_StartDuel() )
		end
			local radiantHeroes = TeamHelper:GetHeroes(DOTA_TEAM_GOODGUYS)
			local direHeroes 	= TeamHelper:GetHeroes(DOTA_TEAM_BADGUYS)

			function RemoveVision(tbl)
				for _, hero in pairs(tbl) do
					hero:RemoveAllModifiersByName("modifier_duel_vision")
					hero:RemoveAllModifiersByName("modifier_edible_gem")
				end
			end
			RemoveVision(radiantHeroes)
			RemoveVision(direHeroes)
	else
		self.nCountdown = nCountdown
	end

	if not self.freeze then
		self:_UpdateCountdownUI()
	end
end

function DuelController:_UpdateCountdownUI()
	local color, time = self:_FormatCountdown()

	Attentions:SetTextMinimapText( self:_GetStateMessage(), color, { ["time"] = time } )
end

function DuelController:_FormatCountdown()
	local t = self.nCountdown

	local textColor = "#FFFFFF"
	
	if t <= 15 then
		textColor = "#FF0000"
	end

	return textColor, MessageFormaters:FormatTime(t)
end

function DuelController:_GetStateMessage()
	if DuelLibrary:IsDuelActive() then
		return "#duel_nobody_wins"
	else
		return "#duel_next_duel"
	end
end

function DuelController:_Init()
	self.nCountdown 	 = self.nCountdown or 0
	self.freeze 		 = self.freeze or false
	self.duelEndTeams	 = self.duelEndTeams or {}
	self.endCallback	 = self.endCallback or nil
	self.delayedLastDuel = self.delayedLastDuel or {}
end

DuelController:_Init()