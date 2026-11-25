-- Хранитель Часов (npc_aa_chronokeeper). Ключ: он оставляет тень и
-- возвращается в неё со старым здоровьем. Разбей тень - отката не будет.

require("creeps/boss/boss_kit")

LinkLuaModifier("modifier_chronokeeper_shadow", "creeps/boss/chronokeeper/chronokeeper_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chronokeeper_frozen", "creeps/boss/chronokeeper/chronokeeper_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chronokeeper_slow",   "creeps/boss/chronokeeper/chronokeeper_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chronokeeper_time_lock", "creeps/boss/chronokeeper/chronokeeper_abilities", LUA_MODIFIER_MOTION_NONE)

local SPHERE_FX   = "particles/units/heroes/hero_faceless_void/faceless_void_chronosphere.vpcf"
local PREIMAGE_FX = "particles/units/heroes/hero_faceless_void/faceless_void_time_walk_preimage.vpcf"
local WALK_FX     = "particles/units/heroes/hero_faceless_void/faceless_void_time_walk.vpcf"
local BACK_FX     = "particles/units/heroes/hero_faceless_void/faceless_void_backtrack.vpcf"
local SHATTER_FX  = "particles/units/heroes/hero_skeletonking/skeleton_king_death_bits.vpcf"

local function Flat(v)
	return Vector(v.x, v.y, 0)
end

--------------------------------------------------------------------------------
-- Тень прошлого
--------------------------------------------------------------------------------
chronokeeper_shadow = chronokeeper_shadow or class({})
local shadow = chronokeeper_shadow

function shadow:Precache(ctx)
	PrecacheUnitByNameSync("npc_aa_chronokeeper_shadow", ctx)
end

function shadow:OnSpellStart()
	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()

	local delay = self:GetSpecialValueFor("rewind_delay")
	local hits  = self:GetSpecialValueFor("hits")
	local count = 1
	if BossKit:Deaths(caster) >= self:GetSpecialValueFor("double_from_death") then count = 2 end

	local savedHp = caster:GetHealth()
	local shadows = {}
	local castAt = GameRules:GetGameTime()

	for i = 1, count do
		local pos = origin
		if i > 1 then pos = origin + RandomVector(self:GetSpecialValueFor("second_offset")) end
		pos = GetGroundPosition(pos, nil)

		local s = CreateUnitByName("npc_aa_chronokeeper_shadow", pos, false, nil, nil, caster:GetTeamNumber())
		if s then
			FindClearSpaceForUnit(s, pos, true)
			s:SetForwardVector(caster:GetForwardVector())
			s:AddNewModifier(caster, self, "modifier_chronokeeper_shadow", { duration = delay + 0.1 })
			BossKit:MakePips(s, caster, self, hits, function()
				local fx = ParticleManager:CreateParticle(SHATTER_FX, PATTACH_WORLDORIGIN, nil)
				ParticleManager:SetParticleControl(fx, 0, s:GetAbsOrigin())
				ParticleManager:ReleaseParticleIndex(fx)
				s:EmitSound("Hero_FacelessVoid.TimeLockImpact")
			end)

			-- часы над тенью: круг сжимается к моменту отката
			s.aa_clock = BossKit:Telegraph(s:GetAbsOrigin(), 140, delay)
			table.insert(shadows, s)
		end
	end

	caster:EmitSound("Hero_FacelessVoid.TimeDilation.Cast")

	Timers:CreateTimer(delay, function()
		local back

		for _, s in pairs(shadows) do
			if s and not s:IsNull() and s:IsAlive() then
				back = back or s:GetAbsOrigin()
			end
		end

		for _, s in pairs(shadows) do
			if s and not s:IsNull() then
				BossKit:StopParticle(s.aa_clock)
				if s:IsAlive() then UTIL_Remove(s) end
			end
		end

		if not back or caster:IsNull() or not caster:IsAlive() then return end
		-- за это время босс ушёл телепортом ротации - тень осталась на старом споте
		if (caster.aa_rotated_at or 0) > castAt then return end

		local fx = ParticleManager:CreateParticle(BACK_FX, PATTACH_ABSORIGIN, caster)
		ParticleManager:ReleaseParticleIndex(fx)

		FindClearSpaceForUnit(caster, back, true)
		caster:SetHealth(math.max(caster:GetHealth(), savedHp))
		-- откат во времени снимает и минус броню (диспел босса)
		BossKit:Dispel(caster)
		caster:EmitSound("Hero_FacelessVoid.TimeWalk")

		local fx2 = ParticleManager:CreateParticle(BACK_FX, PATTACH_ABSORIGIN, caster)
		ParticleManager:ReleaseParticleIndex(fx2)
	end)
end

modifier_chronokeeper_shadow = modifier_chronokeeper_shadow or class({})
local sm = modifier_chronokeeper_shadow

function sm:IsHidden()   return true end
function sm:IsPurgable() return false end
function sm:GetStatusEffectName() return "particles/status_fx/status_effect_faceless_chronosphere.vpcf" end
function sm:StatusEffectPriority() return 20 end

function sm:CheckState()
	return {
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_COMMAND_RESTRICTED] = true,
	}
end

function sm:OnCreated()
	if not IsServer() then return end
	self:GetParent():SetRenderAlpha(140)
	self:StartIntervalThink(0.25)
end

function sm:OnIntervalThink()
	local boss = self:GetCaster()
	if not boss or boss:IsNull() or not boss:IsAlive() then
		local p = self:GetParent()
		BossKit:StopParticle(p.aa_clock)
		UTIL_Remove(p)
	end
end

--------------------------------------------------------------------------------
-- Хроносфера: круг на 1 с, затем все внутри застывают. Босс - нет.
--------------------------------------------------------------------------------
chronokeeper_sphere = chronokeeper_sphere or class({})
local sphere = chronokeeper_sphere

function sphere:GetAOERadius() return self:GetSpecialValueFor("radius") end

function sphere:OnSpellStart()
	local caster = self:GetCaster()
	local pos    = GetGroundPosition(self:GetCursorPosition(), nil)
	local radius = self:GetSpecialValueFor("radius")
	local delay  = self:GetSpecialValueFor("delay")
	local dur    = self:GetSpecialValueFor("duration")

	BossKit:Telegraph(pos, radius, delay)

	Timers:CreateTimer(delay, function()
		if caster:IsNull() or not caster:IsAlive() then return end

		local fx = ParticleManager:CreateParticle(SPHERE_FX, PATTACH_WORLDORIGIN, nil)
		ParticleManager:SetParticleControl(fx, 0, pos)
		ParticleManager:SetParticleControl(fx, 1, Vector(radius, radius, radius))
		Timers:CreateTimer(dur, function()
			ParticleManager:DestroyParticle(fx, false)
			ParticleManager:ReleaseParticleIndex(fx)
		end)
		EmitSoundOnLocationWithCaster(pos, "Hero_FacelessVoid.Chronosphere", caster)

		for _, v in pairs(BossKit:Enemies(caster, pos, radius)) do
			v:AddNewModifier(caster, self, "modifier_chronokeeper_frozen", { duration = dur })
		end
	end)
end

modifier_chronokeeper_frozen = modifier_chronokeeper_frozen or class({})
local frozen = modifier_chronokeeper_frozen

function frozen:IsDebuff()   return true end
function frozen:IsPurgable() return false end
function frozen:GetTexture() return "faceless_void_chronosphere" end
function frozen:GetStatusEffectName() return "particles/status_fx/status_effect_faceless_chronosphere.vpcf" end
function frozen:StatusEffectPriority() return 15 end

function frozen:CheckState()
	return {
		[MODIFIER_STATE_STUNNED] = true,
		[MODIFIER_STATE_FROZEN] = true,
	}
end

--------------------------------------------------------------------------------
-- Рывок во времени: призрак показывает точку, через 0,6 с рывок по линии.
--------------------------------------------------------------------------------
chronokeeper_walk = chronokeeper_walk or class({})
local walk = chronokeeper_walk

function walk:_Target()
	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()
	local d = Flat(self:GetCursorPosition() - origin)
	local range = self:GetSpecialValueFor("range")
	if d:Length2D() > range then d = d:Normalized() * range end
	return GetGroundPosition(origin + d, nil)
end

function walk:OnAbilityPhaseStart()
	if not IsServer() then return true end
	local caster = self:GetCaster()
	self.to = self:_Target()

	self.pre = ParticleManager:CreateParticle(PREIMAGE_FX, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(self.pre, 0, caster:GetAbsOrigin())
	ParticleManager:SetParticleControl(self.pre, 1, self.to)
	ParticleManager:SetParticleControlForward(self.pre, 0, Flat(self.to - caster:GetAbsOrigin()):Normalized())

	self.mark = BossKit:TelegraphLine(caster:GetAbsOrigin(), self.to, self:GetSpecialValueFor("width"), nil)
	return true
end

function walk:OnAbilityPhaseInterrupted()
	BossKit:StopParticle(self.pre)
	BossKit:StopParticle(self.mark)
	self.pre, self.mark = nil, nil
end

function walk:OnSpellStart()
	BossKit:StopParticle(self.pre)
	BossKit:StopParticle(self.mark)
	self.pre, self.mark = nil, nil

	local caster = self:GetCaster()
	local from = caster:GetAbsOrigin()
	local to = self.to or self:_Target()
	local width = self:GetSpecialValueFor("width")

	local fx = ParticleManager:CreateParticle(WALK_FX, PATTACH_CUSTOMORIGIN, caster)
	ParticleManager:SetParticleControl(fx, 0, from)
	ParticleManager:SetParticleControl(fx, 1, to)
	ParticleManager:ReleaseParticleIndex(fx)
	caster:EmitSound("Hero_FacelessVoid.TimeWalk")

	for _, v in pairs(BossKit:Enemies(caster, (from + to) / 2, (to - from):Length2D() / 2 + width)) do
		if CalcDistanceToLineSegment2D(v:GetAbsOrigin(), from, to) <= width then
			BossKit:PctDamage(caster, self, v, self:GetSpecialValueFor("damage_pct"))
			v:AddNewModifier(caster, self, "modifier_chronokeeper_slow",
				{ duration = self:GetSpecialValueFor("slow_duration") * (1 - v:GetStatusResistance()) })
		end
	end

	FindClearSpaceForUnit(caster, to, true)
	caster:SetForwardVector(Flat(to - from):Normalized())
	ProjectileManager:ProjectileDodge(caster)
end

modifier_chronokeeper_slow = modifier_chronokeeper_slow or class({})
local slow = modifier_chronokeeper_slow

function slow:IsDebuff() return true end
function slow:GetTexture() return "faceless_void_time_walk" end
function slow:GetStatusEffectName() return "particles/status_fx/status_effect_faceless_chronosphere.vpcf" end
function slow:DeclareFunctions()
	return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE, MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT }
end
function slow:OnCreated()
	local a = self:GetAbility()
	self.ms = a and a:GetSpecialValueFor("slow_ms") or 0
	self.as = a and a:GetSpecialValueFor("slow_as") or 0
end
function slow:GetModifierMoveSpeedBonus_Percentage() return -self.ms end
function slow:GetModifierAttackSpeedBonus_Constant() return -self.as end

--------------------------------------------------------------------------------
-- Блокировка времени: как у Войда, баш с шансом. Урон в % от макс. HP цели,
-- чтобы броня не спасала. Застывших в хроносфере бьёт всегда.
--------------------------------------------------------------------------------
chronokeeper_time_lock = chronokeeper_time_lock or class({})
function chronokeeper_time_lock:GetIntrinsicModifierName() return "modifier_chronokeeper_time_lock" end

modifier_chronokeeper_time_lock = modifier_chronokeeper_time_lock or class({})
local tl = modifier_chronokeeper_time_lock

function tl:IsHidden()   return true end
function tl:IsPurgable() return false end
function tl:DeclareFunctions() return { MODIFIER_EVENT_ON_ATTACK_LANDED } end

function tl:OnAttackLanded(params)
	if not IsServer() then return end
	local p = self:GetParent()
	if params.attacker ~= p then return end
	local t = params.target
	if not t or t:IsNull() or t:IsBuilding() or t:GetTeamNumber() == p:GetTeamNumber() then return end

	local ab = self:GetAbility()
	local frozen = t:HasModifier("modifier_chronokeeper_frozen")
	if not frozen and not RollPseudoRandomPercentage(ab:GetSpecialValueFor("chance"), DOTA_PSEUDO_RANDOM_CUSTOM_GAME_1, p) then return end

	BossKit:PctDamage(p, ab, t, ab:GetSpecialValueFor("damage_pct"))
	if not frozen then
		t:AddNewModifier(p, ab, "modifier_stunned", { duration = ab:GetSpecialValueFor("stun") * (1 - t:GetStatusResistance()) })
	end

	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_faceless_void/faceless_void_time_lock_bash.vpcf", PATTACH_ABSORIGIN, t)
	ParticleManager:SetParticleControl(fx, 0, t:GetAbsOrigin())
	ParticleManager:SetParticleControl(fx, 1, t:GetAbsOrigin())
	ParticleManager:SetParticleControlEnt(fx, 2, p, PATTACH_CUSTOMORIGIN, "attach_hitloc", p:GetAbsOrigin(), true)
	ParticleManager:ReleaseParticleIndex(fx)
	t:EmitSound("Hero_FacelessVoid.TimeLockImpact")
end
