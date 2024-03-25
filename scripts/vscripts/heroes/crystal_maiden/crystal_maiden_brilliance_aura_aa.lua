LinkLuaModifier("modifier_crystal_maiden_brilliance_aura_aa", "heroes/crystal_maiden/crystal_maiden_brilliance_aura_aa.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_crystal_maiden_brilliance_aura_aa_emitter", "heroes/crystal_maiden/crystal_maiden_brilliance_aura_aa.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_crystal_maiden_brilliance_aura_aa_shield", "heroes/crystal_maiden/crystal_maiden_brilliance_aura_aa.lua", LUA_MODIFIER_MOTION_NONE)

crystal_maiden_brilliance_aura_aa = class({
	GetIntrinsicModifierName = function (self) return "modifier_crystal_maiden_brilliance_aura_aa_emitter" end,
	OnSpellStart = 			function (self)
        if not IsServer() then return end

        local caster = self:GetCaster()

        caster:AddNewModifier(caster, self, "modifier_crystal_maiden_brilliance_aura_aa_shield", { duration = self:GetSpecialValueFor("shield_duration")})
        EmitSoundOn("Hero_Lich.SinisterGaze.Cast.TI10", self:GetCaster())
    end
})


modifier_crystal_maiden_brilliance_aura_aa_emitter = class({
	IsHidden = 				function (self) return true end,
	IsDebuff = 				function (self) return false end,
	IsPurgable = 			function (self) return false end,
	GetAuraRadius = 		function (self) return 25000 end,
	GetAuraSearchFlags = 	function (self) return DOTA_UNIT_TARGET_FLAG_NONE end,
	GetAuraSearchTeam = 	function (self) return DOTA_UNIT_TARGET_TEAM_FRIENDLY end,
	GetAuraSearchType = 	function (self) return DOTA_UNIT_TARGET_HERO end,
	GetModifierAura = 		function (self) return "modifier_crystal_maiden_brilliance_aura_aa" end,  
	IsAura = 				function (self)
		if self:GetCaster():PassivesDisabled() then
			return false
		end
	
		if self:GetCaster():IsIllusion() then
			return false
		end
	
		return true
	end,
})

modifier_crystal_maiden_brilliance_aura_aa = class({
	IsHidden = 				function (self) return false end,
	IsDebuff = 				function (self) return false end,
	IsPurgable = 			function (self) return false end,
	OnCreated = 			function (self)
		self.caster = self:GetCaster()
		self.ability = self:GetAbility()
		self.parent = self:GetParent()
		self.manaregen = self.caster:GetManaRegen()
		self.mana_regen_share = self.ability:GetSpecialValueFor("mana_regen_share") / 100
		self.spellamp_const = self.ability:GetSpecialValueFor("spellamp_const")
		self.spellamp_mlp = self.ability:GetSpecialValueFor("spellamp_mlp") / 100

		if IsServer() then
			self:StartIntervalThink(0.2)
		end 
	end,
	OnIntervalThink = 		function (self)
		if IsServer() then
			if not self:GetAbility() then return end

			if self.parent then
				self:SetStackCount(self.caster:GetManaRegen())
			end
		end
	end,
	OnRefresh = 			function (self) self:OnCreated() end,
	DeclareFunctions = 		function (self)
		local funcs = {
			MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
			MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
		}
		return funcs
	end,
	GetModifierConstantManaRegen = function (self)
		if not self.ability then return end

		if self.parent == self.caster then
			return self.ability:GetSpecialValueFor("mana_regen") * self.ability:GetSpecialValueFor("self_bonus")
		else
			return self.ability:GetSpecialValueFor("mana_regen") + self:GetStackCount() * self.mana_regen_share
		end
	end,
	GetModifierSpellAmplify_Percentage = function (self)
		if self.parent == self.caster then
			return (self:GetStackCount() * self.spellamp_mlp + self.spellamp_const) * self.ability:GetSpecialValueFor("self_bonus")
		else
			return self:GetStackCount() * self.spellamp_mlp + self.spellamp_const
		end 
	end,
})

modifier_crystal_maiden_brilliance_aura_aa_shield = class({
	IsHidden = function(self) return false end,
    IsPurgable = function(self) return false end,
    GetTexture = function(self) return "crystal_maiden_brilliance_aura" end,
    RemoveOnDeath = function(self) return false end,
    DeclareFunctions = function(self) return {
        MODIFIER_PROPERTY_INCOMING_DAMAGE_CONSTANT,
    } end,
    GetModifierIncomingDamageConstant = function(self,params)
    	if IsClient() then 
            return self:GetStackCount()
        end
        if not IsServer() then return end
        if self:GetParent() == params.attacker then return end
        if self:GetStackCount() > params.damage then
            self:SetStackCount(self:GetStackCount() - params.damage)
            local i = params.damage
            return -i
        else
            local i = self:GetStackCount()
            return -i
        end
    end,
    OnIntervalThink = function(self)
    	local mana_regen_to_shield = self:GetAbility():GetSpecialValueFor("mana_regen_to_shield")
        local addbonus = self:GetStackCount() + self:GetCaster():GetManaRegen() * mana_regen_to_shield / 4
        local manaregen = self:GetCaster():GetManaRegen() * mana_regen_to_shield * 10
            if addbonus > manaregen then
                self:GetStackCount()
            else
                self:SetStackCount(addbonus)
            end
    end,
    OnCreated = function(self,kv) 
    if not IsServer() then return end
        self.CanRefresh = true

        self.particle = ParticleManager:CreateParticle("particles/crystal_maiden/immunity_sphere_buff.vpcf", PATTACH_CENTER_FOLLOW, self:GetParent())
        ParticleManager:SetParticleControl(self.particle, 0, self:GetParent():GetAbsOrigin())
        ParticleManager:SetParticleControlEnt(self.particle, 1, self:GetParent(), PATTACH_POINT_FOLLOW, "attach_origin", self:GetParent():GetAbsOrigin(), true)
        ParticleManager:SetParticleControl(self.particle, 2, Vector(0, 0, 0))
        self:AddParticle(self.particle,false, false, -1, false, false)

        self:StartIntervalThink(0.25)
    end,
})
