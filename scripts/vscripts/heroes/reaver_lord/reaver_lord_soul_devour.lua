-- Reaver Lord: Devour. Порт из Angel Arena Global (datadriven), переписано на Lua.
-- Луч на цель: замедляет бег и атаку, каждые 0.5 с урон (база + % макс. HP цели), Reaver Lord
-- лечится на этот урон. В конце даёт душу. Если цель ушла дальше range - луч рвётся без души.

require("heroes/reaver_lord/reaver_lord_soul_collector")

reaver_lord_soul_devour = class({})

LinkLuaModifier("modifier_reaver_lord_soul_devour", "heroes/reaver_lord/reaver_lord_soul_devour", LUA_MODIFIER_MOTION_NONE)

function reaver_lord_soul_devour:Precache(context)
	PrecacheResource("particle", "particles/econ/items/lion/lion_demon_drain/lion_spell_mana_drain_demon_beam.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_terrorblade.vsndevts", context)
end

function reaver_lord_soul_devour:OnSpellStart()
	local target = self:GetCursorTarget()
	if target:TriggerSpellAbsorb(self) then return end

	local caster = self:GetCaster()
	local duration = self:GetSpecialValueFor("duration")
	target:AddNewModifier(caster, self, "modifier_reaver_lord_soul_devour", { duration = duration })

	-- Доп. лучи (2026-11-22): ещё extra_targets крипов рядом с целью, без души
	local extra = self:GetSpecialValueFor("extra_targets")
	if extra <= 0 then return end
	local units = FindUnitsInRadius(caster:GetTeamNumber(), target:GetAbsOrigin(), nil, self:GetSpecialValueFor("extra_radius"),
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_CLOSEST, false)
	for _, unit in ipairs(units) do
		if extra <= 0 then break end
		if unit ~= target and not unit:IsHero() then
			unit:AddNewModifier(caster, self, "modifier_reaver_lord_soul_devour", { duration = duration, secondary = 1 })
			extra = extra - 1
		end
	end
end

--------------------------------------------------------------------------------

modifier_reaver_lord_soul_devour = class({})

function modifier_reaver_lord_soul_devour:IsHidden() return false end
function modifier_reaver_lord_soul_devour:IsDebuff() return true end
function modifier_reaver_lord_soul_devour:IsPurgable() return false end

function modifier_reaver_lord_soul_devour:OnCreated(kv)
	local ability = self:GetAbility()
	if not ability then return end

	self.move_slow = ability:GetSpecialValueFor("movespeed_slow")
	self.attack_slow = ability:GetSpecialValueFor("attackspeed_slow")

	if not IsServer() then return end

	self.interval = 0.5
	self.broken = false
	self.secondary = kv and kv.secondary == 1

	local caster = self:GetCaster()
	local parent = self:GetParent()

	self.beam = ParticleManager:CreateParticle("particles/econ/items/lion/lion_demon_drain/lion_spell_mana_drain_demon_beam.vpcf", PATTACH_CUSTOMORIGIN, caster)
	ParticleManager:SetParticleControlEnt(self.beam, 0, caster, PATTACH_POINT_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
	ParticleManager:SetParticleControlEnt(self.beam, 1, parent, PATTACH_POINT_FOLLOW, "attach_hitloc", parent:GetAbsOrigin(), true)
	self:AddParticle(self.beam, false, false, -1, false, false)

	parent:EmitSound("Hero_Terrorblade.ConjureImage")
	self:StartIntervalThink(self.interval)
end

function modifier_reaver_lord_soul_devour:OnIntervalThink()
	local caster = self:GetCaster()
	local parent = self:GetParent()
	local ability = self:GetAbility()

	if not ability or not caster:IsAlive() or not parent:IsAlive() then
		self.broken = true
		self:Destroy()
		return
	end

	if (caster:GetAbsOrigin() - parent:GetAbsOrigin()):Length2D() > ability:GetSpecialValueFor("range") then
		self.broken = true
		self:Destroy()
		return
	end

	-- В KV урон в секунду, тик раз в 0.5 с
	local damage = (ability:GetSpecialValueFor("damage") + parent:GetMaxHealth() * ability:GetSpecialValueFor("damage_pct") / 100) * self.interval

	local dealt = ApplyDamage({
		victim		= parent,
		attacker	= caster,
		damage		= damage,
		damage_type	= ability:GetAbilityDamageType(),
		ability		= ability,
	})

	caster:Heal(dealt, ability)
end

function modifier_reaver_lord_soul_devour:OnDestroy()
	if not IsServer() then return end
	if self.broken or self.secondary then return end
	ReaverLordAddSouls(self:GetCaster(), 1)
end

function modifier_reaver_lord_soul_devour:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
	}
end

function modifier_reaver_lord_soul_devour:GetModifierMoveSpeedBonus_Percentage() return self.move_slow end
function modifier_reaver_lord_soul_devour:GetModifierAttackSpeedBonus_Constant() return self.attack_slow end
