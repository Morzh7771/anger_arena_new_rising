require("lib/attack_potency")
-- One-file, strict "new format":
-- - ВСЕ методы/поля внутри class({ ... }) где это возможно
-- - OnCreated/OnDestroy и т.д. тоже внутри таблицы (как в твоём примере)
-- Активка: выстрел в цель-врага (трекинг-снаряд), на цель вешается привязка (механика Celestial Spear из 1x6).
-- Партиклы: celestial_spear_* и huskar_disarm_* взяты скомпилированными из VPK 1x6 (particles/items, particles/huskar).

LinkLuaModifier('modifier_rebels_sword_passive', 'items/rebels_sword/rebels_sword', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_rebels_sword_disarmor', 'items/rebels_sword/rebels_sword', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_rebels_sword_disarmor_cd', 'items/rebels_sword/rebels_sword', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_rebels_sword_leash', 'items/rebels_sword/rebels_sword', LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- Item
--------------------------------------------------------------------------------
item_rebels_sword = class({
	GetIntrinsicModifierName = function(self) return 'modifier_rebels_sword_passive' end,

	Precache = function(self, context)
		if self:GetCaster() and self:GetCaster():IsIllusion() then return end

		PrecacheResource("particle", "particles/items/celestial_spear_proj.vpcf", context)
		PrecacheResource("particle", "particles/items/celestial_spear_leash.vpcf", context)
		PrecacheResource("particle", "particles/huskar/huskar_disarm_coil.vpcf", context)
		PrecacheResource("particle", "particles/econ/items/dragon_knight/dk_persona/dk_persona_dragon_tail_dragon_form_proj_impact.vpcf", context)
		PrecacheResource("particle", "particles/units/heroes/hero_monkey_king/monkey_king_quad_tap_hit.vpcf", context)
	end,

	OnSpellStart = function(self)
		if not IsServer() then return end

		local caster = self:GetCaster()
		local target = self:GetCursorTarget()
		if not target then return end

		ProjectileManager:CreateTrackingProjectile({
			Target = target,
			Source = caster,
			Ability = self,
			EffectName = "particles/items/celestial_spear_proj.vpcf",
			iMoveSpeed = self:GetSpecialValueFor("projectile_speed"),
			vSourceLoc = caster:GetAbsOrigin(),
			bDodgeable = true,
			bProvidesVision = false,
		})

		caster:EmitSound("Item_Desolator.Target")
	end,

	OnProjectileHit = function(self, target, location)
		if not IsServer() then return end
		if not target then return end
		if target:TriggerSpellAbsorb(self) then return end

		local impact_fx = ParticleManager:CreateParticle("particles/econ/items/dragon_knight/dk_persona/dk_persona_dragon_tail_dragon_form_proj_impact.vpcf", PATTACH_CUSTOMORIGIN, target)
		for _, cp in ipairs({0, 1, 3}) do
			ParticleManager:SetParticleControlEnt(impact_fx, cp, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), false)
		end
		ParticleManager:ReleaseParticleIndex(impact_fx)

		local hit_fx = ParticleManager:CreateParticle("particles/units/heroes/hero_monkey_king/monkey_king_quad_tap_hit.vpcf", PATTACH_CUSTOMORIGIN, target)
		ParticleManager:SetParticleControlEnt(hit_fx, 0, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), false)
		ParticleManager:SetParticleControlEnt(hit_fx, 1, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), false)
		ParticleManager:ReleaseParticleIndex(hit_fx)

		target:EmitSound("Item.StarEmblem.Enemy")

		local duration = self:GetSpecialValueFor("leash_duration") * (1 - target:GetStatusResistance())
		target:AddNewModifier(self:GetCaster(), self, 'modifier_rebels_sword_leash', { duration = duration })
	end,
})

item_rebels_sword_dummy = item_rebels_sword

--------------------------------------------------------------------------------
-- locals
--------------------------------------------------------------------------------
local DISARMOR_MNAME = "modifier_rebels_sword_disarmor"
local DISARMOR_CD_MNAME = "modifier_rebels_sword_disarmor_cd"
local LEASH_MNAME = "modifier_rebels_sword_leash"

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
-- Leash (привязка): центр - точка, где стояла цель при попадании. Золотой луч
-- от центра к цели; цель не уходит дальше break_radius от центра.
-- Выход за радиус => цель притягивает обратно к центру и привязка снимается.
--------------------------------------------------------------------------------
modifier_rebels_sword_leash = class({
	IsHidden = function(self) return false end,
	IsDebuff = function(self) return true end,
	IsPurgable = function(self) return true end,
	DestroyOnExpire = function(self) return true end,
	GetTexture = function(self) return "../items/rebels_sword" end,

	OnCreated = function(self)
		self.parent = self:GetParent()
		self.caster = self:GetCaster()

		if not IsServer() then return end

		local ability = self:GetAbility()
		self.break_radius = ability and ability:GetSpecialValueFor("break_radius") or 500

		-- центр привязки: 60 у цели в сторону владельца (как в 1x6)
		self.center = self.parent:GetAbsOrigin() - (self.caster:GetAbsOrigin() - self.parent:GetAbsOrigin()):Normalized() * 60

		local coil_fx = ParticleManager:CreateParticle("particles/huskar/huskar_disarm_coil.vpcf", PATTACH_WORLDORIGIN, self.parent)
		ParticleManager:SetParticleControl(coil_fx, 0, self.center)
		self:AddParticle(coil_fx, false, false, -1, false, false)

		local tether_fx = ParticleManager:CreateParticle("particles/items/celestial_spear_leash.vpcf", PATTACH_ABSORIGIN, self.parent)
		ParticleManager:SetParticleControl(tether_fx, 0, self.center)
		ParticleManager:SetParticleControlEnt(tether_fx, 1, self.parent, PATTACH_POINT_FOLLOW, "attach_hitloc", self.parent:GetAbsOrigin(), true)
		self:AddParticle(tether_fx, false, false, -1, false, false)

		self:StartIntervalThink(FrameTime())
	end,

	CheckState = function(self)
		return { [MODIFIER_STATE_TETHERED] = true }
	end,

	OnIntervalThink = function(self)
		if not IsServer() then return end
		if not self.center then return end
		if (self.parent:GetAbsOrigin() - self.center):Length2D() <= self.break_radius then return end
		if self.parent:IsInvulnerable() then return end

		local direction = self.parent:GetOrigin() - self.center
		direction.z = 0
		direction = direction:Normalized()

		local pos = self.parent:GetAbsOrigin() + direction * 10

		self.parent:AddNewModifier(self.caster, self:GetAbility(), "modifier_knockback", {
			center_x = pos.x,
			center_y = pos.y,
			center_z = pos.z,
			duration = 0.2,
			knockback_duration = 0.2,
			knockback_distance = (self.parent:GetOrigin() - self.center):Length2D(),
			knockback_height = 0,
			isStun = true,
		})

		self.parent:EmitSound("Item.StarEmblem.Enemy")
		self:Destroy()
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
		-- внутренний кд пассивки на одну цель (раньше был AbilityCooldown = 0.4)
		self.cooldown         = ability:GetSpecialValueFor("disarmor_cd")
		self.cooldown_leash   = ability:GetSpecialValueFor("disarmor_cd_leash")
		if self.cooldown <= 0 then self.cooldown = 0.4 end
		if self.cooldown_leash <= 0 then self.cooldown_leash = 0.2 end
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

		-- прибавка за удар - с действенностью атаки (снижение брони, apply_effectiveness)
		local potency = AttackPotency:Get(self:GetParent(), kv)
		local total_stack_count = stack_count + ((self.disarmor * armor) + self.disarmor_const) * potency

		if total_stack_count > (self.max_disarmor_pct * armor) then
			total_stack_count = stack_count + self.disarmor_const * potency
		end

		local ability = self:GetAbility()
		if not ability then return end

		-- цель в привязке владельца => внутренний кд 0.2
		local cd = self.cooldown
		if target:FindModifierByNameAndCaster(LEASH_MNAME, self:GetParent()) then
			cd = self.cooldown_leash
		end

		target:AddNewModifier(target, ability, DISARMOR_CD_MNAME, { duration = cd })
		target:AddNewModifier(target, ability, DISARMOR_MNAME, { duration = self.duration })
		target:SetModifierStackCount(DISARMOR_MNAME, target, total_stack_count)
	end,
})
