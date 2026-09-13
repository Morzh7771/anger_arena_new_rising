-- Всё, что про круги захвата знают и сервер (capture_points.lua), и
-- модификатор круга (capture_point_area.lua) - а он грузится и на клиенте,
-- поэтому без IsServer. Числа и цвета - как во frontier, откуда механика.

CAPTURE_POINT_RADIUS = 300

CAPTURE_POINT_TYPES = {
	bounty = {
		rune = DOTA_RUNE_BOUNTY,
		capture_time = 4,
		color = Vector(255, 204, 51),
		particle = "particles/capture_points/bounty_rune_fx.vpcf",
		finish_sound = "AA.CapturePoint.Finish",
	},
	wisdom = {
		rune = DOTA_RUNE_XP,
		capture_time = 6,
		color = Vector(107, 41, 255),
		particle = "particles/capture_points/wisdom_rune_fx.vpcf",
		finish_sound = "AA.CapturePoint.FinishWisdom",
	},
}

-- цвет кольца и часов, пока круг захватывает команда
CAPTURE_POINT_TEAM_COLORS = {
	[DOTA_TEAM_GOODGUYS] = Vector(73, 199, 120),
	[DOTA_TEAM_BADGUYS]  = Vector(214, 56, 55),
}

CAPTURE_POINT_RING           = "particles/capture_point_ring/capture_point_ring.vpcf"
CAPTURE_POINT_RING_CAPTURING = "particles/capture_point_ring/capture_point_ring_capturing.vpcf"
-- часы: CP17.x - заполненность 0..1, CP3 - цвет, CP9 - радиус
CAPTURE_POINT_RING_CLOCK     = "particles/capture_point_ring/capture_point_ring_clock.vpcf"

CAPTURE_POINT_START_SOUND = "AA.CapturePoint.Start"
