function ChangeTeam(keys)
	local caster = keys.caster
	local ability = keys.ability
	local playerId = caster:GetPlayerID()
	if not caster:IsRealHero() or DuelController:GetTimeToDuel() == -1 then
		return
	end
	local oldTeam = caster:GetTeamNumber()
	local newTeam = caster:GetOpposingTeamNumber()
	if GetNumConnectedHumanPlayers(newTeam) >= GetNumConnectedHumanPlayers(oldTeam) and not IsInToolsMode() then
		Containers:DisplayError(playerId, "#arena_hud_error_team_changer_players")
		return
	end

	GameRules:SetCustomGameTeamMaxPlayers(newTeam, GameRules:GetCustomGameTeamMaxPlayers(newTeam) + 1)
	PlayerResource:SetPlayerTeam(playerId, newTeam)
	GameRules:SetCustomGameTeamMaxPlayers(oldTeam, GameRules:GetCustomGameTeamMaxPlayers(oldTeam) - 1)

	FindClearSpaceForUnit(caster, FindFountain(newTeam):GetAbsOrigin(), true)
	local courier = Structures:GetCourier(playerId)
	FindClearSpaceForUnit(courier, caster:GetAbsOrigin() + RandomVector(150), true)
	courier:SetTeam(newTeam)
	Timers:NextTick(function()
		ReloadUnitModifiers(caster)
		ReloadUnitModifiers(courier)
	end)

	ability:SpendCharge()
end

function OnAttacked(keys)
	local ability = keys.ability
	local attacker = keys.attacker
end
