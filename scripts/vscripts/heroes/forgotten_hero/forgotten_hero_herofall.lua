-- Forgotten Hero: Herofall. Порт из Angel Arena Global.
-- Прыжок по дуге в точку, при приземлении урон и оглушение в радиусе.
-- Талант: при приземлении ещё и атакует всех задетых.

forgotten_hero_herofall = class({})

LinkLuaModifier("modifier_forgotten_hero_herofall", "heroes/forgotten_hero/forgotten_hero_herofall", LUA_MODIFIER_MOTION_BOTH)

function forgotten_hero_herofall:Precache(context)
	PrecacheResource("soundfile", "soundevents/heroes/forgotten_hero.vsndevts", context)
	PrecacheResource("particle", "particles/econ/items/monkey_king/arcana/fire/mk_arcana_spring_jump_trail.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/monkey_king/arcana/fire/monkey_king_spring_arcana_fire.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_monkey_king/monkey_king_spring_cast_spiral_arm_b.vpcf", context)
end

function forgotten_hero_herofall:GetAOERadius()
	return self:GetSpecialValueFor("aoe_radius")
end

function forgotten_hero_herofall:OnSpellStart()
	local caster = self:GetCaster()
	local pos = self:GetCursorPosition()

	caster:AddNewModifier(caster, self, "modifier_forgotten_hero_herofall", { px = pos.x, py = pos.y, pz = pos.z })

	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_monkey_king/monkey_king_spring_cast_spiral_arm_b.vpcf", PATTACH_ABSORIGIN, caster)
	ParticleManager:ReleaseParticleIndex(pfx)
	caster:EmitSound("Hero_ForgottenHero.Herofall.Cast")
end

--------------------------------------------------------------------------------

modifier_forgotten_hero_herofall = class({})

function modifier_forgotten_hero_herofall:IsHidden() return true end
function modifier_forgotten_hero_herofall:IsPurgable() return false end

function modifier_forgotten_hero_herofall:OnCreated(kv)
	if not IsServer() then return end

	local ability = self:GetAbility()
	self.start_pos = self:GetParent():GetAbsOrigin()
	self.end_pos = Vector(kv.px, kv.py, kv.pz)
	self.height = ability:GetSpecialValueFor("height")
	self.speed = ability:GetSpecialValueFor("speed")
	self.total = (self.end_pos - self.start_pos):Length2D()
	self.passed = 0
	self.landed = false

	if self.total < 50 then
		self:Land()
		self:Destroy()
		return
	end

	if not self:ApplyHorizontalMotionController() or not self:ApplyVerticalMotionController() then
		self:Destroy()
	end
end

function modifier_forgotten_hero_herofall:UpdateHorizontalMotion(parent, dt)
	self.passed = math.min(self.passed + self.speed * dt, self.total)
	local t = self.passed / self.total
	local pos = self.start_pos + (self.end_pos - self.start_pos) * t
	pos.z = GetGroundHeight(pos, parent) + self.height * math.sin(t * math.pi)
	parent:SetAbsOrigin(pos)

	if self.passed >= self.total then
		self:Land()
		self:Destroy()
	end
end

function modifier_forgotten_hero_herofall:UpdateVerticalMotion(parent, dt)
end

function modifier_forgotten_hero_herofall:OnHorizontalMotionInterrupted()
	self:Destroy()
end

function modifier_forgotten_hero_herofall:OnDestroy()
	if not IsServer() then return end
	local parent = self:GetParent()
	parent:RemoveHorizontalMotionController(self)
	parent:RemoveVerticalMotionController(self)
	FindClearSpaceForUnit(parent, parent:GetAbsOrigin(), true)
end

function modifier_forgotten_hero_herofall:Land()
	if self.landed then return end
	self.landed = true

	local parent = self:GetParent()
	local ability = self:GetAbility()
	if not ability or not parent:IsAlive() then return end

	local pos = parent:GetAbsOrigin()
	local radius = ability:GetSpecialValueFor("aoe_radius")
	local stun = ability:GetSpecialValueFor("stun_duration")
	local performs_attack = ability:GetSpecialValueFor("performs_attack") > 0

	local pfx = ParticleManager:CreateParticle("particles/econ/items/monkey_king/arcana/fire/monkey_king_spring_arcana_fire.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(pfx, 0, pos)
	ParticleManager:SetParticleControl(pfx, 1, Vector(radius, radius, radius))
	ParticleManager:ReleaseParticleIndex(pfx)
	parent:StopSound("Hero_ForgottenHero.Herofall.Cast")
	parent:EmitSound("Hero_ForgottenHero.Herofall.Hit")

	GridNav:DestroyTreesAroundPoint(pos, radius, true)

	local enemies = FindUnitsInRadius(parent:GetTeamNumber(), pos, nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

	for _, enemy in pairs(enemies) do
		enemy:AddNewModifier(parent, ability, "modifier_stunned", { duration = stun })
		ApplyDamage({
			victim		= enemy,
			attacker	= parent,
			damage		= ability:GetSpecialValueFor("damage") + parent:GetAgility() * ability:GetSpecialValueFor("damage_pct") / 100,
			damage_type	= ability:GetAbilityDamageType(),
			ability		= ability,
		})
		if performs_attack then
			parent:PerformAttack(enemy, true, true, true, true, false, false, false)
		end
	end
end

function modifier_forgotten_hero_herofall:CheckState()
	return { [MODIFIER_STATE_STUNNED] = true }
end

function modifier_forgotten_hero_herofall:DeclareFunctions()
	return { MODIFIER_PROPERTY_OVERRIDE_ANIMATION }
end

function modifier_forgotten_hero_herofall:GetOverrideAnimation()
	return ACT_DOTA_MK_SPRING_SOAR
end

function modifier_forgotten_hero_herofall:GetEffectName()
	return "particles/econ/items/monkey_king/arcana/fire/mk_arcana_spring_jump_trail.vpcf"
end

function modifier_forgotten_hero_herofall:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end
