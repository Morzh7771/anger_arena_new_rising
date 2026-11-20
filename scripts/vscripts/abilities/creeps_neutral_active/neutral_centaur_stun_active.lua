-- Кентавр: оглушающий топот вокруг себя (без цели). Урон + % от макс. здоровья цели.
neutral_centaur_stun_active = neutral_centaur_stun_active or class({})
local ability = neutral_centaur_stun_active

function ability:OnAbilityPhaseStart()
	EmitSoundOn("n_creep_Centaur.Stomp", self:GetCaster())
	return true
end

function ability:OnSpellStart()
	local caster = self:GetCaster()
	local radius = self:GetSpecialValueFor("aoe")
	local damage = self:GetSpecialValueFor("damage")
	local damage_health = self:GetSpecialValueFor("damage_health")
	local stun = self:GetSpecialValueFor("stun")

	local units = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

	for _, unit in pairs(units) do
		ApplyDamage({
			victim = unit,
			attacker = caster,
			damage = damage + unit:GetMaxHealth() * damage_health / 100,
			damage_type = DAMAGE_TYPE_MAGICAL,
			ability = self,
		})
		unit:AddNewModifier(caster, self, "modifier_stunned", { duration = stun * (1 - unit:GetStatusResistance()) })
	end
end
