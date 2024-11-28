

LinkLuaModifier("modifier_aa_slark_pounce", "heroes/slark/slark_pounce_aa", LUA_MODIFIER_MOTION_BOTH)
LinkLuaModifier("modifier_aa_slark_pounce_leash", "heroes/slark/slark_pounce_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_aa_slark_pounce_charge_counter", "heroes/slark/slark_pounce_aa", LUA_MODIFIER_MOTION_NONE)

slark_pounce_aa = class({})
modifier_aa_slark_pounce = class({})
modifier_aa_slark_pounce_leash = class({})
modifier_aa_slark_pounce_charge_counter = class({})
function slark_pounce_aa:GetIntrinsicModifierName()
	return "modifier_aa_slark_pounce_charge_counter"
end

function slark_pounce_aa:GetCooldown(level)
	if not self:GetCaster():HasScepter() then
		if not self:GetCaster():HasModifier("modifier_aa_slark_pounce") or IsClient() then
			return self.BaseClass.GetCooldown(self, level)
		elseif IsServer() then
			return (self.BaseClass.GetCooldown(self, level) * (self:GetCaster():GetCooldownReduction())) - self:GetCaster():FindModifierByName("modifier_aa_slark_pounce"):GetElapsedTime()
		end
	else
		return 0
	end
end

function slark_pounce_aa:GetManaCost(level)
	if not self:GetCaster():HasModifier("modifier_aa_slark_pounce") then
		return self.BaseClass.GetManaCost(self, level)
	else
		return 0
	end
end

function slark_pounce_aa:OnSpellStart()
	self:GetCaster():EmitSound("Hero_Slark.Pounce.Cast")
	
	local pounce_particle = ParticleManager:CreateParticle("particles/units/heroes/hero_slark/slark_pounce_start.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetCaster())
	ParticleManager:ReleaseParticleIndex(pounce_particle)
	
	if self:GetCaster():GetName() == "npc_dota_hero_slark" then
		self:GetCaster():StartGesture(ACT_DOTA_SLARK_POUNCE)
	end
	
	-- IMBAfication: Aerial Redirection
	if not self:GetCaster():HasModifier("modifier_aa_slark_pounce") then
		if not self:GetCaster():HasScepter() then
			self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_aa_slark_pounce", {duration = self:GetSpecialValueFor("pounce_distance") / self:GetSpecialValueFor("pounce_speed")})
		else
			self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_aa_slark_pounce", {duration = self:GetSpecialValueFor("pounce_distance_scepter") / (self:GetSpecialValueFor("pounce_speed") * 2)})
		end
		
		self:EndCooldown()
		self:StartCooldown(0.1)
	else
		if self:GetCaster():FindModifierByName("modifier_aa_slark_pounce").redirect_pos then
			self:GetCaster():FindModifierByName("modifier_aa_slark_pounce").direction = (self:GetCaster():FindModifierByName("modifier_aa_slark_pounce").redirect_pos - self:GetCaster():GetAbsOrigin()):Normalized()
		else
			self:GetCaster():FindModifierByName("modifier_aa_slark_pounce").direction = self:GetCaster():GetForwardVector()		
		end
		
		self:UseResources(false, false, false, true)
	end
end

--------------------------------
-- MODIFIER_IMBA_SLARK_POUNCE --
--------------------------------

function modifier_aa_slark_pounce:IsHidden()		return true end
function modifier_aa_slark_pounce:IsPurgable()	return false end

function modifier_aa_slark_pounce:GetEffectName()
	return "particles/units/heroes/hero_slark/slark_pounce_trail.vpcf"
end

function modifier_aa_slark_pounce:OnCreated()
	if not IsServer() then return end

	self.pounce_speed	= self:GetAbility():GetSpecialValueFor("pounce_speed")
	-- self.pounce_acceleration	= self:GetAbility:GetSpecialValueFor("pounce_acceleration") -- I don't use this for anything
	self.pounce_radius	= self:GetAbility():GetSpecialValueFor("pounce_radius")
	self.leash_duration	= self:GetAbility():GetSpecialValueFor("leash_duration")
	self.leash_radius	= self:GetAbility():GetSpecialValueFor("leash_radius")
	
	self.duration		= self:GetAbility():GetSpecialValueFor("pounce_distance") / self.pounce_speed
	self.direction		= self:GetParent():GetForwardVector()

	if self:GetCaster():HasScepter() then
		self.pounce_speed	= self:GetAbility():GetSpecialValueFor("pounce_speed") * 2
		self.duration		= self:GetAbility():GetSpecialValueFor("pounce_distance_scepter") / self.pounce_speed
	end

	self.redirection_commands = 
	{
		[DOTA_UNIT_ORDER_MOVE_TO_POSITION] 	= true,
		[DOTA_UNIT_ORDER_MOVE_TO_TARGET] 	= true,
		[DOTA_UNIT_ORDER_ATTACK_MOVE] 		= true,
		[DOTA_UNIT_ORDER_ATTACK_TARGET] 	= true,
		[DOTA_UNIT_ORDER_CAST_POSITION]		= true,
		[DOTA_UNIT_ORDER_CAST_TARGET]		= true,
		[DOTA_UNIT_ORDER_CAST_TARGET_TREE]	= true,
	}

	-- I don't see notes on the height in wiki so gonna use arbitrary height of 125 for now
	self.vertical_velocity		= 4 * 125 / self.duration
	self.vertical_acceleration	= -(8 * 125) / (self.duration * self.duration)

	if self:ApplyVerticalMotionController() == false then 
		self:Destroy()
	end
	
	if self:ApplyHorizontalMotionController() == false then 
		self:Destroy()
	end
end

function modifier_aa_slark_pounce:OnRemoved()
	if not IsServer() then return end

	if self:GetAbility() then
		if not self:GetCaster():HasScepter() then
			self:GetAbility():UseResources(false, false, false, true)
		else
			if self:GetCaster():GetModifierStackCount("modifier_aa_slark_pounce_charge_counter", self:GetCaster()) == 0 then
				self:GetAbility():StartCooldown(self:GetCaster():FindModifierByName("modifier_aa_slark_pounce_charge_counter"):GetRemainingTime())
			else
				self:GetAbility():UseResources(false, false, false, true)
			end
		end
	end
end

function modifier_aa_slark_pounce:OnDestroy()
	if not IsServer() then return end
	
	self:GetParent():RemoveHorizontalMotionController(self)
	self:GetParent():RemoveVerticalMotionController(self)
	
	if self:GetCaster():GetName() == "npc_dota_hero_slark" then
		self:GetCaster():FadeGesture(ACT_DOTA_SLARK_POUNCE)
	end
	
	-- "Pounce destroys trees within 100 radius around Slark upon landing."
	GridNav:DestroyTreesAroundPoint( self:GetParent():GetAbsOrigin(), 100, true )
end

function modifier_aa_slark_pounce:UpdateHorizontalMotion(me, dt)
	if not IsServer() then return end

	for _, enemy in pairs(FindUnitsInRadius(self:GetParent():GetTeamNumber(), self:GetParent():GetAbsOrigin(), nil, self.pounce_radius, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS, FIND_CLOSEST, false)) do
		if enemy:IsRealHero() or enemy:IsClone() or enemy:IsTempestDouble() then
			enemy:EmitSound("Hero_Slark.Pounce.Impact")

			if self:GetParent():GetName() == "npc_dota_hero_slark" then
				self:GetParent():EmitSound("slark_slark_pounce_0"..RandomInt(1, 6))
			end	

			enemy:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_aa_slark_pounce_leash", {
				duration 		= self.leash_duration * (1 - enemy:GetStatusResistance()),
				leash_radius	= self.leash_radius
			})
			
			self:GetParent():MoveToTargetToAttack(enemy)
			
			-- IMBAfication: β/Remnants of Pounce
			self:GetParent():PerformAttack(enemy, true, true, true, false, false, false, false)
			
			self:Destroy()
			break
		end
	end

	me:SetAbsOrigin( me:GetAbsOrigin() + self.pounce_speed * self.direction * dt )
end

function modifier_aa_slark_pounce:OnHorizontalMotionInterrupted()
	self:Destroy()
end

function modifier_aa_slark_pounce:UpdateVerticalMotion(me, dt)
	if not IsServer() then return end
	
	me:SetAbsOrigin( me:GetAbsOrigin() + Vector(0, 0, self.vertical_velocity) * dt )
	
	self.vertical_velocity = self.vertical_velocity + (self.vertical_acceleration * dt)
end

function modifier_aa_slark_pounce:OnVerticalMotionInterrupted()
	self:Destroy()
end

function modifier_aa_slark_pounce:CheckState()
	return {[MODIFIER_STATE_DISARMED] = true}
end

function modifier_aa_slark_pounce:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_TRANSLATE_ACTIVITY_MODIFIERS,
		
		MODIFIER_EVENT_ON_ORDER
	}
end

function modifier_aa_slark_pounce:GetActivityTranslationModifiers()
	return "leash"
end

function modifier_aa_slark_pounce:OnOrder(keys)
	if keys.unit == self:GetParent() then
		-- Testing something to try and stop randomly cancelled charges but IDK what the issue is
		if self.redirection_commands[keys.order_type] then
			if keys.order_type == DOTA_UNIT_ORDER_MOVE_TO_POSITION and keys.new_pos then
				self.redirect_pos = keys.new_pos
			elseif keys.target then
				self.redirect_pos = keys.target:GetAbsOrigin()
			end
		end
	end
end

--------------------------------------
-- MODIFIER_IMBA_SLARK_POUNCE_LEASH --
--------------------------------------

function modifier_aa_slark_pounce_leash:IsPurgable()	return false end

-- It's pretty annoying to try and figure out all the forced movement exceptions on Pounce, so I think I'm just gonna make it unbreakable and call it an IMBAfication -_-
function modifier_aa_slark_pounce_leash:OnCreated(params)
	if not IsServer() then return end
	
	self.leash_radius	= params.leash_radius
	
	-- Okay there's like no wiki information on how the formula for movespeed limit actually works so I'm going to have to fudge something pretty badly
	self.begin_slow_radius	= params.leash_radius * 80 * 0.01
	
	self.leash_position		= self:GetParent():GetAbsOrigin()
	
	self:GetParent():EmitSound("Hero_Slark.Pounce.Leash")
	
	self.ground_particle = ParticleManager:CreateParticle("particles/units/heroes/hero_slark/slark_pounce_ground.vpcf", PATTACH_WORLDORIGIN, self:GetParent())
	ParticleManager:SetParticleControl(self.ground_particle, 3, self:GetParent():GetAbsOrigin())
	ParticleManager:SetParticleControl(self.ground_particle, 4, Vector(self.leash_radius))
	self:AddParticle(self.ground_particle, false, false, -1, false, false)
	
	self.leash_particle	= ParticleManager:CreateParticle("particles/units/heroes/hero_slark/slark_pounce_leash.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
	ParticleManager:SetParticleControlEnt(self.leash_particle, 1, self:GetParent(), PATTACH_POINT_FOLLOW, "attach_hitloc", self:GetParent():GetAbsOrigin(), true)
	ParticleManager:SetParticleControl(self.leash_particle, 3, self:GetParent():GetAbsOrigin())
	self:AddParticle(self.leash_particle, false, false, -1, false, false)
	
	self:StartIntervalThink(FrameTime())
end

function modifier_aa_slark_pounce_leash:OnIntervalThink()
	self.limit		= 0
	self.move_speed	= self:GetParent():GetMoveSpeedModifier(self:GetParent():GetBaseMoveSpeed(), false)
	self.limit		= ((self.leash_radius - (self:GetParent():GetAbsOrigin() - self.leash_position):Length2D()) / self.leash_radius) * self.move_speed
	
	-- Can't be exactly 0 because that makes the GetModifierMoveSpeed_Limit() function do nothing
	if self.limit == 0 then
		self.limit = -0.01
	end
end

function modifier_aa_slark_pounce_leash:OnDestroy()
	if not IsServer() then return end
	
	self:GetParent():StopSound("Hero_Slark.Pounce.Leash")
	self:GetParent():EmitSound("Hero_Slark.Pounce.End")
	
	-- "When the leash expires while a position changing effect is ongoing, it instantly cancels the position changing effect."
	self:GetParent():InterruptMotionControllers(true)
end

function modifier_aa_slark_pounce_leash:CheckState()
	return {[MODIFIER_STATE_TETHERED] = true}
end

function modifier_aa_slark_pounce_leash:DeclareFunctions()
	return {MODIFIER_PROPERTY_MOVESPEED_LIMIT}
end

function modifier_aa_slark_pounce_leash:GetModifierMoveSpeed_Limit()
	if not IsServer() then return end
	
	-- A R B I T R A R Y   A N G L E
	if (self:GetParent():GetAbsOrigin() - self.leash_position):Length2D() >= self.begin_slow_radius and math.abs(AngleDiff(VectorToAngles(self:GetParent():GetAbsOrigin() - self.leash_position).y, VectorToAngles(self:GetParent():GetForwardVector() ).y)) <= 85 then
		return self.limit
	end
end

-----------------------------------------------
-- MODIFIER_IMBA_SLARK_POUNCE_CHARGE_COUNTER --
-----------------------------------------------

function modifier_aa_slark_pounce_charge_counter:IsHidden()			return not self:GetCaster():HasScepter() end
function modifier_aa_slark_pounce_charge_counter:DestroyOnExpire()	return false end
function modifier_aa_slark_pounce_charge_counter:RemoveOnDeath()		return false end

function modifier_aa_slark_pounce_charge_counter:OnCreated()
	if not IsServer() then return end

	-- Sphaget way of getting this working but it's hardcode (doesn't read the server-side value if RequiresScepter flag is on and scepter is not held)
	self:SetStackCount(math.max(self:GetAbility():GetSpecialValueFor("max_charges"), 2))
	self:CalculateCharge()
end

function modifier_aa_slark_pounce_charge_counter:OnIntervalThink()
	self:IncrementStackCount()
	self:StartIntervalThink(-1)
	self:CalculateCharge()
end

function modifier_aa_slark_pounce_charge_counter:CalculateCharge()	
	if self:GetStackCount() >= math.max(self:GetAbility():GetSpecialValueFor("max_charges"), 2) then
		self:SetDuration(-1, true)
		self:StartIntervalThink(-1)
	else
		if self:GetRemainingTime() <= 0.05 then			
			self:StartIntervalThink(self:GetAbility():GetSpecialValueFor("charge_restore_time") * self:GetParent():GetCooldownReduction())
			self:SetDuration(self:GetAbility():GetSpecialValueFor("charge_restore_time") * self:GetParent():GetCooldownReduction(), true)
		end
		
		-- if self:GetStackCount() == 0 then
			-- self:GetAbility():StartCooldown(self:GetRemainingTime())
		-- else
			self:GetAbility():StartCooldown(0.1)
		-- end
	end
end

function modifier_aa_slark_pounce_charge_counter:DeclareFunctions()
	return {MODIFIER_EVENT_ON_ABILITY_FULLY_CAST}
end

function modifier_aa_slark_pounce_charge_counter:OnAbilityFullyCast(params)
	if params.unit ~= self:GetParent() or not self:GetParent():HasScepter() then return end
	
	if params.ability == self:GetAbility() then
		-- All this garbage is just to try and check for WTF mode to not expend charges and yet it's still bypassable
		local wtf_mode = true
		
		if not GameRules:IsCheatMode() then
			wtf_mode = false
		else
			for ability = 0, 24 - 1 do
				if self:GetParent():GetAbilityByIndex(ability) and self:GetParent():GetAbilityByIndex(ability):GetCooldownTimeRemaining() > 0 then
					wtf_mode = false
					break
				end
			end

			if wtf_mode == false then
				for item = 0, 15 do
					if self:GetParent():GetItemInSlot(item) and self:GetParent():GetItemInSlot(item):GetCooldownTimeRemaining() > 0 then
						wtf_mode = false
						break
					end
				end
			end
		end
		
		if wtf_mode == false then
			self:DecrementStackCount()
			self:CalculateCharge()
		end
	elseif params.ability:GetName() == "item_refresher" or params.ability:GetName() == "item_refresher_shard" then
		self:StartIntervalThink(-1)
		self:SetDuration(-1, true)
		self:SetStackCount(self:GetAbility():GetSpecialValueFor("max_charges"))
	end
end