huntress_curse_arrow = huntress_curse_arrow or class({})

local debuffModifier = "modifier_huntress_curse_arrow"
LinkLuaModifier(debuffModifier, "heroes/huntress/huntress_curse_arrow/" .. debuffModifier, LUA_MODIFIER_MOTION_NONE)

function huntress_curse_arrow:Precache(context)
	PrecacheResource("particle", "particles/huntress/huntress_curse_arrow/huntress_curse_arrow.vpcf", context)
	PrecacheResource("particle", "particles/huntress/huntress_hunting_spirit/huntress_hunting_spirit.vpcf", context)
end

function huntress_curse_arrow:OnSpellStart()
	if not IsServer() then return end
	self.target = self:GetCursorTarget()
	self.channelTime = 0
end

function huntress_curse_arrow:OnChannelThink(intervalTime)
	self.channelTime = (self.channelTime or 0) + intervalTime
end

-- стрела летит и при прерванном чтении, длительность - по прочитанному времени
function huntress_curse_arrow:OnChannelFinish()
	local target = self.target
	self.target = nil
	if not target or target:IsNull() or not target:IsAlive() then return end
	local caster = self:GetCaster()

	local min_d = self:GetSpecialValueFor("min_duration")
	local max_d = self:GetSpecialValueFor("max_duration")
	local frac = math.min(1, (self.channelTime or 0) / math.max(0.01, self:GetChannelTime()))

	ProjectileManager:CreateTrackingProjectile({
		Target = target,
		Source = caster,
		Ability = self,
		EffectName = "particles/huntress/huntress_curse_arrow/huntress_curse_arrow.vpcf",
		iMoveSpeed = self:GetSpecialValueFor("projectile_speed"),
		vSourceLoc = caster:GetAbsOrigin(),
		bDrawsOnMinimap = false,
		bDodgeable = false,
		bIsAttack = false,
		bVisibleToEnemies = true,
		bReplaceExisting = false,
		flExpireTime = GameRules:GetGameTime() + 10,
		bProvidesVision = false,
		ExtraData = { duration = min_d + (max_d - min_d) * frac },
	})
end

function huntress_curse_arrow:OnProjectileHit_ExtraData(target, location, data)
	if not target or target:IsNull() or not target:IsAlive() then return true end
	if target:TriggerSpellAbsorb(self) then return true end

	local caster = self:GetCaster()
	ApplyDamage({
		victim = target,
		attacker = caster,
		damage = self:GetSpecialValueFor("damage"),
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = self,
	})
	if target:IsAlive() then
		target:AddNewModifier(caster, self, debuffModifier, { duration = (data and data.duration) or self:GetSpecialValueFor("min_duration") })
	end
	return true
end
