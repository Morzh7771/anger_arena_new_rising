-- Forgotten Hero: Meditation. Порт из Angel Arena Global.
-- Канал: реген % макс. HP в секунду. Таланты: невидимость во время медитации;
-- после полной медитации бонус к урону атаки.

forgotten_hero_meditation = class({})

LinkLuaModifier("modifier_forgotten_hero_meditation", "heroes/forgotten_hero/forgotten_hero_meditation", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_forgotten_hero_meditation_buff", "heroes/forgotten_hero/forgotten_hero_meditation", LUA_MODIFIER_MOTION_NONE)

function forgotten_hero_meditation:Precache(context)
	PrecacheResource("soundfile", "soundevents/heroes/forgotten_hero.vsndevts", context)
	PrecacheResource("particle", "particles/heroes/forgotten_hero/meditation/streaks.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_monkey_king/monkey_king_spring_cast_rays.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_monkey_king/monkey_king_quad_tap_overhead.vpcf", context)
end

function forgotten_hero_meditation:GetChannelTime()
	return self:GetSpecialValueFor("duration")
end

function forgotten_hero_meditation:OnSpellStart()
	local caster = self:GetCaster()
	caster:AddNewModifier(caster, self, "modifier_forgotten_hero_meditation", {})
	caster:EmitSound("Hero_ForgottenHero.Meditation.Start")
end

function forgotten_hero_meditation:OnChannelFinish(interrupted)
	local caster = self:GetCaster()
	caster:RemoveModifierByName("modifier_forgotten_hero_meditation")
	caster:StopSound("Hero_ForgottenHero.Meditation.Start")
	caster:EmitSound("Hero_ForgottenHero.Meditation.End")

	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_monkey_king/monkey_king_spring_cast_rays.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:ReleaseParticleIndex(pfx)

	if not interrupted and self:GetSpecialValueFor("bonus_damage") > 0 then
		caster:AddNewModifier(caster, self, "modifier_forgotten_hero_meditation_buff", { duration = self:GetSpecialValueFor("buff_duration") })
	end
end

--------------------------------------------------------------------------------

modifier_forgotten_hero_meditation = class({})

function modifier_forgotten_hero_meditation:IsHidden() return false end
function modifier_forgotten_hero_meditation:IsPurgable() return false end

function modifier_forgotten_hero_meditation:OnCreated()
	local ability = self:GetAbility()
	if not ability then return end
	self.regen = ability:GetSpecialValueFor("hp_regen")
	self.invisible = ability:GetSpecialValueFor("invisible") > 0
end

function modifier_forgotten_hero_meditation:CheckState()
	local state = { [MODIFIER_STATE_NO_UNIT_COLLISION] = true }
	if self.invisible then state[MODIFIER_STATE_INVISIBLE] = true end
	return state
end

function modifier_forgotten_hero_meditation:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE,
		MODIFIER_PROPERTY_INVISIBILITY_LEVEL,
	}
end

function modifier_forgotten_hero_meditation:GetModifierHealthRegenPercentage() return self.regen end

function modifier_forgotten_hero_meditation:GetModifierInvisibilityLevel()
	if self.invisible then return 1 end
end

function modifier_forgotten_hero_meditation:GetEffectName()
	return "particles/heroes/forgotten_hero/meditation/streaks.vpcf"
end

function modifier_forgotten_hero_meditation:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

--------------------------------------------------------------------------------

modifier_forgotten_hero_meditation_buff = class({})

function modifier_forgotten_hero_meditation_buff:IsHidden() return false end
function modifier_forgotten_hero_meditation_buff:IsPurgable() return true end

function modifier_forgotten_hero_meditation_buff:OnCreated()
	local ability = self:GetAbility()
	self.damage = ability and ability:GetSpecialValueFor("bonus_damage") or 0
end

function modifier_forgotten_hero_meditation_buff:DeclareFunctions()
	return { MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE }
end

function modifier_forgotten_hero_meditation_buff:GetModifierPreAttack_BonusDamage() return self.damage end

function modifier_forgotten_hero_meditation_buff:GetEffectName()
	return "particles/units/heroes/hero_monkey_king/monkey_king_quad_tap_overhead.vpcf"
end

function modifier_forgotten_hero_meditation_buff:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end
