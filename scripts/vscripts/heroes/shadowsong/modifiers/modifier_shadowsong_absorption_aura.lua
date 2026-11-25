modifier_shadowsong_absorption_aura = class({})
mod = modifier_shadowsong_absorption_aura

local talentName = "shadowsong_special_bonus_absorbtion"

function mod:IsHidden() 		return false end
function mod:IsPurgable() 		return false end
function mod:IsPurgeException() return false end
function mod:DestroyOnExpire() 	return true  end
function mod:IsAura() 			return true  end

function mod:OnCreated( kv )
	if not IsServer() then return end

	self.isOk = true

	local ability = self:GetAbility()
	local caster  = self:GetParent()

	self.radius   = ability:GetCastRange(caster:GetAbsOrigin(), nil) + caster:GetCastRangeBonus()
	self.team 	  = ability:GetAbilityTargetTeam()
	self.type 	  = ability:GetAbilityTargetType()
	self.damage   = ability:GetSpecialValueFor("damage") + caster:GetTalentSpecialValueFor(talentName)
	self.shard_slow_pct = ability:GetSpecialValueFor("shard_slow_pct")
	self.shard_ally_lifesteal_pct = ability:GetSpecialValueFor("shard_ally_lifesteal_pct")

	self:StartIntervalThink( ability:GetSpecialValueFor("interval") )

end

function mod:register( unit )
	if not self.isOk then return end

	local ability = self:GetAbility()

	if not ability then return end

	ability.units = ability.units or {}
	ability.units[unit] = true
end

function mod:unregister( unit )
	if not self.isOk then return end

	local ability = self:GetAbility()

	if not ability or not ability.units then return end

	ability.units[unit] = nil
end

function mod:OnDestroy()
	self.isOk = false

	if IsServer() then
		local ability = self:GetAbility()
		ability.units = {}
	end
end

function mod:OnIntervalThink()
	if not IsServer() then return end

	local ability = self:GetAbility()
	local parent  = self:GetParent()

	if not ability or not parent:IsAlive() then 
		self:Destroy()
		return 
	end

	local units = ability.units

	if not units then return end

	local damage 	 = self.damage
	local damageType = ability:GetAbilityDamageType()

	local sumHeal = 0

	for unit, _ in pairs(units) do
		hasUnits = true
		local damage = ApplyDamage({
			victim 		= unit,
			attacker 	= parent,
			damage 		= self.damage + parent:GetAgility() * self:GetAbility():GetSpecialValueFor("damage_str_pct") / 100,
			damage_type = damageType,
			ability 	= ability,
		})

		sumHeal = sumHeal + damage


		local part = ParticleManager:CreateParticle("particles/econ/items/lifestealer/lifestealer_immortal_backbone/lifestealer_immortal_backbone_rage_flek.vpcf", PATTACH_ABSORIGIN_FOLLOW, unit)
		ParticleManager:SetParticleControl(part, 2, unit:GetAbsOrigin())
		ParticleManager:ReleaseParticleIndex(part)
	end

	if sumHeal ~= 0 then
		parent:Heal(sumHeal, parent)

		ParticleManager:CreateParticle("particles/generic_gameplay/generic_lifesteal.vpcf", PATTACH_OVERHEAD_FOLLOW, parent)
    	SendOverheadEventMessage(parent, OVERHEAD_ALERT_HEAL, parent, sumHeal, nil)

		-- Шард: союзные герои получают вампиризм
		if self.shard_ally_lifesteal_pct > 0 then
			local allyHeal = sumHeal * self.shard_ally_lifesteal_pct / 100

			if allyHeal > 0 and not units then return end

			local allies = FindUnitsInRadius(
				parent:GetTeamNumber(),
				parent:GetAbsOrigin(),
				nil,
				self.radius,
				DOTA_UNIT_TARGET_TEAM_FRIENDLY,
				DOTA_UNIT_TARGET_HERO,
				DOTA_UNIT_TARGET_FLAG_INVULNERABLE,
				FIND_ANY_ORDER,
				false
			)

			for _, ally in pairs(allies) do
				if ally ~= parent and ally:IsAlive() then
					ally:Heal(allyHeal, parent)
					SendOverheadEventMessage(ally, OVERHEAD_ALERT_HEAL, ally, allyHeal, nil)
				end
			end
		end
	end
end

mod.OnRefresh = mod.OnCreated

function mod:GetEffectName()
	return "particles/econ/items/lifestealer/lifestealer_immortal_backbone/lifestealer_immortal_backbone_rage.vpcf"
end

function mod:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

function mod:GetModifierAura()
	return "modifier_shadowsong_absorption_aura_effect"
end

function mod:GetAuraSearchTeam()
	return self.team
end

function mod:GetAuraDuration()
	return 0
end

function mod:GetAuraSearchType()
	return self.type
end

function mod:GetAuraRadius()
	return self.radius
end

