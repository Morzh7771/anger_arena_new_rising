require('lib/duel/duel_lib')
require('lib/attentions')
require('lib/team_helper')
require('lib/message_formatters')
LinkLuaModifier("modifier_duel_vision", 'modifiers/modifier_duel_vision', LUA_MODIFIER_MOTION_NONE)
local DUEL_INTERVAL = 360
local DUEL_INTERVAL_AFTER = 240
local DUEL_NOBODY_WINS = 150

local DUEL_FIRST_BONUS_GOLD = 250
local DUEL_FIRST_BONUS_EXP  = 250
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

-- Вызывается из PRE_GAME. firstInterval - сколько секунд игрового времени до
-- первой дуэли (обычно "до горна + 30"); без него первая дуэль через 30 с
-- после старта таймера. Двери сюда намеренно НЕ переносим: они открываются в
-- GAME_IN_PROGRESS, как и раньше (см. addon_game_mode.lua).
function DuelController:OnGameStart(endCallback, firstInterval)
	self:_StartDuelTimer(true, firstInterval)

	self.endCallback = endCallback
end

-- Сколько "циклов дуэли" уже прошло: реальные дуэли + пропущенные из-за
-- нехватки игроков. От этого числа считаются и интервал таймера, и тиры
-- нейтралок - иначе при игре одному цикл всегда был бы первым (30 секунд),
-- а тиры нейтралок не открывались бы вообще.
function DuelController:GetDuelCycle()
	return DuelLibrary:GetDuelCount() + ( self.skippedDuels or 0 )
end

function DuelController:_StartDuel()
	self:_CancelDuels()

	local radiantHeroes = TeamHelper:GetHeroes(DOTA_TEAM_GOODGUYS)
	local direHeroes 	= TeamHelper:GetHeroes(DOTA_TEAM_BADGUYS)

	-- Считаем игроков ДО сброса кулдаунов: если драться не с кем, ничего не
	-- рефрешим, просто пишем "недостаточно игроков" и живём дальше по таймеру.
	-- Проверяем именно общее число подключённых героев, а не живых - живых
	-- добирает RespawnHeroes ниже.
	local _, nConnectedRadiants, _, nConnectedDires = DuelLibrary:GetMaximumHeroes( radiantHeroes, direHeroes, false )

	if nConnectedRadiants == 0 or nConnectedDires == 0 then
		self:_OnDuelSkipped()
		return false
	end

	local no_refresh_skill = {
		["faceless_void_chronosphere"] = 15,
	}
	local refresher_shared = {
		["item_refresher"] = 20, 
		["item_vision"] = 10,
		["item_aeon_disk"] = 10,
	}
		function RespawnHeroes(tbl)
			for _, hero in pairs(tbl) do
				if not hero:IsAlive() then
					hero:RespawnHero(false, false)
				end
				for i = 0, hero:GetAbilityCount() - 1 do
					local ability = hero:GetAbilityByIndex( i )
					if ability then
						if no_refresh_skill[ ability:GetAbilityName() ] then
							if not ability:IsCooldownReady() then  
								ability:EndCooldown()
								ability:StartCooldown(no_refresh_skill[ ability:GetAbilityName()])
							end
						else
							ability:EndCooldown()
							ability:RefreshCharges()
						end
					end
				end
				for i = 0, 5 do
					local item = hero:GetItemInSlot( i )
					if item then
						if refresher_shared[ item:GetAbilityName() ] then
							if not item:IsCooldownReady() then  
								item:EndCooldown()
								item:StartCooldown(refresher_shared[ item:GetAbilityName()])
							end
						else
							item:EndCooldown()
						end
					end
				end
			end
			
		end

		RespawnHeroes(radiantHeroes)
		RespawnHeroes(direHeroes)

	local nRadiants, nTotalRadiants, nDires, nTotalDires = DuelLibrary:GetMaximumHeroes( radiantHeroes, direHeroes, false )

	local nUnits = min(nTotalRadiants, nTotalDires)

	if nRadiants == 0 or nDires == 0 then
		-- Страховка: кто-то так и не встал после RespawnHeroes.
		-- Таймер всё равно продолжает идти и зайдёт сюда снова.
		-- Раньше в чит-режиме здесь замораживался таймер, и следующего цикла
		-- не наступало никогда.
		self:_OnDuelSkipped()
		return false
	end

	if KillFeed then KillFeed:DuelStart() end
	-- звук дуэли легионки на старт
	EmitGlobalSound("Hero_LegionCommander.Duel.Cast")

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

-- Дуэль не состоялась (нет противников). Ничего не рефрешим и не морозим:
-- пишем в чат и считаем цикл пройденным, чтобы соло-игра всё равно
-- открывала тиры нейтралок и не сваливалась в 30-секундный интервал.
function DuelController:_OnDuelSkipped()
	self.skippedDuels = ( self.skippedDuels or 0 ) + 1

	if KillFeed then KillFeed:DuelSkipped() end

	if MadstoneSystem then
		MadstoneSystem:OnDuelEnd( self:GetDuelCycle() )
	end
end

function DuelController:_OnDuelEnd(winnerTeam)
	local duelCount = DuelLibrary:GetDuelCount()

	-- открытие следующего тира нейтралок и снятие лимита безумрудов
	-- завязано именно на конец дуэли
	if MadstoneSystem then
		MadstoneSystem:OnDuelEnd( self:GetDuelCycle() )
	end

	if EndGameStats then EndGameStats:OnDuelEnd(winnerTeam) end

	local allowedTeams = {
		[DOTA_TEAM_GOODGUYS] = "#duel_end_win_radiant",
		[DOTA_TEAM_BADGUYS]  = "#duel_end_win_demons"
	}

	local goldBonus
	local expBonus

	if duelCount == 1 then
		goldBonus = DUEL_FIRST_BONUS_GOLD
		expBonus = DUEL_FIRST_BONUS_EXP
	else
		local minute = (math.max(0, GameRules:GetDOTATime(false, false)) / 60)

		goldBonus = DUEL_WINNER_GOLD_MULTIPLER * duelCount + DUEL_GOLD_PER_MINUTE * minute
		expBonus  = DUEL_WINNER_EXP_MULTIPLER * minute
	end

	local message = allowedTeams[winnerTeam]

	if message ~= nil then
		if self.duelEndTeams[winnerTeam] then
			self.endCallback( winnerTeam )
		end

		if KillFeed then KillFeed:DuelWin(winnerTeam, goldBonus) end
		-- звук победы в дуэли легионки
		EmitGlobalSound("Hero_LegionCommander.Duel.Victory")
		-- косметика премиума: эффект победы в дуэли (lib/cosmetics/events_fx.lua)
		if AACosDuelWin then pcall(AACosDuelWin, winnerTeam) end

		TeamHelper:ApplyForHeroes( winnerTeam, function(playerid, hero)
			PlayerResource:ModifyGold(playerid, goldBonus, true, 0)
			-- после конца дуэли героев переносят с арены: эффект, созданный
			-- в этот же кадр, остаётся на старом месте и его не видно
			Timers:CreateTimer(0.5, function()
				AngelArena:ShowGoldPopup(playerid, goldBonus)
			end)

			if hero and IsValidEntity(hero) and hero:IsRealHero() and not hero:IsNull() then
				hero:AddExperience(expBonus, 0, false, true)
			end
		end,
		true)
	else
		if KillFeed then KillFeed:DuelDraw() end
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

function DuelController:_StartDuelTimer(toDuel, firstInterval)
	local interval
	-- считаем и пропущенные циклы, иначе соло-игра вечно висела бы
	-- на "первом" 30-секундном интервале
	local duelCount = self:GetDuelCycle()

	if toDuel then
		if duelCount == 0 then
			-- первый интервал может идти от старта PRE_GAME, тогда он длиннее 30
			interval = firstInterval or 30
	    elseif duelCount > 5 then
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
	-- аура телепорта на всех живых героях за 3 с до переноса на дуэль
	if nCountdown == 3 and not self.freeze and not isEnd and not DuelLibrary:IsDuelActive() then
		self:_StartTeleportFx()
	end
	--print(nCountdown)
	if nCountdown <= 10 then
		if nCountdown == 0 then
			EmitAnnouncerSound("announcer_ann_custom_mode_20")
		elseif nCountdown == 10 then
			EmitAnnouncerSound("announcer_ann_custom_countdown_10")
		else
			EmitAnnouncerSound("announcer_ann_custom_countdown_0".. nCountdown)
		end
    end
	if nCountdown == -1 then
		self:_StopTeleportFx()
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

-- цвет таймера, когда дуэль решающая: цвет команды, набравшей лимит
-- убийств, или жёлтый, если набрали обе
local FINAL_COLORS = {
	radiant = "#49C778",
	dire    = "#D63837",
	both    = "#FFD24A",
}

-- "radiant" | "dire" | "both" - если эта команда выиграет следующую (или
-- идущую) дуэль, она выиграет игру; nil - дуэль обычная
function DuelController:_GetFinalTeams()
	local radiant = self.duelEndTeams[DOTA_TEAM_GOODGUYS] ~= nil
	local dire    = self.duelEndTeams[DOTA_TEAM_BADGUYS] ~= nil

	if radiant and dire then return "both" end
	if radiant then return "radiant" end
	if dire then return "dire" end

	return nil
end

local TELEPORT_FX       = "particles/units/heroes/hero_chen/chen_teleport.vpcf"
local TELEPORT_FX_FLASH = "particles/units/heroes/hero_chen/chen_teleport_flash.vpcf"

function DuelController:_StartTeleportFx()
	self:_StopTeleportFx(true)
	self.teleportFx = {}
	for _, team in ipairs({ DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS }) do
		for _, hero in pairs(TeamHelper:GetHeroes(team)) do
			if IsValidEntity(hero) and hero:IsAlive() then
				local fx = ParticleManager:CreateParticle(TELEPORT_FX, PATTACH_ABSORIGIN_FOLLOW, hero)
				table.insert(self.teleportFx, { hero = hero, fx = fx })
				hero:EmitSound("Hero_Chen.TeleportLoop")
			end
		end
	end
end

-- silent = снять без вспышки
function DuelController:_StopTeleportFx(silent)
	if not self.teleportFx then return end
	for _, t in ipairs(self.teleportFx) do
		ParticleManager:DestroyParticle(t.fx, false)
		ParticleManager:ReleaseParticleIndex(t.fx)
		if IsValidEntity(t.hero) then
			t.hero:StopSound("Hero_Chen.TeleportLoop")
			if not silent and t.hero:IsAlive() then
				local pos = t.hero:GetAbsOrigin()
				local flash = ParticleManager:CreateParticle(TELEPORT_FX_FLASH, PATTACH_WORLDORIGIN, nil)
				ParticleManager:SetParticleControl(flash, 0, pos)
				ParticleManager:ReleaseParticleIndex(flash)
				EmitSoundOnLocationWithCaster(pos, "Hero_Chen.TeleportOut", t.hero)
			end
		end
	end
	self.teleportFx = nil
end

function DuelController:_UpdateCountdownUI()
	local color, time = self:_FormatCountdown()
	local final = self:_GetFinalTeams()

	if final then
		color = FINAL_COLORS[final]
	end

	Attentions:SetTextMinimapText( self:_GetStateMessage(final), color, { ["time"] = time }, final )
end

function DuelController:_FormatCountdown()
	local t = self.nCountdown

	local textColor = "#FFFFFF"
	
	if t <= 15 then
		textColor = "#FF0000"
	end

	return textColor, MessageFormaters:FormatTime(t)
end

function DuelController:_GetStateMessage(final)
	if DuelLibrary:IsDuelActive() then
		return final and "#duel_final_active" or "#duel_nobody_wins"
	else
		return final and "#duel_final_next" or "#duel_next_duel"
	end
end

function DuelController:_Init()
	self.nCountdown 	 = self.nCountdown or 0
	self.freeze 		 = self.freeze or false
	self.duelEndTeams	 = self.duelEndTeams or {}
	self.endCallback	 = self.endCallback or nil
	self.delayedLastDuel = self.delayedLastDuel or {}
	self.skippedDuels	 = self.skippedDuels or 0
end

DuelController:_Init()