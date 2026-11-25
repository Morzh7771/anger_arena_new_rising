-- Новые скиллы Possessed (Дум), по мотивам Дума из Angel Arena Frontier:
-- огненные стены с проходом, отброс по кругу, рывок по видимой дорожке,
-- пробуждение на половине здоровья. Всё объявлено заранее на земле.

require("creeps/boss/boss_kit")

LinkLuaModifier("modifier_possessed_charge_move", "creeps/boss/possessed/possessed_inferno", LUA_MODIFIER_MOTION_HORIZONTAL)
LinkLuaModifier("modifier_possessed_awaken_watch", "creeps/boss/possessed/possessed_inferno", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_possessed_awaken",       "creeps/boss/possessed/possessed_inferno", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_possessed_awaken_aura",  "creeps/boss/possessed/possessed_inferno", LUA_MODIFIER_MOTION_NONE)

local WALL_PRE_FX  = "particles/econ/items/lina/lina_ti7/light_strike_array_pre_ti7.vpcf"
local WALL_HIT_FX  = "particles/econ/items/lina/lina_ti7/lina_spell_light_strike_array_ti7.vpcf"
local BASH_FX      = "particles/units/heroes/hero_mars/mars_shield_bash.vpcf"
local CHARGE_FX    = "particles/units/heroes/hero_primal_beast/primal_beast_onslaught_charge_active.vpcf"
local AWAKEN_FX    = "particles/units/heroes/hero_doom_bringer/doom_bringer_doom_aura.vpcf"
local SCORCH_FX    = "particles/units/heroes/hero_doom_bringer/doom_scorched_earth.vpcf"

local function Flat(v)
	return Vector(v.x, v.y, 0)
end

local function Awake(unit)
	return unit:HasModifier("modifier_possessed_awaken")
end

--------------------------------------------------------------------------------
-- Огненная стена: волны огня одна за другой идут от Дума вперёд.
-- В каждой стене один проход - его видно по разметке.
--------------------------------------------------------------------------------
possessed_flame_wall = possessed_flame_wall or class({})
local wall = possessed_flame_wall

function wall:OnSpellStart()
	local caster  = self:GetCaster()
	local origin  = caster:GetAbsOrigin()
	local forward = Flat(caster:GetForwardVector()):Normalized()
	local right   = Vector(-forward.y, forward.x, 0)

	local waves = self:GetSpecialValueFor("waves")
	if Awake(caster) then waves = self:GetSpecialValueFor("waves_awaken") end

	local step     = self:GetSpecialValueFor("step")
	local interval = self:GetSpecialValueFor("interval")

	caster:EmitSound("Hero_DoomBringer.ScorchedEarthAura")

	for i = 1, waves do
		Timers:CreateTimer(interval * (i - 1), function()
			if caster:IsNull() or not caster:IsAlive() then return end
			self:_Wall(origin + forward * step * i, right)
		end)
	end
end

function wall:_Wall(center, right)
	local caster = self:GetCaster()
	local side   = self:GetSpecialValueFor("side_segments")
	local offset = self:GetSpecialValueFor("segment_offset")
	local radius = self:GetSpecialValueFor("segment_radius")
	local delay  = self:GetSpecialValueFor("delay")
	local dmg    = self:GetSpecialValueFor("damage_pct")
	local stun   = self:GetSpecialValueFor("stun")

	-- проход: один случайный сегмент стены не горит
	local gap = RandomInt(-side, side)

	for s = -side, side do
		if s ~= gap then
			local pos = GetGroundPosition(center + right * offset * s, nil)

			local pre = ParticleManager:CreateParticle(WALL_PRE_FX, PATTACH_WORLDORIGIN, nil)
			ParticleManager:SetParticleControl(pre, 0, pos)
			ParticleManager:SetParticleControl(pre, 1, Vector(radius, 1, 1))
			ParticleManager:ReleaseParticleIndex(pre)

			Timers:CreateTimer(delay, function()
				if caster:IsNull() or not caster:IsAlive() or self:IsNull() then return end

				local fx = ParticleManager:CreateParticle(WALL_HIT_FX, PATTACH_WORLDORIGIN, nil)
				ParticleManager:SetParticleControl(fx, 0, pos)
				ParticleManager:SetParticleControl(fx, 1, Vector(radius, 1, 1))
				ParticleManager:ReleaseParticleIndex(fx)

				for _, v in pairs(BossKit:Enemies(caster, pos, radius)) do
					BossKit:PctDamage(caster, self, v, dmg)
					v:AddNewModifier(caster, self, "modifier_stunned", { duration = stun * (1 - v:GetStatusResistance()) })
				end
			end)
		end
	end

	EmitSoundOnLocationWithCaster(center, "Hero_DoomBringer.InfernalBlade.PreAttack", caster)
end

--------------------------------------------------------------------------------
-- Адский отброс: круг вокруг Дума, через замах всех внутри отбрасывает
-- к краю и оглушает. Отойди сам - не полетишь.
--------------------------------------------------------------------------------
possessed_sweep = possessed_sweep or class({})
local sweep = possessed_sweep

function sweep:OnAbilityPhaseStart()
	if not IsServer() then return true end
	self.mark = BossKit:Telegraph(self:GetCaster():GetAbsOrigin(), self:GetSpecialValueFor("radius"), self:GetCastPoint())
	self:GetCaster():EmitSound("Hero_DoomBringer.InfernalBlade.PreAttack")
	return true
end

function sweep:OnAbilityPhaseInterrupted()
	BossKit:StopParticle(self.mark)
	self.mark = nil
end

function sweep:OnSpellStart()
	self.mark = nil

	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()
	local radius = self:GetSpecialValueFor("radius")
	local push   = self:GetSpecialValueFor("push_duration")

	for _, v in pairs(BossKit:Enemies(caster, origin, radius)) do
		BossKit:PctDamage(caster, self, v, self:GetSpecialValueFor("damage_pct"))

		local dist = (v:GetAbsOrigin() - origin):Length2D()
		v:AddNewModifier(caster, self, "modifier_knockback", {
			center_x = origin.x, center_y = origin.y, center_z = origin.z,
			knockback_duration = push,
			knockback_distance = math.max(100, radius - dist + 150),
			knockback_height = 60,
			should_stun = 1,
			duration = push,
		})

		local stun = self:GetSpecialValueFor("stun") * (1 - v:GetStatusResistance())
		Timers:CreateTimer(push, function()
			if v and not v:IsNull() and v:IsAlive() then
				v:AddNewModifier(caster, self, "modifier_stunned", { duration = stun })
			end
		end)
	end

	for _, d in pairs({ Vector(1, 0, 0), Vector(0, 1, 0), Vector(-1, 0, 0), Vector(0, -1, 0) }) do
		local fx = ParticleManager:CreateParticle(BASH_FX, PATTACH_WORLDORIGIN, nil)
		ParticleManager:SetParticleControl(fx, 0, origin)
		ParticleManager:SetParticleControlForward(fx, 0, d)
		ParticleManager:SetParticleControl(fx, 1, Vector(radius, radius, radius))
		ParticleManager:ReleaseParticleIndex(fx)
	end

	caster:EmitSound("Hero_DoomBringer.InfernalBlade.Target")
end

--------------------------------------------------------------------------------
-- Рывок: дорожка огненных кругов показывает путь, затем Дум несётся по ней.
-- Кого задел - урон и отброс в сторону.
--------------------------------------------------------------------------------
possessed_charge = possessed_charge or class({})
local charge = possessed_charge

function charge:_Path()
	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()
	local dir = Flat(self:GetCursorPosition() - origin)
	if dir:Length2D() < 1 then dir = Flat(caster:GetForwardVector()) end
	return origin, dir:Normalized()
end

function charge:OnAbilityPhaseStart()
	if not IsServer() then return true end
	local origin, dir = self:_Path()
	local dist   = self:GetSpecialValueFor("distance")
	local radius = self:GetSpecialValueFor("hit_radius")

	self.dir = dir
	self.marks = { BossKit:TelegraphLine(origin, origin + dir * dist, radius, nil) }

	self:GetCaster():EmitSound("Hero_DoomBringer.Doom")
	return true
end

function charge:OnAbilityPhaseInterrupted()
	for _, m in pairs(self.marks or {}) do BossKit:StopParticle(m) end
	self.marks = nil
end

function charge:OnSpellStart()
	for _, m in pairs(self.marks or {}) do BossKit:StopParticle(m) end
	self.marks = nil
	local caster = self:GetCaster()
	local _, dir = self:_Path()
	dir = self.dir or dir

	local speed = self:GetSpecialValueFor("speed")
	caster:SetForwardVector(dir)
	caster:AddNewModifier(caster, self, "modifier_possessed_charge_move",
		{ duration = self:GetSpecialValueFor("distance") / speed, dx = dir.x, dy = dir.y })
end

modifier_possessed_charge_move = modifier_possessed_charge_move or class({})
local cm = modifier_possessed_charge_move

function cm:IsHidden()   return true end
function cm:IsPurgable() return false end
function cm:GetEffectName() return CHARGE_FX end
function cm:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function cm:CheckState()
	return {
		[MODIFIER_STATE_DEBUFF_IMMUNE] = true,
		[MODIFIER_STATE_UNSLOWABLE] = true,
		[MODIFIER_STATE_COMMAND_RESTRICTED] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
	}
end

function cm:DeclareFunctions()
	return { MODIFIER_PROPERTY_OVERRIDE_ANIMATION, MODIFIER_PROPERTY_DISABLE_TURNING }
end
function cm:GetOverrideAnimation() return ACT_DOTA_RUN end
function cm:GetModifierDisableTurning() return 1 end

function cm:OnCreated(kv)
	if not IsServer() then return end
	local ab = self:GetAbility()
	self.dir    = Vector(kv.dx, kv.dy, 0)
	self.speed  = ab:GetSpecialValueFor("speed")
	self.radius = ab:GetSpecialValueFor("hit_radius")
	self.dmg    = ab:GetSpecialValueFor("damage_pct")
	self.push   = ab:GetSpecialValueFor("push_duration")
	self.hit    = {}
	if not self:ApplyHorizontalMotionController() then self:Destroy() end
end

function cm:OnDestroy()
	if not IsServer() then return end
	local p = self:GetParent()
	p:RemoveHorizontalMotionController(self)
	FindClearSpaceForUnit(p, p:GetAbsOrigin(), true)
end

function cm:UpdateHorizontalMotion(unit, dt)
	local cur  = unit:GetAbsOrigin()
	local next = cur + self.dir * self.speed * dt

	-- в стену или обрыв не бежим
	if not GridNav:IsTraversable(next) or GridNav:IsBlocked(next)
		or math.abs(GetGroundHeight(next, unit) - GetGroundHeight(cur, unit)) > 32 then
		self:Destroy()
		return
	end

	unit:SetOrigin(next)

	local ab = self:GetAbility()
	for _, v in pairs(BossKit:Enemies(unit, next, self.radius)) do
		local id = v:entindex()
		if not self.hit[id] then
			self.hit[id] = true
			BossKit:PctDamage(unit, ab, v, self.dmg)

			-- отбрасывает вбок от линии рывка
			local side = Vector(-self.dir.y, self.dir.x, 0)
			if (v:GetAbsOrigin() - next):Dot(side) < 0 then side = -side end
			local c = v:GetAbsOrigin() - side * 100

			v:AddNewModifier(unit, ab, "modifier_knockback", {
				center_x = c.x, center_y = c.y, center_z = c.z,
				knockback_duration = self.push,
				knockback_distance = 350,
				knockback_height = 80,
				should_stun = 1,
				duration = self.push,
			})
			v:EmitSound("Hero_DoomBringer.Attack.Impact")
		end
	end
end

--------------------------------------------------------------------------------
-- Пробуждение: на половине здоровья Дум вспыхивает до конца жизни.
-- Вплотную к нему - немота, атакует быстрее, стен больше.
--------------------------------------------------------------------------------
possessed_awaken = possessed_awaken or class({})
function possessed_awaken:GetIntrinsicModifierName() return "modifier_possessed_awaken_watch" end

modifier_possessed_awaken_watch = modifier_possessed_awaken_watch or class({})
local watch = modifier_possessed_awaken_watch

function watch:IsHidden()   return true end
function watch:IsPurgable() return false end

function watch:DeclareFunctions() return { MODIFIER_EVENT_ON_TAKEDAMAGE } end

function watch:OnTakeDamage(params)
	if not IsServer() then return end
	local p = self:GetParent()
	if params.unit ~= p or self.done then return end
	if p:GetHealthPercent() > self:GetAbility():GetSpecialValueFor("hp_pct") then return end

	self.done = true
	p:AddNewModifier(p, self:GetAbility(), "modifier_possessed_awaken", {})

	local fx = ParticleManager:CreateParticle(SCORCH_FX, PATTACH_ABSORIGIN_FOLLOW, p)
	ParticleManager:ReleaseParticleIndex(fx)
	p:EmitSound("Hero_DoomBringer.Doom.Self")
end

modifier_possessed_awaken = modifier_possessed_awaken or class({})
local aw = modifier_possessed_awaken

function aw:IsHidden()   return false end
function aw:IsPurgable() return false end
function aw:GetTexture() return "doom_bringer_doom" end
function aw:GetEffectName() return AWAKEN_FX end
function aw:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function aw:IsAura() return true end
function aw:GetAuraRadius() return self:GetAbility():GetSpecialValueFor("aura_radius") end
function aw:GetAuraSearchTeam() return DOTA_UNIT_TARGET_TEAM_ENEMY end
function aw:GetAuraSearchType() return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end
function aw:GetModifierAura() return "modifier_possessed_awaken_aura" end

function aw:DeclareFunctions() return { MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT } end
function aw:GetModifierAttackSpeedBonus_Constant()
	return self:GetAbility():GetSpecialValueFor("attack_speed")
end

modifier_possessed_awaken_aura = modifier_possessed_awaken_aura or class({})
local aa = modifier_possessed_awaken_aura

function aa:IsDebuff() return true end
function aa:GetTexture() return "doom_bringer_doom" end
function aa:GetEffectName() return "particles/generic_gameplay/generic_silenced.vpcf" end
function aa:GetEffectAttachType() return PATTACH_OVERHEAD_FOLLOW end
function aa:CheckState() return { [MODIFIER_STATE_SILENCED] = true } end
