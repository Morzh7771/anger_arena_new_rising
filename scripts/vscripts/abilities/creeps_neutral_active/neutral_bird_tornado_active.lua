-- Птица: торнадо в точке, урон и замедление врагов в радиусе.
neutral_bird_tornado_active = neutral_bird_tornado_active or class({})
local ability = neutral_bird_tornado_active

function ability:OnSpellStart()
	local caster = self:GetCaster()
	local point = self:GetCursorPosition()
	local radius = self:GetSpecialValueFor("radius")
	local damage = self:GetSpecialValueFor("damage")
	local damage_health = self:GetSpecialValueFor("damage_health")
	local slow = self:GetSpecialValueFor("slow")
	local duration = self:GetSpecialValueFor("duration")

	EmitSoundOnLocationWithCaster(point, "n_creep_Centaur.Stomp", caster)

	local units = FindUnitsInRadius(caster:GetTeamNumber(), point, nil, radius,
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
		unit:AddNewModifier(caster, self, "modifier_neutral_creep_active", { duration = duration, slow = slow })
	end
end
