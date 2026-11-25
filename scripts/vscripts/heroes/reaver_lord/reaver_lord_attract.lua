-- Reaver Lord: Attract & Destroy (ульт). Порт из Angel Arena Global (datadriven), переписано на Lua.
-- Нужен полный запас душ (талант снимает требование). Стягивает врагов в радиусе к точке перед собой,
-- оглушает. Урон каждому = сумма (damage_by_hero за каждого героя + damage_by_creep за каждого крипа)
-- + damage_pct% макс. HP цели. Боссы урона не получают (только стан). Души не тратятся.

require("heroes/reaver_lord/reaver_lord_soul_collector")

reaver_lord_attract = class({})

LinkLuaModifier("modifier_reaver_lord_attract", "heroes/reaver_lord/reaver_lord_attract", LUA_MODIFIER_MOTION_NONE)

function reaver_lord_attract:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_terrorblade/terrorblade_sunder.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_terrorblade.vsndevts", context)
end

function reaver_lord_attract:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function reaver_lord_attract:CastFilterResult()
	-- Стаки душ видны и на клиенте, поэтому проверка работает с обеих сторон
	local caster = self:GetCaster()
	if self:GetSpecialValueFor("no_souls_required") > 0 then return UF_SUCCESS end
	-- аганим снижает требование (souls_required_pct от максимума)
	local max_souls = ReaverLordGetMaxSouls(caster)
	local need = math.ceil(max_souls * self:GetSpecialValueFor("souls_required_pct") / 100)
	if max_souls == 0 or ReaverLordGetSouls(caster) < need then
		return UF_FAIL_CUSTOM
	end
	return UF_SUCCESS
end

function reaver_lord_attract:GetCustomCastError()
	return "#dota_hud_error_reaver_lord_need_souls"
end

function reaver_lord_attract:OnSpellStart()
	local caster = self:GetCaster()
	local radius = self:GetSpecialValueFor("radius")

	local units = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_CREEP, DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, FIND_ANY_ORDER, false)

	local total = 0
	for _, unit in pairs(units) do
		total = total + (unit:IsRealHero() and self:GetSpecialValueFor("damage_by_hero") or self:GetSpecialValueFor("damage_by_creep"))
	end

	local point = caster:GetAbsOrigin() + caster:GetForwardVector() * 200
	local stun = self:GetSpecialValueFor("stun_duration")
	local pct = self:GetSpecialValueFor("damage_pct") / 100

	for _, unit in pairs(units) do
		unit:AddNewModifier(caster, self, "modifier_reaver_lord_attract", { duration = stun })

		if not (BossSpawner and BossSpawner.IsBoss and BossSpawner:IsBoss(unit)) then
			ApplyDamage({
				victim		= unit,
				attacker	= caster,
				damage		= total + unit:GetMaxHealth() * pct,
				damage_type	= self:GetAbilityDamageType(),
				ability		= self,
			})
		end

		if unit:IsAlive() then
			FindClearSpaceForUnit(unit, point, true)
		end

		local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_terrorblade/terrorblade_sunder.vpcf", PATTACH_POINT_FOLLOW, unit)
		ParticleManager:SetParticleControlEnt(pfx, 0, unit, PATTACH_POINT_FOLLOW, "attach_hitloc", unit:GetAbsOrigin(), true)
		ParticleManager:SetParticleControlEnt(pfx, 1, caster, PATTACH_POINT_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
		ParticleManager:ReleaseParticleIndex(pfx)
	end

	caster:EmitSound("Hero_Terrorblade.Sunder.Cast")
end

--------------------------------------------------------------------------------

modifier_reaver_lord_attract = class({})

function modifier_reaver_lord_attract:IsHidden() return false end
function modifier_reaver_lord_attract:IsDebuff() return true end
function modifier_reaver_lord_attract:IsStunDebuff() return true end
function modifier_reaver_lord_attract:IsPurgable() return false end
function modifier_reaver_lord_attract:IsPurgeException() return true end

function modifier_reaver_lord_attract:CheckState()
	return {
		[MODIFIER_STATE_STUNNED] = true,
		[MODIFIER_STATE_FROZEN] = true,
	}
end

function modifier_reaver_lord_attract:GetEffectName()
	return "particles/generic_gameplay/generic_stunned.vpcf"
end

function modifier_reaver_lord_attract:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end

function modifier_reaver_lord_attract:GetStatusEffectName()
	return "particles/status_fx/status_effect_faceless_chronosphere.vpcf"
end
