-- New-format single-file version (как договаривались):
-- - LinkLuaModifier указывает на этот файл
-- - item = class({ ... }) стиль
-- - Precache: ТОЛЬКО ресурсы, которые реально используются (particles + models если есть)
-- - Логику оставил как в оригинале

LinkLuaModifier('modifier_item_fury_shield_passive', 'items/fury_shield/item_fury_shield', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_item_fury_shield_active', 'items/fury_shield/item_fury_shield', LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- Item
--------------------------------------------------------------------------------
item_fury_shield = class({
	GetIntrinsicModifierName = function(self) return 'modifier_item_fury_shield_passive' end
})

function item_fury_shield:GetTexture()
	return "fury_shield"
end

function item_fury_shield:Precache(context)
	-- ONLY used particles
	PrecacheResource("particle", "particles/status_fx/status_effect_forcestaff.vpcf", context) -- GetStatusEffectName
	PrecacheResource("particle", "particles/fury_shield/fury_shield.vpcf", context)            -- OnCreated particle
end

function item_fury_shield:OnSpellStart()
	local caster = self:GetCaster()

	caster:AddNewModifier(caster, self, "modifier_item_fury_shield_active", {
		duration = self:GetSpecialValueFor("shield_duration"),
		block_damage = self:GetSpecialValueFor("block_damage"),
	})
end

--------------------------------------------------------------------------------
-- Active
--------------------------------------------------------------------------------
modifier_item_fury_shield_active = class({
	IsHidden = function(self) return false end,
	IsDebuff = function(self) return false end,
	IsPurgable = function(self) return true end,
	DestroyOnExpire = function(self) return true end,
	GetTexture = function(self) return "../items/fury_shield_big" end,

	GetStatusEffectName = function(self)
		return "particles/status_fx/status_effect_forcestaff.vpcf"
	end,

	DeclareFunctions = function(self)
		return {
			MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
			MODIFIER_PROPERTY_PHYSICAL_CONSTANT_BLOCK,
		}
	end,

	GetModifierAttackSpeedBonus_Constant = function(self) return self.aspeed or 0 end,
	GetModifierPhysical_ConstantBlock = function(self) return self.block or 0 end,
})

function modifier_item_fury_shield_active:OnCreated(kv)
	self.block = (kv and kv.block_damage) or 0
	self.aspeed = (self:GetAbility() and self:GetAbility():GetSpecialValueFor("active_bonus_aspeed")) or 0

	if not IsServer() then return end

	self.particleFuryShield = ParticleManager:CreateParticle(
		"particles/fury_shield/fury_shield.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		self:GetParent()
	)
	ParticleManager:SetParticleControlEnt(
		self.particleFuryShield,
		1,
		self:GetParent(),
		PATTACH_POINT_FOLLOW,
		"attach_hitloc",
		self:GetParent():GetAbsOrigin(),
		true
	)
end

function modifier_item_fury_shield_active:OnDestroy()
	if not IsServer() then return end
	if self.particleFuryShield then
		ParticleManager:DestroyParticle(self.particleFuryShield, false)
		ParticleManager:ReleaseParticleIndex(self.particleFuryShield)
		self.particleFuryShield = nil
	end
end

--------------------------------------------------------------------------------
-- Passive
--------------------------------------------------------------------------------
modifier_item_fury_shield_passive = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,
	DestroyOnExpire = function(self) return false end,
	GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT end,

	DeclareFunctions = function(self)
		return {
			MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
			MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
			MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
		}
	end,

	GetModifierBonusStats_Strength = function(self)
		return (self:GetAbility() and self:GetAbility():GetSpecialValueFor("bonus_stats")) or 0
	end,

	GetModifierBonusStats_Agility = function(self)
		return (self:GetAbility() and self:GetAbility():GetSpecialValueFor("bonus_stats")) or 0
	end,

	GetModifierBonusStats_Intellect = function(self)
		return (self:GetAbility() and self:GetAbility():GetSpecialValueFor("bonus_stats")) or 0
	end,
})