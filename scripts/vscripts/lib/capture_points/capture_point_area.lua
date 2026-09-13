--[[
	Модификатор круга захвата (lib/capture_points). Правила и числа - из
	frontier, без их полёта круга, батлпасса и амулетов.

	Каждый кадр смотрим, кто стоит в круге:
	  * одна команда - прогресс растёт; время захвата у типа круга, каждый
	    лишний герой той же команды +50% к скорости;
	  * прогресс чужой - сперва сжигаем его до нуля, потом круг наш;
	  * две команды - спор: прогресс стоит, а если хозяина прогресса в круге
	    нет - тает;
	  * в круге пусто - прогресс медленно тает.
	Считаются только настоящие герои: без иллюзий, Tempest Double, солдат
	Monkey King и призрака WK после аганима. Meepo со всеми клонами и
	Brewmaster с пандами идут за одного.

	Заполнилось - CapturePoints:OnCaptured отдаёт руну команде и убирает круг.
]]

require("lib/capture_points/capture_points_declarations")

capture_point_area = capture_point_area or class({})

-- одна команда в круге / каждый лишний её герой
local RATE_CAPTURE = 1
local RATE_PER_EXTRA_HERO = 0.5
-- пустой круг тает с этой скоростью; чужой прогресс сжигается с ней же
-- плюс по единице за каждого героя в круге
local RATE_DECAY = 0.5

function capture_point_area:IsHidden() return true end
function capture_point_area:IsPurgable() return false end

function capture_point_area:CheckState()
	return {
		[MODIFIER_STATE_UNSELECTABLE] = true,
		[MODIFIER_STATE_ATTACK_IMMUNE] = true,
		[MODIFIER_STATE_MAGIC_IMMUNE] = true,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_OUT_OF_GAME] = true,
		[MODIFIER_STATE_NOT_ON_MINIMAP] = true,
	}
end

function capture_point_area:OnCreated(kv)
	if not IsServer() then return end

	self.def = CAPTURE_POINT_TYPES[kv.capture_type]
	if not self.def then return end

	local parent = self:GetParent()

	self.center = parent:GetAbsOrigin()
	self.progress = 0
	self.current_team = DOTA_TEAM_NEUTRALS
	self.heroes_in_radius = {}

	self.ring_fx = ParticleManager:CreateParticle(CAPTURE_POINT_RING, PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:SetParticleControlEnt(self.ring_fx, 0, parent, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", GetGroundPosition(self.center, parent), true)
	ParticleManager:SetParticleControl(self.ring_fx, 3, self.def.color)
	ParticleManager:SetParticleControl(self.ring_fx, 9, Vector(CAPTURE_POINT_RADIUS, 0, 0))

	self:StartIntervalThink(0)
end

function capture_point_area:OnIntervalThink()
	if self.done then return end
	if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then return end

	local parent = self:GetParent()
	local byTeam, total = self:_FindCapturers()

	self.heroes_in_radius = byTeam

	local teams, onlyTeam = 0, DOTA_TEAM_NEUTRALS

	for team, _ in pairs(byTeam) do
		teams = teams + 1
		onlyTeam = team
	end

	local capturing = teams == 1

	if self.capturing ~= capturing then
		self.capturing = capturing

		if capturing then
			parent:EmitSound(CAPTURE_POINT_START_SOUND)
		else
			parent:StopSound(CAPTURE_POINT_START_SOUND)
		end
	end

	if teams > 1 then
		if not byTeam[self.current_team] then
			self:_AddProgress(-RATE_DECAY - total)
		end
	elseif capturing then
		if self.current_team == DOTA_TEAM_NEUTRALS then
			self.current_team = onlyTeam
			self:_UpdateRingColor()
		end

		if self.current_team ~= onlyTeam then
			self:_AddProgress(-RATE_DECAY - total)
		else
			self:_AddProgress(RATE_CAPTURE + (#byTeam[onlyTeam] - 1) * RATE_PER_EXTRA_HERO)

			if self.progress >= 1 then
				self:_Capture(onlyTeam)
				return
			end
		end
	elseif self.progress > 0 then
		self:_AddProgress(-RATE_DECAY)
	end

	-- прогресс кончился - круг снова ничей. Если его сжигали, на следующем
	-- кадре он перейдёт к тому, кто стоит внутри
	if self.progress <= 0 and self.current_team ~= DOTA_TEAM_NEUTRALS then
		self.current_team = DOTA_TEAM_NEUTRALS
		self:_UpdateRingColor()
	end

	self:_UpdateClock(capturing)
end

function capture_point_area:_AddProgress(rate)
	local progress = self.progress + GameRules:GetGameFrameTime() * rate / self.def.capture_time

	self.progress = math.max(0, math.min(1, progress))
end

function capture_point_area:_Capture(team)
	self.done = true
	self:StartIntervalThink(-1)

	CapturePoints:OnCaptured(self:GetParent(), self.heroes_in_radius[team])
end

function capture_point_area:_UpdateRingColor()
	local color = CAPTURE_POINT_TEAM_COLORS[self.current_team] or self.def.color

	ParticleManager:SetParticleControl(self.ring_fx, 3, color)
end

-- Свечение и часы появляются с первым захватом и дальше живут до конца круга.
-- Контрольные точки уходят по сети, поэтому шлём их, только когда значение
-- поменялось.
function capture_point_area:_UpdateClock(capturing)
	local color = CAPTURE_POINT_TEAM_COLORS[self.current_team]

	if capturing and color then
		local parent = self:GetParent()

		if not self.capturing_fx then
			self.capturing_fx = ParticleManager:CreateParticle(CAPTURE_POINT_RING_CAPTURING, PATTACH_ABSORIGIN, parent)
			ParticleManager:SetParticleControl(self.capturing_fx, 9, Vector(CAPTURE_POINT_RADIUS, 0, 0))
		end

		if not self.clock_fx then
			self.clock_fx = ParticleManager:CreateParticle(CAPTURE_POINT_RING_CLOCK, PATTACH_ABSORIGIN, parent)
			ParticleManager:SetParticleControl(self.clock_fx, 9, Vector(CAPTURE_POINT_RADIUS, 0, 0))
			ParticleManager:SetParticleControl(self.clock_fx, 11, Vector(0, 0, 1))
		end

		if self.fx_team ~= self.current_team then
			self.fx_team = self.current_team
			ParticleManager:SetParticleControl(self.capturing_fx, 3, color)
			ParticleManager:SetParticleControl(self.clock_fx, 3, color)
		end
	end

	if self.clock_fx and self.clock_progress ~= self.progress then
		self.clock_progress = self.progress
		ParticleManager:SetParticleControl(self.clock_fx, 17, Vector(self.progress, 0, 0))
	end
end

-- { [команда] = { герои } }, всего героев
function capture_point_area:_FindCapturers()
	local found = FindUnitsInRadius(
		DOTA_TEAM_NEUTRALS,
		self.center,
		nil,
		CAPTURE_POINT_RADIUS,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_INVULNERABLE,
		FIND_ANY_ORDER,
		false
	)

	local byTeam, total = {}, 0
	local meepoCounted, brewCounted = false, false

	for _, unit in pairs(found) do
		if self:_CanCapture(unit) then
			local isMeepo = unit:HasModifier("modifier_meepo_divided_we_stand")
			local isBrew = unit:GetUnitName():find("_brewmaster") ~= nil

			if (not isMeepo or not meepoCounted) and (not isBrew or not brewCounted) then
				local team = unit:GetTeamNumber()

				byTeam[team] = byTeam[team] or {}
				table.insert(byTeam[team], unit)
				total = total + 1
			end

			if isMeepo then meepoCounted = true end
			if isBrew then brewCounted = true end
		end
	end

	return byTeam, total
end

function capture_point_area:_CanCapture(unit)
	if unit:IsInvulnerable() and not unit:HasModifier("modifier_naga_siren_song_of_the_siren") then return false end
	if unit:HasModifier("modifier_ringmaster_the_box_buff") then return false end

	if unit:IsRealHero() then
		if unit:HasModifier("modifier_skeleton_king_reincarnation_scepter_active") then return false end
		if unit:IsTempestDouble() then return false end
		if unit:HasModifier("modifier_monkey_king_fur_army_soldier") then return false end
		if unit:HasModifier("modifier_wukongs_command_warrior") then return false end

		return true
	end

	-- панды Brewmaster после ульты считаются за героя
	return unit:GetUnitName():find("npc_dota_brewmaster_") ~= nil
end

function capture_point_area:OnDestroy()
	if not IsServer() then return end

	for _, fx in pairs({ self.clock_fx, self.capturing_fx, self.ring_fx }) do
		ParticleManager:DestroyParticle(fx, false)
		ParticleManager:ReleaseParticleIndex(fx)
	end

	local parent = self:GetParent()
	if not IsValidEntity(parent) then return end

	parent:StopSound(CAPTURE_POINT_START_SOUND)

	if self.captured and self.def then
		EmitSoundOnLocationWithCaster(parent:GetAbsOrigin(), self.def.finish_sound, parent)
	end
end
