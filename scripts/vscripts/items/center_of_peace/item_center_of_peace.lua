LinkLuaModifier('modifier_center_of_peace', 'items/center_of_peace/item_center_of_peace', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_center_of_peace_active_channel', 'items/center_of_peace/item_center_of_peace', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_center_of_peace_active_finish', 'items/center_of_peace/item_center_of_peace', LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- Item
--------------------------------------------------------------------------------
item_center_of_peace = class({
	GetIntrinsicModifierName = function(self) return 'modifier_center_of_peace' end
})

function item_center_of_peace:Precache(context)
	-- ONLY resources реально используемые этим предметом/модификаторами
	PrecacheResource("particle", "particles/center_of_peace/center_of_peace_channel.vpcf", context)
	PrecacheResource("particle", "particles/center_of_peace/center_of_peace_finish_a.vpcf", context)
end

function item_center_of_peace:OnSpellStart()
	local caster = self:GetCaster()
	local durationChannel = self:GetChannelTime()
	caster:AddNewModifier(caster, self, "modifier_center_of_peace_active_channel", { duration = durationChannel })
end

function item_center_of_peace:OnChannelFinish(bInterrupted)
	local caster = self:GetCaster()
	caster:RemoveModifierByName("modifier_center_of_peace_active_channel")

	if not bInterrupted then
		local durationFinishBuff = self:GetSpecialValueFor("after_cast_bonus_duration")
		caster:AddNewModifier(caster, self, "modifier_center_of_peace_active_finish", { duration = durationFinishBuff })
	end
end

--------------------------------------------------------------------------------
-- Active: Channel
--------------------------------------------------------------------------------
modifier_center_of_peace_active_channel = class({
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return false end,
	DestroyOnExpire = function(self) return true end,
	IsDebuff = function(self) return false end,
	RemoveOnDeath = function(self) return true end,
	GetTexture = function(self) return "../items/center_of_peace_big" end,
	GetEffectName = function(self) return "particles/center_of_peace/center_of_peace_channel.vpcf" end,

	OnCreated = function(self)
		if not self:GetAbility() then return end
		self.mana_regen_total_pct = self:GetAbility():GetSpecialValueFor("mana_regen_total_pct")
		self.bonus_magical_resist = self:GetAbility():GetSpecialValueFor("bonus_magical_resist")
	end,

	DeclareFunctions = function(self)
		return {
			MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
			MODIFIER_PROPERTY_MANA_REGEN_TOTAL_PERCENTAGE,
		}
	end,

	GetModifierMagicalResistanceBonus = function(self)
		return self.bonus_magical_resist or 0
	end,

	GetModifierTotalPercentageManaRegen = function(self)
		return self.mana_regen_total_pct or 0
	end,
})

--------------------------------------------------------------------------------
-- Active: Finish
--------------------------------------------------------------------------------
modifier_center_of_peace_active_finish = class({
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return false end,
	DestroyOnExpire = function(self) return true end,
	IsDebuff = function(self) return false end,
	RemoveOnDeath = function(self) return true end,
	GetTexture = function(self) return "../items/center_of_peace_big" end,
	GetEffectName = function(self) return "particles/center_of_peace/center_of_peace_finish_a.vpcf" end,

	OnCreated = function(self)
		if not self:GetAbility() then return end
		self.after_cast_mana_regen = self:GetAbility():GetSpecialValueFor("after_cast_mana_regen")
		self.after_cast_reduce_manacost_pct = self:GetAbility():GetSpecialValueFor("after_cast_reduce_manacost_pct")
	end,

	DeclareFunctions = function(self)
		return {
			MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
			MODIFIER_PROPERTY_MANACOST_PERCENTAGE_STACKING,
		}
	end,

	GetModifierConstantManaRegen = function(self)
		return self.after_cast_mana_regen or 0
	end,

	GetModifierPercentageManacostStacking = function(self)
		return self.after_cast_reduce_manacost_pct or 0
	end,
})

--------------------------------------------------------------------------------
-- Passive: Intrinsic stats
--------------------------------------------------------------------------------
modifier_center_of_peace = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,
	DestroyOnExpire = function(self) return false end,

	GetAttributes = function(self)
		return MODIFIER_ATTRIBUTE_PERMANENT
	end,

	OnCreated = function(self)
		if not self:GetAbility() then return end
		self.bonus_mana = self:GetAbility():GetSpecialValueFor("bonus_mana")
		self.bonus_int = self:GetAbility():GetSpecialValueFor("bonus_int")
		self.bonus_agi = self:GetAbility():GetSpecialValueFor("bonus_agi")
		self.bonus_str = self:GetAbility():GetSpecialValueFor("bonus_str")
		self.bonus_manaregen = self:GetAbility():GetSpecialValueFor("bonus_manaregen")
		self.bonus_spell_amp = self:GetAbility():GetSpecialValueFor("bonus_spell_amp")
	end,

	DeclareFunctions = function(self)
		return {
			MODIFIER_PROPERTY_MANA_BONUS,
			MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
			MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
			MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
			MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
			MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
		}
	end,

	GetModifierManaBonus = function(self) return self.bonus_mana or 0 end,
	GetModifierBonusStats_Strength = function(self) return self.bonus_str or 0 end,
	GetModifierBonusStats_Agility = function(self) return self.bonus_agi or 0 end,
	GetModifierBonusStats_Intellect = function(self) return self.bonus_int or 0 end,
	GetModifierConstantManaRegen = function(self) return self.bonus_manaregen or 0 end,
	GetModifierSpellAmplify_Percentage = function(self) return self.bonus_spell_amp or 0 end,
})