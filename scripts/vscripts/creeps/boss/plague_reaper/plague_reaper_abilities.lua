-- Чумной Жнец (npc_aa_plague_reaper). Ключ: он добивает слабого. Держи HP
-- выше и не стой один - метка делит урон на всех, кто рядом.

require("creeps/boss/boss_kit")

LinkLuaModifier("modifier_plague_reaper_mark",       "creeps/boss/plague_reaper/plague_reaper_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_plague_reaper_aura",       "creeps/boss/plague_reaper/plague_reaper_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_plague_reaper_aura_debuff","creeps/boss/plague_reaper/plague_reaper_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_plague_reaper_shroud",     "creeps/boss/plague_reaper/plague_reaper_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_plague_reaper_shroud_slow","creeps/boss/plague_reaper/plague_reaper_abilities", LUA_MODIFIER_MOTION_NONE)

local SCYTHE_START_FX = "particles/units/heroes/hero_necrolyte/necrolyte_scythe_start.vpcf"
local SCYTHE_FX       = "particles/units/heroes/hero_necrolyte/necrolyte_scythe.vpcf"
local WAVE_FX         = "particles/units/heroes/hero_necrolyte/necrolyte_death_seeker_linear_enemy.vpcf"
local AMBIENT_FX      = "particles/units/heroes/hero_necrolyte/necrolyte_ambient_glow.vpcf"

--------------------------------------------------------------------------------
-- Метка жатвы: коса над самым слабым героем, через N с удар.
-- Урон делится на всех героев в круге вокруг меченого.
--------------------------------------------------------------------------------
plague_reaper_mark = plague_reaper_mark or class({})
local mark = plague_reaper_mark

function mark:_FindVictim()
	local caster = self:GetCaster()
	local best, bestPct

	for _, h in pairs(BossKit:EnemyHeroes(caster, caster:GetAbsOrigin(), self:GetSpecialValueFor("search_radius"))) do
		if h:IsAlive() and caster:CanEntityBeSeenByMyTeam(h) then
			local pct = h:GetHealthPercent()
			if not bestPct or pct < bestPct then best, bestPct = h, pct end
		end
	end

	return best
end

-- AI зовёт перед кастом: есть ли кого метить
function mark:HasVictim()
	return self:_FindVictim() ~= nil
end

function mark:OnSpellStart()
	local caster = self:GetCaster()
	local victim = self:_FindVictim()
	if not victim then return end

	local delay = math.max(self:GetSpecialValueFor("delay_min"),
		self:GetSpecialValueFor("delay") - self:GetSpecialValueFor("delay_per_death") * BossKit:Deaths(caster))

	victim:AddNewModifier(caster, self, "modifier_plague_reaper_mark", { duration = delay })
	caster:EmitSound("Hero_Necrolyte.ReapersScythe.Cast")
end

modifier_plague_reaper_mark = modifier_plague_reaper_mark or class({})
local mm = modifier_plague_reaper_mark

function mm:IsDebuff()   return true end
function mm:IsPurgable() return false end
function mm:GetTexture() return "necrolyte_reapers_scythe" end

function mm:OnCreated()
	if not IsServer() then return end
	local p = self:GetParent()
	local radius = self:GetAbility():GetSpecialValueFor("share_radius")

	self.ring = BossKit:TelegraphFollow(p, radius, self:GetDuration())
	self.scythe = ParticleManager:CreateParticle(SCYTHE_START_FX, PATTACH_ABSORIGIN_FOLLOW, p)
	ParticleManager:SetParticleControlEnt(self.scythe, 0, p, PATTACH_ABSORIGIN_FOLLOW, nil, p:GetAbsOrigin(), true)
	ParticleManager:SetParticleControlEnt(self.scythe, 1, p, PATTACH_ABSORIGIN_FOLLOW, nil, p:GetAbsOrigin(), true)
	p:EmitSound("Hero_Necrolyte.ReapersScythe.Target")

	-- удар по своему таймеру: проверка остатка времени в OnDestroy на
	-- естественном истечении срабатывала не всегда, и коса не била
	self:StartIntervalThink(math.max(0.03, self:GetDuration() - 0.03))
end

function mm:OnIntervalThink()
	self:StartIntervalThink(-1)
	self:Strike()
	self:Destroy()
end

function mm:OnDestroy()
	if not IsServer() then return end
	BossKit:StopParticle(self.ring)
	BossKit:StopParticle(self.scythe)
end

function mm:Strike()
	if self.struck then return end
	self.struck = true

	local p = self:GetParent()
	local caster = self:GetCaster()
	local ab = self:GetAbility()

	if not p:IsAlive() or not caster or caster:IsNull() or not caster:IsAlive() or not ab or ab:IsNull() then return end

	local radius = ab:GetSpecialValueFor("share_radius")
	local total  = p:GetMaxHealth() * ab:GetSpecialValueFor("damage_pct") / 100

	local share = BossKit:EnemyHeroes(caster, p:GetAbsOrigin(), radius)
	if #share == 0 then share = { p } end

	local each = total / #share

	for _, h in pairs(share) do
		ApplyDamage({
			victim = h,
			attacker = caster,
			damage = each,
			damage_type = DAMAGE_TYPE_PURE,
			damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,
			ability = ab,
		})
	end

	local fx = ParticleManager:CreateParticle(SCYTHE_FX, PATTACH_ABSORIGIN_FOLLOW, p)
	ParticleManager:SetParticleControlEnt(fx, 0, caster, PATTACH_POINT_FOLLOW, "attach_attack1", caster:GetAbsOrigin(), true)
	ParticleManager:SetParticleControlEnt(fx, 1, p, PATTACH_POINT_FOLLOW, "attach_hitloc", p:GetAbsOrigin(), true)
	ParticleManager:ReleaseParticleIndex(fx)
end

--------------------------------------------------------------------------------
-- Чумная волна: поток черепов из Жнеца медленно проворачивается по кругу,
-- как стрелка часов. Попал - урон и Жнец лечится.
--------------------------------------------------------------------------------
plague_reaper_wave = plague_reaper_wave or class({})
local wave = plague_reaper_wave

-- красная линия на замахе: откуда пойдёт поток
function wave:OnAbilityPhaseStart()
	if not IsServer() then return true end
	local c = self:GetCaster()
	local f = c:GetForwardVector()
	f = Vector(f.x, f.y, 0):Normalized()
	self.line = BossKit:TelegraphLine(c:GetAbsOrigin(), c:GetAbsOrigin() + f * self:GetSpecialValueFor("range"), self:GetSpecialValueFor("width"), nil)
	return true
end

function wave:OnAbilityPhaseInterrupted()
	BossKit:StopParticle(self.line)
	self.line = nil
end

function wave:OnSpellStart()
	BossKit:StopParticle(self.line)
	self.line = nil
	local caster = self:GetCaster()

	local duration = self:GetSpecialValueFor("duration")
	local interval = self:GetSpecialValueFor("interval")
	local turn     = self:GetSpecialValueFor("turn_degrees")
	local speed    = self:GetSpecialValueFor("speed")
	local range    = self:GetSpecialValueFor("range")
	local width    = self:GetSpecialValueFor("width")

	local rays = 1
	if BossKit:Deaths(caster) >= self:GetSpecialValueFor("double_from_death") then rays = 2 end

	local fwd = caster:GetForwardVector()
	local dir = RandomInt(0, 1) == 0 and 1 or -1
	local steps = math.floor(duration / interval)
	local step = 0

	caster:EmitSound("Hero_Necrolyte.DeathPulse")

	Timers:CreateTimer(0, function()
		if caster:IsNull() or not caster:IsAlive() then return end
		step = step + 1
		if step > steps then return end

		local base = dir * turn * step / steps

		for r = 1, rays do
			local d = RotatePosition(Vector(0, 0, 0), QAngle(0, base + (r - 1) * 180, 0), fwd)
			d = Vector(d.x, d.y, 0):Normalized()

			ProjectileManager:CreateLinearProjectile({
				Ability = self,
				EffectName = WAVE_FX,
				vSpawnOrigin = caster:GetAbsOrigin(),
				fDistance = range,
				fStartRadius = width,
				fEndRadius = width,
				Source = caster,
				iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
				iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
				iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
				vVelocity = d * speed,
			})
		end

		return interval
	end)
end

function wave:OnProjectileHit(target, location)
	if not target then return true end
	local caster = self:GetCaster()
	if caster:IsNull() or not caster:IsAlive() then return true end

	BossKit:PctDamage(caster, self, target, self:GetSpecialValueFor("damage_pct"))
	if target:IsHero() then
		caster:Heal(caster:GetMaxHealth() * self:GetSpecialValueFor("heal_pct") / 100, self)
	end
	target:EmitSound("Hero_Necrolyte.ProjectileImpact")
	return true
end

--------------------------------------------------------------------------------
-- Аура тлена: рядом с Жнецом лечение героев хуже. Отошёл - лечись.
--------------------------------------------------------------------------------
plague_reaper_decay = plague_reaper_decay or class({})
function plague_reaper_decay:GetIntrinsicModifierName() return "modifier_plague_reaper_aura" end

modifier_plague_reaper_aura = modifier_plague_reaper_aura or class({})
local aura = modifier_plague_reaper_aura

function aura:IsHidden()   return true end
function aura:IsPurgable() return false end
function aura:IsAura()     return true end
function aura:GetAuraRadius() return self:GetAbility():GetSpecialValueFor("radius") end
function aura:GetAuraSearchTeam()  return DOTA_UNIT_TARGET_TEAM_ENEMY end
function aura:GetAuraSearchType()  return DOTA_UNIT_TARGET_HERO end
function aura:GetModifierAura()    return "modifier_plague_reaper_aura_debuff" end
function aura:GetEffectName() return AMBIENT_FX end
function aura:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

modifier_plague_reaper_aura_debuff = modifier_plague_reaper_aura_debuff or class({})
local ad = modifier_plague_reaper_aura_debuff

function ad:IsDebuff() return true end
function ad:GetTexture() return "necrolyte_heartstopper_aura" end

function ad:OnCreated()
	local ab = self:GetAbility()
	self.cut = ab and -ab:GetSpecialValueFor("heal_reduction") or 0
end

function ad:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_HEAL_AMPLIFY_PERCENTAGE_TARGET,
		MODIFIER_PROPERTY_HP_REGEN_AMPLIFY_PERCENTAGE,
	}
end

function ad:GetModifierHealAmplify_PercentageTarget() return self.cut end
function ad:GetModifierHPRegenAmplify_Percentage() return self.cut end

--------------------------------------------------------------------------------
-- Призрачный покров (Ghost Shroud): замах 1 с со свечением, затем снимает
-- дебафы и на duration с бесплотен: не бьёт, физический урон не проходит,
-- рядом замедляет. Минус броню вешать после покрова.
--------------------------------------------------------------------------------
plague_reaper_shroud = plague_reaper_shroud or class({})
local shroud = plague_reaper_shroud

function shroud:OnAbilityPhaseStart()
	if not IsServer() then return true end
	local c = self:GetCaster()
	self.fx = ParticleManager:CreateParticle("particles/units/heroes/hero_necrolyte/necrolyte_spirit.vpcf", PATTACH_ABSORIGIN_FOLLOW, c)
	c:EmitSound("Hero_Necrolyte.SpiritForm.Cast")
	return true
end

function shroud:OnAbilityPhaseInterrupted()
	BossKit:StopParticle(self.fx)
	self.fx = nil
end

function shroud:OnSpellStart()
	BossKit:StopParticle(self.fx)
	self.fx = nil
	local c = self:GetCaster()
	BossKit:Dispel(c)
	c:AddNewModifier(c, self, "modifier_plague_reaper_shroud", { duration = self:GetSpecialValueFor("duration") })
end

modifier_plague_reaper_shroud = modifier_plague_reaper_shroud or class({})
local sh = modifier_plague_reaper_shroud

function sh:IsPurgable() return false end
function sh:GetTexture() return "necrolyte_sadist" end
-- бесплотность должна читаться сразу: призрачный статус-эффект как у Ghost Scepter
-- и свечение духа на всё время покрова
function sh:GetStatusEffectName() return "particles/status_fx/status_effect_ghost.vpcf" end
function sh:StatusEffectPriority() return 20 end
function sh:GetEffectName() return "particles/units/heroes/hero_necrolyte/necrolyte_spirit.vpcf" end
function sh:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end
function sh:CheckState()
	return { [MODIFIER_STATE_ATTACK_IMMUNE] = true, [MODIFIER_STATE_DISARMED] = true }
end
function sh:DeclareFunctions() return { MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL } end
function sh:GetAbsoluteNoDamagePhysical() return 1 end

function sh:IsAura() return true end
function sh:GetAuraRadius() return self:GetAbility():GetSpecialValueFor("slow_radius") end
function sh:GetAuraSearchTeam() return DOTA_UNIT_TARGET_TEAM_ENEMY end
function sh:GetAuraSearchType() return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end
function sh:GetModifierAura() return "modifier_plague_reaper_shroud_slow" end

modifier_plague_reaper_shroud_slow = modifier_plague_reaper_shroud_slow or class({})
function modifier_plague_reaper_shroud_slow:IsDebuff() return true end
function modifier_plague_reaper_shroud_slow:GetTexture() return "necrolyte_sadist" end
function modifier_plague_reaper_shroud_slow:DeclareFunctions() return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE } end
function modifier_plague_reaper_shroud_slow:GetModifierMoveSpeedBonus_Percentage()
	local a = self:GetAbility()
	return a and not a:IsNull() and -a:GetSpecialValueFor("slow") or 0
end
