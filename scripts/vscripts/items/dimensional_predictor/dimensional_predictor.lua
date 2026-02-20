-- New-format single-file version:
-- - class({...}) style
-- - all LinkLuaModifier point to THIS file
-- - Precache contains ONLY particles actually used by this item/modifiers (и статус эффект тоже)
-- - (моделей в коде нет, поэтому model precache не добавляю)

LinkLuaModifier('modifier_dimensional_predictor_passive', 'items/dimensional_predictor/dimensional_predictor', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_dimensional_predictor_active', 'items/dimensional_predictor/dimensional_predictor', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_dimensional_predictor_passive_unique', 'items/dimensional_predictor/dimensional_predictor', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_dimensional_predictor_charged_dummy', 'items/dimensional_predictor/dimensional_predictor', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_dimensional_predictor_charged_dummy_cd', 'items/dimensional_predictor/dimensional_predictor', LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- Item
--------------------------------------------------------------------------------
item_dimensional_predictor = class({
	GetIntrinsicModifierName = function(self) return 'modifier_dimensional_predictor_passive' end
})

item_dimensional_predictor_1 = item_dimensional_predictor
item_dimensional_predictor_2 = item_dimensional_predictor
item_dimensional_predictor_3 = item_dimensional_predictor

function item_dimensional_predictor:Precache(context)
	-- ONLY реально используемые particle paths из кода/модификаторов:
	PrecacheResource("particle", "particles/status_fx/status_effect_blur.vpcf", context) -- GetStatusEffectName
	PrecacheResource("particle", "particles/econ/items/sven/sven_warcry_ti5/sven_spell_warcry_small_c_it_5.vpcf", context) -- OnCharged
	PrecacheResource("particle", "particles/units/heroes/hero_sven/sven_storm_bolt_projectile_explosion.vpcf", context) -- OnUncharge(target)
end

function item_dimensional_predictor:OnSpellStart()
	if not IsServer() then return end
	local caster = self:GetCaster()

	caster:AddNewModifier(caster, self, "modifier_dimensional_predictor_active", {
		duration = self:GetSpecialValueFor("active_duration")
	})
end

function item_dimensional_predictor:GetAbilityTextureName()
	local caster = self:GetCaster()
	local levelSuffix = self:GetName():match("%d+")

	if caster and caster:HasModifier("modifier_dimensional_predictor_charged_dummy") then
		return "dimensional_predictor_charge_" .. tostring(levelSuffix)
	end

	return "dimensional_predictor_" .. tostring(levelSuffix)
end

--------------------------------------------------------------------------------
-- Active modifier (cast)
--------------------------------------------------------------------------------
modifier_dimensional_predictor_active = class({
	IsHidden = function(self) return false end,
	RemoveOnDeath = function(self) return true end,
	IsDebuff = function(self) return false end,
	IsPurgable = function(self) return false end,
	DestroyOnExpire = function(self) return true end,

	GetTexture = function(self)
		return "../items/dimensional_predictor_big" .. "_" .. self:GetAbility():GetName():match("%d+")
	end,

	CheckState = function(self)
		return {
			[MODIFIER_STATE_NOT_ON_MINIMAP_FOR_ENEMIES] = true,
		}
	end,

	GetStatusEffectName = function(self)
		return "particles/status_fx/status_effect_blur.vpcf"
	end,
})

--------------------------------------------------------------------------------
-- Charged dummy CD (visual only)
--------------------------------------------------------------------------------
modifier_dimensional_predictor_charged_dummy_cd = class({
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return false end,
	DestroyOnExpire = function(self) return false end,
	IsDebuff = function(self) return false end,
	RemoveOnDeath = function(self) return false end,
	GetAttributes = function(self) return MODIFIER_ATTRIBUTE_PERMANENT end,

	GetTexture = function(self)
		return "../items/dimensional_predictor_big" .. "_" .. self:GetAbility():GetName():match("%d+")
	end,
})

--------------------------------------------------------------------------------
-- Charged dummy (visual/state)
--------------------------------------------------------------------------------
modifier_dimensional_predictor_charged_dummy = class({
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return false end,
	DestroyOnExpire = function(self) return false end,
	RemoveOnDeath = function(self) return false end,
	GetAttributes = function(self) return MODIFIER_ATTRIBUTE_PERMANENT end,

	GetTexture = function(self)
		return "../items/dimensional_predictor_charge_big" .. "_" .. self:GetAbility():GetName():match("%d+")
	end,
})

--------------------------------------------------------------------------------
-- Passive (stats + unique handler)
--------------------------------------------------------------------------------
modifier_dimensional_predictor_passive = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,
	DestroyOnExpire = function(self) return false end,
	RemoveOnDeath = function(self) return false end,
	GetAttributes = function(self) return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end,

	OnCreated = function(self)
		local ability = self:GetAbility()
		if not ability then return end

		self.bonus_strength = ability:GetSpecialValueFor("bonus_strength")
		self.bonus_intellect = ability:GetSpecialValueFor("bonus_intellect")
		self.attack_speed = ability:GetSpecialValueFor("bonus_attackspeed")
		self.bonus_mana_regen = ability:GetSpecialValueFor("bonus_mana_regen")
		self.bonus_damage = ability:GetSpecialValueFor("bonus_damage")
		self.bonus_magresist = ability:GetSpecialValueFor("bonus_magresist")

		if not IsServer() then return end
		local caster = self:GetParent()
		if caster and not caster:IsIllusion() then
			caster:AddNewModifier(caster, ability, "modifier_dimensional_predictor_passive_unique", { duration = -1 })
		end
	end,

	OnDestroy = function(self)
		if not IsServer() then return end
		local caster = self:GetParent()
		if caster and not caster:IsIllusion() then
			caster:RemoveModifierByName("modifier_dimensional_predictor_passive_unique")
		end
	end,

	DeclareFunctions = function(self)
		return {
			MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
			MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
			MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
			MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
			MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
			MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
		}
	end,

	GetModifierBonusStats_Strength = function(self) return self.bonus_strength or 0 end,
	GetModifierBonusStats_Intellect = function(self) return self.bonus_intellect or 0 end,
	GetModifierConstantManaRegen = function(self) return self.bonus_mana_regen or 0 end,
	GetModifierAttackSpeedBonus_Constant = function(self) return self.attack_speed or 0 end,
	GetModifierPreAttack_BonusDamage = function(self) return self.bonus_damage or 0 end,
	GetModifierMagicalResistanceBonus = function(self) return self.bonus_magresist or 0 end,
})

--------------------------------------------------------------------------------
-- Passive unique (charge logic + proc)
--------------------------------------------------------------------------------
modifier_dimensional_predictor_passive_unique = class({
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,
	DestroyOnExpire = function(self) return false end,
	RemoveOnDeath = function(self) return false end,
	GetAttributes = function(self) return MODIFIER_ATTRIBUTE_PERMANENT end,
})

function modifier_dimensional_predictor_passive_unique:OnCreated()
	if not IsServer() then return end
	local ability = self:GetAbility()
	if not ability then return end

	self.cd = ability:GetSpecialValueFor("passive_cd")
	self.dmg = ability:GetSpecialValueFor("passive_damage_att") / 100
	self.radius = ability:GetSpecialValueFor("radius")

	self.charged = false
	self.timerID = "dimensional_predictor_" .. tostring(self:GetParent():entindex())

	self:StartCharge()
end

function modifier_dimensional_predictor_passive_unique:OnDestroy()
	if not IsServer() then return end
	self:OnUncharge(nil)
	self:StopCharge()
end

function modifier_dimensional_predictor_passive_unique:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ATTACK_LANDED,
		MODIFIER_EVENT_ON_RESPAWN,
	}
end

function modifier_dimensional_predictor_passive_unique:OnRespawn(kv)
	if not IsServer() then return end
	if kv.unit ~= self:GetParent() then return end

	self:OnUncharge(nil)
	self:StopCharge()
	self:StartCharge()
end

function modifier_dimensional_predictor_passive_unique:OnAttackLanded(kv)
	if not IsServer() then return end
	if self:GetParent() ~= kv.attacker then return end

	local target = kv.target
	if not target then return end

	local targetName = target:GetUnitName()
	if targetName == "npc_dota_observer_wards" or targetName == "npc_dota_sentry_wards" then return end

	local caster = kv.attacker
	if not self.charged then return end

	-- calculate damage from primary attribute (оригинальная логика сохранена)
	local damage = 0
	local hero = self:GetCaster()
	if not hero then return end

	local function calcFrom(h)
		local prim = h:GetPrimaryAttribute()
		if prim == DOTA_ATTRIBUTE_ALL then
			return ((h:GetStrength() + h:GetAgility() + h:GetIntellect(false)) / 3) * self.dmg
		elseif prim == DOTA_ATTRIBUTE_STRENGTH then
			return h:GetStrength() * self.dmg
		elseif prim == DOTA_ATTRIBUTE_AGILITY then
			return h:GetAgility() * self.dmg
		elseif prim == DOTA_ATTRIBUTE_INTELLECT then
			return h:GetIntellect(false) * self.dmg
		end
		return 0
	end

	-- иллюзии/саммоны: в оригинале была ветка с owner, но всё равно считалось от self:GetCaster()
	damage = calcFrom(hero)

	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		target:GetAbsOrigin(),
		nil,
		self.radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		0,
		0,
		false
	)

	if #enemies > 0 then
		for _, enemy in pairs(enemies) do
			if enemy and (not enemy:IsMagicImmune()) and (not enemy:IsInvulnerable()) then
				ApplyDamage({
					victim = enemy,
					attacker = caster,
					damage = damage,
					ability = self:GetAbility(),
					damage_type = DAMAGE_TYPE_MAGICAL,
				})
				SendOverheadEventMessage(enemy, OVERHEAD_ALERT_BONUS_SPELL_DAMAGE, caster, damage, nil)
				enemy:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_item_mage_slayer_debuff", {
					duration = self:GetAbility():GetSpecialValueFor('duration')
				})
			end
		end
	end

	self:OnUncharge(target)
	self:StartCharge()
end

function modifier_dimensional_predictor_passive_unique:OnCharged()
	self.charged = true

	self:GetParent():AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_dimensional_predictor_charged_dummy", { duration = -1 })

	local caster = self:GetParent()
	if caster and caster:IsAlive() then
		local idx = ParticleManager:CreateParticle(
			"particles/econ/items/sven/sven_warcry_ti5/sven_spell_warcry_small_c_it_5.vpcf",
			PATTACH_ABSORIGIN_FOLLOW,
			caster
		)
		ParticleManager:SetParticleControl(idx, 0, caster:GetAbsOrigin())
		ParticleManager:ReleaseParticleIndex(idx)
	end
end

function modifier_dimensional_predictor_passive_unique:OnUncharge(target)
	self.charged = false
	self:GetParent():RemoveModifierByName("modifier_dimensional_predictor_charged_dummy")

	if target then
		local idx = ParticleManager:CreateParticle(
			"particles/units/heroes/hero_sven/sven_storm_bolt_projectile_explosion.vpcf",
			PATTACH_OVERHEAD_FOLLOW,
			target
		)
		ParticleManager:SetParticleControl(idx, 3, target:GetAbsOrigin())
		ParticleManager:ReleaseParticleIndex(idx)
	end
end

function modifier_dimensional_predictor_passive_unique:StartCharge()
	Timers:CreateTimer(self.timerID, {
		useGameTime = true,
		endTime = self.cd,
		callback = function()
			self:OnCharged()
			self:StopCharge()
			return nil
		end
	})

	self:GetParent():AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_dimensional_predictor_charged_dummy_cd", { duration = self.cd })
end

function modifier_dimensional_predictor_passive_unique:StopCharge()
	Timers:RemoveTimer(self.timerID)
	self:GetParent():RemoveModifierByName("modifier_dimensional_predictor_charged_dummy_cd")
end