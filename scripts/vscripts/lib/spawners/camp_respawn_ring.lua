if not IsServer() then return end

--[[
	Круг респавна на зачищенном кемпе.

	Кемп зачистили - на его точке встаёт серый круг с часами, которые
	заполняются ровно к респавну. Заполнились - крипы появились, круг ушёл.
	Партиклы те же, что у кругов захвата рун (lib/capture_points).

	Зовёт его lib/spawners/creep_spawner.lua: Start - когда планирует
	респавн, Stop - когда кемп спавнится. Если к моменту респавна кемп занят,
	спавнер, как и раньше, откладывает респавн на новые 30-60 с - круг тогда
	начинает заполняться заново под новое время.

	Заполненность часов - контрольная точка партикла, каждая её смена уходит
	клиентам по сети. Поэтому двигаем её не каждый кадр, а раз в TICK - на
	глаз разницы нет.
]]

require('lib/timers')
require('lib/capture_points/capture_points_declarations')

CampRespawnRing = CampRespawnRing or {}
CampRespawnRing._rings = CampRespawnRing._rings or {}

local RADIUS = 200
local COLOR = Vector(220, 220, 220)
local TICK = 0.2

local function TimerName(name)
	return "CampRespawnRing_" .. name
end

local function DestroyFx(fx, immediate)
	ParticleManager:DestroyParticle(fx, immediate)
	ParticleManager:ReleaseParticleIndex(fx)
end

-- name - имя спавнера, pos - его точка, duration - через сколько респавн
function CampRespawnRing:Start(name, pos, duration)
	-- круг уже стоит (кемп был занят, респавн отложен) - ставим заново,
	-- без эффекта исчезновения
	self:Stop(name, true)

	if not pos or not duration or duration <= 0 then return end

	local ground = GetGroundPosition(pos, nil)

	local ring = ParticleManager:CreateParticle(CAPTURE_POINT_RING, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(ring, 0, ground)
	ParticleManager:SetParticleControl(ring, 3, COLOR)
	ParticleManager:SetParticleControl(ring, 9, Vector(RADIUS, 0, 0))

	local clock = ParticleManager:CreateParticle(CAPTURE_POINT_RING_CLOCK, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(clock, 0, ground)
	ParticleManager:SetParticleControl(clock, 3, COLOR)
	ParticleManager:SetParticleControl(clock, 9, Vector(RADIUS, 0, 0))
	ParticleManager:SetParticleControl(clock, 11, Vector(0, 0, 1))
	ParticleManager:SetParticleControl(clock, 17, Vector(0, 0, 0))

	self._rings[name] = { ring = ring, clock = clock }

	local startTime = GameRules:GetGameTime()

	Timers:CreateTimer(TimerName(name), {
		useGameTime = true,
		endTime = TICK,
		callback = function()
			if not self._rings[name] then return nil end

			local progress = math.min(1, (GameRules:GetGameTime() - startTime) / duration)

			ParticleManager:SetParticleControl(clock, 17, Vector(progress, 0, 0))

			if progress >= 1 then return nil end

			return TICK
		end
	})
end

-- immediate - убрать без эффекта исчезновения. На респавне эффект, наоборот,
-- к месту: круг вспыхивает ровно тогда, когда появляются крипы.
function CampRespawnRing:Stop(name, immediate)
	Timers:RemoveTimer(TimerName(name))

	local entry = self._rings[name]
	if not entry then return end

	self._rings[name] = nil

	DestroyFx(entry.clock, immediate == true)
	DestroyFx(entry.ring, immediate == true)
end

function CampRespawnRing:StopAll()
	for name, _ in pairs(self._rings) do
		self:Stop(name, true)
	end
end
