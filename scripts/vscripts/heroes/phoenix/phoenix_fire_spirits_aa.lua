--[[
	Fire Spirits Феникса на Lua - как в доте, но урон ожога включает
	max_health_damage_pct % макс. здоровья Феникса в секунду.

	Каст: spirit_count духов вокруг Феникса на spirit_duration, способность
	меняется на Launch Fire Spirit. Дух летит в точку со скоростью spirit_speed,
	взрывается в radius: ожог duration (урон раз в tick_interval + замедление атаки).
]]

LinkLuaModifier("modifier_phoenix_fire_spirits_aa", "heroes/phoenix/phoenix_fire_spirits_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_phoenix_fire_spirits_aa_burn", "heroes/phoenix/phoenix_fire_spirits_aa", LUA_MODIFIER_MOTION_NONE)

phoenix_fire_spirits = phoenix_fire_spirits or class({})

function phoenix_fire_spirits:OnUpgrade()
	local launch = self:GetCaster():FindAbilityByName("phoenix_launch_fire_spirit")
	if launch then launch:SetLevel(self:GetLevel()) end
end

function phoenix_fire_spirits:OnSpellStart()
	local caster = self:GetCaster()

	local cost = caster:GetHealth() * self:GetSpecialValueFor("hp_cost_perc") / 100
	caster:SetHealth(math.max(1, caster:GetHealth() - cost))

	caster:EmitSound("Hero_Phoenix.FireSpirits.Cast")
	caster:RemoveModifierByName("modifier_phoenix_fire_spirits_aa")
	caster:AddNewModifier(caster, self, "modifier_phoenix_fire_spirits_aa", { duration = self:GetSpecialValueFor("spirit_duration") })
end

--------------------------------------------------------------------------------
phoenix_launch_fire_spirit = phoenix_launch_fire_spirit or class({})

function phoenix_launch_fire_spirit:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function phoenix_launch_fire_spirit:OnSpellStart()
	local caster = self:GetCaster()
	local mod = caster:FindModifierByName("modifier_phoenix_fire_spirits_aa")
	if not mod then return end

	-- значения берём у основной способности (её прокачка и таланты)
	local source = mod:GetAbility() or self
	local point = self:GetCursorPosition()
	local speed = math.max(1, source:GetSpecialValueFor("spirit_speed"))

	caster:StartGesture(ACT_DOTA_OVERRIDE_ABILITY_2)
	caster:EmitSound("Hero_Phoenix.FireSpirits.Launch")

	local start = caster:GetAttachmentOrigin(caster:ScriptLookupAttachment("attach_hitloc"))
	local dir = point - start
	dir.z = 0
	local dist = dir:Length2D()
	dir = dist > 1 and dir:Normalized() or caster:GetForwardVector()

	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_phoenix/phoenix_fire_spirit_launch.vpcf", PATTACH_CUSTOMORIGIN, nil)
	ParticleManager:SetParticleControl(pfx, 0, start)
	ParticleManager:SetParticleControl(pfx, 1, dir * speed)

	local radius = source:GetSpecialValueFor("radius")
	local duration = source:GetSpecialValueFor("duration")
	local team = caster:GetTeamNumber()

	Timers:CreateTimer(dist / speed, function()
		ParticleManager:DestroyParticle(pfx, false)
		ParticleManager:ReleaseParticleIndex(pfx)

		local ground = ParticleManager:CreateParticle("particles/units/heroes/hero_phoenix/phoenix_fire_spirit_ground.vpcf", PATTACH_WORLDORIGIN, nil)
		ParticleManager:SetParticleControl(ground, 0, point)
		ParticleManager:SetParticleControl(ground, 1, Vector(radius, radius, radius))
		ParticleManager:ReleaseParticleIndex(ground)

		if not caster or caster:IsNull() or not source or source:IsNull() then return end
		EmitSoundOnLocationWithCaster(point, "Hero_Phoenix.FireSpirits.Target", caster)
		AddFOWViewer(team, point, radius, 1, true)

		for _, enemy in pairs(FindUnitsInRadius(team, point, nil, radius,
			DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)) do
			enemy:EmitSound("Hero_Phoenix.FireSpirits.ProjectileHit")
			enemy:AddNewModifier(caster, source, "modifier_phoenix_fire_spirits_aa_burn", { duration = duration })
		end
	end)

	mod:DecrementStackCount()
	mod:UpdateSpirits()
	if mod:GetStackCount() <= 0 then
		mod:Destroy()
	end
end

--------------------------------------------------------------------------------
-- Духи вокруг Феникса
--------------------------------------------------------------------------------
modifier_phoenix_fire_spirits_aa = class({})

function modifier_phoenix_fire_spirits_aa:IsHidden() return false end
function modifier_phoenix_fire_spirits_aa:IsPurgable() return false end
function modifier_phoenix_fire_spirits_aa:GetTexture() return "phoenix_fire_spirits" end

function modifier_phoenix_fire_spirits_aa:OnCreated()
	if not IsServer() then return end
	local parent = self:GetParent()
	self.count = math.max(1, self:GetAbility():GetSpecialValueFor("spirit_count"))
	self:SetStackCount(self.count)

	self.pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_phoenix/phoenix_fire_spirits.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent)
	self:AddParticle(self.pfx, false, false, -1, false, false)
	self:UpdateSpirits()

	if parent:HasAbility("phoenix_launch_fire_spirit") then
		parent:SwapAbilities("phoenix_fire_spirits", "phoenix_launch_fire_spirit", false, true)
	end
end

function modifier_phoenix_fire_spirits_aa:UpdateSpirits()
	if not self.pfx then return end
	local n = self:GetStackCount()
	ParticleManager:SetParticleControl(self.pfx, 1, Vector(n, 0, 0))
	ParticleManager:SetParticleControl(self.pfx, 6, Vector(n, 0, 0))
	for i = 1, self.count do
		ParticleManager:SetParticleControl(self.pfx, 8 + i, Vector(i <= n and 1 or 0, 0, 0))
	end
end

function modifier_phoenix_fire_spirits_aa:OnDestroy()
	if not IsServer() then return end
	local parent = self:GetParent()
	if parent:HasAbility("phoenix_launch_fire_spirit") then
		parent:SwapAbilities("phoenix_launch_fire_spirit", "phoenix_fire_spirits", false, true)
	end
end

--------------------------------------------------------------------------------
-- Ожог
--------------------------------------------------------------------------------
modifier_phoenix_fire_spirits_aa_burn = class({})

function modifier_phoenix_fire_spirits_aa_burn:IsDebuff() return true end
function modifier_phoenix_fire_spirits_aa_burn:IsPurgable() return true end
function modifier_phoenix_fire_spirits_aa_burn:GetTexture() return "phoenix_fire_spirits" end
function modifier_phoenix_fire_spirits_aa_burn:GetEffectName() return "particles/units/heroes/hero_phoenix/phoenix_fire_spirit_burn.vpcf" end
function modifier_phoenix_fire_spirits_aa_burn:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_phoenix_fire_spirits_aa_burn:OnCreated()
	local ability = self:GetAbility()
	self.slow = ability and ability:GetSpecialValueFor("attackspeed_slow") or 0
	if not IsServer() then return end
	self.interval = math.max(0.1, ability:GetSpecialValueFor("tick_interval"))
	self:StartIntervalThink(self.interval)
end

function modifier_phoenix_fire_spirits_aa_burn:OnRefresh()
	local ability = self:GetAbility()
	self.slow = ability and ability:GetSpecialValueFor("attackspeed_slow") or 0
end

function modifier_phoenix_fire_spirits_aa_burn:OnIntervalThink()
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

function modifier_phoenix_fire_spirits_aa_burn:DeclareFunctions()
	return { MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT }
end

function modifier_phoenix_fire_spirits_aa_burn:GetModifierAttackSpeedBonus_Constant() return self.slow end
