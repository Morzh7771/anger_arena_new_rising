if not IsServer() then return end

--[[
	Круги захвата вместо рун богатства и мудрости - механика из frontier.

	На споте руны вместо самой руны встаёт круг. Одна команда в круге - он
	заполняется, заполнился - руна достаётся этой команде. Правила захвата
	(кто считается, скорость, спор двух команд) - в capture_point_area.lua.

	Награду заново не пишем. Руну активирует бутылка первого героя в круге:
	движок считает, что руну подобрали, шлёт dota_rune_activated_server, и
	дальше работает тот же AngelArena:OnRuneActivate, что и с лежащей руной.
	Поэтому цифры богатства и мудрости не меняются.

	Где и когда круги появляются, решает lib/bounty.lua - расписание прежнее.
]]

require('lib/timers')
require('lib/capture_points/capture_points_declarations')

LinkLuaModifier("capture_point_area", "lib/capture_points/capture_point_area", LUA_MODIFIER_MOTION_NONE)

CapturePoints = CapturePoints or {}
CapturePoints.zones = CapturePoints.zones or {}

local ZONE_UNIT = "npc_aa_capture_point"
local SPAWN_SOUND = "Item.PickUpGemWorld"

-- юнит круга убираем не сразу: кольцо ещё доигрывает эффект исчезновения
local REMOVE_DELAY = 2.0

-- typeName - ключ CAPTURE_POINT_TYPES: "bounty" | "wisdom"
function CapturePoints:SpawnZone(pos, typeName)
	local def = CAPTURE_POINT_TYPES[typeName]
	if not def then return nil end

	local zone = CreateUnitByName(ZONE_UNIT, pos, false, nil, nil, DOTA_TEAM_NEUTRALS)
	if not zone then return nil end

	zone:SetAbsOrigin(pos)
	zone.capture_type = typeName

	-- сама руна в центре круга
	zone.rune_fx = ParticleManager:CreateParticle(def.particle, PATTACH_ABSORIGIN_FOLLOW, zone)
	ParticleManager:SetParticleControl(zone.rune_fx, 3, Vector(CAPTURE_POINT_RADIUS - 25, 0, 0))

	zone:AddNewModifier(zone, nil, "capture_point_area", { capture_type = typeName })

	self.zones[zone:GetEntityIndex()] = zone

	-- круги на обоих спотах встают в один кадр - звук один на всех
	local now = GameRules:GetGameTime()

	if self._lastSpawnSound ~= now then
		self._lastSpawnSound = now
		EmitGlobalSound(SPAWN_SOUND)
	end

	return zone
end

-- Зовёт модификатор круга, когда тот заполнился. units - герои захватившей
-- команды, стоявшие в круге в этот момент.
function CapturePoints:OnCaptured(zone, units)
	local def = CAPTURE_POINT_TYPES[zone.capture_type]
	local activator = self:_PickActivator(units)

	if def and activator then
		local ok, err = pcall(self._ActivateRune, self, def.rune, activator)

		if not ok then
			print("[AA] capture point: руна не активировалась: " .. tostring(err))
		end
	end

	self:RemoveZone(zone, true)
end

-- AngelArena:OnRuneActivate берёт героя через PlayerResource:GetPlayer, а у
-- отключившегося игрока это nil. Поэтому руну активирует тот, кто в игре.
function CapturePoints:_PickActivator(units)
	for _, unit in ipairs(units or {}) do
		if IsValidEntity(unit) and PlayerResource:GetPlayer(unit:GetPlayerOwnerID()) then
			return unit
		end
	end

	return nil
end

function CapturePoints:_ActivateRune(rune, unit)
	local bottle = CreateItem("item_bottle", unit, unit)

	bottle:SetStoredRune(rune)
	bottle:OnSpellStart()

	Timers:CreateTimer(0.1, function()
		if IsValidEntity(bottle) then UTIL_Remove(bottle) end
	end)
end

-- captured - круг взяли (играет звук захвата), а не просто сменили новым
function CapturePoints:RemoveZone(zone, captured)
	if not IsValidEntity(zone) then return end

	self.zones[zone:GetEntityIndex()] = nil

	local mod = zone:FindModifierByName("capture_point_area")

	if mod then
		mod.captured = captured
		mod:Destroy()
	end

	if zone.rune_fx then
		ParticleManager:DestroyParticle(zone.rune_fx, true)
		ParticleManager:ReleaseParticleIndex(zone.rune_fx)
		zone.rune_fx = nil
	end

	Timers:CreateTimer(REMOVE_DELAY, function()
		if IsValidEntity(zone) then UTIL_Remove(zone) end
	end)
end

function CapturePoints:RemoveZonesNear(pos, radius)
	for _, zone in pairs(self.zones) do
		if IsValidEntity(zone) and (zone:GetAbsOrigin() - pos):Length2D() <= radius then
			self:RemoveZone(zone, false)
		end
	end
end

function CapturePoints:HasZoneNear(pos, radius)
	for idx, zone in pairs(self.zones) do
		if not IsValidEntity(zone) then
			self.zones[idx] = nil
		elseif (zone:GetAbsOrigin() - pos):Length2D() <= radius then
			return true
		end
	end

	return false
end
