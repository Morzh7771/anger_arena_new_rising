void_spirit_astral_step_aa = class({})

LinkLuaModifier( "modifier_void_spirit_astral_step_lua", "heroes/void_spirit/void_spirit_astral_step", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------

function void_spirit_astral_step_aa:GetCastRange(vLocation, hTarget)
    local max_dist = self:GetSpecialValueFor( "max_travel_distance" )
        if IsClient() then 
            return max_dist 
        end
        return
    end
-- Ability Start
function void_spirit_astral_step_aa:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_void_spirit/astral_step/void_spirit_astral_step.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_void_spirit/astral_step/void_spirit_astral_step_impact.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_void_spirit/astral_step/void_spirit_astral_step_debuff.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_void_spirit/astral_step/void_spirit_astral_step_dmg.vpcf", context)
end
function void_spirit_astral_step_aa:OnSpellStart()
	-- unit identifier
	local caster = self:GetCaster()
	local point = self:GetCursorPosition()
	local origin = caster:GetOrigin()

	-- load data
	local min_dist = self:GetSpecialValueFor( "min_travel_distance" )
	local max_dist = self:GetSpecialValueFor( "max_travel_distance" ) + self:GetCaster():GetCastRangeBonus()
	local radius = self:GetSpecialValueFor( "radius" )
	local delay = self:GetSpecialValueFor( "pop_damage_delay" )

	-- find destination
	local direction = (point-origin)
	local dist = math.max( math.min( max_dist, direction:Length2D() ), min_dist )
	direction.z = 0
	direction = direction:Normalized()

	local target = GetGroundPosition( origin + direction*dist, nil )

	-- teleport
	FindClearSpaceForUnit( caster, target, true )

	-- find units in line
	local enemies = FindUnitsInLine(
		self:GetCaster():GetTeamNumber(),	-- int, your team number
		origin,	-- point, start point
		target,	-- point, end point
		nil,	-- handle, cacheUnit. (not known)
		radius,	-- float, radius. or use FIND_UNITS_EVERYWHERE
		DOTA_UNIT_TARGET_TEAM_ENEMY,	-- int, team filter
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,	-- int, type filter
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES	-- int, flag filter
	)

	for _,enemy in pairs(enemies) do
		-- perform attack
		caster:PerformAttack( enemy, true, true, true, false, true, false, true )

		-- add modifier
		enemy:AddNewModifier(
			caster, -- player source
			self, -- ability source
			"modifier_void_spirit_astral_step_lua", -- modifier name
			{ duration = delay } -- kv
		)

		-- play effects
		self:PlayEffects2( enemy )
	end

	-- play effects
	self:PlayEffects1( origin, target )
end

--------------------------------------------------------------------------------
function void_spirit_astral_step_aa:PlayEffects1( origin, target )
	-- Get Resources
	local particle_cast = "particles/units/heroes/hero_void_spirit/astral_step/void_spirit_astral_step.vpcf"
	local sound_start = "Hero_VoidSpirit.AstralStep.Start"
	local sound_end = "Hero_VoidSpirit.AstralStep.End"

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_WORLDORIGIN, self:GetCaster() )
	ParticleManager:SetParticleControl( effect_cast, 0, origin )
	ParticleManager:SetParticleControl( effect_cast, 1, target )
	ParticleManager:ReleaseParticleIndex( effect_cast )

	-- Create Sound
	EmitSoundOnLocationWithCaster( origin, sound_start, self:GetCaster() )
	EmitSoundOnLocationWithCaster( target, sound_end, self:GetCaster() )
end

function void_spirit_astral_step_aa:PlayEffects2( target )
	-- Get Resources
	local particle_cast = "particles/units/heroes/hero_void_spirit/astral_step/void_spirit_astral_step_impact.vpcf"

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN_FOLLOW, target )
	ParticleManager:ReleaseParticleIndex( effect_cast )
end

modifier_void_spirit_astral_step_lua = class({
    IsHidden = function() return false end,
    IsDebuff = function() return true end,
    IsStunDebuff = function() return false end,
    IsPurgable = function() return true end,
    GetAttributes = function() return MODIFIER_ATTRIBUTE_MULTIPLE end,
    GetModifierMoveSpeedBonus_Percentage = function(self) return self:GetAbility():GetSpecialValueFor( "movement_slow_pct" ) end,
    DeclareFunctions = function() return {MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE} end,
    GetEffectName = function() return "particles/units/heroes/hero_void_spirit/astral_step/void_spirit_astral_step_debuff.vpcf" end,
    GetEffectAttachType = function() return PATTACH_ABSORIGIN_FOLLOW end,
    GetStatusEffectName = function() return "particles/status_fx/status_effect_void_spirit_astral_step_debuff.vpcf" end,
    StatusEffectPriority = function() return MODIFIER_PRIORITY_NORMAL end,
})
function modifier_void_spirit_astral_step_lua:OnDestroy()
	if not IsServer() then return end
	-- Apply damage
	local damageTable = {
		victim = self:GetParent(),
		attacker = self:GetCaster(),
		damage = self:GetAbility():GetSpecialValueFor( "pop_damage" ) + self:GetParent():GetHealth() * self:GetAbility():GetSpecialValueFor( "damage_hp_pct" )/100,
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = self:GetAbility(), --Optional.
	}
	ApplyDamage(damageTable)

	-- play effects
	self:PlayEffects()
end

function modifier_void_spirit_astral_step_lua:PlayEffects()
	-- Get Resources
	local particle_cast = "particles/units/heroes/hero_void_spirit/astral_step/void_spirit_astral_step_dmg.vpcf"
	local sound_target = "Hero_VoidSpirit.AstralStep.MarkExplosion"

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN_FOLLOW, self:GetParent() )
	ParticleManager:ReleaseParticleIndex( effect_cast )

	-- Create Sound
	EmitSoundOn( sound_target, self:GetParent() )
end