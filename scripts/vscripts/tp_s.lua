require('lib/repick_menu')

-- Зона репика на карте. Сейчас сменить героя нельзя - говорим почему,
-- красной строкой со звуком, как у доты "нет маны". Раньше зона в таком
-- случае молча не открывалась, и было непонятно, что вообще не так.
function hc_menu_open(trigger)
	if not IsServer() then return end

	local activator = trigger.activator

	if not activator or not activator.GetPlayerOwner then return end

	local player = activator:GetPlayerOwner()

	if not player then return end

	local reason = RepickMenu:GetBlockReason()

	if reason then
		-- в зону заходят и курьеры с иллюзиями - говорим только за героя
		if activator.IsRealHero and activator:IsRealHero() then
			CustomGameEventManager:Send_ServerToPlayer(player, "CreateIngameErrorMessage", { message = reason })
		end

		return
	end

	RepickMenu:Open( player )
end

function hc_menu_close(trigger)
	if not trigger.activator then return end

	local player = trigger.activator:GetPlayerOwner()

	if not player then return end

	RepickMenu:Close( player )
end

-- Кружок зоны репика (info_particle_system с cp_allied_fire на карте, имя TELEPORTIK) горит
-- только когда репик открыт: Soul Guardian убит и до дуэли далеко. Раньше светился всегда.
local RepickRing = { open = nil }

local function RingEntities()
	local out = {}

	for _, ent in ipairs(Entities:FindAllByName("TELEPORTIK") or {}) do
		if ent:GetClassname() == "info_particle_system" then out[#out + 1] = ent end
	end

	if #out == 0 then
		for _, ent in ipairs(Entities:FindAllByClassname("info_particle_system") or {}) do
			if ent:GetName() == "TELEPORTIK" then out[#out + 1] = ent end
		end
	end

	return out
end

local function RingTick()
	local ok, reason = pcall(RepickMenu.GetBlockReason, RepickMenu)
	local open = ok and reason == nil

	if open ~= RepickRing.open then
		RepickRing.open = open

		for _, ent in ipairs(RingEntities()) do
			DoEntFireByInstanceHandle(ent, open and "Start" or "Stop", "", 0, nil, nil)
		end
	end

	return 1
end

-- файл грузится и как скрипт каждого триггера зоны (своя область видимости) - слушатель один на игру
if IsServer() and not GameRules.__aaRepickRing then
GameRules.__aaRepickRing = true

ListenToGameEvent("game_rules_state_change", function()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME and not RepickRing.started then
		RepickRing.started = true
		Timers:CreateTimer(0.5, function()
			local ok, d = pcall(RingTick)

			return ok and d or 1
		end)
	end
end, nil)

end
