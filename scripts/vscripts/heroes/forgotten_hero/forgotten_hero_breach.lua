-- Forgotten Hero: Breach. Порт из Angel Arena Global.
-- Через fade_time уходит в другое измерение: невидимость, проход сквозь юнитов, скорость.
-- Атака или каст выводят. Талант: дольше и первая атака из Breach критует.

forgotten_hero_breach = class({})

LinkLuaModifier("modifier_forgotten_hero_breach", "heroes/forgotten_hero/forgotten_hero_breach", LUA_MODIFIER_MOTION_NONE)

function forgotten_hero_breach:Precache(context)
	PrecacheResource("soundfile", "soundevents/heroes/forgotten_hero.vsndevts", context)
	PrecacheResource("particle", "particles/heroes/forgotten_hero/breach/breach_start.vpcf", context)
	PrecacheResource("particle", "particles/heroes/forgotten_hero/breach/breach.vpcf", context)
	PrecacheResource("particle", "particles/status_fx/status_effect_dark_willow_shadow_realm.vpcf", context)
end

function forgotten_hero_breach:OnSpellStart()
	local caster = self:GetCaster()
	local duration = self:GetSpecialValueFor("duration")

	local pfx = ParticleManager:CreateParticle("particles/heroes/forgotten_hero/breach/breach_start.vpcf", PATTACH_ABSORIGIN, caster)
	ParticleManager:ReleaseParticleIndex(pfx)
	caster:EmitSound("Hero_ForgottenHero.Breach.Cast")

	Timers:CreateTimer(self:GetSpecialValueFor("fade_time"), function()
		if caster:IsNull() or not caster:IsAlive() then return end
		caster:AddNewModifier(caster, self, "modifier_forgotten_hero_breach", { duration = duration })
	end)
end

--------------------------------------------------------------------------------

modifier_forgotten_hero_breach = class({})

function modifier_forgotten_hero_breach:IsHidden() return false end
function modifier_forgotten_hero_breach:IsDebuff() return false end
function modifier_forgotten_hero_breach:IsPurgable() return false end

function modifier_forgotten_hero_breach:OnCreated()
	local ability = self:GetAbility()
	if not ability then return end

	self.ms = ability:GetSpecialValueFor("bonus_ms")
	self.crit = ability:GetSpecialValueFor("crit_damage")
end

function modifier_forgotten_hero_breach:OnDestroy()
	if not IsServer() then return end

	local parent = self:GetParent()
	parent:EmitSound("Hero_ForgottenHero.Breach.End")

	-- шард: при выходе из Breach вперёд вылетает малый дух Spirit Release
	local ability = self:GetAbility()
	local pct = ability and ability:GetSpecialValueFor("shard_spirit_pct") or 0
	local ult = parent:FindAbilityByName("forgotten_hero_spirit_releash")

	if pct > 0 and ult and ult:GetLevel() > 0 and parent:IsAlive() then
		local dir = parent:GetForwardVector()
		dir.z = 0
		ult:Launch(parent:GetAbsOrigin(), dir:Normalized(), ability:GetSpecialValueFor("shard_spirit_range"), pct, false)
		parent:EmitSound("Hero_ForgottenHero.SpiritReleash.Start")
	end
end

function modifier_forgotten_hero_breach:CheckState()
	return {
		[MODIFIER_STATE_INVISIBLE]			= true,
		[MODIFIER_STATE_NO_UNIT_COLLISION]	= true,
	}
end

function modifier_forgotten_hero_breach:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_INVISIBILITY_LEVEL,
		MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
		MODIFIER_PROPERTY_PROCATTACK_FEEDBACK,
		MODIFIER_EVENT_ON_ABILITY_EXECUTED,
	}
end

function modifier_forgotten_hero_breach:GetModifierMoveSpeedBonus_Percentage() return self.ms end
function modifier_forgotten_hero_breach:GetModifierInvisibilityLevel() return 1 end

function modifier_forgotten_hero_breach:GetModifierPreAttack_CriticalStrike()
	if self.crit and self.crit > 0 then return self.crit end
end

function modifier_forgotten_hero_breach:GetModifierProcAttack_Feedback()
	if IsServer() then self:Destroy() end
end

function modifier_forgotten_hero_breach:OnAbilityExecuted(params)
	if not IsServer() then return end
	if params.unit ~= self:GetParent() then return end
	self:Destroy()
end

function modifier_forgotten_hero_breach:GetStatusEffectName()
	return "particles/status_fx/status_effect_dark_willow_shadow_realm.vpcf"
end

function modifier_forgotten_hero_breach:GetEffectName()
	return "particles/heroes/forgotten_hero/breach/breach.vpcf"
end

function modifier_forgotten_hero_breach:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end
