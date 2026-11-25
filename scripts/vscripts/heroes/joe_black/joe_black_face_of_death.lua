-- Joe Black: Face of Death. Порт из Angel Arena Frontier, цифры Angel Arena Global.
-- Снаряд в цель: врагу урон, союзнику лечение (база + % интеллекта).
-- Таланты: снаряды во всех в радиусе; снаряды во всех, кто сейчас под Song.

joe_black_face_of_death = class({})

function joe_black_face_of_death:Precache(context)
	PrecacheResource("particle", "particles/econ/items/abaddon/abaddon_alliance/abaddon_death_coil_alliance.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_abaddon.vsndevts", context)
end

function joe_black_face_of_death:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function joe_black_face_of_death:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	local radius = self:GetSpecialValueFor("radius")

	local launched = {}
	local function launch(unit)
		if not unit or unit:IsNull() or launched[unit] then return end
		launched[unit] = true
		self:LaunchProjectile(caster, unit)
	end

	launch(target)

	if radius > 0 then
		local units = FindUnitsInRadius(caster:GetTeamNumber(), target:GetAbsOrigin(), nil, radius,
			DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
		for _, unit in pairs(units) do
			if unit ~= caster then launch(unit) end
		end
	end

	caster:EmitSound("Hero_Abaddon.DeathCoil.Cast")

	if self:GetSpecialValueFor("cast_on_song_targets") <= 0 then return end

	local song = caster:FindAbilityByName("joe_black_song")
	if not song or not song.active_targets then return end

	local range = self:GetCastRange(caster:GetAbsOrigin(), nil) + caster:GetCastRangeBonus()
	for _, unit in pairs(song.active_targets) do
		if not unit:IsNull() and unit:IsAlive() and (caster:GetAbsOrigin() - unit:GetAbsOrigin()):Length2D() <= range then
			launch(unit)
		end
	end
end

function joe_black_face_of_death:LaunchProjectile(source, target)
	ProjectileManager:CreateTrackingProjectile({
		Target				= target,
		Source				= source,
		Ability				= self,
		EffectName			= "particles/econ/items/abaddon/abaddon_alliance/abaddon_death_coil_alliance.vpcf",
		bDodgeable			= true,
		bProvidesVision		= false,
		iMoveSpeed			= self:GetSpecialValueFor("projectile_speed"),
		iSourceAttachment	= DOTA_PROJECTILE_ATTACHMENT_ATTACK_1,
	})
end

function joe_black_face_of_death:OnProjectileHit(target, location)
	if not target or target:IsNull() then return end

	local caster = self:GetCaster()
	target:EmitSound("Hero_Abaddon.DeathCoil.Target")

	local amount = self:GetSpecialValueFor("damage") + caster:GetIntellect(true) * self:GetSpecialValueFor("int_percent") / 100

	if target:GetTeamNumber() == caster:GetTeamNumber() then
		target:Heal(amount, self)
		SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, target, amount, nil)
		return
	end

	if target:TriggerSpellAbsorb(self) then return end
	if target:IsMagicImmune() then return end

	ApplyDamage({
		victim		= target,
		attacker	= caster,
		damage		= amount,
		damage_type	= self:GetAbilityDamageType(),
		ability		= self,
	})
end
