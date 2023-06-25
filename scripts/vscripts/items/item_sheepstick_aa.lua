item_sheepstick_aa = class({})


LinkLuaModifier( "modifier_item_sheepstick_aa", "items/item_sheepstick_aa.lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_sheepstick_hex", "items/item_sheepstick_aa.lua", LUA_MODIFIER_MOTION_NONE )

function item_sheepstick_aa:GetIntrinsicModifierName()
	return "modifier_item_sheepstick_aa"
end
function item_sheepstick_aa:OnSpellStart()
	self.caster = self:GetCaster()
	self.target = self:GetCursorTarget()
	self.duration = self:GetSpecialValueFor("sheep_duration")

    if self.target:TriggerSpellAbsorb( self ) then return end
	self.target:AddNewModifier(self.caster, self, "modifier_sheepstick_hex", {duration = self.duration})
end

---------------------------------------------------------------------
--Modifiers
if modifier_item_sheepstick_aa == nil then
	modifier_item_sheepstick_aa = class({})
end
function modifier_item_sheepstick_aa:IsHidden() return true end

function modifier_item_sheepstick_aa:OnCreated(params)
	if IsServer() then
	end
end
function modifier_item_sheepstick_aa:OnRefresh(params)
	if IsServer() then
	end
end
function modifier_item_sheepstick_aa:OnDestroy()
	if IsServer() then
	end
end
function modifier_item_sheepstick_aa:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
        MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
	}
end

function modifier_item_sheepstick_aa:GetModifierBonusStats_Strength()
	return self:GetAbility():GetSpecialValueFor("bonus_strength")
end
function modifier_item_sheepstick_aa:GetModifierBonusStats_Agility()
	return self:GetAbility():GetSpecialValueFor("bonus_agility")
end
function modifier_item_sheepstick_aa:GetModifierBonusStats_Intellect()
	return self:GetAbility():GetSpecialValueFor("bonus_intellect")
end
function modifier_item_sheepstick_aa:GetModifierConstantManaRegen()
	return self:GetAbility():GetSpecialValueFor("bonus_mana_regen")
end
if modifier_sheepstick_hex == nil then
	modifier_sheepstick_hex = class({})
end
function modifier_sheepstick_hex:GetTexture() return "item_sheepstick" end
function modifier_sheepstick_hex:IsHidden()
	return false
end

function modifier_sheepstick_hex:IsDebuff()
	return true
end

function modifier_sheepstick_hex:IsPurgable()
	return true
end
function modifier_sheepstick_hex:OnCreated( kv )
	self.base_speed = self:GetAbility():GetSpecialValueFor( "sheep_movement_speed" )
	self.model = "models/items/hex/sheep_hex/sheep_hex.vmdl"

	if IsServer() then

		self:PlayEffects( true )

		if self:GetParent():IsIllusion() then
			self:GetParent():Kill( self:GetAbility(), self:GetCaster() )
		end
	end
end
function modifier_sheepstick_hex:OnRefresh( kv )
	-- references
	self.base_speed = self:GetAbility():GetSpecialValueFor( "sheep_movement_speed" )
	if IsServer() then
		-- play effects
		self:PlayEffects( true )
	end
end

function modifier_sheepstick_hex:OnDestroy( kv )
	if IsServer() then
		-- play effects
		self:PlayEffects( false )
	end
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_sheepstick_hex:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_MOVESPEED_BASE_OVERRIDE,
		MODIFIER_PROPERTY_MODEL_CHANGE,
	}

	return funcs
end

function modifier_sheepstick_hex:GetModifierMoveSpeedOverride()
	return self.base_speed
end
function modifier_sheepstick_hex:GetModifierModelChange()
	return self.model
end

--------------------------------------------------------------------------------
-- Status Effects
function modifier_sheepstick_hex:CheckState()
	local state = {
	[MODIFIER_STATE_HEXED] = true,
	[MODIFIER_STATE_DISARMED] = true,
	[MODIFIER_STATE_SILENCED] = true,
	[MODIFIER_STATE_MUTED] = true,
    [MODIFIER_STATE_PASSIVES_DISABLED] = true,
	}

	return state
end

--------------------------------------------------------------------------------
-- Graphics & Animations
function modifier_sheepstick_hex:PlayEffects( bStart )
	local sound_cast = "Hero_Lion.Hex.Target"
	local particle_cast = "particles/units/heroes/hero_lion/lion_spell_voodoo.vpcf"

	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN, self:GetParent() )
	ParticleManager:ReleaseParticleIndex( effect_cast )

	if bStart then
		EmitSoundOn( sound_cast, self:GetParent() )
	end
end