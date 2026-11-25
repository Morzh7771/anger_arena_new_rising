--[[
	Sun Ray Феникса на Lua - как в доте, но урон включает max_health_damage_pct %
	макс. здоровья Феникса в секунду.

	Луч длиной в дальность каста (+ бонусы) из головы Феникса. Раз в tick_interval:
	  враги  - base_damage + hp_perc_damage % их макс. здоровья + % макс. здоровья Феникса;
	  союзники (кроме Феникса) - base_heal + hp_perc_heal % их макс. здоровья;
	  Феникс платит hp_cost_perc_per_second % текущего здоровья (не убивает).
	Поворот: turn_rate_initial первые 0.5 с, потом turn_rate (град/с), курс - по приказам.
	Toggle Move - движение вперёд со скоростью forward_move_speed.
	Врождённая Blinding Sun: враги в луче копят промах blind_per_second % в секунду.
	Шард: враги в луче замедлены на shard_move_slow_pct, луч работает из яйца Supernova.
	Прерывается оглушением, сайленсом, хексом (в яйце с шардом - нет).
]]

LinkLuaModifier("modifier_phoenix_sun_ray_aa", "heroes/phoenix/phoenix_sun_ray_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_phoenix_sun_ray_aa_slow", "heroes/phoenix/phoenix_sun_ray_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_phoenix_sun_ray_aa_blind", "heroes/phoenix/phoenix_sun_ray_aa", LUA_MODIFIER_MOTION_NONE)

local INITIAL_TURN_TIME = 0.5

local function SetSubAbility(caster, name, level, active)
	local a = caster:FindAbilityByName(name)
	if not a then return end
	if level and a:GetLevel() < level then a:SetLevel(level) end
	if active ~= nil then a:SetActivated(active) end
end

phoenix_sun_ray = phoenix_sun_ray or class({})

function phoenix_sun_ray:OnUpgrade()
	local caster = self:GetCaster()
	SetSubAbility(caster, "phoenix_sun_ray_stop", self:GetLevel())
	SetSubAbility(caster, "phoenix_sun_ray_toggle_move", 1, caster:HasModifier("modifier_phoenix_sun_ray_aa"))
end

function phoenix_sun_ray:OnSpellStart()
	local caster = self:GetCaster()
	caster:RemoveModifierByName("modifier_phoenix_sun_ray_aa")
	local mod = caster:AddNewModifier(caster, self, "modifier_phoenix_sun_ray_aa", { duration = self:GetDuration() })
	if mod then
		mod:SetTargetPoint(self:GetCursorPosition())
	end
end

--------------------------------------------------------------------------------
phoenix_sun_ray_stop = phoenix_sun_ray_stop or class({})

function phoenix_sun_ray_stop:OnSpellStart()
	self:GetCaster():RemoveModifierByName("modifier_phoenix_sun_ray_aa")
end

--------------------------------------------------------------------------------
phoenix_sun_ray_toggle_move = phoenix_sun_ray_toggle_move or class({})

function phoenix_sun_ray_toggle_move:Spawn()
	if IsServer() then
		self:SetLevel(1)
		self:SetActivated(false)
	end
end

function phoenix_sun_ray_toggle_move:OnSpellStart()
	local mod = self:GetCaster():FindModifierByName("modifier_phoenix_sun_ray_aa")
	if mod then mod.moving = not mod.moving end
end

--------------------------------------------------------------------------------
-- Луч
--------------------------------------------------------------------------------
modifier_phoenix_sun_ray_aa = class({})

function modifier_phoenix_sun_ray_aa:IsHidden() return false end
function modifier_phoenix_sun_ray_aa:IsPurgable() return false end
function modifier_phoenix_sun_ray_aa:GetTexture() return "phoenix_sun_ray" end
function modifier_phoenix_sun_ray_aa:GetEffectName() return "particles/units/heroes/hero_phoenix/phoenix_sunray_mane.vpcf" end
function modifier_phoenix_sun_ray_aa:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_phoenix_sun_ray_aa:OnCreated()
	if not IsServer() then return end
	local parent = self:GetParent()
	local ability = self:GetAbility()

	self.interval = math.max(0.1, ability:GetSpecialValueFor("tick_interval"))
	self.radius = ability:GetSpecialValueFor("radius")
	self.move_speed = ability:GetSpecialValueFor("forward_move_speed")
	self.turn_initial = ability:GetSpecialValueFor("turn_rate_initial")
	self.turn_rate = ability:GetSpecialValueFor("turn_rate")

	self.moving = false
	self.elapsed = 0
	self.tick_timer = 0
	self.dir = parent:GetForwardVector()
	self.target_dir = self.dir

	self.pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_phoenix/phoenix_sunray.vpcf", PATTACH_CUSTOMORIGIN, nil)
	ParticleManager:SetParticleControlEnt(self.pfx, 0, parent, PATTACH_POINT_FOLLOW, "attach_head", parent:GetAbsOrigin(), true)
	ParticleManager:SetParticleControlEnt(self.pfx, 9, parent, PATTACH_POINT_FOLLOW, "attach_head", parent:GetAbsOrigin(), true)
	self:AddParticle(self.pfx, false, false, -1, false, false)

	local flare = ParticleManager:CreateParticle("particles/units/heroes/hero_phoenix/phoenix_sunray_flare.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:SetParticleControlEnt(flare, 9, parent, PATTACH_POINT_FOLLOW, "attach_mouth", parent:GetAbsOrigin(), true)
	self:AddParticle(flare, false, false, -1, false, false)

	parent:EmitSound("Hero_Phoenix.SunRay.Cast")
	parent:EmitSound("Hero_Phoenix.SunRay.Loop")
	parent:StartGesture(ACT_DOTA_OVERRIDE_ABILITY_3)

	if parent:HasAbility("phoenix_sun_ray_stop") then
		SetSubAbility(parent, "phoenix_sun_ray_stop", ability:GetLevel())
		parent:SwapAbilities("phoenix_sun_ray", "phoenix_sun_ray_stop", false, true)
	end
	SetSubAbility(parent, "phoenix_sun_ray_toggle_move", 1, true)

	self:UpdateBeam()
	self:StartIntervalThink(FrameTime())
end

function modifier_phoenix_sun_ray_aa:SetTargetPoint(point)
	local d = point - self:GetParent():GetAbsOrigin()
	d.z = 0
	if d:Length2D() > 1 then
		self.target_dir = d:Normalized()
	end
end

function modifier_phoenix_sun_ray_aa:GetLength()
	local parent = self:GetParent()
	local ability = self:GetAbility()
	return ability:GetCastRange(parent:GetAbsOrigin(), nil) + parent:GetCastRangeBonus()
end

function modifier_phoenix_sun_ray_aa:InEgg()
	return self:GetParent():HasModifier("modifier_phoenix_supernova_aa_hidden")
end

function modifier_phoenix_sun_ray_aa:UpdateBeam()
	local parent = self:GetParent()
	local endpos = GetGroundPosition(parent:GetAbsOrigin() + self.dir * self:GetLength(), nil)
	endpos.z = endpos.z + 92
	ParticleManager:SetParticleControl(self.pfx, 1, endpos)
	return endpos
end

function modifier_phoenix_sun_ray_aa:OnIntervalThink()
	local parent = self:GetParent()
	local dt = FrameTime()

	if not parent:IsAlive() then self:Destroy() return end
	if not self:InEgg() and (parent:IsStunned() or parent:IsSilenced() or parent:IsHexed()) then
		self:Destroy()
		return
	end

	self.elapsed = self.elapsed + dt
	local diving = parent:HasModifier("modifier_phoenix_icarus_dive_aa")

	if diving then
		-- во время Icarus Dive луч смотрит туда же, куда летит Феникс
		self.dir = parent:GetForwardVector()
		self.target_dir = self.dir
	else
		local rate = self.elapsed < INITIAL_TURN_TIME and self.turn_initial or self.turn_rate
		local step = rate * dt
		local cur = VectorToAngles(self.dir).y
		local diff = AngleDiff(VectorToAngles(self.target_dir).y, cur)
		if math.abs(diff) <= step then
			self.dir = self.target_dir
		else
			self.dir = RotatePosition(Vector(0, 0, 0), QAngle(0, diff > 0 and step or -step, 0), self.dir)
		end
		self.dir.z = 0
		self.dir = self.dir:Normalized()
		parent:SetForwardVector(self.dir)

		if self.moving and not parent:IsRooted() and not self:InEgg() then
			local pos = GetGroundPosition(parent:GetAbsOrigin() + self.dir * self.move_speed * dt, parent)
			parent:SetAbsOrigin(pos)
			GridNav:DestroyTreesAroundPoint(pos, 128, false)
		end
	end

	local endpos = self:UpdateBeam()

	self.tick_timer = self.tick_timer + dt
	if self.tick_timer >= self.interval - 0.001 then
		self.tick_timer = self.tick_timer - self.interval
		self:Tick(endpos)
	end
end

function modifier_phoenix_sun_ray_aa:Tick(endpos)
	local parent = self:GetParent()
	local ability = self:GetAbility()
	local team = parent:GetTeamNumber()
	local origin = parent:GetAbsOrigin()
	local iv = self.interval

	-- цена здоровьем
	local cost = parent:GetHealth() * ability:GetSpecialValueFor("hp_cost_perc_per_second") / 100 * iv
	parent:SetHealth(math.max(1, parent:GetHealth() - cost))

	local base_damage = ability:GetSpecialValueFor("base_damage")
	local pct_damage = ability:GetSpecialValueFor("hp_perc_damage") / 100
	local own_damage = parent:GetMaxHealth() * ability:GetSpecialValueFor("max_health_damage_pct") / 100
	local base_heal = ability:GetSpecialValueFor("base_heal")
	local pct_heal = ability:GetSpecialValueFor("hp_perc_heal") / 100

	local shard = parent:HasModifier("modifier_item_aghanims_shard")
	local blind = parent:FindAbilityByName("phoenix_blinding_sun")
	if blind and (blind:GetLevel() <= 0 or parent:PassivesDisabled()) then blind = nil end

	for i = 0, math.ceil(self:GetLength() / self.radius) do
		AddFOWViewer(team, origin + self.dir * self.radius * i, self.radius, iv * 2, false)
	end

	for _, unit in pairs(FindUnitsInLine(team, origin + self.dir * 32, endpos, nil, self.radius,
		DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE)) do
		if unit:GetTeamNumber() ~= team then
			ApplyDamage({
				victim = unit,
				attacker = parent,
				damage = (base_damage + unit:GetMaxHealth() * pct_damage + own_damage) * iv,
				damage_type = DAMAGE_TYPE_MAGICAL,
				ability = ability,
			})
			local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_phoenix/phoenix_sunray_debuff.vpcf", PATTACH_ABSORIGIN, unit)
			ParticleManager:SetParticleControlEnt(pfx, 1, unit, PATTACH_POINT_FOLLOW, "attach_hitloc", unit:GetAbsOrigin(), true)
			ParticleManager:ReleaseParticleIndex(pfx)

			if shard then
				unit:AddNewModifier(parent, ability, "modifier_phoenix_sun_ray_aa_slow", { duration = iv * 2 })
			end
			if blind then
				local m = unit:AddNewModifier(parent, blind, "modifier_phoenix_sun_ray_aa_blind", { duration = blind:GetSpecialValueFor("blind_duration") })
				if m then m:AddBlind(blind:GetSpecialValueFor("blind_per_second") * iv) end
			end
		elseif unit ~= parent then
			local heal = (base_heal + unit:GetMaxHealth() * pct_heal) * iv
			unit:Heal(heal, ability)
			SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, unit, heal, nil)
			local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_phoenix/phoenix_sunray_beam_friend.vpcf", PATTACH_ABSORIGIN, unit)
			ParticleManager:SetParticleControlEnt(pfx, 1, unit, PATTACH_POINT_FOLLOW, "attach_hitloc", unit:GetAbsOrigin(), true)
			ParticleManager:ReleaseParticleIndex(pfx)
		end
	end
end

function modifier_phoenix_sun_ray_aa:OnDestroy()
	if not IsServer() then return end
	local parent = self:GetParent()
	parent:RemoveGesture(ACT_DOTA_OVERRIDE_ABILITY_3)
	parent:StopSound("Hero_Phoenix.SunRay.Loop")
	parent:EmitSound("Hero_Phoenix.SunRay.Stop")
	if parent:HasAbility("phoenix_sun_ray_stop") then
		parent:SwapAbilities("phoenix_sun_ray_stop", "phoenix_sun_ray", false, true)
	end
	SetSubAbility(parent, "phoenix_sun_ray_toggle_move", nil, false)
	if not self:InEgg() then
		FindClearSpaceForUnit(parent, parent:GetAbsOrigin(), false)
	end
end

function modifier_phoenix_sun_ray_aa:CheckState()
	return {
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY] = true,
	}
end

function modifier_phoenix_sun_ray_aa:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_LIMIT,
		MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE,
		MODIFIER_PROPERTY_DISABLE_TURNING,
		MODIFIER_PROPERTY_IGNORE_CAST_ANGLE,
		MODIFIER_EVENT_ON_ORDER,
	}
end

-- обычное движение заменено поворотом луча
function modifier_phoenix_sun_ray_aa:GetModifierMoveSpeed_Limit() return 0.001 end
function modifier_phoenix_sun_ray_aa:GetModifierMoveSpeed_Absolute() return 0.001 end
function modifier_phoenix_sun_ray_aa:GetModifierDisableTurning() return 1 end
function modifier_phoenix_sun_ray_aa:GetModifierIgnoreCastAngle() return 1 end

function modifier_phoenix_sun_ray_aa:OnOrder(params)
	if not IsServer() or params.unit ~= self:GetParent() then return end
	local t = params.order_type
	if t == DOTA_UNIT_ORDER_MOVE_TO_POSITION or t == DOTA_UNIT_ORDER_MOVE_TO_DIRECTION
		or t == DOTA_UNIT_ORDER_ATTACK_MOVE then
		self:SetTargetPoint(params.new_pos)
	elseif (t == DOTA_UNIT_ORDER_MOVE_TO_TARGET or t == DOTA_UNIT_ORDER_ATTACK_TARGET)
		and params.target and not params.target:IsNull() then
		self:SetTargetPoint(params.target:GetAbsOrigin())
	end
end

--------------------------------------------------------------------------------
-- Замедление от шарда
--------------------------------------------------------------------------------
modifier_phoenix_sun_ray_aa_slow = class({})

function modifier_phoenix_sun_ray_aa_slow:IsDebuff() return true end
function modifier_phoenix_sun_ray_aa_slow:IsHidden() return false end
function modifier_phoenix_sun_ray_aa_slow:GetTexture() return "phoenix_sun_ray" end

function modifier_phoenix_sun_ray_aa_slow:OnCreated()
	local ability = self:GetAbility()
	self.slow = ability and -ability:GetSpecialValueFor("shard_move_slow_pct") or 0
end

function modifier_phoenix_sun_ray_aa_slow:DeclareFunctions()
	return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end

function modifier_phoenix_sun_ray_aa_slow:GetModifierMoveSpeedBonus_Percentage() return self.slow end

--------------------------------------------------------------------------------
-- Blinding Sun: копящийся промах
--------------------------------------------------------------------------------
modifier_phoenix_sun_ray_aa_blind = class({})

function modifier_phoenix_sun_ray_aa_blind:IsDebuff() return true end
function modifier_phoenix_sun_ray_aa_blind:IsHidden() return false end
function modifier_phoenix_sun_ray_aa_blind:IsPurgable() return true end
function modifier_phoenix_sun_ray_aa_blind:GetTexture() return "phoenix_blinding_sun" end

function modifier_phoenix_sun_ray_aa_blind:AddBlind(value)
	self.blind = (self.blind or 0) + value
	self:SetStackCount(math.floor(self.blind + 0.5))
end

function modifier_phoenix_sun_ray_aa_blind:DeclareFunctions()
	return { MODIFIER_PROPERTY_MISS_PERCENTAGE }
end

function modifier_phoenix_sun_ray_aa_blind:GetModifierMiss_Percentage() return self:GetStackCount() end
