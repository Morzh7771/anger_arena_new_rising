--------------------------------------------------------------------------------
abaddon_aphotic_shield_lua = class({})
LinkLuaModifier( "modifier_abaddon_aphotic_shield_lua", "heroes/abaddon/abaddon_aphotic_shield_lua", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------
-- Init Abilities
function abaddon_aphotic_shield_lua:Precache( context )
	PrecacheResource( "soundfile", "soundevents/game_sounds_heroes/game_sounds_abaddon.vsndevts", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_abaddon/abaddon_aphotic_shield.vpcf", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_abaddon/abaddon_aphotic_shield_hit.vpcf", context )
end

--------------------------------------------------------------------------------
-- Ability Start
function abaddon_aphotic_shield_lua:OnSpellStart()
	-- unit identifier
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	-- load data
	local duration = self:GetSpecialValueFor( "duration" )

	-- destroy old one
	local modifier = target:FindModifierByNameAndCaster( "modifier_abaddon_aphotic_shield_lua", caster)
	if modifier then
		modifier:Destroy()
	end

	-- add modifier
	target:AddNewModifier(
		caster,
		self,
		"modifier_abaddon_aphotic_shield_lua",
		{duration = duration}
	)

	-- purge
	target:Purge( false, true, false, true, true)
end

modifier_abaddon_aphotic_shield_lua = class({
    IsHidden = function () return false end,
    IsDebuff = function () return false end,
    IsPurgable = function () return true end,
    GetModifierConstantHealthRegen = function (self) return self:GetAbility():GetSpecialValueFor( "regen" ) end,
})

function modifier_abaddon_aphotic_shield_lua:OnCreated( kv )
	self.caster = self:GetCaster()
	self.parent = self:GetParent()

	-- references
	self.barrier = self:GetAbility():GetSpecialValueFor( "damage_absorb" ) + self:GetCaster():GetMaxHealth() * self:GetAbility():GetSpecialValueFor( "damage_absorb_pct" ) / 100
	self.radius = self:GetAbility():GetSpecialValueFor( "radius" )

	if not IsServer() then return end

	self.max_shield = self.barrier
	self.current_shield = self.barrier

	-- send init data from server to client
	self:SetHasCustomTransmitterData( true )

	-- precache damage
	self.damageTable = {
		-- victim = target,
		attacker = self:GetParent(),
		damage = self.barrier,
		damage_type = self:GetAbility():GetAbilityDamageType(),
		ability = self:GetAbility(), --Optional.
	}

	-- Play effects
	self:PlayEffects()
end

function modifier_abaddon_aphotic_shield_lua:OnDestroy()
	if not IsServer() then return end

	-- find units in radius
	local enemies = FindUnitsInRadius(
		self.caster:GetTeamNumber(),	-- int, your team number
		self.parent:GetOrigin(),	-- point, center point
		nil,	-- handle, cacheUnit. (not known)
		self.radius,	-- float, radius. or use FIND_UNITS_EVERYWHERE
		DOTA_UNIT_TARGET_TEAM_ENEMY,	-- int, team filter
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,	-- int, type filter
		0,	-- int, flag filter
		0,	-- int, order filter
		false	-- bool, can grow cache
	)

	for _,enemy in pairs(enemies) do
		-- apply damage
		self.damageTable.victim = enemy
		ApplyDamage( self.damageTable )
	end

	-- Play effects
	StopSoundOn("Hero_Abaddon.AphoticShield.Loop", self.parent)
	EmitSoundOn("Hero_Abaddon.AphoticShield.Destroy", self.parent)
end

--------------------------------------------------------------------------------
-- Transmitter data
function modifier_abaddon_aphotic_shield_lua:AddCustomTransmitterData()
	-- on server
	local data = {
		max_shield = self.max_shield,
		current_shield = self.current_shield
	}

	return data
end

function modifier_abaddon_aphotic_shield_lua:HandleCustomTransmitterData( data )
	-- on client
	self.max_shield = data.max_shield
	self.current_shield = data.current_shield
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_abaddon_aphotic_shield_lua:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_INCOMING_DAMAGE_CONSTANT,
        MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT 
	}

	return funcs
end

function modifier_abaddon_aphotic_shield_lua:GetModifierIncomingDamageConstant( params )
	if not IsServer() then
		-- shows max and current shield value on client
		if params.report_max then
			return self.max_shield
		else
			return self.current_shield
		end
	end

	-- play effects
	self:PlayEffects2()

	-- block based on damage
	if params.damage>self.current_shield then
		self:Destroy()
		return -self.current_shield
	else
		self.current_shield = self.current_shield-params.damage

		-- refresh shield on client using transmitter data
		self:SendBuffRefreshToClients()

		return -params.damage
	end
end

--------------------------------------------------------------------------------
-- Graphics & Animations
function modifier_abaddon_aphotic_shield_lua:PlayEffects()
	-- Get Resources
	local particle_cast = "particles/units/heroes/hero_abaddon/abaddon_aphotic_shield.vpcf"

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_POINT_FOLLOW, self.parent )
	ParticleManager:SetParticleControlEnt(
		effect_cast,
		0,
		self.parent,
		PATTACH_POINT_FOLLOW,
		"attach_hitloc",
		Vector(0,0,0), -- unknown
		true -- unknown, true
	)
	ParticleManager:SetParticleControl( effect_cast, 1, Vector(80,80,80) )

	-- buff particle
	self:AddParticle(
		effect_cast,
		false, -- bDestroyImmediately
		false, -- bStatusEffect
		-1, -- iPriority
		false, -- bHeroEffect
		false -- bOverheadEffect
	)

	-- Create Sound
	EmitSoundOn("Hero_Abaddon.AphoticShield.Cast", self.parent)
	EmitSoundOn("Hero_Abaddon.AphoticShield.Loop", self.parent)
end


function modifier_abaddon_aphotic_shield_lua:PlayEffects2()
	-- Get Resources
	local particle_cast = "particles/units/heroes/hero_abaddon/abaddon_aphotic_shield_hit.vpcf"

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_POINT_FOLLOW, self.parent )
	ParticleManager:SetParticleControlEnt(
		effect_cast,
		0,
		self.parent,
		PATTACH_POINT_FOLLOW,
		"attach_hitloc",
		Vector(0,0,0), -- unknown
		true -- unknown, true
	)
	ParticleManager:SetParticleControl( effect_cast, 1, Vector(80,80,80) )
	ParticleManager:ReleaseParticleIndex( effect_cast )
end