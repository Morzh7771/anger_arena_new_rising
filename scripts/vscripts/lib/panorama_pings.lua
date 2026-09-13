PanoramaPingManager = PanoramaPingManager or {}

function PanoramaPingManager:OnKillimitGet(data)
	local playerid = data['PlayerID']
	local text = data['s']
	
	local player = PlayerResource:GetPlayer(playerid)

	if not player then return end

	local team = PlayerResource:GetTeam(playerid)
	local enemy_team = DOTA_TEAM_GOODGUYS

	if team == DOTA_TEAM_GOODGUYS then
		enemy_team = DOTA_TEAM_BADGUYS
	elseif team ~= DOTA_TEAM_BADGUYS then
		return
	end

	local kl = _G.KILL_LIMIT
	local myteamkills = PlayerResource:GetTeamKills(team)
	local enemykills = PlayerResource:GetTeamKills(enemy_team)
	
	local need_myteam = max(kl - myteamkills, 0)
	local need_enemyteam = max(kl - enemykills, 0)

	text = text:format( need_myteam, need_enemyteam )

	Say(player, ">" .. text, true)
end

function PanoramaPingManager:OnDuelGet(data)
	local playerid = data['PlayerID']
	local text = data['s']
	
	local player = PlayerResource:GetPlayer(playerid)

	if not player then return end

	Say(player, ">" .. text, true)
end

-- Пинг как по alt-клику по карте: круг на миникарте всей команде, метка в мире
-- и звук. Настоящего пинга в vscript нет, поэтому собираем его из частей.
local PING_PARTICLE = "particles/ui_mouseactions/ping_circle.vpcf"
local PING_COLOR = Vector(255, 200, 60)
-- звук ванильного пинга; если движок переименует событие, круг на миникарте
-- всё равно останется - молча пропадёт только звук
local PING_SOUND = "General.Ping"
local PING_DURATION = 3.0

-- MinimapEvent рисует метку в точке x/y, а энтити ему нужна как якорь - Valve в
-- conquest вешает его на героя команды. Якорь должен быть у клиента: серверные
-- info_target и свежие thinker'ы не рисовались вовсе. И одна энтити держит одно
-- событие - на общем герое выживал только последний пинг. Поэтому каждой точке
-- свой якорь из того, что клиент своей команды знает всегда: герои и постройки.
local ANCHOR_CLASSES = {
	"npc_dota_fort",
	"npc_dota_tower",
	"npc_dota_building",
	"ent_dota_fountain",
}

local function CollectAnchors(team)
	local anchors = {}

	TeamHelper:ApplyForHeroes(team, function(_, hero)
		table.insert(anchors, hero)
	end)

	for _, classname in pairs(ANCHOR_CLASSES) do
		for _, entity in pairs(Entities:FindAllByClassname(classname)) do
			if entity:GetTeamNumber() == team then
				table.insert(anchors, entity)
			end
		end
	end

	return anchors
end

function PanoramaPingManager:PingLocation(team, anchor, pos)
	MinimapEvent(team, anchor, pos.x, pos.y, DOTA_MINIMAP_EVENT_HINT_LOCATION, PING_DURATION)

	local fx = ParticleManager:CreateParticleForTeam(PING_PARTICLE, PATTACH_CUSTOMORIGIN, nil, team)

	ParticleManager:SetParticleControl(fx, 0, pos)
	ParticleManager:SetParticleControl(fx, 1, PING_COLOR)
	ParticleManager:ReleaseParticleIndex(fx)
end

-- Alt-клик по кружку руны под таймером (panorama/scripts/custom_game/rune_timers.js):
-- пишем команде, через сколько руна, и пингуем её точки. Баунти и мудрость падают
-- в одни и те же места, у усиления свои спавнеры - всё это знает lib/bounty.lua.
function PanoramaPingManager:OnRuneTimerClick(data)
	local playerid = data['PlayerID']
	local player = PlayerResource:GetPlayer(playerid)

	if not player then return end

	local team = PlayerResource:GetTeam(playerid)
	local spots = Bounty and Bounty:GetRuneSpots(data['rune']) or {}
	local anchors = CollectAnchors(team)

	-- если пинг снова не тот - смотреть сюда: точек больше, чем якорей, значит
	-- часть точек останется без метки
	print("[AA] rune ping:", data['rune'], "spots:", #spots, "anchors:", #anchors)

	for i, spot in ipairs(spots) do
		local anchor = anchors[i]

		if anchor and IsValidEntity(spot) then
			PanoramaPingManager:PingLocation(team, anchor, spot:GetAbsOrigin())
		end
	end

	-- звук один на клик, сколько бы точек ни пингнули: два наложенных пинга
	-- звучат просто громче
	if #spots > 0 then
		TeamHelper:ApplyForPlayers(team, function(pid)
			local listener = PlayerResource:GetPlayer(pid)

			if listener then
				EmitSoundOnClient(PING_SOUND, listener)
			end
		end)
	end

	local text = data['s']

	-- пустую строку клиент шлёт, когда время следующей руны ещё неизвестно
	if text and text ~= "" then
		Say(player, ">" .. text, true)
	end
end

CustomGameEventManager:RegisterListener("on_kill_limit_click", Dynamic_Wrap(PanoramaPingManager, 'OnKillimitGet'))
CustomGameEventManager:RegisterListener("on_duel_timer_click", Dynamic_Wrap(PanoramaPingManager, 'OnDuelGet'))

CustomGameEventManager:RegisterListener("on_rune_timer_click", Dynamic_Wrap(PanoramaPingManager, 'OnRuneTimerClick'))
