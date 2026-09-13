soul_guardian_pure_heal = class({})

-- Сгенерировано: ресурсы, на которые ссылается этот скрипт.
-- Движок зовёт этот метод при прекеше юнита со способностью, поэтому
-- партиклы приезжают вместе с героем (пик/репик), а не на старте карты.
function soul_guardian_pure_heal:Precache(context)
	PrecacheResource("particle", "particles/bosses/soul_guardian/soul_guardian_pure_heal/soul_guardian_pure_heal.vpcf", context)
end

--------------------------------------------------------------------------------
function soul_guardian_pure_heal:OnSpellStart()
	local base_heal = self:GetSpecialValueFor("base_heal")
	local heal_pct_from_max_hp = self:GetSpecialValueFor("heal_pct_from_max_hp") / 100
	local caster = self:GetCaster()
	
	local healFromHP = caster:GetMaxHealth() * heal_pct_from_max_hp
	local heal = base_heal + healFromHP
	local healParticle = ParticleManager:CreateParticle(
		"particles/bosses/soul_guardian/soul_guardian_pure_heal/soul_guardian_pure_heal.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:SetParticleControlEnt(healParticle, 0, caster, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
	ParticleManager:ReleaseParticleIndex(healParticle)
	caster:Heal(heal, self)
	caster:Purge(false, true, false, true, false)
end

--------------------------------------------------------------------------------
