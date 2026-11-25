huntress_aim_shot = huntress_aim_shot or class({})

LinkLuaModifier("modifier_huntress_aim_shot", "heroes/huntress/huntress_aim_shot/modifier_huntress_aim_shot", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_huntress_aim_shot_busy", "heroes/huntress/huntress_aim_shot/modifier_huntress_aim_shot", LUA_MODIFIER_MOTION_NONE)

function huntress_aim_shot:OnToggle()
	if not IsServer() then return end
	local caster = self:GetCaster()

	if self:GetToggleState() then
		caster:AddNewModifier(caster, self, "modifier_huntress_aim_shot", { duration = -1 })
		caster:EmitSound("Hero_Huntress.AimShot.Enable")
	else
		caster:RemoveModifierByName("modifier_huntress_aim_shot")
		caster:EmitSound("Hero_Huntress.AimShot.Disable")
	end
end

-- стойку включают и выключают на ходу: каст не должен сбивать стрельбу и бег
function huntress_aim_shot:IsStealable() return false
end


--------------------------------------------------------------------------------
-- Пронзающая стрела: в стойке каждая атака выпускает по направлению цели стрелу
-- на дальность атаки. Урон наносит только она (и основной цели тоже), от неё можно
-- уйти. Каждая пробитая цель снижает урон следующим на pierce_damage_reduction %
-- от остатка. Скорость - скорость снарядов героя со всеми бонусами (Parasma и т.п.).
function huntress_aim_shot:FireArrow(target)
	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()
	local dir = (target:GetAbsOrigin() - origin)
	dir.z = 0
	if dir:Length2D() < 1 then dir = caster:GetForwardVector() end
	dir.z = 0
	dir = dir:Normalized()

	local speed = caster:GetProjectileSpeed()
	if not speed or speed <= 0 then speed = 900 end

	self.arrow_key = (self.arrow_key or 0) + 1
	self.arrow_hits = self.arrow_hits or {}
	self.arrow_hits[self.arrow_key] = 0

	ProjectileManager:CreateLinearProjectile({
		Ability				= self,
		EffectName			= "particles/units/heroes/hero_windrunner/windrunner_spell_powershot.vpcf",
		vSpawnOrigin		= origin,
		fDistance			= caster:Script_GetAttackRange() + caster:GetHullRadius(),
		fStartRadius		= self:GetSpecialValueFor("arrow_width"),
		fEndRadius			= self:GetSpecialValueFor("arrow_width"),
		Source				= caster,
		iUnitTargetTeam		= DOTA_UNIT_TARGET_TEAM_ENEMY,
		iUnitTargetType		= DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		-- атака: бьёт и тех, кто под иммунитетом к магии (BKB)
		iUnitTargetFlags	= DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
		vVelocity			= dir * speed,
		bProvidesVision		= true,
		iVisionRadius		= 150,
		iVisionTeamNumber	= caster:GetTeamNumber(),
		ExtraData			= { key = self.arrow_key },
	})
end

function huntress_aim_shot:OnProjectileHit_ExtraData(target, location, data)
	local key = data and data.key
	self.arrow_hits = self.arrow_hits or {}
	if not target then
		if key then self.arrow_hits[key] = nil end
		return true
	end

	local caster = self:GetCaster()
	if not caster:IsAlive() then return true end

	local hits = (key and self.arrow_hits[key]) or 0
	local reduction = self:GetSpecialValueFor("pierce_damage_reduction") / 100

	-- бесплотный / неуязвимый: стрела пролетает насквозь без урона и не тратит пробитие
	if target:IsAttackImmune() or target:IsInvulnerable() then return false end

	caster.aa_aim_shot_arrow = true
	caster.aa_aim_shot_arrow_mult = (1 - reduction) ^ hits
	caster:PerformAttack(target, true, true, true, false, false, false, true)
	caster.aa_aim_shot_arrow = nil
	caster.aa_aim_shot_arrow_mult = nil

	-- цель видит, кто в неё стреляет
	AddFOWViewer(target:GetTeamNumber(), caster:GetAbsOrigin(), 100, 1, false)

	if key then self.arrow_hits[key] = hits + 1 end
	return false
end
