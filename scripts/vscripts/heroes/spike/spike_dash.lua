-- Spike: Spiked Dash. Порт из Angel Arena Global (datadriven), переписано на Lua.
-- Рывок к точке со скоростью 1600. Каждого врага на пути (радиус 200) бьёт один раз:
-- damage + средний урон атаки Спайка (физический). Талант: урон атаки учитывается attack_multiplier раз.
-- Оглушение или рут прерывают рывок.

spike_dash = class({})

LinkLuaModifier("modifier_spike_dash", "heroes/spike/spike_dash", LUA_MODIFIER_MOTION_HORIZONTAL)

function spike_dash:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_bloodseeker/bloodseeker_rupture.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_items.vsndevts", context)
end

function spike_dash:OnSpellStart()
	local caster = self:GetCaster()
	local point = self:GetCursorPosition()
	caster:AddNewModifier(caster, self, "modifier_spike_dash", { px = point.x, py = point.y })
	caster:EmitSound("Item_Desolator.Target")
end

--------------------------------------------------------------------------------

modifier_spike_dash = class({})

function modifier_spike_dash:IsHidden() return true end
function modifier_spike_dash:IsPurgable() return false end

function modifier_spike_dash:OnCreated(kv)
	if not IsServer() then return end

	local parent = self:GetParent()
	local target = Vector(kv.px, kv.py, 0)
	local origin = parent:GetAbsOrigin()

	self.direction = target - origin
	self.direction.z = 0
	self.distance = math.min(self.direction:Length2D(), self:GetAbility():GetSpecialValueFor("dash_range") + parent:GetCastRangeBonus())
	self.direction = self.distance > 0 and self.direction:Normalized() or parent:GetForwardVector()
	self.speed = self:GetAbility():GetSpecialValueFor("dash_speed")
	self.traveled = 0
	self.hit = {}

	if not self:ApplyHorizontalMotionController() then
		self:Destroy()
	end
end

function modifier_spike_dash:UpdateHorizontalMotion(parent, dt)
	if parent:IsStunned() or parent:IsRooted() then
		self:Destroy()
		return
	end

	local step = math.min(self.speed * dt, self.distance - self.traveled)
	parent:SetAbsOrigin(GetGroundPosition(parent:GetAbsOrigin() + self.direction * step, parent))
	self.traveled = self.traveled + step

	self:HitAround(parent)

	if self.traveled >= self.distance then
		self:Destroy()
	end
end

function modifier_spike_dash:HitAround(parent)
	local ability = self:GetAbility()
	if not ability then return end

	local enemies = FindUnitsInRadius(parent:GetTeamNumber(), parent:GetAbsOrigin(), nil, ability:GetSpecialValueFor("hit_radius"),
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_CREEP, DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, FIND_ANY_ORDER, false)

	for _, enemy in pairs(enemies) do
		if not self.hit[enemy] then
			self.hit[enemy] = true
			ApplyDamage({
				victim		= enemy,
				attacker	= parent,
				damage		= ability:GetSpecialValueFor("damage") + parent:GetStrength() * ability:GetSpecialValueFor("damage_pct") / 100
								+ parent:GetAverageTrueAttackDamage(nil) * ability:GetSpecialValueFor("attack_multiplier"),
				damage_type	= ability:GetAbilityDamageType(),
				ability		= ability,
			})
		end
	end
end

function modifier_spike_dash:OnHorizontalMotionInterrupted()
	self:Destroy()
end

function modifier_spike_dash:OnDestroy()
	if not IsServer() then return end
	local parent = self:GetParent()
	parent:RemoveHorizontalMotionController(self)
	FindClearSpaceForUnit(parent, parent:GetAbsOrigin(), true)
end

function modifier_spike_dash:DeclareFunctions()
	return { MODIFIER_PROPERTY_OVERRIDE_ANIMATION }
end

function modifier_spike_dash:GetOverrideAnimation()
	return ACT_DOTA_RUN
end

function modifier_spike_dash:GetEffectName()
	return "particles/units/heroes/hero_bloodseeker/bloodseeker_rupture.vpcf"
end

function modifier_spike_dash:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end
