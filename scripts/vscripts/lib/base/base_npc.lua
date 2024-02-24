--[[ Overrides for BaseNpc entity(creep, heroes, buildings, etc)
   
   API:
	unit:IsPlayerAbandoned()		-- short-cut, if no player owner - return false
	unit:IsPlayerConnected()		-- short-cut, if no player owner - return false
	unit:IsPlayerDisconnected()		-- short-cut, if no player owner - return false 
]]

------------------------------------------------------------------------------------------------------------------------------------------------

require("lib/base/player")

------------------------------------------------------------------------------------------------------------------------------------------------

function CDOTA_BaseNPC:IsPlayerAbandoned()
    local playerid = self:GetPlayerOwnerID()

    if not playerid or not PlayerResource:IsValidPlayerID(playerid) then return false end -- no player owner -> no abaddoned

    return PlayerResource:IsAbandoned(playerid) 
end 

function CDOTA_BaseNPC:IsPlayerConnected()
	local playerid = self:GetPlayerOwnerID()

    if not playerid or not PlayerResource:IsValidPlayerID(playerid) then return false end -- no player owner -> no connected

    return PlayerResource:IsConnected(playerid) 
end 

function CDOTA_BaseNPC:IsPlayerDisconnected()
	local playerid = self:GetPlayerOwnerID()

    if not playerid or not PlayerResource:IsValidPlayerID(playerid) then return false end -- no player owner -> no disconnected

    return PlayerResource:IsDisconnected(playerid) 
end 

function CDOTA_BaseNPC:IsDebuffImmune()
    return self:HasModifierState(MODIFIER_STATE_DEBUFF_IMMUNE)
end

function CDOTA_BaseNPC:HasModifierState(state, exceptions)
    for _, mod in pairs(self:FindAllModifiers()) do
        if not exceptions or not table.contains(exceptions, mod) then
            local states = {} mod:CheckStateToTable(states)
            if states[tostring(state)] ~= nil then return true end
        end
    end
    return false
end