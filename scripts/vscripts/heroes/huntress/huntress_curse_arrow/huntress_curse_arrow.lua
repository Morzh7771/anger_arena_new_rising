huntress_curse_arrow = huntress_curse_arrow or class({})
local debuffModifier = "modifier_huntress_curse_arrow"
local scepterMuteModifier = "modifier_huntress_curse_arrow_scepter_mute"
LinkLuaModifier(debuffModifier, "heroes/huntress/huntress_curse_arrow/" .. debuffModifier, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier(scepterMuteModifier, "heroes/huntress/huntress_curse_arrow/" .. scepterMuteModifier, LUA_MODIFIER_MOTION_NONE)

function huntress_curse_arrow:OnSpellStart()
	if not IsServer() then return end
	self.target = self:GetCursorTarget()
	
	if self.target:TriggerSpellAbsorb(self) or self.target:TriggerSpellReflect(self) then return end
	
	self.channelTime = 0
	self.min_duration = self:GetSpecialValueFor("min_duration")
	self.max_duration = self:GetSpecialValueFor("max_duration")
end

function huntress_curse_arrow:OnChannelThink(intervalTime)
	self.channelTime = self.channelTime + intervalTime
end

function huntress_curse_arrow:OnChannelFinish()
	if not self.target:IsAlive() then return end
	local caster = self:GetCaster()

	local info =
	{
		Target = self.target,
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
	}
	ProjectileManager:CreateTrackingProjectile(info)
end

function huntress_curse_arrow:OnProjectileHit(target)
	if not self then return end
	local caster = self:GetCaster()
	local duration = self.channelTime / self:GetChannelTime() * (self.max_duration - self.min_duration) + self.min_duration
	target:AddNewModifier(caster, self, debuffModifier, { duration = duration })

	-- Scepter upgrade: area effect with mute
	if caster:HasScepter() then
		local scepter_radius = self:GetSpecialValueFor("scepter_radius")
		local scepter_mute_duration = self:GetSpecialValueFor("scepter_mute_duration")

		if scepter_radius > 0 then
			local nearby_enemies = FindUnitsInRadius(
				caster:GetTeamNumber(),
				target:GetAbsOrigin(),
				nil,
				scepter_radius,
				DOTA_UNIT_TARGET_TEAM_ENEMY,
				DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
				DOTA_UNIT_TARGET_FLAG_NONE,
				FIND_ANY_ORDER,
				false
			)

			for _, enemy in pairs(nearby_enemies) do
				if enemy ~= target then
					enemy:AddNewModifier(caster, self, scepterMuteModifier, { duration = scepter_mute_duration })
				end
			end
		end
	end
end

function huntress_curse_arrow:OnInventoryContentsChanged()
	self:SetLevel(1)
	self:SetHidden(not self:GetCaster():HasModifier("modifier_item_hurricane_pike_aa"))
end
