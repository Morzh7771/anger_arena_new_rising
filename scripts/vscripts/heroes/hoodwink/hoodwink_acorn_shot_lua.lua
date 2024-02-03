local mainTree = 0
hoodwink_acorn_shot_lua = class({})
LinkLuaModifier( "modifier_hoodwink_acorn_shot_lua", "heroes/hoodwink/hoodwink_acorn_shot_lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_hoodwink_acorn_shot_lua_thinker", "heroes/hoodwink/hoodwink_acorn_shot_lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_hoodwink_acorn_shot_lua_debuff", "heroes/hoodwink/hoodwink_acorn_shot_lua", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------
-- Init Abilities
function hoodwink_acorn_shot_lua:Precache( context )
	PrecacheResource( "soundfile", "soundevents/game_sounds_heroes/game_sounds_hoodwink.vsndevts", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_tracking.vpcf", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_slow.vpcf", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_tree.vpcf", context )
	PrecacheResource( "particle", "particles/tree_fx/tree_simple_explosion.vpcf", context )
end

function hoodwink_acorn_shot_lua:Spawn()
	if not IsServer() then return end
end

--------------------------------------------------------------------------------
-- Custom KV
function hoodwink_acorn_shot_lua:GetCastRange( vLocation, hTarget )
	return self:GetCaster():Script_GetAttackRange() + self:GetSpecialValueFor( "bonus_range" )
end

--------------------------------------------------------------------------------
-- Ability Start
function hoodwink_acorn_shot_lua:OnSpellStart()
	-- unit identifier
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	local point = self:GetCursorPosition()

	-- Hardcoded as it has no kv value
	self.tree_duration = 20
	self.tree_vision = 300

	-- create thinker
	local thinker = CreateModifierThinker(
		caster, -- player source
		self, -- ability source
		"modifier_hoodwink_acorn_shot_lua_thinker", -- modifier name
		{  }, -- kv
		caster:GetOrigin(),
		caster:GetTeamNumber(),
		false
	)
	local mod = thinker:FindModifierByName( "modifier_hoodwink_acorn_shot_lua_thinker" )

	if not target then
		target = thinker
		thinker:SetOrigin( point )
	end
	mod.source = caster
	mod.target = target

	-- play effects
	local sound_cast = "Hero_Hoodwink.AcornShot.Cast"
	EmitSoundOn( sound_cast, caster )
end

--------------------------------------------------------------------------------
-- Projectile
function hoodwink_acorn_shot_lua:OnProjectileHit_ExtraData( target, location, ExtraData )
	--print(location)
	local caster = self:GetCaster()
	local thinker = EntIndexToHScript( ExtraData.thinker )
	local mod = thinker:FindModifierByName( "modifier_hoodwink_acorn_shot_lua_thinker" )
	if not mod then return end

	-- bounce
	thinker:SetOrigin( location )
	mod:Bounce()

	-- only on first shot, if target dodges or no target, create tree
	if ExtraData.first==1 then
		if self:GetAutoCastState() ~= true then
			if target==thinker then
				self:CreateTree( location )
				return
			end
		else
			self:CreateTree( location )
			mod.target = thinker
			return
		end
		-- if no enemy
		if not target then
			self:CreateTree( location )
			mod.target = thinker
			return
		end
		
		if target:TriggerSpellAbsorb( self ) then
			mod:Destroy()
			return
		end
	end

	-- check target
	if not target then
		mod:Destroy()
		return
	end

	local duration = self:GetSpecialValueFor( "debuff_duration" )

	-- attack enemy
	--if self:GetCaster():GetTeamNumber() ~= caster:GetTeamNumber() then
		local mod = caster:AddNewModifier(
			caster, -- player source
			self, -- ability source
			"modifier_hoodwink_acorn_shot_lua", -- modifier name
			{} -- kv
		)
	--end
	caster:PerformAttack(
		target,
		true,
		true,
		true,
		true,
		false,
		false,
		true
	)
	mod:Destroy()
	--print(caster)
	-- debuff
	if target ~= mainTree then
		if target:IsMagicImmune() then
			target:AddNewModifier(
				caster, -- player source
				self, -- ability source
				"modifier_hoodwink_acorn_shot_lua_debuff", -- modifier name
				{ duration = duration } -- kv
			)

			-- play effects
			local sound_slow = "Hero_Hoodwink.AcornShot.Slow"
			EmitSoundOn( sound_slow, target )
		end
	end

	-- play effects
	local sound_target = "Hero_Hoodwink.AcornShot.Target"
	EmitSoundOn( sound_target, target )
end

function hoodwink_acorn_shot_lua:CreateTree( location )
	-- vision
	AddFOWViewer( self:GetCaster():GetTeamNumber(), location, self.tree_vision, self.tree_duration, false )

	-- tree
	mainTree = CreateTempTreeWithModel( location, self.tree_duration, "models/heroes/hoodwink/hoodwink_tree_model.vmdl" )

	-- move everyone on tree collision so they don't get stuck
	local units = FindUnitsInRadius(
		self:GetCaster():GetTeamNumber(),	-- int, your team number
		location,	-- point, center point
		nil,	-- handle, cacheUnit. (not known)
		100,	-- float, radius. or use FIND_UNITS_EVERYWHERE
		DOTA_UNIT_TARGET_TEAM_BOTH,	-- int, team filter
		DOTA_UNIT_TARGET_ALL,	-- int, type filter
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,	-- int, flag filter
		0,	-- int, order filter
		false	-- bool, can grow cache
	)
	for _,unit in pairs(units) do
		FindClearSpaceForUnit( unit, unit:GetOrigin(), true )
	end

	self:PlayEffects1( mainTree, location )
	self:PlayEffects2( mainTree, location )
end

--------------------------------------------------------------------------------
-- Effects
function hoodwink_acorn_shot_lua:PlayEffects1( tree, location )
	print('PlayEffects1')
	-- Get Resources
	local particle_cast = "particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_tree.vpcf"

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN_FOLLOW, tree )
	ParticleManager:SetParticleControl( effect_cast, 0, tree:GetOrigin() )
	ParticleManager:SetParticleControl( effect_cast, 1, Vector( 1, 1, 1 ) )
	ParticleManager:ReleaseParticleIndex( effect_cast )
end

function hoodwink_acorn_shot_lua:PlayEffects2( tree, location )
	print('PlayEffects2')
	-- Get Resources
	local particle_cast = "particles/tree_fx/tree_simple_explosion.vpcf"

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_WORLDORIGIN, nil )
	ParticleManager:SetParticleControl( effect_cast, 0, tree:GetOrigin()+Vector(1,0,0) )
	ParticleManager:ReleaseParticleIndex( effect_cast )
end
modifier_hoodwink_acorn_shot_lua = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_hoodwink_acorn_shot_lua:IsHidden()
	return true
end

function modifier_hoodwink_acorn_shot_lua:IsPurgable()
	return false
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_hoodwink_acorn_shot_lua:OnCreated( kv )
	-- references
	if not IsServer() then return end
	self.bonus = self:GetAbility():GetSpecialValueFor( "bonus_damage" )
end

function modifier_hoodwink_acorn_shot_lua:OnRefresh( kv )
	-- references
	self.bonus = self:GetAbility():GetSpecialValueFor( "bonus_damage" )	
end

function modifier_hoodwink_acorn_shot_lua:OnRemoved()
end

function modifier_hoodwink_acorn_shot_lua:OnDestroy()
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_hoodwink_acorn_shot_lua:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_PROCATTACK_FEEDBACK,
	}

	return funcs
end

function modifier_hoodwink_acorn_shot_lua:GetModifierPreAttack_BonusDamage()
	return self.bonus
end

function modifier_hoodwink_acorn_shot_lua:GetModifierProcAttack_Feedback( params )
	SendOverheadEventMessage(
		nil,
		OVERHEAD_ALERT_DAMAGE,
		params.target,
		params.damage,
		self:GetCaster():GetPlayerOwner()
	)
end
modifier_hoodwink_acorn_shot_lua_debuff = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_hoodwink_acorn_shot_lua_debuff:IsHidden()
	return false
end

function modifier_hoodwink_acorn_shot_lua_debuff:IsDebuff()
	return true
end

function modifier_hoodwink_acorn_shot_lua_debuff:IsStunDebuff()
	return false
end

function modifier_hoodwink_acorn_shot_lua_debuff:IsPurgable()
	return true
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_hoodwink_acorn_shot_lua_debuff:OnCreated( kv )
	-- references
	self.slow = -self:GetAbility():GetSpecialValueFor( "slow" )

	if not IsServer() then return end
end

function modifier_hoodwink_acorn_shot_lua_debuff:OnRefresh( kv )
	self:OnCreated( kv )
end

function modifier_hoodwink_acorn_shot_lua_debuff:OnRemoved()
end

function modifier_hoodwink_acorn_shot_lua_debuff:OnDestroy()
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_hoodwink_acorn_shot_lua_debuff:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	}

	return funcs
end

function modifier_hoodwink_acorn_shot_lua_debuff:GetModifierMoveSpeedBonus_Percentage()
	return self.slow
end

--------------------------------------------------------------------------------
-- Graphics & Animations
function modifier_hoodwink_acorn_shot_lua_debuff:GetEffectName()
	return "particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_slow.vpcf"
end

function modifier_hoodwink_acorn_shot_lua_debuff:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end
modifier_hoodwink_acorn_shot_lua_thinker = class({})

--------------------------------------------------------------------------------
-- Classifications

--------------------------------------------------------------------------------
-- Initializations
function modifier_hoodwink_acorn_shot_lua_thinker:OnCreated( kv )
	self.caster = self:GetCaster()
	self.parent = self:GetParent()
	self.ability = self:GetAbility()

	-- references
	self.projectile_name = "particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_tracking.vpcf"

	self.projectile_speed = self:GetAbility():GetSpecialValueFor( "projectile_speed" )
	self.bounces = self:GetAbility():GetSpecialValueFor( "bounce_count" )+1
	self.damage = self:GetAbility():GetSpecialValueFor( "bonus_damage" )
	self.delay = self:GetAbility():GetSpecialValueFor( "bounce_delay" )
	self.range = self:GetAbility():GetSpecialValueFor( "bounce_range" )

	if not IsServer() then return end
	-- ability properties
	self.abilityDamageType = self:GetAbility():GetAbilityDamageType()
	self.abilityTargetTeam = self:GetAbility():GetAbilityTargetTeam()
	self.abilityTargetType = self:GetAbility():GetAbilityTargetType()
	self.abilityTargetFlags = self:GetAbility():GetAbilityTargetFlags()

	-- precache projectile
	self.info = {
		-- Target = self.target,
		-- Source = self.parent,
		Ability = self.ability,	
		
		EffectName = self.projectile_name,
		iMoveSpeed = self.projectile_speed,
		bDodgeable = true,                           -- Optional
	
		iSourceAttachment = DOTA_PROJECTILE_ATTACHMENT_HITLOCATION,

		bVisibleToEnemies = true,                         -- Optional
		bProvidesVision = true,                           -- Optional
		iVisionRadius = 200,                              -- Optional
		iVisionTeamNumber = self.caster:GetTeamNumber(),        -- Optional
		ExtraData = {
			thinker = self.parent:entindex()
		}
	}
	self.unit = nil
	-- Start bounce in next frame
	self:StartIntervalThink( 0 )
end

function modifier_hoodwink_acorn_shot_lua_thinker:OnRefresh( kv )
	
end

function modifier_hoodwink_acorn_shot_lua_thinker:OnRemoved()
end

function modifier_hoodwink_acorn_shot_lua_thinker:OnDestroy()
	if not IsServer() then return end
	UTIL_Remove( self:GetParent() )
end

--------------------------------------------------------------------------------
-- Interval Effects
function modifier_hoodwink_acorn_shot_lua_thinker:OnIntervalThink()
	
	self.bounces = self.bounces-1
	if self.bounces<0 then
		self:Destroy()
		return
	end

	self:StartIntervalThink(-1)

	local first = 0
	if not self.first then
		self.first = true
		first = 1
		self.info.iMoveSpeed = self.projectile_speed
	else
		self.source = self.target

		-- Find enemies
		local enemies = FindUnitsInRadius(
			self.caster:GetTeamNumber(),	-- int, your team number
			self.target:GetOrigin(),	-- point, center point
			nil,	-- handle, cacheUnit. (not known)
			self.range,	-- float, radius. or use FIND_UNITS_EVERYWHERE
			DOTA_UNIT_TARGET_TEAM_ENEMY,	-- int, team filter
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,	-- int, type filter
			DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,	-- int, flag filter
			0,	-- int, order filter
			false	-- bool, can grow cache
		)
		if #enemies<1 then
			self:Destroy()
			return
		end

		local next_target
		for _,enemy in pairs(enemies) do
			if enemy ~= self.target then
				next_target = enemy
				break
			end
		end
		if not next_target then
			local trees = GridNav:GetAllTreesAroundPoint( self.target:GetAbsOrigin(), self.range, false )
			local bestTree = mainTree
			for _,tree in pairs(trees) do
				print(self.target:GetUnitName())
				if (tree:GetAbsOrigin() - self.target:GetAbsOrigin()):Length2D() < (bestTree:GetAbsOrigin() - self.target:GetAbsOrigin()):Length2D() then
					bestTree = tree
				end
			end
			self.unit = CreateUnitByName("npc_tree_thinker",bestTree:GetAbsOrigin(),false,nil,nil,DOTA_TEAM_NEUTRALS )
			next_target = self.unit
			mainTree = bestTree
			self.bounces = self.bounces+1
		end
		if not next_target then
			self:Destroy()
			return
		end
		self.target = next_target

		self.info.iMoveSpeed = self.caster:GetProjectileSpeed()
	end
	self.info.Source = self.source
	self.info.Target = self.target
	self.info.ExtraData.first = first
	ProjectileManager:CreateTrackingProjectile( self.info )

	-- play effects
	local sound_cast = "Hero_Hoodwink.AcornShot.Bounce"
	EmitSoundOn( sound_cast, self.source )
	
end

--------------------------------------------------------------------------------
-- Helper
function modifier_hoodwink_acorn_shot_lua_thinker:Bounce()
	self:StartIntervalThink( self.delay )
end