-- Forgotten Hero: Spirit Release (ульт). Порт из Angel Arena Global.
-- Линейный дух на всю дальность каста, урон всем задетым. Талант: ещё и оглушение.
-- Аганим: долетев, дух возвращается к герою и задевает врагов второй раз.
-- Шард (у Breach): при выходе из Breach вылетает малый дух (shard_spirit_pct% урона) - зовёт Launch.

forgotten_hero_spirit_releash = class({})

function forgotten_hero_spirit_releash:Precache(context)
	PrecacheResource("soundfile", "soundevents/heroes/forgotten_hero.vsndevts", context)
	PrecacheResource("particle", "particles/heroes/forgotten_hero/spirit_releash/spirit_releash.vpcf", context)
end

function forgotten_hero_spirit_releash:OnSpellStart()
	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()

	local direction = self:GetCursorPosition() - origin
	direction.z = 0
	if direction:Length2D() < 1 then direction = caster:GetForwardVector() end

	self:Launch(origin, direction:Normalized(), self:GetCastRange(origin, nil) + caster:GetCastRangeBonus(), 100, false)
	caster:EmitSound("Hero_ForgottenHero.SpiritReleash.Start")
end

-- pct - % урона ульты, returning - это обратный полёт (аганим)
function forgotten_hero_spirit_releash:Launch(origin, direction, distance, pct, returning)
	local width = self:GetSpecialValueFor("projectile_width")

	ProjectileManager:CreateLinearProjectile({
		EffectName			= "particles/heroes/forgotten_hero/spirit_releash/spirit_releash.vpcf",
		Ability				= self,
		vSpawnOrigin		= origin,
		fStartRadius		= width,
		fEndRadius			= width,
		vVelocity			= direction * self:GetSpecialValueFor("projectile_speed"),
		fDistance			= distance,
		Source				= self:GetCaster(),
		iUnitTargetTeam		= DOTA_UNIT_TARGET_TEAM_ENEMY,
		iUnitTargetType		= DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		iUnitTargetFlags	= DOTA_UNIT_TARGET_FLAG_NONE,
		ExtraData			= { pct = pct, returning = returning and 1 or 0 },
	})
end

function forgotten_hero_spirit_releash:OnProjectileHit_ExtraData(target, location, extra)
	local caster = self:GetCaster()

	-- конец полёта: по аганиму дух летит обратно к герою
	if not target then
		if tonumber(extra.returning) == 0 and tonumber(extra.pct) >= 100 and self:GetSpecialValueFor("scepter_return") > 0 and caster:IsAlive() then
			local back = caster:GetAbsOrigin() - location
			back.z = 0
			if back:Length2D() > 50 then
				self:Launch(location, back:Normalized(), back:Length2D(), 100, true)
			end
		end
		return true
	end

	if target:IsMagicImmune() or target:IsInvulnerable() then return false end

	ApplyDamage({
		victim		= target,
		attacker	= caster,
		damage		= (self:GetSpecialValueFor("damage") + caster:GetAgility() * self:GetSpecialValueFor("damage_pct") / 100) * tonumber(extra.pct or 100) / 100,
		damage_type	= self:GetAbilityDamageType(),
		ability		= self,
	})

	local stun = self:GetSpecialValueFor("stun_duration")
	if stun > 0 then
		target:AddNewModifier(caster, self, "modifier_stunned", { duration = stun })
	end

	target:EmitSound("Hero_ForgottenHero.SpiritReleash.Hit")
	return false
end
