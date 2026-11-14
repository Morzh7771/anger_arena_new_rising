TeamHelper = TeamHelper or class({})

--[[
	IN:
		iTeamNumber - number of team or nil(for all teams)
	OUT:
		table where key is playerid, value is hero entity
]]
function TeamHelper:GetHeroes(iTeamNumber, allowInvalidHeroes)
	local result = {}

	self:ApplyForHeroes(iTeamNumber, function(playerid, hero)
		result[playerid] = hero
	end,
	allowInvalidHeroes)

	return result 
end 

--[[
	IN:
		iTeamNumber - number of team or nil(for all teams)
		functor - callable object that must accept (playerid, hero)
]]
function TeamHelper:ApplyForHeroes(iTeamNumber, functor, allowInvalidHeroes)
	TeamHelper:ApplyForPlayers(iTeamNumber, function(playerid)
		local ent = PlayerResource:GetSelectedHeroEntity( playerid )

		if allowInvalidHeroes or (ent and not ent:IsNull() and IsValidEntity(ent) and ent:IsRealHero() and not ent:IsNull()) then
			functor(playerid, ent)
		end
	end)
end 

--[[
	IN:
		iTeamNumber - number of team or nil(for all teams)
		functor - callable object that must accept (playerid)
]]
function TeamHelper:ApplyForPlayers(iTeamNumber, functor)
	for playerid = 0, PlayerResource:GetPlayerCount() do
		if iTeamNumber == nil or ( PlayerResource:GetTeam(playerid) == iTeamNumber ) then 
			functor( playerid )
		end 
	end 
end 

-- Сколько игроков в команде (nil - во всех). Раньше параметр назывался
-- iteamNumber, а проверялся iTeamNumber - глобальная, то есть nil, и функция
-- всегда считала всех игроков, да ещё с лишним номером сверху.
function TeamHelper:GetPlayerCount(iTeamNumber)
	local res = 0

	for playerid = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(playerid) and ( iTeamNumber == nil or PlayerResource:GetTeam(playerid) == iTeamNumber ) then
			res = res + 1
		end
	end

	return res
end
