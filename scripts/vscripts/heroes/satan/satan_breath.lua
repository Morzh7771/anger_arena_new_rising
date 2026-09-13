satan_breath = class({})

-- Сгенерировано: ресурсы, на которые ссылается этот скрипт.
-- Движок зовёт этот метод при прекеше юнита со способностью, поэтому
-- партиклы приезжают вместе с героем (пик/репик), а не на старте карты.
function satan_breath:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_dragon_knight/dragon_knight_breathe_fire.vpcf", context)
end

LinkLuaModifier("modifier_satan_breath_ground", "heroes/satan/modifier_satan_breath_ground", LUA_MODIFIER_MOTION_NONE)



function satan_breath:OnSpellStart()
	local caster = self:GetCaster()

	local start_radius = self:GetSpecialValueFor("start_radius")
	local end_radius   = self:GetSpecialValueFor("end_radius")
	local range        = self:GetSpecialValueFor("range")
	local speed        = self:GetSpecialValueFor("speed")
	local duration     = self:GetSpecialValueFor("duration")
	local think_time   = self:GetSpecialValueFor("think_time")

	local projectileTable =
	{
		EffectName 		= "particles/units/heroes/hero_dragon_knight/dragon_knight_breathe_fire.vpcf",
		Ability 		= self,
		vSpawnOrigin 	= caster:GetOrigin(),
		vVelocity 		= caster:GetForwardVector() * speed,
		fDistance 		= range,
		fStartRadius 	= start_radius,
		fEndRadius 		= end_radius,
		Source 			= caster,
		bHasFrontalCone = true,
		iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
		iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
	}
	ProjectileManager:CreateLinearProjectile( projectileTable )

	ticks_passed = 0
	Timers:CreateTimer(0, function()
		caster:EmitSound("Hero_DragonKnight.BreathFire")
		projectileTable.vSpawnOrigin = caster:GetOrigin()
		projectileTable.vVelocity = caster:GetForwardVector() * speed
		ProjectileManager:CreateLinearProjectile( projectileTable )
		ticks_passed = ticks_passed + think_time
		if ticks_passed < duration and caster:IsAlive() then return think_time end
		return nil
	end)
end

function satan_breath:OnProjectileHit(hTarget, vLocation)
	if not IsServer() or hTarget == nil then return end
	local caster = self:GetCaster()

	local base_damage = self:GetSpecialValueFor("damage")
	local str_mult    = self:GetSpecialValueFor("damage_from_str") / 100
	local creep_mult  = self:GetSpecialValueFor("creep_multipler")

	local talent = caster:FindAbilityByName("satan_special_bonus_breath_damage")

	if talent and talent:GetLevel() > 0 then
		base_damage = base_damage + talent:GetSpecialValueFor("value")
	end

	local damage = base_damage + caster:GetStrength() * str_mult

	local damage_table = {
		victim 		= hTarget,
		attacker 	= caster,
		damage 		= damage,
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability 	= self
	}

	if hTarget:IsCreep() and not hTarget:IsAncient() and not hTarget:IsSummoned() then
		if BossSpawner:IsBoss(hTarget) then
			creep_mult = creep_mult / 4
		end
		damage_table.damage = damage * creep_mult
	end
	ApplyDamage(damage_table)

	-- Шард: горящая земля наносит урон врагам в зоне
	local shard_enabled = self:GetSpecialValueFor("shard_enabled")
	if shard_enabled == 1 then
		local shard_duration = self:GetSpecialValueFor("shard_ground_duration")
		local shard_damage = self:GetSpecialValueFor("shard_ground_damage")
		if shard_duration > 0 and shard_damage > 0 then
			-- Запускаем таймер для нанесения урона врагам в зоне
			local tick_count = 0
			Timers:CreateTimer(0, function()
				tick_count = tick_count + 1
				local elapsed = tick_count * 1.0

				local enemies = FindUnitsInRadius(
					caster:GetTeamNumber(),
					vLocation,
					nil,
					200,
					DOTA_UNIT_TARGET_TEAM_ENEMY,
					DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
					DOTA_UNIT_TARGET_FLAG_NONE,
					FIND_ANY_ORDER,
					false
				)

				for _, enemy in ipairs(enemies) do
					local dmg = {
						victim = enemy,
						attacker = caster,
						damage = shard_damage,
						damage_type = DAMAGE_TYPE_MAGICAL,
						ability = self
					}
					ApplyDamage(dmg)
				end

				if elapsed >= shard_duration then
					return nil
				end
				return 1.0
			end)
		end
	end
end
