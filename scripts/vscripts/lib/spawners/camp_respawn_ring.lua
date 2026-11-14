if not IsServer() then return end

--[[
	Круг респавна на зачищенном кемпе.

	Кемп зачистили - на его точке встаёт серый круг с часами, которые
	заполняются ровно к респавну. Заполнились - крипы появились, круг ушёл.
	Кольцо то же, что у кругов захвата рун (lib/capture_points), а часы свои:
	particles/camp_respawn/camp_respawn_clock.vpcf.

	Часы заполняются сами: им один раз передаётся длительность (CP17.x, в
	секундах), а заполненность партикл считает по своему возрасту. Так круг
	идёт плавно и ничего не шлёт по сети, пока крутится. У часов кругов рун
	заполненность, наоборот, двигает сервер - там её задаёт захват.

	Зовёт его lib/spawners/creep_spawner.lua: Start - когда планирует
	респавн, Stop - когда кемп спавнится. Если к моменту респавна кемп занят,
	спавнер, как и раньше, откладывает респавн на новые 30-60 с - круг тогда
	ставится заново под новое время.

	Тот же круг встаёт на точке убитого босса (lib/boss/boss_spawner.lua),
	там он шире - под размер босса. Время респавна у босса случайное: часы
	идут до максимума, а жёлтая дуга внутри показывает, с какого момента
	он уже может встать (particles/camp_respawn/camp_respawn_window.vpcf).
]]

require('lib/capture_points/capture_points_declarations')

CampRespawnRing = CampRespawnRing or {}
CampRespawnRing._rings = CampRespawnRing._rings or {}

local CLOCK = "particles/camp_respawn/camp_respawn_clock.vpcf"
-- дуга окна респавна: от доли часов CP17.y до конца круга. Нумерация частиц
-- та же, что у часов, поэтому заливка входит в дугу ровно в минимальное время
local WINDOW = "particles/camp_respawn/camp_respawn_window.vpcf"

local RADIUS = 200
local COLOR = Vector(220, 220, 220)
local WINDOW_COLOR = Vector(255, 170, 40)

local function DestroyFx(fx, immediate)
	ParticleManager:DestroyParticle(fx, immediate)
	ParticleManager:ReleaseParticleIndex(fx)
end

-- name - имя спавнера, pos - его точка, duration - через сколько респавн,
-- radius - необязательно, по умолчанию размер кемпа.
-- windowFrom - необязательно, доля 0..1: респавн случайный и может случиться
-- уже с этой доли часов. Тогда duration - максимальное время, а от windowFrom
-- до конца круга идёт жёлтая дуга (у боссов).
function CampRespawnRing:Start(name, pos, duration, radius, windowFrom)
	-- круг уже стоит (кемп был занят, респавн отложен) - ставим заново,
	-- без эффекта исчезновения
	self:Stop(name, true)

	if not pos or not duration or duration <= 0 then return end

	local ground = GetGroundPosition(pos, nil)
	radius = radius or RADIUS

	local ring = ParticleManager:CreateParticle(CAPTURE_POINT_RING, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(ring, 0, ground)
	ParticleManager:SetParticleControl(ring, 3, COLOR)
	ParticleManager:SetParticleControl(ring, 9, Vector(radius, 0, 0))

	local clock = ParticleManager:CreateParticle(CLOCK, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(clock, 0, ground)
	ParticleManager:SetParticleControl(clock, 3, COLOR)
	ParticleManager:SetParticleControl(clock, 9, Vector(radius, 0, 0))
	ParticleManager:SetParticleControl(clock, 11, Vector(0, 0, 1))
	-- за сколько секунд часы заполнятся
	ParticleManager:SetParticleControl(clock, 17, Vector(duration, 0, 0))

	local window = nil

	if windowFrom and windowFrom > 0 and windowFrom < 1 then
		window = ParticleManager:CreateParticle(WINDOW, PATTACH_WORLDORIGIN, nil)
		ParticleManager:SetParticleControl(window, 0, ground)
		ParticleManager:SetParticleControl(window, 3, WINDOW_COLOR)
		ParticleManager:SetParticleControl(window, 9, Vector(radius, 0, 0))
		ParticleManager:SetParticleControl(window, 11, Vector(0, 0, 1))
		ParticleManager:SetParticleControl(window, 17, Vector(duration, windowFrom, 0))
	end

	self._rings[name] = { ring = ring, clock = clock, window = window }
end

-- immediate - убрать без эффекта исчезновения. На респавне эффект, наоборот,
-- к месту: круг вспыхивает ровно тогда, когда появляются крипы.
function CampRespawnRing:Stop(name, immediate)
	local entry = self._rings[name]
	if not entry then return end

	self._rings[name] = nil

	DestroyFx(entry.clock, immediate == true)
	DestroyFx(entry.ring, immediate == true)

	if entry.window then
		DestroyFx(entry.window, immediate == true)
	end
end

function CampRespawnRing:StopAll()
	for name, _ in pairs(self._rings) do
		self:Stop(name, true)
	end
end
