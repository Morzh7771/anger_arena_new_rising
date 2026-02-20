-- New-format (единый стиль, один файл):
-- - LinkLuaModifier -> на этот файл
-- - item_void_stick = class({ ... }) и все методы внутри ({})
-- - Precache: ТОЛЬКО реально используемые particles/models
--   Used particles:
--     particles/void_stick/void_stick_astral.vpcf   (astral)
--     particles/void_stick/void_stick_finish.vpcf   (finish buff)
--   Models: нет
--   Sounds: не precache-им тут (ты просил particles/models)

LinkLuaModifier("modifier_item_void_stick", "items/void_stick/item_void_stick", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_void_stick_cooldown", "items/void_stick/item_void_stick", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_void_stick_astral", "items/void_stick/item_void_stick", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_void_stick_active_finish", "items/void_stick/item_void_stick", LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- locals
--------------------------------------------------------------------------------
local function IsLoneDruidBear(hTarget)
	if not hTarget then return false end
	local name = hTarget:GetUnitName()
	return name == "npc_dota_lone_druid_bear1"
		or name == "npc_dota_lone_druid_bear2"
		or name == "npc_dota_lone_druid_bear3"
		or name == "npc_dota_lone_druid_bear4"
end

--------------------------------------------------------------------------------
-- Item
--------------------------------------------------------------------------------
item_void_stick = class({
	GetIntrinsicModifierName = function(self) return "modifier_item_void_stick" end,

	Precache = function(self, context)
		PrecacheResource("particle", "particles/void_stick/void_stick_astral.vpcf", context)
		PrecacheResource("particle", "particles/void_stick/void_stick_finish.vpcf", context)
	end,

	-- каст на себя разрешаем, также только герои/крипы/медведь
	CastFilterResultTarget = function(self, hTarget)
		if self:GetCaster() == hTarget then
			return UF_SUCCESS
		end

		if not hTarget:IsCreep() and not hTarget:IsHero() and not IsLoneDruidBear(hTarget) then
			return UF_FAIL_CUSTOM
		end

		-- disable-help check (у тебя было второй функцией с тем же именем; объединяю)
		if IsServer() then
			local caster = self:GetCaster()
			local nCasterID = caster:GetPlayerOwnerID()
			local nTargetID = hTarget:GetPlayerOwnerID()

			if (not hTarget:IsOpposingTeam(caster:GetTeamNumber()))
				and PlayerResource:IsDisableHelpSetForPlayerID(nTargetID, nCasterID)
			then
				return UF_FAIL_DISABLE_HELP
			end
		end

		return UF_SUCCESS
	end,

	GetCustomCastErrorTarget = function(self, hTarget)
		if not hTarget:IsCreep() and not hTarget:IsHero() and not IsLoneDruidBear(hTarget) then
			return "#dota_hud_error_cast_only_hero_and_creeps"
		end
		return ""
	end,

	_StartAstral = function(self)
		self:_EndAstral()

		local caster = self:GetCaster()
		local duration = self:GetSpecialValueFor("astral_duration")

		caster:AddNewModifier(caster, self, "modifier_item_void_stick_astral", { duration = duration })
		caster:EmitSound("Hero_Grimstroke.InkSwell.Cast")
	end,

	_EndAstral = function(self)
		local caster = self:GetCaster()
		caster:StopSound("Hero_Grimstroke.InkSwell.Cast")
		caster:RemoveModifierByName("modifier_item_void_stick_astral")
	end,

	OnSpellStart = function(self)
		local caster = self:GetCaster()
		if caster then
			self:SetChanneling(false)
			self:_StartAstral()
		end
	end,

	OnChannelFinish = function(self, bInterrupted)
		local caster = self:GetCaster()

		if not bInterrupted then
			local durationFinishBuff = self:GetSpecialValueFor("after_cast_bonus_duration")
			caster:AddNewModifier(caster, self, "modifier_void_stick_active_finish", { duration = durationFinishBuff })
		end

		self:_EndAstral()
	end,
})

--------------------------------------------------------------------------------
-- Astral modifier (out of game + regen)
--------------------------------------------------------------------------------
modifier_item_void_stick_astral = class({
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return false end,
	DestroyOnExpire = function(self) return true end,
	IsDebuff = function(self) return false end,
	GetTexture = function(self) return "../items/void_stick_big" end,

	OnCreated = function(self)
		local ability = self:GetAbility()
		self.regen = ability and ability:GetSpecialValueFor("astral_regen") or 0

		if not IsServer() then return end

		local caster = ability:GetCaster()
		local casterPosition = caster:GetAbsOrigin()

		caster:AddNoDraw()

		self.particle1 = ParticleManager:CreateParticle(
			"particles/void_stick/void_stick_astral.vpcf",
			PATTACH_WORLDORIGIN,
			caster
		)
		ParticleManager:SetParticleControl(self.particle1, 0, casterPosition + Vector(0, 0, 135))

		caster:Purge(false, true, false, true, false)
		caster:RemoveModifierByName("modifier_wisp_tether")
	end,

	OnDestroy = function(self)
		if not IsServer() then return end

		if self.particle1 then
			ParticleManager:DestroyParticle(self.particle1, false)
			ParticleManager:ReleaseParticleIndex(self.particle1)
			self.particle1 = nil
		end

		local ability = self:GetAbility()
		if ability and ability:GetCaster() then
			ability:GetCaster():RemoveNoDraw()
		end
	end,

	DeclareFunctions = function(self)
		return {
			MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE,
			MODIFIER_PROPERTY_MANA_REGEN_TOTAL_PERCENTAGE,
		}
	end,

	CheckState = function(self)
		return {
			[MODIFIER_STATE_OUT_OF_GAME] = true,
			[MODIFIER_STATE_NOT_ON_MINIMAP] = true,
			[MODIFIER_STATE_ATTACK_IMMUNE] = true,
			[MODIFIER_STATE_MAGIC_IMMUNE] = true,
			[MODIFIER_STATE_NO_HEALTH_BAR] = true,
			[MODIFIER_STATE_INVULNERABLE] = true,
			[MODIFIER_STATE_INVISIBLE] = true,
		}
	end,

	GetModifierHealthRegenPercentage = function(self) return self.regen or 0 end,
	GetModifierTotalPercentageManaRegen = function(self) return self.regen or 0 end,
})

--------------------------------------------------------------------------------
-- Cooldown reduction modifier (separate)
--------------------------------------------------------------------------------
modifier_item_void_stick_cooldown = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,
	DestroyOnExpire = function(self) return false end,
	GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT end,

	OnCreated = function(self)
		self.bonus_cooldown_reduction = (self:GetAbility() and self:GetAbility():GetSpecialValueFor("cooldown_reduction")) or 0
	end,

	DeclareFunctions = function(self)
		return { MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE }
	end,

	GetModifierPercentageCooldown = function(self)
		return self.bonus_cooldown_reduction or 0
	end,
})

--------------------------------------------------------------------------------
-- Intrinsic stats modifier
--------------------------------------------------------------------------------
modifier_item_void_stick = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,
	DestroyOnExpire = function(self) return false end,
	GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT end,

	DeclareFunctions = function(self)
		return {
			MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
			MODIFIER_PROPERTY_HEALTH_BONUS,
			MODIFIER_PROPERTY_MANA_BONUS,
			MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
			MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
			MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
			MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE,
			MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
		}
	end,

	ReloadCooldownBuff = function(self)
		if not IsServer() then return end

		local parent = self:GetParent()
		local cooldownModifierName = "modifier_item_void_stick_cooldown"
		local hasMainBuff = parent:HasModifier(self:GetName())

		if not parent:HasModifier(cooldownModifierName) and hasMainBuff then
			parent:AddNewModifier(parent, self:GetAbility(), cooldownModifierName, nil)
		elseif not hasMainBuff then
			parent:RemoveModifierByName(cooldownModifierName)
		end
	end,

	OnCreated = function(self)
		local ability = self:GetAbility()
		self.bonus_int = (ability and ability:GetSpecialValueFor("bonus_int")) or 0
		self.bonus_hp = (ability and ability:GetSpecialValueFor("bonus_hp")) or 0
		self.bonus_mana = (ability and ability:GetSpecialValueFor("bonus_mana")) or 0
		self.bonus_mgregen = (ability and ability:GetSpecialValueFor("bonus_mpregen")) or 0
		self.bonus_hpregen = (ability and ability:GetSpecialValueFor("bonus_hpregen")) or 0
		self.bonus_speed = (ability and ability:GetSpecialValueFor("bonus_speed")) or 0
		self.bonus_spell_lifesteal = (ability and ability:GetSpecialValueFor("bonus_spell_lifesteal")) or 0
		self.bonus_spell_amp = (ability and ability:GetSpecialValueFor("bonus_spell_amp")) or 0

		self:ReloadCooldownBuff()
	end,

	OnDestroy = function(self)
		self:ReloadCooldownBuff()
	end,

	GetModifierManaBonus = function(self) return self.bonus_mana or 0 end,
	GetModifierHealthBonus = function(self) return self.bonus_hp or 0 end,
	GetModifierBonusStats_Intellect = function(self) return self.bonus_int or 0 end,
	GetModifierConstantManaRegen = function(self) return self.bonus_mgregen or 0 end,
	GetModifierConstantHealthRegen = function(self) return self.bonus_hpregen or 0 end,
	GetModifierSpellAmplify_Percentage = function(self) return self.bonus_spell_amp or 0 end,
	GetModifierMoveSpeedBonus_Constant = function(self) return self.bonus_speed or 0 end,
})

--------------------------------------------------------------------------------
-- Finish buff after successful channel
--------------------------------------------------------------------------------
modifier_void_stick_active_finish = class({
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return false end,
	DestroyOnExpire = function(self) return true end,
	IsDebuff = function(self) return false end,
	RemoveOnDeath = function(self) return true end,
	GetTexture = function(self) return "../items/void_stick_big" end,
	GetEffectName = function(self) return "particles/void_stick/void_stick_finish.vpcf" end,

	OnCreated = function(self)
		local ability = self:GetAbility()
		self.after_cast_mana_regen = ability and ability:GetSpecialValueFor("after_cast_mana_regen") or 0
		self.after_cast_reduce_manacost_pct = ability and ability:GetSpecialValueFor("after_cast_reduce_manacost_pct") or 0
	end,

	DeclareFunctions = function(self)
		return {
			MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
			MODIFIER_PROPERTY_MANACOST_PERCENTAGE,
		}
	end,

	GetModifierConstantManaRegen = function(self) return self.after_cast_mana_regen or 0 end,
	GetModifierPercentageManacost = function(self) return self.after_cast_reduce_manacost_pct or 0 end,
})