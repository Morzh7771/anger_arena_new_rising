Attentions = Attentions or class({})

function Attentions:SetKillLimit( nCount )
	CustomNetTables:SetTableValue("game_info", "kill_limit", { kl = nCount })
end

-- final - чья следующая дуэль решающая ("radiant" | "dire" | "both"), для
-- подсказки у таймера; у остальных таймеров пусто
function Attentions:SetTextMinimapText(text, color, formatters, final)
	if not formatters then
		formatters = {}
	end

	CustomNetTables:SetTableValue("game_info", "timer", { text = text, formatters = formatters, color = color, final = final or "" })
end

-- Убийства команд для полосок под таймером дуэли. Зовётся на смерть любого
-- юнита, поэтому в нет-таблицу пишем только когда счёт сменился.
function Attentions:SetTeamKills(radiant, dire)
	if self.lastRadiantKills == radiant and self.lastDireKills == dire then return end

	self.lastRadiantKills = radiant
	self.lastDireKills = dire

	CustomNetTables:SetTableValue("game_info", "kills", { radiant = radiant, dire = dire })
end

function Attentions:SendChatMessage( msg, plyid, count )
	if plyid == nil then
		plyid = 0
	end

	if count == nil then
		count = 0
	end

	GameRules:SendCustomMessage(msg, plyid, count)
end

function Attentions:HideAttentionText()
	if self.attentionTextTimer then
		Timers:RemoveTimer( self.attentionTextTimer )
	end

	self:_HideAttentionText()
end

function Attentions:SendAttentionText(text, showTime, priority)
	priority = priority or 0

	-- ignore message with lower-priority
	if self.attentionTextTimer and priority < self.lastAttentionPriority then return end 

	self.lastAttentionPriority = priority

	CustomGameEventManager:Send_ServerToAllClients("attension_text", { string = text })
	self.attentionTextTimer = Timers:CreateTimer(showTime, function()
		self:HideAttentionText()
	end)
end


function Attentions:_HideAttentionText()
	CustomGameEventManager:Send_ServerToAllClients("attension_close", nil)
	self.attentionTextTimer = nil
end


function Attentions:_Init()
	self.attentionTextTimer = nil
	self.lastAttentionPriority = nil
end

Attentions:_Init()