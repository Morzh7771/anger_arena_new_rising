-- Пудж (npc_aa_pudge_boss). Хук, Rot, Dismember как в доте. Dismember - это
-- и еда: пока жрёт героя, лечится; дожрал - снимает дебафы и лечится сильно.
-- Подход: не подходить вплотную, держать стан под Dismember.

require("creeps/boss/boss_kit")

LinkLuaModifier("modifier_pudge_boss_rot",        "creeps/boss/pudge/pudge_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_pudge_boss_rot_debuff", "creeps/boss/pudge/pudge_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_pudge_boss_hooked",     "creeps/boss/pudge/pudge_abilities", LUA_MODIFIER_MOTION_NONE)

local HOOK_FX = "particles/units/heroes/hero_pudge/pudge_meathook.vpcf"

--------------------------------------------------------------------------------
-- Хук: летит по прямой, первого героя - урон и к Пуджу.
--------------------------------------------------------------------------------
pudge_boss_hook = pudge_boss_hook or class({})
local hook = pudge_boss_hook

function hook:_Dir()
	local caster = self:GetCaster()
	local dir = self:GetCursorPosition() - caster:GetAbsOrigin()
	dir.z = 0
	if dir:Length2D() < 1 then dir = caster:GetForwardVector() end
	return dir:Normalized()
end

-- красная линия на замахе: куда полетит крюк
function hook:OnAbilityPhaseStart()
	if not IsServer() then return true end
	local origin = self:GetCaster():GetAbsOrigin()
	self.dir = self:_Dir()
	self.line = BossKit:TelegraphLine(origin, origin + self.dir * self:GetSpecialValueFor("range"), self:GetSpecialValueFor("width"), nil)
	return true
end

function hook:OnAbilityPhaseInterrupted()
	BossKit:StopParticle(self.line)
	self.line, self.dir = nil, nil
end

function hook:OnSpellStart()
	BossKit:StopParticle(self.line)
	self.line = nil

	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()
	local dir = self.dir or self:_Dir()
	self.dir = nil

	local range = self:GetSpecialValueFor("range")
	local speed = self:GetSpecialValueFor("speed")
	local width = self:GetSpecialValueFor("width")
	local endPos = origin + dir * range

	self.fx = ParticleManager:CreateParticle(HOOK_FX, PATTACH_CUSTOMORIGIN, caster)
	ParticleManager:SetParticleControlEnt(self.fx, 0, caster, PATTACH_POINT_FOLLOW, "attach_weapon_chain_rt", origin, true)
	ParticleManager:SetParticleControl(self.fx, 1, endPos)
	ParticleManager:SetParticleControl(self.fx, 2, Vector(speed, range, width))
	ParticleManager:SetParticleControl(self.fx, 3, Vector(range / speed * 2, 0, 0))
	ParticleManager:SetParticleControl(self.fx, 4, Vector(1, 0, 0))
	ParticleManager:SetParticleControl(self.fx, 5, Vector(0, 0, 0))
	ParticleManager:SetParticleControlEnt(self.fx, 7, caster, PATTACH_CUSTOMORIGIN, nil, origin, true)

	self.caught = false

	ProjectileManager:CreateLinearProjectile({
		Ability = self,
		EffectName = "",
		vSpawnOrigin = origin,
		fDistance = range,
		fStartRadius = width,
		fEndRadius = width,
		Source = caster,
		iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
		iUnitTargetType = DOTA_UNIT_TARGET_HERO,
		iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
		vVelocity = dir * speed,
	})

	caster:EmitSound("Hero_Pudge.AttackHookExtend")

	-- промах: цепь вернулась сама
	local fx = self.fx
	Timers:CreateTimer(range / speed * 2, function()
		if not self.caught then
			ParticleManager:DestroyParticle(fx, false)
			ParticleManager:ReleaseParticleIndex(fx)
		end
	end)
end

function hook:OnProjectileHit(target, location)
	if not target or self.caught then return true end
	self.caught = true

	local caster = self:GetCaster()

	BossKit:PctDamage(caster, self, target, self:GetSpecialValueFor("damage_pct"))
	target:EmitSound("Hero_Pudge.AttackHookImpact")

	ParticleManager:SetParticleControlEnt(self.fx, 1, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)
	target:AddNewModifier(caster, self, "modifier_pudge_boss_hooked", { duration = 2 })
	return true
end

-- тянет цель к Пуджу
modifier_pudge_boss_hooked = modifier_pudge_boss_hooked or class({})
local hk = modifier_pudge_boss_hooked

function hk:IsDebuff() return true end
function hk:IsHidden() return true end
function hk:CheckState() return { [MODIFIER_STATE_STUNNED] = true } end

function hk:OnCreated()
	if not IsServer() then return end
	self.speed = self:GetAbility():GetSpecialValueFor("speed")
	self:StartIntervalThink(FrameTime())
end

function hk:OnIntervalThink()
	local t = self:GetParent()
	local pudge = self:GetCaster()
	if pudge:IsNull() or not pudge:IsAlive() then return self:Destroy() end

	local to = pudge:GetAbsOrigin() - t:GetAbsOrigin()
	to.z = 0
	local step = self.speed * FrameTime()

	if to:Length2D() <= 150 + step then return self:Destroy() end

	t:SetAbsOrigin(t:GetAbsOrigin() + to:Normalized() * step)
end

function hk:OnDestroy()
	if not IsServer() then return end
	local t = self:GetParent()
	FindClearSpaceForUnit(t, t:GetAbsOrigin(), true)

	local ab = self:GetAbility()
	if ab and not ab:IsNull() and ab.fx then
		ParticleManager:DestroyParticle(ab.fx, false)
		ParticleManager:ReleaseParticleIndex(ab.fx)
		ab.fx = nil
	end
	self:GetCaster():EmitSound("Hero_Pudge.AttackHookRetractStop")
end

--------------------------------------------------------------------------------
-- Rot: всегда включён, % HP в секунду и замедление рядом с Пуджем.
--------------------------------------------------------------------------------
pudge_boss_rot = pudge_boss_rot or class({})
function pudge_boss_rot:GetIntrinsicModifierName() return "modifier_pudge_boss_rot" end

modifier_pudge_boss_rot = modifier_pudge_boss_rot or class({})
local rot = modifier_pudge_boss_rot

function rot:IsHidden()   return true end
function rot:IsPurgable() return false end
function rot:IsAura()     return true end
function rot:GetAuraRadius() return self:GetAbility():GetSpecialValueFor("radius") end
function rot:GetAuraSearchTeam() return DOTA_UNIT_TARGET_TEAM_ENEMY end
function rot:GetAuraSearchType() return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end
function rot:GetModifierAura() return "modifier_pudge_boss_rot_debuff" end

function rot:OnCreated()
	if not IsServer() then return end
	local p = self:GetParent()
	local r = self:GetAbility():GetSpecialValueFor("radius")
	self.fx = ParticleManager:CreateParticle("particles/units/heroes/hero_pudge/pudge_rot.vpcf", PATTACH_ABSORIGIN_FOLLOW, p)
	ParticleManager:SetParticleControl(self.fx, 1, Vector(r, 0, 0))
	self:AddParticle(self.fx, false, false, -1, false, false)
end

modifier_pudge_boss_rot_debuff = modifier_pudge_boss_rot_debuff or class({})
local rd = modifier_pudge_boss_rot_debuff

function rd:IsDebuff() return true end
function rd:GetTexture() return "pudge_rot" end
function rd:GetEffectName() return "particles/units/heroes/hero_pudge/pudge_rot_recipient.vpcf" end

function rd:OnCreated()
	if not IsServer() then return end
	self:StartIntervalThink(0.5)
end

function rd:OnIntervalThink()
	local ab = self:GetAbility()
	local pudge = self:GetCaster()
	if not ab or ab:IsNull() or pudge:IsNull() or not pudge:IsAlive() then return end
	BossKit:PctDamage(pudge, ab, self:GetParent(), ab:GetSpecialValueFor("damage_pct_per_sec") / 2)
end

function rd:DeclareFunctions() return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE } end
function rd:GetModifierMoveSpeedBonus_Percentage()
	local a = self:GetAbility()
	return a and -a:GetSpecialValueFor("slow") or 0
end

--------------------------------------------------------------------------------
-- Dismember: канал, держит героя и жрёт его - % его HP в секунду, Пудж
-- лечится % своего HP в секунду. Дожрал до конца - снимает с себя дебафы и
-- лечится на finish_heal_pct. Стан по Пуджу сбивает - ни хила, ни диспела.
--------------------------------------------------------------------------------
pudge_boss_dismember = pudge_boss_dismember or class({})
local dis = pudge_boss_dismember

function dis:GetChannelTime() return self:GetSpecialValueFor("duration") end

function dis:OnAbilityPhaseStart()
	if not IsServer() then return true end
	local t = self:GetCursorTarget()
	if t then self.mark = BossKit:TelegraphFollow(t, 150, self:GetCastPoint()) end
	return true
end

function dis:OnAbilityPhaseInterrupted()
	BossKit:StopParticle(self.mark)
	self.mark = nil
end

function dis:OnSpellStart()
	BossKit:StopParticle(self.mark)
	self.mark = nil
	local t = self:GetCursorTarget()
	if not t then return end
	self.target = t
	self.tick = 0
	t:AddNewModifier(self:GetCaster(), self, "modifier_stunned", { duration = self:GetChannelTime() })
	self.fx = ParticleManager:CreateParticle("particles/units/heroes/hero_pudge/pudge_dismember.vpcf", PATTACH_ABSORIGIN_FOLLOW, t)
	self:GetCaster():EmitSound("Hero_Pudge.Dismember.Cast")
end

function dis:OnChannelThink(dt)
	self.tick = (self.tick or 0) + dt
	if self.tick < 0.5 then return end
	self.tick = self.tick - 0.5

	local caster = self:GetCaster()
	local t = self.target
	if t and not t:IsNull() and t:IsAlive() then
		BossKit:PctDamage(caster, self, t, self:GetSpecialValueFor("damage_pct_per_sec") / 2)
		t:EmitSound("Hero_Pudge.Dismember")
		caster:Heal(caster:GetMaxHealth() * self:GetSpecialValueFor("heal_pct_per_sec") / 200, self)
	end
end

function dis:OnChannelFinish(interrupted)
	local caster = self:GetCaster()
	local t = self.target
	if t and not t:IsNull() then t:RemoveModifierByNameAndCaster("modifier_stunned", caster) end
	BossKit:StopParticle(self.fx)
	self.fx, self.target = nil, nil

	if interrupted then return end

	BossKit:Dispel(caster)
	local heal = caster:GetMaxHealth() * self:GetSpecialValueFor("finish_heal_pct") / 100
	caster:Heal(heal, self)
	SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, caster, heal, nil)
	caster:EmitSound("Hero_Pudge.Attack.Rip")

	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_pudge/pudge_fleshheap_block_activation.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:ReleaseParticleIndex(fx)
end
