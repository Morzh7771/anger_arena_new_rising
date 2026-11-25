--[[
	Icarus Dive Феникса на Lua - как в доте, но урон ожога включает
	max_health_damage_pct % макс. здоровья Феникса в секунду (раньше
	lib/percent_damage.lua добавлял % на каждый тик отдельно).

	Полёт - эллипс dash_length x dash_width за dive_duration, обратно к месту каста.
	Враги в hit_radius получают ожог: урон раз в burn_tick_interval + замедление.
]]

LinkLuaModifier("modifier_phoenix_icarus_dive_aa", "heroes/phoenix/phoenix_icarus_dive_aa", LUA_MODIFIER_MOTION_HORIZONTAL)
LinkLuaModifier("modifier_phoenix_icarus_dive_aa_burn", "heroes/phoenix/phoenix_icarus_dive_aa", LUA_MODIFIER_MOTION_NONE)

phoenix_icarus_dive = phoenix_icarus_dive or class({})

function phoenix_icarus_dive:OnUpgrade()
	local stop = self:GetCaster():FindAbilityByName("phoenix_icarus_dive_stop")
	if stop then stop:SetLevel(self:GetLevel()) end
end

function phoenix_icarus_dive:OnSpellStart()
	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()
	local point = self:GetCursorPosition()

	local dir = point - origin
	dir.z = 0
	if dir:Length2D() < 1 then dir = caster:GetForwardVector() end
	dir = dir:Normalized()
	caster:SetForwardVector(dir)

	-- цена - % текущего здоровья, не убивает
	local cost = caster:GetHealth() * self:GetSpecialValueFor("hp_cost_perc") / 100
	caster:SetHealth(math.max(1, caster:GetHealth() - cost))

	caster:RemoveModifierByName("modifier_phoenix_icarus_dive_aa")
	caster:AddNewModifier(caster, self, "modifier_phoenix_icarus_dive_aa", { duration = self:GetSpecialValueFor("dive_duration") })
end

--------------------------------------------------------------------------------
phoenix_icarus_dive_stop = phoenix_icarus_dive_stop or class({})

function phoenix_icarus_dive_stop:OnSpellStart()
	self:GetCaster():RemoveModifierByName("modifier_phoenix_icarus_dive_aa")
end

--------------------------------------------------------------------------------
-- Полёт
--------------------------------------------------------------------------------
modifier_phoenix_icarus_dive_aa = class({})

function modifier_phoenix_icarus_dive_aa:IsHidden() return true end
function modifier_phoenix_icarus_dive_aa:IsPurgable() return false end

function modifier_phoenix_icarus_dive_aa:OnCreated()
	if not IsServer() then return end
	local parent = self:GetParent()
	local ability = self:GetAbility()

	self.length = ability:GetSpecialValueFor("dash_length")
	self.width = ability:GetSpecialValueFor("dash_width")
	self.hit_radius = ability:GetSpecialValueFor("hit_radius")
	self.burn_duration = ability:GetSpecialValueFor("burn_duration")
	self.dive_duration = math.max(0.1, self:GetDuration())

	self.forward = parent:GetForwardVector()
	self.right = parent:GetRightVector()
	self.yaw = parent:GetAnglesAsVector().y
	self.center = parent:GetAbsOrigin() + self.forward * (self.length / 2)
	self.elapsed = 0

	self.pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_phoenix/phoenix_icarus_dive.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(self.pfx, 0, parent:GetAbsOrigin())
	self:AddParticle(self.pfx, false, false, -1, false, false)

	parent:EmitSound("Hero_Phoenix.IcarusDive.Cast")
	parent:StartGesture(ACT_DOTA_OVERRIDE_ABILITY_1)

	if parent:HasAbility("phoenix_icarus_dive_stop") then
		parent:SwapAbilities("phoenix_icarus_dive", "phoenix_icarus_dive_stop", false, true)
	end

	if not self:ApplyHorizontalMotionController() then
		self:Destroy()
	end
end

function modifier_phoenix_icarus_dive_aa:UpdateHorizontalMotion(me, dt)
	self.elapsed = self.elapsed + dt
	local progress = math.min(1, self.elapsed / self.dive_duration)

	local theta = -2 * math.pi * progress
	local x = math.sin(theta) * self.width * 0.5
	local y = -math.cos(theta) * self.length * 0.5
	local pos = GetGroundPosition(self.center + self.right * x + self.forward * y, me)

	me:SetOrigin(pos)
	me:SetAbsAngles(0, self.yaw + 90 - progress * 360, 0)
	ParticleManager:SetParticleControl(self.pfx, 0, pos + me:GetRightVector() * 32)
	GridNav:DestroyTreesAroundPoint(pos, 80, false)

	local caster = self:GetCaster()
	local ability = self:GetAbility()
	for _, enemy in pairs(FindUnitsInRadius(me:GetTeamNumber(), pos, nil, self.hit_radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)) do
		enemy:AddNewModifier(caster, ability, "modifier_phoenix_icarus_dive_aa_burn", { duration = self.burn_duration })
	end
end

function modifier_phoenix_icarus_dive_aa:OnHorizontalMotionInterrupted()
	self:Destroy()
end

function modifier_phoenix_icarus_dive_aa:OnDestroy()
	if not IsServer() then return end
	local parent = self:GetParent()
	parent:RemoveHorizontalMotionController(self)
	parent:StopSound("Hero_Phoenix.IcarusDive.Cast")
	parent:EmitSound("Hero_Phoenix.IcarusDive.Stop")
	parent:RemoveGesture(ACT_DOTA_OVERRIDE_ABILITY_1)
	if parent:HasAbility("phoenix_icarus_dive_stop") then
		parent:SwapAbilities("phoenix_icarus_dive_stop", "phoenix_icarus_dive", false, true)
	end
	FindClearSpaceForUnit(parent, parent:GetAbsOrigin(), true)
end

function modifier_phoenix_icarus_dive_aa:DeclareFunctions()
	return { MODIFIER_PROPERTY_IGNORE_CAST_ANGLE }
end

function modifier_phoenix_icarus_dive_aa:GetModifierIgnoreCastAngle() return 1 end

function modifier_phoenix_icarus_dive_aa:CheckState()
	return { [MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY] = true }
end

--------------------------------------------------------------------------------
-- Ожог
--------------------------------------------------------------------------------
modifier_phoenix_icarus_dive_aa_burn = class({})

function modifier_phoenix_icarus_dive_aa_burn:IsDebuff() return true end
function modifier_phoenix_icarus_dive_aa_burn:IsPurgable() return true end
function modifier_phoenix_icarus_dive_aa_burn:GetTexture() return "phoenix_icarus_dive" end
function modifier_phoenix_icarus_dive_aa_burn:GetEffectName() return "particles/units/heroes/hero_phoenix/phoenix_icarus_dive_burn_debuff.vpcf" end
function modifier_phoenix_icarus_dive_aa_burn:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_phoenix_icarus_dive_aa_burn:OnCreated()
	local ability = self:GetAbility()
	self.slow = ability and -ability:GetSpecialValueFor("slow_movement_speed_pct") or 0
	if not IsServer() then return end
	self.interval = math.max(0.1, ability:GetSpecialValueFor("burn_tick_interval"))
	self:StartIntervalThink(self.interval)
end

function modifier_phoenix_icarus_dive_aa_burn:OnIntervalThink()
	local caster = self:GetCaster()
	local ability = self:GetAbility()
	if not caster or caster:IsNull() or not ability or ability:IsNull() then return end
	local dps = ability:GetSpecialValueFor("damage_per_second")
		+ caster:GetMaxHealth() * ability:GetSpecialValueFor("max_health_damage_pct") / 100
	ApplyDamage({
		victim = self:GetParent(),
		attacker = caster,
		damage = dps * self.interval,
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = ability,
	})
end

function modifier_phoenix_icarus_dive_aa_burn:DeclareFunctions()
	return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end

function modifier_phoenix_icarus_dive_aa_burn:GetModifierMoveSpeedBonus_Percentage() return self.slow end
