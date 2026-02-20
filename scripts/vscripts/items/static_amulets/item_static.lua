-- New-format (единый стиль, без разнобоя):
-- - убрал отдельные _projectileHit/_startSpell: всё внутри class({}) как методы
-- - LinkLuaModifier -> на ЭТОТ файл
-- - Precache: ТОЛЬКО реально используемые particles + модели (моделей нет)
--   Используемые particles здесь:
--     1) particles/items2_fx/skadi_projectile.vpcf (tracking projectile)
--     2) particles/units/heroes/hero_pangolier/pangolier_luckyshot_disarm_debuff.vpcf (disarm debuff effect)
--     3) particles/status_fx/status_effect_faceless_timewalk.vpcf (status effect на count моде)
--
-- ВАЖНО: В оригинале звук в _startSpell указан как путь к .vsnd файлу.
-- В Dota обычно нужны sound event names (типа "Hero_Winter_Wyvern.ArcticBurn.Cast"), а не путь.
-- Я НЕ меняю логику, оставляю как есть: EmitSoundOnLocationWithCaster(..., "sounds/...vsnd", ...)
-- Если будет краш/тишина — заменишь на event name.

LinkLuaModifier("modifier_static_amulet", "items/static_amulets/item_static", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_slice_amulet", "items/static_amulets/item_static", LUA_MODIFIER_MOTION_NONE)

LinkLuaModifier("modifier_static_mag_amplify_count", "items/static_amulets/item_static", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_static_mag_amplify", "items/static_amulets/item_static", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_static_disarm", "items/static_amulets/item_static", LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- shared locals
--------------------------------------------------------------------------------
local ITEMS_NAMES = { ["item_static_amulet_old"] = 1, ["item_slice_amulet_old"] = 1 }

local AMPLIFY_NAME_MOD = "modifier_static_mag_amplify"
local COUNT_NAME_MOD   = "modifier_static_mag_amplify_count"

local ABILITY_NOT_TRIGGER = {
	["invoker_invoke"] = 1,
	["reaver_lord_attract"] = 1,
	["phantom_lancer_phantom_edge"] = 1,
	["leshrac_pulse_nova"] = 1,
	["shadow_demon_shadow_poison_release"] = 1,
}

--------------------------------------------------------------------------------
-- Base amulet class
--------------------------------------------------------------------------------
base_amulet_class = class({
	Precache = function(self, context)
		PrecacheResource("particle", "particles/items2_fx/skadi_projectile.vpcf", context)
		PrecacheResource("particle", "particles/units/heroes/hero_pangolier/pangolier_luckyshot_disarm_debuff.vpcf", context)
		PrecacheResource("particle", "particles/status_fx/status_effect_faceless_timewalk.vpcf", context)
	end,

	OnSpellStart = function(self)
		local caster = self:GetCaster()
		local target = self:GetCursorTarget()

		local info = {
			Target = target,
			Source = caster,
			Ability = self,
			EffectName = "particles/items2_fx/skadi_projectile.vpcf",
			bDodgeable = false,
			bProvidesVision = true,
			iMoveSpeed = self:GetSpecialValueFor("debuff_speed"),
			iVisionRadius = 150,
			bVisibleToEnemies = true,
			iSourceAttachment = DOTA_PROJECTILE_ATTACHMENT_ATTACK_1,
		}

		ProjectileManager:CreateTrackingProjectile(info)

		EmitSoundOnLocationWithCaster(
			caster:GetAbsOrigin(),
			"sounds/weapons/hero/winter_wyvern/arctic_burn.vsnd",
			caster
		)
	end,

	OnProjectileHit = function(self, target, location)
		if not target then return end
		if target:IsMagicImmune() then return end

		if target:TriggerSpellAbsorb(self) or target:TriggerSpellReflect(self) then return end

		target:AddNewModifier(
			self:GetCaster(),
			self,
			"modifier_static_disarm",
			{ duration = self:GetSpecialValueFor("debuff_duration") * (1 - target:GetStatusResistance()) }
		)

		EmitSoundOnLocationWithCaster(target:GetAbsOrigin(), "DOTA_Item.HeavensHalberd.Activate", self:GetCaster())
	end,
})

--------------------------------------------------------------------------------
-- Items using base class
--------------------------------------------------------------------------------
item_slice_amulet_old  = class(base_amulet_class)
item_static_amulet_old = class(base_amulet_class)

item_slice_amulet_old.GetIntrinsicModifierName  = function(self) return "modifier_slice_amulet" end
item_static_amulet_old.GetIntrinsicModifierName = function(self) return "modifier_static_amulet" end

--------------------------------------------------------------------------------
-- Shared passive modifier base class
--------------------------------------------------------------------------------
static_mod_class = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,
	DestroyOnExpire = function(self) return false end,
	IsDebuff = function(self) return false end,
	RemoveOnDeath = function(self) return false end,
	GetAttributes = function(self) return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end,

	OnCreated = function(self)
		local ability = self:GetAbility()
		if not ability then return end

		self.bonus_armor  = ability:GetSpecialValueFor("bonus_armor")
		self.bonus_int    = ability:GetSpecialValueFor("bonus_int")
		self.bonus_stats  = ability:GetSpecialValueFor("bonus_stats")
		self.amplify_duration = ability:GetSpecialValueFor("buff_duration")
	end,

	DeclareFunctions = function(self)
		return {
			MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
			MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
			MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
			MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
			MODIFIER_EVENT_ON_ABILITY_EXECUTED,
		}
	end,

	GetModifierPhysicalArmorBonus = function(self) return self.bonus_armor or 0 end,
	GetModifierBonusStats_Strength = function(self) return self.bonus_stats or 0 end,
	GetModifierBonusStats_Agility = function(self) return self.bonus_stats or 0 end,
	GetModifierBonusStats_Intellect = function(self) return (self.bonus_stats or 0) + (self.bonus_int or 0) end,

	OnAbilityExecuted = function(self, keys)
		if not IsServer() then return end

		local caster = keys.unit
		if caster ~= self:GetParent() then return end

		local ability = self:GetAbility()
		local casted_ability = keys.ability
		if not ability or not casted_ability then return end

		if casted_ability:IsItem() then return end

		-- не стакаем если у героя есть другой такой амулет (как в оригинале)
		for i = 0, 5 do
			local item = caster:GetItemInSlot(i)
			if item == ability then break end

			if item and ITEMS_NAMES[item:GetName()] and item ~= ability then
				return
			end
		end

		if ABILITY_NOT_TRIGGER[casted_ability:GetName()] then return end

		-- оригинальная проверка (оставляю)
		if casted_ability:GetCooldown(ability:GetLevel() - 1) == 0 then return end

		-- Stack counter
		local hMod = caster:AddNewModifier(caster, ability, COUNT_NAME_MOD, { duration = self.amplify_duration })
		hMod:IncrementStackCount()

		-- Real amplify
		caster:AddNewModifier(caster, ability, AMPLIFY_NAME_MOD, { duration = self.amplify_duration })
	end,
})

--------------------------------------------------------------------------------
-- Passive modifiers
--------------------------------------------------------------------------------
modifier_static_amulet = class(static_mod_class)
modifier_slice_amulet  = class(static_mod_class)

--------------------------------------------------------------------------------
-- Debuff: disarm
--------------------------------------------------------------------------------
modifier_static_disarm = class({
	IsHidden = function(self) return false end,
	IsDebuff = function(self) return true end,
	IsPurgable = function(self) return false end,
	DestroyOnExpire = function(self) return true end,

	GetTexture = function(self)
		if not self:GetAbility() then return "" end
		return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") .. "_big"
	end,

	CheckState = function(self)
		return { [MODIFIER_STATE_DISARMED] = true }
	end,

	GetEffectName = function(self)
		return "particles/units/heroes/hero_pangolier/pangolier_luckyshot_disarm_debuff.vpcf"
	end,

	GetEffectAttachType = function(self)
		return PATTACH_OVERHEAD_FOLLOW
	end,
})

--------------------------------------------------------------------------------
-- Buff counter: visible stacks
--------------------------------------------------------------------------------
modifier_static_mag_amplify_count = class({
	IsHidden = function(self) return false end,
	IsDebuff = function(self) return false end,
	IsPurgable = function(self) return true end,
	DestroyOnExpire = function(self) return true end,
	GetAttributes = function(self) return MODIFIER_ATTRIBUTE_PERMANENT end,

	GetTexture = function(self)
		if not self:GetAbility() then return "" end
		return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") .. "_big"
	end,

	GetStatusEffectName = function(self)
		return "particles/status_fx/status_effect_faceless_timewalk.vpcf"
	end,
})

--------------------------------------------------------------------------------
-- Real amplify buff
--------------------------------------------------------------------------------
modifier_static_mag_amplify = class({
	IsHidden = function(self) return true end,
	IsDebuff = function(self) return false end,
	IsPurgable = function(self) return true end,
	DestroyOnExpire = function(self) return true end,
	GetAttributes = function(self) return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end,

	DeclareFunctions = function(self)
		return { MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE }
	end,

	OnCreated = function(self)
		local ability = self:GetAbility()
		self.spellamp = ability and ability:GetSpecialValueFor("spell_amplify_by_cast") or 0
	end,

	OnDestroy = function(self)
		if not IsServer() then return end

		local caster = self:GetParent()
		if not caster then return end

		local stack_count = caster:GetModifierStackCount(COUNT_NAME_MOD, caster)
		caster:SetModifierStackCount(COUNT_NAME_MOD, caster, stack_count - 1)

		if (stack_count - 1) == 0 then
			caster:RemoveModifierByName(COUNT_NAME_MOD)
		end
	end,

	GetModifierSpellAmplify_Percentage = function(self)
		return self.spellamp or 0
	end,
})