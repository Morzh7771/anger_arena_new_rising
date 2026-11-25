-- Reaver Lord: Soul Burn. Был в Angel Arena Global (datadriven, не подключён), переписан на Lua.
-- Сжигает все собранные души: вражеские герои в радиусе получают чистый урон -
-- за каждую душу (damage + damage_agi_pct% ловкости) и ещё damage_pct% своего макс. здоровья.
-- Боссы получают 1/5 урона. Нужна хотя бы одна душа.

require("heroes/reaver_lord/reaver_lord_soul_collector")

reaver_lord_soul_burn = class({})

function reaver_lord_soul_burn:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_obsidian_destroyer/obsidian_destroyer_sanity_eclipse_area.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_terrorblade/terrorblade_metamorphosis_transform.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_arc_warden.vsndevts", context)
end

function reaver_lord_soul_burn:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function reaver_lord_soul_burn:CastFilterResult()
	if ReaverLordGetSouls(self:GetCaster()) <= 0 then return UF_FAIL_CUSTOM end
	return UF_SUCCESS
end

function reaver_lord_soul_burn:GetCustomCastError()
	return "#dota_hud_error_reaver_lord_no_souls"
end

function reaver_lord_soul_burn:OnAbilityPhaseStart()
	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_terrorblade/terrorblade_metamorphosis_transform.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetCaster())
	ParticleManager:ReleaseParticleIndex(pfx)
	return true
end

function reaver_lord_soul_burn:OnSpellStart()
	local caster = self:GetCaster()
	local souls = ReaverLordGetSouls(caster)
	local radius = self:GetSpecialValueFor("radius")

	local per_soul = self:GetSpecialValueFor("damage") + caster:GetAgility() * self:GetSpecialValueFor("damage_agi_pct") / 100
	local pct = self:GetSpecialValueFor("damage_pct") / 100

	caster:RemoveModifierByName("modifier_reaver_lord_soul")

	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_obsidian_destroyer/obsidian_destroyer_sanity_eclipse_area.vpcf", PATTACH_ABSORIGIN, caster)
	ParticleManager:SetParticleControl(pfx, 1, Vector(radius, 0, 0))
	ParticleManager:SetParticleControl(pfx, 2, Vector(radius, 0, 0))
	ParticleManager:SetParticleControl(pfx, 3, Vector(radius, 0, 0))
	ParticleManager:ReleaseParticleIndex(pfx)
	caster:EmitSound("Hero_ArcWarden.SparkWraith.Activate")

	local enemies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

	for _, enemy in pairs(enemies) do
		local damage = per_soul * souls + enemy:GetMaxHealth() * pct

		if BossSpawner and BossSpawner.IsBoss and BossSpawner:IsBoss(enemy) then
			damage = damage / 5
		end

		ApplyDamage({ victim = enemy, attacker = caster, damage = damage, damage_type = DAMAGE_TYPE_PURE, ability = self })
	end
end
