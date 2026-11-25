-- Joe Black: Song (ульт). Порт из Angel Arena Frontier, цифры Angel Arena Global.
-- Враги в радиусе: 100% промахов, минус к сопротивлению эффектам, обзор урезан. В конце урон
-- (даже если развеяли). Талант: союзники в радиусе получают реген % HP.

joe_black_song = class({})

LinkLuaModifier("modifier_joe_black_song_buff", "heroes/joe_black/joe_black_song", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_joe_black_song_debuff", "heroes/joe_black/joe_black_song", LUA_MODIFIER_MOTION_NONE)

function joe_black_song:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_silencer/silencer_last_word_dmg.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_siren/naga_siren_siren_song_cast.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dark_willow/dark_willow_wisp_spell_fear_debuff.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_queenofpain.vsndevts", context)
end

function joe_black_song:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function joe_black_song:OnSpellStart()
	local caster = self:GetCaster()
	local team = caster:GetTeamNumber()
	local origin = caster:GetAbsOrigin()
	local duration = self:GetSpecialValueFor("duration")
	local heal_allies = self:GetSpecialValueFor("ally_health_regen_pct") > 0

	-- Цели под Song: нужен Face of Death с талантом
	self.active_targets = self.active_targets or {}

	local units = FindUnitsInRadius(team, origin, nil, self:GetSpecialValueFor("radius"),
		DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

	for _, unit in pairs(units) do
		if unit:GetTeamNumber() == team then
			if heal_allies then
				unit:AddNewModifier(caster, self, "modifier_joe_black_song_buff", { duration = duration })
			end
		else
			unit:AddNewModifier(caster, self, "modifier_joe_black_song_debuff", { duration = duration })
		end
	end

	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_siren/naga_siren_siren_song_cast.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:ReleaseParticleIndex(pfx)

	caster:EmitSound("Hero_QueenOfPain.SonicWave")
end

--------------------------------------------------------------------------------

modifier_joe_black_song_buff = class({})

function modifier_joe_black_song_buff:IsHidden() return false end
function modifier_joe_black_song_buff:IsDebuff() return false end
function modifier_joe_black_song_buff:IsPurgable() return true end

function modifier_joe_black_song_buff:OnCreated()
	local ability = self:GetAbility()
	if not ability then return end

	self.regen_pct = ability:GetSpecialValueFor("ally_health_regen_pct")

	if not IsServer() then return end
	ability.active_targets = ability.active_targets or {}
	ability.active_targets[self:GetParent():entindex()] = self:GetParent()
end

function modifier_joe_black_song_buff:OnDestroy()
	if not IsServer() then return end
	local ability = self:GetAbility()
	if ability and ability.active_targets then
		ability.active_targets[self:GetParent():entindex()] = nil
	end
end

function modifier_joe_black_song_buff:DeclareFunctions()
	return { MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE }
end

function modifier_joe_black_song_buff:GetModifierHealthRegenPercentage()
	return self.regen_pct
end

--------------------------------------------------------------------------------

modifier_joe_black_song_debuff = class({})

function modifier_joe_black_song_debuff:IsHidden() return false end
function modifier_joe_black_song_debuff:IsDebuff() return true end
function modifier_joe_black_song_debuff:IsPurgable() return true end

function modifier_joe_black_song_debuff:OnCreated()
	local ability = self:GetAbility()
	if not ability then return end

	self.miss_chance		= ability:GetSpecialValueFor("miss_chance")
	self.fixed_vision		= ability:GetSpecialValueFor("fixed_vision")
	self.status_resistance	= -ability:GetSpecialValueFor("status_resistance")
	self.finish_damage		= ability:GetSpecialValueFor("finish_damage") + self:GetCaster():GetIntellect(true) * ability:GetSpecialValueFor("damage_pct") / 100
	self.silence_duration	= ability:GetSpecialValueFor("scepter_silence")

	if not IsServer() then return end
	ability.active_targets = ability.active_targets or {}
	ability.active_targets[self:GetParent():entindex()] = self:GetParent()
end

function modifier_joe_black_song_debuff:CheckState()
	-- аганим: первые scepter_silence секунд ещё и безмолвие
	local silence = self.silence_duration and self.silence_duration > 0 and self:GetElapsedTime() < self.silence_duration
	return {
		[MODIFIER_STATE_EVADE_DISABLED] = true,
		[MODIFIER_STATE_SILENCED] = silence or nil,
	}
end

function modifier_joe_black_song_debuff:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MISS_PERCENTAGE,
		MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING,
		MODIFIER_PROPERTY_FIXED_DAY_VISION,
		MODIFIER_PROPERTY_FIXED_NIGHT_VISION,
	}
end

function modifier_joe_black_song_debuff:GetModifierMiss_Percentage() return self.miss_chance end
function modifier_joe_black_song_debuff:GetModifierStatusResistanceStacking() return self.status_resistance end
function modifier_joe_black_song_debuff:GetFixedDayVision() return self.fixed_vision end
function modifier_joe_black_song_debuff:GetFixedNightVision() return self.fixed_vision end

-- Урон в конце проходит и при развеивании
function modifier_joe_black_song_debuff:OnDestroy()
	if not IsServer() then return end

	local parent = self:GetParent()
	local ability = self:GetAbility()

	if ability and ability.active_targets then
		ability.active_targets[parent:entindex()] = nil
	end

	if not ability or not parent:IsAlive() then return end

	ApplyDamage({
		victim		= parent,
		attacker	= self:GetCaster(),
		damage		= self.finish_damage,
		damage_type	= DAMAGE_TYPE_MAGICAL,
		ability		= ability,
	})

	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_silencer/silencer_last_word_dmg.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:ReleaseParticleIndex(pfx)
	parent:EmitSound("Hero_QueenOfPain.ShadowStrike")
end

function modifier_joe_black_song_debuff:GetEffectName()
	return "particles/units/heroes/hero_dark_willow/dark_willow_wisp_spell_fear_debuff.vpcf"
end

function modifier_joe_black_song_debuff:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end
