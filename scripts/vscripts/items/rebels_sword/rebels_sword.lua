-- One-file, strict "new format":
-- - ВСЕ методы/поля внутри class({ ... }) где это возможно
-- - OnCreated/OnDestroy и т.д. тоже внутри таблицы (как в твоём примере)
-- - Precache: только реально используемые ресурсы (тут нет particles/models) => Precache не нужен

LinkLuaModifier('modifier_rebels_sword_passive', 'items/rebels_sword/rebels_sword', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_rebels_sword_disarmor', 'items/rebels_sword/rebels_sword', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_rebels_sword_disarmor_cd', 'items/rebels_sword/rebels_sword', LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- Item
--------------------------------------------------------------------------------
item_rebels_sword = class({
	GetIntrinsicModifierName = function(self) return 'modifier_rebels_sword_passive' end
})

item_rebels_sword_dummy = item_rebels_sword

--------------------------------------------------------------------------------
-- locals
--------------------------------------------------------------------------------
local DISARMOR_MNAME = "modifier_rebels_sword_disarmor"
local DISARMOR_CD_MNAME = "modifier_rebels_sword_disarmor_cd"

--------------------------------------------------------------------------------
-- CD marker
--------------------------------------------------------------------------------
modifier_rebels_sword_disarmor_cd = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return true end,
	DestroyOnExpire = function(self) return true end,
})

--------------------------------------------------------------------------------
-- Disarmor debuff (stacks => negative armor)
--------------------------------------------------------------------------------
modifier_rebels_sword_disarmor = class({
	IsHidden = function(self) return false end,
	IsDebuff = function(self) return true end,
	IsPurgable = function(self) return true end,
	DestroyOnExpire = function(self) return true end,
	GetTexture = function(self) return "../items/rebels_sword_big" end,

	DeclareFunctions = function(self)
		return { MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS }
	end,

	GetModifierPhysicalArmorBonus = function(self)
		return -(self:GetStackCount() or 0)
	end,
})

--------------------------------------------------------------------------------
-- Passive stats + on-hit stacking logic
--------------------------------------------------------------------------------
modifier_rebels_sword_passive = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,
	DestroyOnExpire = function(self) return false end,
	GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT end,

	OnCreated = function(self)
		local ability = self:GetAbility()
		if not ability then return end

		-- client + server stats (как в оригинале)
		self.bonus_damage       = ability:GetSpecialValueFor("bonus_damage")
		self.bonus_all_stats    = ability:GetSpecialValueFor("bonus_all_stats")
		self.bonus_attack_speed = ability:GetSpecialValueFor("bonus_attack_speed")

		if not IsServer() then return end

		self.disarmor         = ability:GetSpecialValueFor("disarmor") / 100
		self.disarmor_const   = ability:GetSpecialValueFor("disarmor_const")
		self.max_disarmor_pct = ability:GetSpecialValueFor("max_disarmor_pct") / 100
		self.duration         = ability:GetSpecialValueFor("duration")
		self.cooldown         = ability:GetCooldown(1)
	end,

	DeclareFunctions = function(self)
		return {
			-- Properties
			MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
			MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
			MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
			MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
			MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,

			-- Events
			MODIFIER_EVENT_ON_ATTACK_LANDED,
		}
	end,

	GetModifierPreAttack_BonusDamage = function(self)     return self.bonus_damage or 0 end,
	GetModifierBonusStats_Strength = function(self)       return self.bonus_all_stats or 0 end,
	GetModifierBonusStats_Agility = function(self)        return self.bonus_all_stats or 0 end,
	GetModifierBonusStats_Intellect = function(self)      return self.bonus_all_stats or 0 end,
	GetModifierAttackSpeedBonus_Constant = function(self) return self.bonus_attack_speed or 0 end,

	OnAttackLanded = function(self, kv)
		if not IsServer() then return end
		if self:GetParent() ~= kv.attacker then return end

		local target = kv.target
		if not target then return end

		if target:HasModifier(DISARMOR_CD_MNAME) then return end

		local stack_count = target:GetModifierStackCount(DISARMOR_MNAME, target)

		-- оригинально учитывает сторонний дебафф (стигий)
		local stygianStacks = target:GetModifierStackCount("modifier_item_stygian_aa_disarmor", kv.attacker)
		local armor = target:GetPhysicalArmorValue(false) + stack_count + stygianStacks

		local total_stack_count = stack_count + (self.disarmor * armor) + self.disarmor_const

		if total_stack_count > (self.max_disarmor_pct * armor) then
			total_stack_count = stack_count + self.disarmor_const
		end

		local ability = self:GetAbility()
		if not ability then return end

		target:AddNewModifier(target, ability, DISARMOR_CD_MNAME, { duration = self.cooldown })
		target:AddNewModifier(target, ability, DISARMOR_MNAME, { duration = self.duration })
		target:SetModifierStackCount(DISARMOR_MNAME, target, total_stack_count)
	end,
})