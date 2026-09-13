megacreep_ancient_golem_fireball = class({})

-- Сгенерировано: ресурсы, на которые ссылается этот скрипт.
-- Движок зовёт этот метод при прекеше юнита со способностью, поэтому
-- партиклы приезжают вместе с героем (пик/репик), а не на старте карты.
function megacreep_ancient_golem_fireball:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_forged_spirit_projectile.vpcf", context)
end


function megacreep_ancient_golem_fireball:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	local fireball = {
		EffectName = "particles/units/heroes/hero_invoker/invoker_forged_spirit_projectile.vpcf",
		Ability = self,
		iMoveSpeed = self:GetSpecialValueFor( "fireball_speed" ),
		Source = caster,
		Target = target,
	}
	ProjectileManager:CreateTrackingProjectile( fireball )
end

function megacreep_ancient_golem_fireball:OnProjectileHit(hTarget)
	if hTarget == nil or hTarget:TriggerSpellAbsorb(self) or not IsServer() then return end
	local damage = {
		victim = hTarget,
		attacker = self:GetCaster(),
		damage = self:GetSpecialValueFor("fireball_damage"),
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = self
	}
	ApplyDamage( damage )
end
