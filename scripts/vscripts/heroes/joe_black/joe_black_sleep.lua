-- Joe Black: Terrible Nightmare. Порт из Angel Arena Frontier, цифры Angel Arena Global.
-- Сон: цель оглушена и каждую секунду теряет HP и ману. Атака будит.
-- Талант: при касте сон разлетается снарядами по врагам рядом с целью.

joe_black_sleep = class({})

LinkLuaModifier("modifier_joe_black_sleep", "heroes/joe_black/joe_black_sleep", LUA_MODIFIER_MOTION_NONE)

function joe_black_sleep:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_bane/bane_nightmare.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_bane/bane_projectile.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_bane.vsndevts", context)
end

function joe_black_sleep:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	if target:TriggerSpellAbsorb(self) or target:TriggerSpellReflect(self) then return end

	target:AddNewModifier(caster, self, "modifier_joe_black_sleep", { duration = self:GetSpecialValueFor("duration") })

	local spread_radius = self:GetSpecialValueFor("spread_radius")
	if spread_radius <= 0 then return end

	local enemies = FindUnitsInRadius(caster:GetTeamNumber(), target:GetAbsOrigin(), nil, spread_radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_CREEP, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

	for _, enemy in pairs(enemies) do
		if enemy ~= target then
			ProjectileManager:CreateTrackingProjectile({
				Target		= enemy,
				Source		= target,
				Ability		= self,
				EffectName	= "particles/units/heroes/hero_bane/bane_projectile.vpcf",
				bDodgeable	= true,
				iMoveSpeed	= self:GetSpecialValueFor("spread_speed"),
			})
		end
	end
end

function joe_black_sleep:OnProjectileHit(target, location)
	if not target or target:IsNull() or not target:IsAlive() then return end
	if target:IsMagicImmune() then return end
	if target:TriggerSpellAbsorb(self) then return end

	target:AddNewModifier(self:GetCaster(), self, "modifier_joe_black_sleep", { duration = self:GetSpecialValueFor("duration") })
end

--------------------------------------------------------------------------------

modifier_joe_black_sleep = class({})

function modifier_joe_black_sleep:IsHidden() return false end
function modifier_joe_black_sleep:IsDebuff() return true end
function modifier_joe_black_sleep:IsPurgable() return true end

function modifier_joe_black_sleep:OnCreated()
	local ability = self:GetAbility()
	if not ability then return end

	self.interval = ability:GetSpecialValueFor("interval")
	-- В KV значения в секунду, тут переводим на тик
	-- база + % интеллекта Джо, всё в секунду
	self.health_drain_const	= (ability:GetSpecialValueFor("health_drain_const") + self:GetCaster():GetIntellect(true) * ability:GetSpecialValueFor("drain_int_pct") / 100) * self.interval
	self.health_drain_pct	= ability:GetSpecialValueFor("health_drain_pct") * self.interval / 100
	self.mana_drain_const	= ability:GetSpecialValueFor("mana_drain_const") * self.interval
	self.mana_drain_pct		= ability:GetSpecialValueFor("mana_drain_pct") * self.interval / 100

	if not IsServer() then return end

	self:GetParent():EmitSound("Hero_Bane.Nightmare")
	self:GetParent():EmitSound("Hero_Bane.Nightmare.Loop")
	self:StartIntervalThink(self.interval)
end

function modifier_joe_black_sleep:OnIntervalThink()
	local parent = self:GetParent()
	local ability = self:GetAbility()
	if not parent:IsAlive() or not ability then return end

	ApplyDamage({
		victim		= parent,
		attacker	= self:GetCaster(),
		damage		= parent:GetHealth() * self.health_drain_pct + self.health_drain_const,
		damage_type	= DAMAGE_TYPE_MAGICAL,
		ability		= ability,
	})

	parent:Script_ReduceMana(parent:GetMana() * self.mana_drain_pct + self.mana_drain_const, ability)
end

function modifier_joe_black_sleep:OnDestroy()
	if not IsServer() then return end
	self:GetParent():StopSound("Hero_Bane.Nightmare.Loop")
	self:GetParent():EmitSound("Hero_Bane.Nightmare.End")
end

function modifier_joe_black_sleep:CheckState()
	return {
		[MODIFIER_STATE_NIGHTMARED]				= true,
		[MODIFIER_STATE_STUNNED]				= true,
		[MODIFIER_STATE_LOW_ATTACK_PRIORITY]	= true,
	}
end

function modifier_joe_black_sleep:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end

function modifier_joe_black_sleep:GetOverrideAnimation()
	return ACT_DOTA_DISABLED
end

-- Атака по спящему будит его
function modifier_joe_black_sleep:OnAttackLanded(params)
	if not IsServer() then return end
	if params.target ~= self:GetParent() then return end
	self:Destroy()
end

function modifier_joe_black_sleep:GetEffectName()
	return "particles/units/heroes/hero_bane/bane_nightmare.vpcf"
end

function modifier_joe_black_sleep:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end
