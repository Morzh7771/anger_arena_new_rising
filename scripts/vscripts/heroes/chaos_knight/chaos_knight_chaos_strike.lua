-- Chaos Knight: Chaos Strike на Lua (2026-11-22). Нужен, чтобы точно знать,
-- какая атака - крит Chaos Strike (по урону атаки определять нельзя: Daedalus и
-- прочие криты давали ложные срабатывания).
-- Как в доте: шанс chance% на крит случайной силы crit_min..crit_max и вампиризм
-- lifesteal% с этой атаки (по крипам меньше на creep_lifesteal_reduction_pct%).
-- Работает и у иллюзий. Против крипов: крит бьёт creep_splash_pct% урона крипов вокруг.

chaos_knight_chaos_strike = class({})

LinkLuaModifier("modifier_chaos_knight_chaos_strike_aa", "heroes/chaos_knight/chaos_knight_chaos_strike", LUA_MODIFIER_MOTION_NONE)

function chaos_knight_chaos_strike:Precache(context)
	PrecacheResource("particle", "particles/generic_gameplay/generic_lifesteal.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_chaos_knight.vsndevts", context)
end

function chaos_knight_chaos_strike:GetIntrinsicModifierName()
	return "modifier_chaos_knight_chaos_strike_aa"
end

--------------------------------------------------------------------------------

modifier_chaos_knight_chaos_strike_aa = class({})

function modifier_chaos_knight_chaos_strike_aa:IsHidden() return true end
function modifier_chaos_knight_chaos_strike_aa:IsPurgable() return false end

function modifier_chaos_knight_chaos_strike_aa:OnCreated()
	self.crits = {}
end

function modifier_chaos_knight_chaos_strike_aa:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
		MODIFIER_EVENT_ON_ATTACK_RECORD_DESTROY,
	}
end

function modifier_chaos_knight_chaos_strike_aa:GetModifierPreAttack_CriticalStrike(params)
	if not IsServer() then return end
	local parent = self:GetParent()
	local ab = self:GetAbility()
	if not ab or ab:GetLevel() <= 0 or parent:PassivesDisabled() then return end
	if not params.target or params.target:IsBuilding() or params.target:GetTeamNumber() == parent:GetTeamNumber() then return end
	if not RollPseudoRandomPercentage(ab:GetSpecialValueFor("chance"), DOTA_PSEUDO_RANDOM_CHAOS_STRIKE or 0, parent) then return end
	local crit = RandomInt(ab:GetSpecialValueFor("crit_min"), ab:GetSpecialValueFor("crit_max"))
	self.crits[params.record] = crit
	return crit
end

function modifier_chaos_knight_chaos_strike_aa:OnAttackLanded(params)
	if not IsServer() or params.attacker ~= self:GetParent() or not self.crits[params.record] then return end
	self.crits[params.record] = nil
	local parent, target, ab = self:GetParent(), params.target, self:GetAbility()
	target:EmitSound("Hero_ChaosKnight.ChaosStrike")

	-- вампиризм с крита
	local pct = ab:GetSpecialValueFor("lifesteal")
	if not target:IsHero() then pct = pct * (100 - ab:GetSpecialValueFor("creep_lifesteal_reduction_pct")) / 100 end
	local heal = params.damage * pct / 100
	if heal > 0 then
		parent:HealWithParams(heal, ab, true, true, parent, false)
		local fx = ParticleManager:CreateParticle("particles/generic_gameplay/generic_lifesteal.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent)
		ParticleManager:ReleaseParticleIndex(fx)
	end

	-- против крипов: крит по площади
	if target:GetTeamNumber() ~= DOTA_TEAM_NEUTRALS or target.IsAngelArenaBoss then return end
	local damage = params.damage * ab:GetSpecialValueFor("creep_splash_pct") / 100
	local units = FindUnitsInRadius(parent:GetTeamNumber(), target:GetAbsOrigin(), nil, ab:GetSpecialValueFor("creep_splash_radius"),
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	for _, u in ipairs(units) do
		if u ~= target and u:GetTeamNumber() == DOTA_TEAM_NEUTRALS and not u.IsAngelArenaBoss then
			ApplyDamage({ victim = u, attacker = parent, damage = damage, damage_type = DAMAGE_TYPE_PHYSICAL, ability = ab })
		end
	end
end

function modifier_chaos_knight_chaos_strike_aa:OnAttackRecordDestroy(params)
	if self.crits then self.crits[params.record] = nil end
end
