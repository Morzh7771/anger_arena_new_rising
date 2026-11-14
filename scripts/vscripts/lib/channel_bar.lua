-- Полоска канала для предметов и способностей на Lua (Meteor Hammer).
--
-- Ванильная DOTAChannelBar у item_lua в нашем режиме не появляется, поэтому
-- рисуем свою, внешне такую же: panorama/scripts/custom_game/channel_bar.js.
-- Сервер шлёт владельцу начало (длительность, способность) и конец канала.

ChannelBar = ChannelBar or {}

local function OwnerPlayer(caster)
	if not caster or caster:IsNull() then return nil end

	local playerID = caster:GetPlayerOwnerID()

	if not playerID or playerID < 0 then return nil end

	return PlayerResource:GetPlayer(playerID)
end

function ChannelBar:Start(caster, ability, duration)
	local player = OwnerPlayer(caster)

	if not player or not duration or duration <= 0 then return end

	CustomGameEventManager:Send_ServerToPlayer(player, "aa_channel_start", {
		unit = caster:entindex(),
		ability = ability and ability:GetAbilityName() or "",
		is_item = (ability and ability:IsItem()) and 1 or 0,
		duration = duration,
	})
end

function ChannelBar:Stop(caster)
	local player = OwnerPlayer(caster)

	if not player then return end

	CustomGameEventManager:Send_ServerToPlayer(player, "aa_channel_stop", { unit = caster:entindex() })
end
