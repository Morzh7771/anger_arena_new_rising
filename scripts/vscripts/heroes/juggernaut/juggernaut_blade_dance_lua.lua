juggernaut_blade_dance_lua = class({
    GetIntrinsicModifierName = function(self) return "modifier_juggernaut_blade_dance_lua" end
})
LinkLuaModifier( "modifier_juggernaut_blade_dance_lua", "heroes/juggernaut/juggernaut_blade_dance_lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_juggernaut_blade_dance_lua_mortal", "heroes/juggernaut/juggernaut_blade_dance_lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_juggernaut_blade_dance_castil", "heroes/juggernaut/juggernaut_blade_dance_lua", LUA_MODIFIER_MOTION_NONE )

modifier_juggernaut_blade_dance_lua = class({
    IsHidden = function(self) return true end,
    IsPurgable = function(self) return false end,
    DeclareFunctions = function(self) return {
        MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
		MODIFIER_PROPERTY_PROCATTACK_FEEDBACK
    } end,
})
modifier_juggernaut_blade_dance_castil = class({
    IsHidden = function(self) return true end,
    IsPurgable = function(self) return false end,
})
function modifier_juggernaut_blade_dance_lua:GetModifierPreAttack_CriticalStrike( params )
	if IsServer() and (not self:GetParent():PassivesDisabled()) then
		if params.target:GetTeamNumber()==self:GetParent():GetTeamNumber() then
			return
		end

		if RollPseudoRandomPercentage(self:GetAbility():GetSpecialValueFor( "blade_dance_crit_chance"),12,self:GetParent()) then
			self.record = params.record
            if self:GetAbility():GetSpecialValueFor("blade_dance_lifesteal") > 0 then
                self:GetCaster():Heal(self:GetCaster():GetAverageTrueAttackDamage(self:GetParent()) * (self:GetAbility():GetSpecialValueFor( "blade_dance_crit_mult")/100) * self:GetAbility():GetSpecialValueFor("blade_dance_lifesteal")/100 ,self:GetAbility())
            end
            return self:GetAbility():GetSpecialValueFor( "blade_dance_crit_mult" )
		end
	end
end
function modifier_juggernaut_blade_dance_lua:GetModifierProcAttack_Feedback( params )
	if IsServer() then
		if self.record and self.record == params.record then
			self.record = nil
            print(self:GetParent():GetAverageTrueAttackDamage(self:GetParent()))
            self:GetCaster():SetNetworkableEntityInfo("mortal_pizdec",self:GetCaster():GetAverageTrueAttackDamage(self:GetCaster()))
            params.target:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_juggernaut_blade_dance_lua_mortal", { duration = self:GetAbility():GetSpecialValueFor("mortal_duration")*(1 - params.target:GetStatusResistance())})
			local sound_cast = "Hero_Juggernaut.BladeDance"
			EmitSoundOn( sound_cast, params.target )
		end
	end
end

    
modifier_juggernaut_blade_dance_lua_mortal = class({
    IsHidden = function(self) return false end,
    IsPurgable = function(self) return false end,
    GetTexture = function(self) return "blade_dance_mortal" end,
    OnTooltip = function(self) return self:GetCaster():GetNetworkableEntityInfo("mortal_pizdec") * (self:GetAbility():GetSpecialValueFor("mortal_damage")/100) * self:GetStackCount() end,
    OnRefresh = function(self) if not IsServer() then return end self:SetStackCount(self:GetStackCount()+1) end,
    DeclareFunctions = function(self) return {MODIFIER_PROPERTY_TOOLTIP} end,
})

function modifier_juggernaut_blade_dance_lua_mortal:OnCreated(table)
    if not IsServer() then return end
    
    self.ability = self:GetAbility()
    self.caster = self:GetCaster()

    if self.caster:IsIllusion() then 
        self.caster = self.caster.owner
    end
    
    self:SetStackCount(1)
    self.damage = self:GetCaster():GetAverageTrueAttackDamage(self:GetParent()) * (self:GetAbility():GetSpecialValueFor("mortal_damage")/100)
    self:StartIntervalThink(0.1)
end



function modifier_juggernaut_blade_dance_lua_mortal:OnDestroy()
    if not IsServer() then return end
        local parent = self:GetParent()

        local trail_pfx2 = ParticleManager:CreateParticle("particles/jugg_legendary_proc_.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
        ParticleManager:DestroyParticle(trail_pfx2, false)
        ParticleManager:ReleaseParticleIndex(trail_pfx2)

        local trail_pfx = ParticleManager:CreateParticle("particles/items3_fx/iron_talon_active.vpcf", PATTACH_ABSORIGIN, self:GetParent())

        ParticleManager:SetParticleControlEnt(trail_pfx, 0, parent, PATTACH_ABSORIGIN_FOLLOW, nil, parent:GetAbsOrigin(), true)
        ParticleManager:SetParticleControlEnt( trail_pfx, 1, parent, PATTACH_ABSORIGIN_FOLLOW, nil, parent:GetAbsOrigin(), true)
        ParticleManager:ReleaseParticleIndex(trail_pfx)
        self:GetParent():EmitSound("DOTA_Item.Daedelus.Crit")

        ApplyDamage({ victim = self:GetParent(), attacker = self.caster, ability = self.ability, damage = self.damage*self:GetStackCount(), damage_type = DAMAGE_TYPE_MAGICAL})
        self:Destroy()
end

function modifier_juggernaut_blade_dance_lua_mortal:OnIntervalThink()
    if not IsServer() then return end
        if self:GetParent():GetHealthPercent() < self:GetAbility():GetSpecialValueFor("mortal_hp") 
        or self:GetCaster():GetNetworkableEntityInfo("mortal_pizdec") * (self:GetAbility():GetSpecialValueFor("mortal_damage")/100) * self:GetStackCount() > self:GetParent():GetHealth() then  
        self:Destroy()
    end
end
