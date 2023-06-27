wisp_spirits_aa = class({})
LinkLuaModifier("modifier_wisp_spirits_aa", "abilities/wisp_spirits_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_wisp_spirits_aa_wisp", "abilities/wisp_spirits_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_wisp_spirits_aa_talent", "abilities/wisp_spirits_aa", LUA_MODIFIER_MOTION_NONE)

--Valve fucked up and didnt sync up the spirit particles
--so the the actual spirit particles are the default ones regardless
--so i just made it a 50% of either the normal particles and immo particles

function wisp_spirits_aa:IsStealable()
    return false
end

function wisp_spirits_aa:IsHiddenWhenStolen()
    return false
end

function wisp_spirits_aa:OnToggle()
	local caster = self:GetCaster()
	
	self.direction = caster:GetForwardVector()

	if not self:GetToggleState() then
		for _,spirit in pairs(self.spirits) do
			if not spirit:IsNull() then
				spirit:ForceKill(false)
			end
		end
		
		caster:RemoveModifierByName("modifier_wisp_spirits_aa")
		self.spirits = {}
	else
		EmitSoundOn("Hero_Wisp.Spirits.Cast", caster)
		self.spirits = {}
		caster:AddNewModifier(caster, self, "modifier_wisp_spirits_aa", {})
	end
end

function wisp_spirits_aa:CreateSpiritWisp()
	local caster = self:GetCaster()

	local distance = self:GetTrueCastRange()

	local point = caster:GetAbsOrigin() + self.direction * distance --+ Vector(0, 0, 100)

	local wisp = caster:CreateSummon("npc_dota_wisp_spirit", point)
 	wisp:SetAbsOrigin(point)
	wisp:AddNewModifier(caster, self, "modifier_wisp_spirits_aa_wisp", {})
	caster:SpendMana( self:GetTalentSpecialValueFor("wisp_regen_cost"), self )
	table.insert(self.spirits, wisp)
end

modifier_wisp_spirits_aa = class({})
function modifier_wisp_spirits_aa:OnCreated(table)
	if IsServer() then
		EmitSoundOn("Hero_Wisp.Spirits.Loop", self:GetCaster())

		self.wispCount = self:GetTalentSpecialValueFor("max_wisps")
		self.max_wisps = self:GetTalentSpecialValueFor("max_wisps")
		self.speed = self:GetTalentSpecialValueFor("spirit_movement_rate")

		if self:GetCaster():HasTalent("special_bonus_unique_wisp_spirits_aa_2") then
			self.talent = true
		end

		self.maxDistance = self:GetAbility():GetTrueCastRange()

		self.minDistance = self:GetTalentSpecialValueFor("min_radius")

		self.currentDistance = self.minDistance

		self.distanceTick = self.speed/3 * FrameTime()

		self.time = (360/self.speed)/(self.max_wisps + 1)

		self.elaspedTime = 0
		self.cost = self:GetTalentSpecialValueFor("wisp_regen_cost") * self:GetCaster():GetManaCostReduction()
		self:StartIntervalThink(FrameTime())
	end
end

function modifier_wisp_spirits_aa:OnIntervalThink()
	local caster = self:GetCaster()
	if self.elaspedTime < self.time then
		self.elaspedTime = self.elaspedTime + FrameTime()
	else
		if self.wispCount > 0 and caster:GetMana() >= self.cost then
			self:GetAbility():CreateSpiritWisp()
			self.wispCount = self.wispCount - 1
		else
			self.time = self:GetTalentSpecialValueFor("wisp_regen_rate")
		end
		self.elaspedTime = 0
	end

	local toggleAbility = caster:FindAbilityByName("wisp_spirit_inout")
	if toggleAbility:GetToggleState() then
		if self.currentDistance > self.minDistance then
			self.currentDistance = self.currentDistance - self.distanceTick
		end
	else
		if self.currentDistance < self.maxDistance then
			self.currentDistance = self.currentDistance + self.distanceTick
		end
	end
end

function modifier_wisp_spirits_aa:OnRemoved()
	if IsServer() then
		StopSoundOn("Hero_Wisp.Spirits.Loop", self:GetCaster())
		self:GetCaster():RemoveModifierByName("modifier_wisp_spirits_aa_spirit")
	end
end

function modifier_wisp_spirits_aa:IsAura()
    return self.talent
end

function modifier_wisp_spirits_aa:GetAuraDuration()
    return 0.5
end

function modifier_wisp_spirits_aa:GetAuraRadius()
    return self.currentDistance
end

function modifier_wisp_spirits_aa:GetAuraEntityReject(hEntity)
	if hEntity == self:GetParent() then
		return true
	end
end

function modifier_wisp_spirits_aa:GetAuraSearchFlags()
    return DOTA_UNIT_TARGET_FLAG_NONE
end

function modifier_wisp_spirits_aa:GetAuraSearchTeam()
    return DOTA_UNIT_TARGET_TEAM_FRIENDLY
end

function modifier_wisp_spirits_aa:GetAuraSearchType()
    return DOTA_UNIT_TARGET_ALL
end

function modifier_wisp_spirits_aa:GetModifierAura()
    return "modifier_wisp_spirits_aa_talent"
end

function modifier_wisp_spirits_aa:IsPurgable()
    return false
end

function modifier_wisp_spirits_aa:IsPurgeException()
    return false
end

modifier_wisp_spirits_aa_wisp = class({})
function modifier_wisp_spirits_aa_wisp:OnCreated(table)
	if IsServer() then
		local caster = self:GetCaster()
		local parent = self:GetParent()

		local particle = "particles/units/heroes/hero_wisp/wisp_guardian_.vpcf"
		if RollPercentage(50) then
			particle = "particles/econ/items/wisp/wisp_guardian_ti7.vpcf"
		end

		local nfx = ParticleManager:CreateParticle(particle, PATTACH_POINT, caster)
					ParticleManager:SetParticleControlEnt(nfx, 0, parent, PATTACH_POINT_FOLLOW, "attach_hitloc", parent:GetAbsOrigin(), true)
		self:AttachEffect(nfx)

		self.maxDistance = self:GetAbility():GetTrueCastRange()

		self.minDistance = self:GetTalentSpecialValueFor("min_radius")

		self.currentDistance = self.minDistance

		self.direction = self:GetAbility().direction
		
		self.speed = self:GetTalentSpecialValueFor("spirit_movement_rate")

		self.angle = 360 / self:GetTalentSpecialValueFor("max_wisps")

		self.point = caster:GetAbsOrigin() + self.direction * self.currentDistance --+ Vector(0, 0, 100)

		self.time = 360/self.speed/self:GetTalentSpecialValueFor("max_wisps")

		self.distanceTick = self.speed/3 * FrameTime()

		self.hitUnits = {}

		self.elaspedTime = 0

		self.collisionDamage = self:GetTalentSpecialValueFor("damage_collide")

		self.endDamage = self:GetTalentSpecialValueFor("damage_end")

		self.collisionRadius = self:GetTalentSpecialValueFor("hit_radius")

		self.endRadius = self:GetTalentSpecialValueFor("explode_radius")

		if caster:HasTalent("special_bonus_unique_wisp_spirits_aa_1") then
			self.talentTime = caster:FindTalentValue("special_bonus_unique_wisp_spirits_aa_1", "tick_rate")
			self.talentElaspedTime = 0

			self.talentWidth = caster:FindTalentValue("special_bonus_unique_wisp_spirits_aa_1", "width")
			self.talentDamage = self.endDamage * caster:FindTalentValue("special_bonus_unique_wisp_spirits_aa_1", "damage")/100
		end

		self:StartIntervalThink(FrameTime())
	end
end

function modifier_wisp_spirits_aa_wisp:OnIntervalThink()
	local caster = self:GetCaster()
	local parent = self:GetParent()

	local qAngle = QAngle(0, self.angle, 0)
	local casterPos = caster:GetAbsOrigin()

	local newSpawn = RotatePosition(casterPos, qAngle, self.point)

	parent:SetAbsOrigin(newSpawn)

	local toggleAbility = caster:FindAbilityByName("wisp_spirit_inout")
	if toggleAbility:GetToggleState() then
		if self.currentDistance > self.minDistance then
			self.currentDistance = self.currentDistance - self.distanceTick
		end
	else
		if self.currentDistance < self.maxDistance then
			self.currentDistance = self.currentDistance + self.distanceTick
		end
	end

	self.point = casterPos + self.direction * self.currentDistance

	self.angle = self.angle - self.speed * FrameTime()

	local enemies = caster:FindEnemyUnitsInRadius(parent:GetAbsOrigin(), self.collisionRadius)
	for _,enemy in pairs(enemies) do
		if not self.hitUnits[enemy:entindex()] and enemy:IsMinion() then

			EmitSoundOn("Hero_Wisp.Spirits.TargetCreep", parent)
			if not enemy:TriggerSpellAbsorb( self:GetAbility() ) then
				if RollPercentage(50) then
					local nfx2 = ParticleManager:CreateParticle("particles/units/heroes/hero_wisp/wisp_guardian_explosion_small.vpcf", PATTACH_POINT_FOLLOW, parent)
								 ParticleManager:SetParticleControlEnt(nfx2, 0, parent, PATTACH_POINT_FOLLOW, "attach_hitloc", parent:GetAbsOrigin(), true)
								 ParticleManager:ReleaseParticleIndex(nfx2)
				else
					local nfx2 = ParticleManager:CreateParticle("particles/units/heroes/hero_wisp/wisp_guardian_explosion_small.vpcf", PATTACH_POINT, caster)
								 ParticleManager:SetParticleControlEnt(nfx2, 0, parent, PATTACH_POINT_FOLLOW, "attach_hitloc", parent:GetAbsOrigin(), true)
								 ParticleManager:ReleaseParticleIndex(nfx2)
				end

				self:GetAbility():DealDamage(caster, enemy, self.collisionDamage, {}, OVERHEAD_ALERT_BONUS_POISON_DAMAGE)
			end
			self.hitUnits[enemy:entindex()] = true
		else
			parent:ForceKill(false)
			return
		end
	end

	if self.elaspedTime < self.time then
		self.elaspedTime = self.elaspedTime + FrameTime()
	else
		self.hitUnits = {}
		self.elaspedTime = 0
	end

	if self.talentTime then
		if self.talentElaspedTime < self.talentTime then
			self.talentElaspedTime = self.talentElaspedTime + FrameTime()
		else
			local nfx = ParticleManager:CreateParticle("particles/units/heroes/hero_zuus/zuus_arc_lightning.vpcf", PATTACH_POINT, caster)
						ParticleManager:SetParticleControlEnt(nfx, 0, caster, PATTACH_POINT, "attach_hitloc", caster:GetAbsOrigin(), true)
						ParticleManager:SetParticleControlEnt(nfx, 1, parent, PATTACH_POINT, "attach_hitloc", parent:GetAbsOrigin(), true)
						ParticleManager:ReleaseParticleIndex(nfx)

			local enemies = caster:FindEnemyUnitsInLine(parent:GetAbsOrigin(), caster:GetAbsOrigin(), self.talentWidth, {})
			for _,enemy in pairs(enemies) do
				self:GetAbility():DealDamage(caster, enemy, self.talentDamage, {}, OVERHEAD_ALERT_BONUS_SPELL_DAMAGE)
			end

			self.talentElaspedTime = 0
		end
	end
end

function modifier_wisp_spirits_aa_wisp:OnRemoved()
	if IsServer() then
		local caster = self:GetCaster()
		local parent = self:GetParent()

		EmitSoundOn("Hero_Wisp.Spirits.Target", parent)

		if RollPercentage(50) then
			local nfx2 = ParticleManager:CreateParticle("particles/units/heroes/hero_wisp/wisp_guardian_explosion.vpcf", PATTACH_POINT_FOLLOW, parent)
						 ParticleManager:SetParticleControlEnt(nfx2, 0, parent, PATTACH_POINT_FOLLOW, "attach_hitloc", parent:GetAbsOrigin(), true)
						 ParticleManager:ReleaseParticleIndex(nfx2)
		else
			local nfx2 = ParticleManager:CreateParticle("particles/units/heroes/hero_wisp/wisp_guardian_explosion.vpcf", PATTACH_POINT, caster)
					 	 ParticleManager:SetParticleControlEnt(nfx2, 0, parent, PATTACH_POINT_FOLLOW, "attach_hitloc", parent:GetAbsOrigin(), true)
					 	 ParticleManager:ReleaseParticleIndex(nfx2)
		end

		local slow = self:GetTalentSpecialValueFor("slow_duration")
		local enemies = caster:FindEnemyUnitsInRadius(parent:GetAbsOrigin(), self.endRadius)
		for _,enemy in pairs(enemies) do
			if not enemy:TriggerSpellAbsorb( self:GetAbility() ) then
				enemy:Paralyze(self:GetAbility(), caster, slow)
				self:GetAbility():DealDamage(caster, enemy, self.endDamage, {}, OVERHEAD_ALERT_BONUS_SPELL_DAMAGE)
			end
		end
		if caster:HasModifier("modifier_wisp_spirits_aa") then
			local modifier = caster:FindModifierByName("modifier_wisp_spirits_aa")
			modifier.wispCount = modifier.wispCount + 1
		end
	end
end

function modifier_wisp_spirits_aa_wisp:CheckState()
	return {[MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY] = true,
			[MODIFIER_STATE_NO_HEALTH_BAR] = true,
			[MODIFIER_STATE_COMMAND_RESTRICTED] = true,
			[MODIFIER_STATE_UNSELECTABLE] = true,
			[MODIFIER_STATE_UNTARGETABLE] = true,
			[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
			[MODIFIER_STATE_NOT_ON_MINIMAP] = true,
			[MODIFIER_STATE_INVULNERABLE] = true}
end

modifier_wisp_spirits_aa_talent = class({})
function modifier_wisp_spirits_aa_talent:OnCreated(table)
	self.bonus_sr = self:GetCaster():FindTalentValue("special_bonus_unique_wisp_spirits_aa_2")
end

function modifier_wisp_spirits_aa_talent:DeclareFunctions()
	local funcs = {MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING}
	return funcs
end

function modifier_wisp_spirits_aa_talent:GetModifierStatusResistanceStacking()
	return self.bonus_sr
end

function modifier_wisp_spirits_aa_talent:GetEffectName()
	return "particles/econ/items/wisp/wisp_ambient_ti7_trace.vpcf"
end

function modifier_wisp_spirits_aa_talent:IsDebuff()
	return false
end