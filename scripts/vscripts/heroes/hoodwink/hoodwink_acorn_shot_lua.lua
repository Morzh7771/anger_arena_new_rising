hoodwink_acorn_shot_lua = class({})
LinkLuaModifier( "modifier_hoodwink_acorn_shot_lua", "heroes/hoodwink/hoodwink_acorn_shot_lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_hoodwink_acorn_shot_lua_thinker", "heroes/hoodwink/hoodwink_acorn_shot_lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_hoodwink_acorn_shot_lua_debuff", "heroes/hoodwink/hoodwink_acorn_shot_lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_hoodwink_acorn_shot_lua_tree_target", "heroes/hoodwink/hoodwink_acorn_shot_lua", LUA_MODIFIER_MOTION_NONE )

-- Hardcoded as it has no kv value
local TREE_DURATION = 20
local TREE_VISION = 300
-- высота мишени над деревом: жёлудь летит в крону, а не в корни
local TREE_TARGET_HEIGHT = 100

--------------------------------------------------------------------------------
-- Init Abilities
function hoodwink_acorn_shot_lua:Precache( context )
	PrecacheResource( "soundfile", "soundevents/game_sounds_heroes/game_sounds_hoodwink.vsndevts", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_tracking.vpcf", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_slow.vpcf", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_tree.vpcf", context )
	PrecacheResource( "particle", "particles/tree_fx/tree_simple_explosion.vpcf", context )
end

--------------------------------------------------------------------------------
-- Custom KV
function hoodwink_acorn_shot_lua:GetCastRange( vLocation, hTarget )
	return self:GetCaster():Script_GetAttackRange() + self:GetSpecialValueFor( "bonus_range" )
end

--------------------------------------------------------------------------------
-- Ability Start
function hoodwink_acorn_shot_lua:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	local point = self:GetCursorPosition()

	local thinker = CreateModifierThinker(
		caster, self, "modifier_hoodwink_acorn_shot_lua_thinker", {},
		caster:GetOrigin(), caster:GetTeamNumber(), false
	)
	local mod = thinker:FindModifierByName( "modifier_hoodwink_acorn_shot_lua_thinker" )

	if not target then
		target = thinker
		thinker:SetOrigin( point )
	end
	mod.source = caster
	mod.target = target

	EmitSoundOn( "Hero_Hoodwink.AcornShot.Cast", caster )
end

--------------------------------------------------------------------------------
-- Projectile
function hoodwink_acorn_shot_lua:OnProjectileHit_ExtraData( target, location, ExtraData )
	local caster = self:GetCaster()
	local thinker = EntIndexToHScript( ExtraData.thinker )
	if not thinker or thinker:IsNull() then return end
	local mod = thinker:FindModifierByName( "modifier_hoodwink_acorn_shot_lua_thinker" )
	if not mod then return end

	-- следующий отскок считается от точки попадания
	thinker:SetOrigin( location )
	mod:Bounce()

	-- попали в дерево: урона нет, просто летим дальше
	if ExtraData.tree==1 then
		return
	end

	-- only on first shot, if target dodges or no target, create tree
	if ExtraData.first==1 then
		if self:GetAutoCastState() or not target or target==thinker then
			mod.last_tree = self:CreateTree( location )
			mod.target = thinker
			return
		end

		if target:TriggerSpellAbsorb( self ) then
			mod:Destroy()
			return
		end
	end

	if not target then
		mod:Destroy()
		return
	end

	-- attack enemy
	local bonus = caster:AddNewModifier( caster, self, "modifier_hoodwink_acorn_shot_lua", {} )
	caster:PerformAttack( target, true, true, true, true, false, false, true )
	if bonus and not bonus:IsNull() then bonus:Destroy() end

	-- debuff
	target:AddNewModifier( caster, self, "modifier_hoodwink_acorn_shot_lua_debuff", { duration = self:GetSpecialValueFor( "debuff_duration" ) } )
	EmitSoundOn( "Hero_Hoodwink.AcornShot.Slow", target )
	EmitSoundOn( "Hero_Hoodwink.AcornShot.Target", target )
end

function hoodwink_acorn_shot_lua:CreateTree( location )
	AddFOWViewer( self:GetCaster():GetTeamNumber(), location, TREE_VISION, TREE_DURATION, false )

	local tree = CreateTempTreeWithModel( location, TREE_DURATION, "models/heroes/hoodwink/hoodwink_tree_model.vmdl" )

	-- move everyone on tree collision so they don't get stuck
	local units = FindUnitsInRadius(
		self:GetCaster():GetTeamNumber(), location, nil, 100,
		DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_ALL,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, 0, false
	)
	for _,unit in pairs(units) do
		FindClearSpaceForUnit( unit, unit:GetOrigin(), true )
	end

	if tree then
		self:PlayEffects1( tree )
		self:PlayEffects2( tree )
	end
	return tree
end

--------------------------------------------------------------------------------
-- Ближайшее стоящее дерево в радиусе: деревья карты и любые временные
-- (Hoodwink, Furion, Monkey King, Ironwood Tree и т.п.).
function hoodwink_acorn_shot_lua:FindNearestTree( point, radius, exclude )
	local best, best_dist = nil, radius + 1

	local function consider( tree )
		if not tree or tree:IsNull() or tree == exclude then return end
		-- срубленное дерево карты остаётся сущностью - пропускаем
		if tree.IsStanding and not tree:IsStanding() then return end
		local dist = ( tree:GetAbsOrigin() - point ):Length2D()
		if dist < best_dist then
			best, best_dist = tree, dist
		end
	end

	for _,tree in pairs( GridNav:GetAllTreesAroundPoint( point, radius, false ) ) do
		consider( tree )
	end
	-- временные деревья добираем по классу, если GridNav их не отдал
	for _,tree in pairs( Entities:FindAllByClassnameWithin( "dota_temp_tree", point, radius ) ) do
		consider( tree )
	end

	return best
end

--------------------------------------------------------------------------------
-- Effects
function hoodwink_acorn_shot_lua:PlayEffects1( tree )
	local effect_cast = ParticleManager:CreateParticle( "particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_tree.vpcf", PATTACH_ABSORIGIN_FOLLOW, tree )
	ParticleManager:SetParticleControl( effect_cast, 0, tree:GetOrigin() )
	ParticleManager:SetParticleControl( effect_cast, 1, Vector( 1, 1, 1 ) )
	ParticleManager:ReleaseParticleIndex( effect_cast )
end

function hoodwink_acorn_shot_lua:PlayEffects2( tree )
	local effect_cast = ParticleManager:CreateParticle( "particles/tree_fx/tree_simple_explosion.vpcf", PATTACH_WORLDORIGIN, nil )
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
modifier_hoodwink_acorn_shot_lua_tree_target = class({})
-- Невидимая мишень в кроне дерева: самонаводящемуся снаряду нужен юнит-цель.
-- Живёт по duration и удаляет своего тинкера.
function modifier_hoodwink_acorn_shot_lua_tree_target:IsHidden() return true end
function modifier_hoodwink_acorn_shot_lua_tree_target:IsPurgable() return false end
function modifier_hoodwink_acorn_shot_lua_tree_target:OnDestroy()
	if not IsServer() then return end
	UTIL_Remove( self:GetParent() )
end

modifier_hoodwink_acorn_shot_lua_thinker = class({})

--------------------------------------------------------------------------------
-- Initializations
function modifier_hoodwink_acorn_shot_lua_thinker:OnCreated( kv )
	self.caster = self:GetCaster()
	self.parent = self:GetParent()
	self.ability = self:GetAbility()

	self.projectile_speed = self.ability:GetSpecialValueFor( "projectile_speed" )
	self.bounces = self.ability:GetSpecialValueFor( "bounce_count" )+1
	self.delay = self.ability:GetSpecialValueFor( "bounce_delay" )
	self.range = self.ability:GetSpecialValueFor( "bounce_range" )
	self.bounce_speed = self.ability:GetSpecialValueFor( "bounce_speed" )

	if not IsServer() then return end

	self.info = {
		Ability = self.ability,
		EffectName = "particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_tracking.vpcf",
		iMoveSpeed = self.projectile_speed,
		bDodgeable = true,
		iSourceAttachment = DOTA_PROJECTILE_ATTACHMENT_HITLOCATION,
		bVisibleToEnemies = true,
		bProvidesVision = true,
		iVisionRadius = 200,
		iVisionTeamNumber = self.caster:GetTeamNumber(),
		ExtraData = {
			thinker = self.parent:entindex()
		}
	}
	-- Start bounce in next frame
	self:StartIntervalThink( 0 )
end

function modifier_hoodwink_acorn_shot_lua_thinker:OnDestroy()
	if not IsServer() then return end
	UTIL_Remove( self:GetParent() )
end

--------------------------------------------------------------------------------
-- Interval Effects
function modifier_hoodwink_acorn_shot_lua_thinker:OnIntervalThink()
	self:StartIntervalThink(-1)

	self.bounces = self.bounces-1
	if self.bounces<0 then
		self:Destroy()
		return
	end

	local first = 0
	local is_tree = 0
	if not self.first then
		self.first = true
		first = 1
	else
		if not self.target or self.target:IsNull() then
			self:Destroy()
			return
		end
		self.source = self.target
		-- точка отскока: тинкер стоит там, где жёлудь попал в прошлую цель
		local origin = self.parent:GetAbsOrigin()

		-- 1) ближайший враг, кроме того, в кого только что попали
		local next_target
		local enemies = FindUnitsInRadius(
			self.caster:GetTeamNumber(), origin, nil, self.range,
			DOTA_UNIT_TARGET_TEAM_ENEMY,
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
			FIND_CLOSEST, false
		)
		for _,enemy in pairs(enemies) do
			if enemy ~= self.target then
				next_target = enemy
				break
			end
		end

		-- 2) врагов нет - отскок в ближайшее дерево (кроме того, от которого отлетели)
		if not next_target then
			local tree = self.ability:FindNearestTree( origin, self.range, self.last_tree )
			if tree then
				local pos = GetGroundPosition( tree:GetAbsOrigin(), nil ) + Vector( 0, 0, TREE_TARGET_HEIGHT )
				next_target = CreateModifierThinker(
					self.caster, self.ability, "modifier_hoodwink_acorn_shot_lua_tree_target",
					{ duration = 10 }, pos, self.caster:GetTeamNumber(), false
				)
				self.last_tree = tree
				is_tree = 1
			end
		end

		if not next_target then
			self:Destroy()
			return
		end
		-- попали во врага - дерево снова можно выбрать
		if is_tree==0 then
			self.last_tree = nil
		end
		self.target = next_target
		self.info.iMoveSpeed = self.bounce_speed
	end

	self.info.Source = self.source
	self.info.Target = self.target
	self.info.ExtraData.first = first
	self.info.ExtraData.tree = is_tree
	ProjectileManager:CreateTrackingProjectile( self.info )

	EmitSoundOn( "Hero_Hoodwink.AcornShot.Bounce", self.source )
end

--------------------------------------------------------------------------------
-- Helper
function modifier_hoodwink_acorn_shot_lua_thinker:Bounce()
	self:StartIntervalThink( self.delay )
end
