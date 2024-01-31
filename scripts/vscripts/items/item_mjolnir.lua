LinkLuaModifier('item_mjolnir_modifier', 'items/item_mjolnir', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('item_mjolnir_modifier_tinkerer', 'items/item_mjolnir', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_item_mjolnir_shield', 'items/item_mjolnir', LUA_MODIFIER_MOTION_NONE)

item_mjolnir_aa_1 = class({
    GetIntrinsicModifierName = function (self) return "item_mjolnir_modifier" end
})
item_mjolnir_aa_2 = item_mjolnir_aa_1
item_mjolnir_aa_3 = item_mjolnir_aa_1
item_maelstorm_aa = item_mjolnir_aa_1

function item_mjolnir_aa_1:OnSpellStart()
    local target = self:GetCursorTarget()
    target:AddNewModifier(self:GetCaster(), self, "modifier_item_mjolnir_shield", {duration = self:GetSpecialValueFor("active_duration")})
end
function item_mjolnir_aa_2:OnSpellStart()
	local target = self:GetCursorTarget()
    target:AddNewModifier(self:GetCaster(), self, "modifier_item_mjolnir_shield", {duration = self:GetSpecialValueFor("active_duration")})
end
function item_mjolnir_aa_3:OnSpellStart()
	local target = self:GetCursorTarget()
    target:AddNewModifier(self:GetCaster(), self, "modifier_item_mjolnir_shield", {duration = self:GetSpecialValueFor("active_duration")})
end

item_mjolnir_modifier = class({
    IsHidden = function (self) return true end,
    DeclareFunctions = function (self) return 
    {
        MODIFIER_EVENT_ON_ATTACK_LANDED,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_BASEATTACK_BONUSDAMAGE,
    }
    end,
    GetModifierAttackSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("bonus_attack_speed") end,
    GetModifierBaseAttack_BonusDamage = function (self)return self:GetAbility():GetSpecialValueFor('bonus_damage') end,

})
modifier_item_mjolnir_shield = class({
    IsHidden = function (self) return false end,
    DeclareFunctions = function (self) return 
    {
        MODIFIER_EVENT_ON_ATTACK_LANDED,
    }
    end,
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
})
function modifier_item_mjolnir_shield:OnCreated()
	self.shield_particle = ParticleManager:CreateParticle("particles/items2_fx/mjollnir_shield.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
	self:AddParticle(self.shield_particle, false, false, -1, false, false)
end
function modifier_item_mjolnir_shield:OnAttackLanded(keys)
    if keys.target == self:GetParent() then
        if RollPseudoRandomPercentage(self:GetAbility():GetSpecialValueFor('active_chance'),100,self:GetParent()) then
            self:GetParent():AddNewModifier(self:GetParent(), self:GetAbility(), "item_mjolnir_modifier_tinkerer", {
                starting_unit_entindex	= keys.attacker:entindex(),self_casted = 1
                
            })
        end
    end
end
function item_mjolnir_modifier:OnAttackLanded(keys)
    if keys.attacker == self:GetParent() then
        if RollPseudoRandomPercentage(self:GetAbility():GetSpecialValueFor('chance'),99,self:GetParent()) then
            self:GetParent():AddNewModifier(self:GetParent(), self:GetAbility(), "item_mjolnir_modifier_tinkerer", {
                starting_unit_entindex = keys.target:entindex(),self_casted = 0
            })
        end
    end
end
item_mjolnir_modifier_tinkerer = class({
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    RemoveOnDeath = function (self) return false end,
    IsPurgable = function (self) return false end,
    IsHidden = function (self) return true end,
})
function item_mjolnir_modifier_tinkerer:OnCreated(keys)
	if not IsServer() or not self:GetAbility() then return end
    print(keys.self_casted)
    if keys.self_casted == 0 then
        self.arc_damage			= self:GetAbility():GetSpecialValueFor('arc_damage') + self:GetParent():GetDamageMax() * self:GetAbility():GetSpecialValueFor('bonus_damage_per_base_damage') / 100
        self.radius				= self:GetAbility():GetSpecialValueFor('radius')
        self.jump_count			= self:GetAbility():GetSpecialValueFor('jump_count')
    else
        self.arc_damage			= self:GetAbility():GetSpecialValueFor('active_arc_damage') + self:GetParent():GetDamageMax() * self:GetAbility():GetSpecialValueFor('active_damage_per_base_damage') / 100
	    self.radius				= self:GetAbility():GetSpecialValueFor('active_radius')
	    self.jump_count			= self:GetAbility():GetSpecialValueFor('active_jump_count')
    end

	self.jump_delay			= 0.15

	self.starting_unit_entindex	= keys.starting_unit_entindex

	self.units_affected			= {}

	if self.starting_unit_entindex and EntIndexToHScript(self.starting_unit_entindex) then
		self.current_unit						= EntIndexToHScript(self.starting_unit_entindex)
		self.units_affected[self.current_unit]	= 1
    
		self.lightning_particle = ParticleManager:CreateParticle("particles/units/heroes/hero_zuus/zuus_arc_lightning_.vpcf", PATTACH_ABSORIGIN_FOLLOW, self.current_unit)
			ParticleManager:SetParticleControlEnt(self.lightning_particle, 0, self.current_unit, PATTACH_POINT_FOLLOW, "attach_hitloc", self.current_unit:GetAbsOrigin(), true)
			ParticleManager:SetParticleControlEnt(self.lightning_particle, 1, self.current_unit, PATTACH_POINT_FOLLOW, "attach_hitloc", self.current_unit:GetAbsOrigin(), true)
			ParticleManager:SetParticleControl(self.lightning_particle, 62, Vector(2, 0, 2))
			ParticleManager:ReleaseParticleIndex(self.lightning_particle)
    
		ApplyDamage({
			victim 			= self.current_unit,
			damage 			= self.arc_damage,
			damage_type		= DAMAGE_TYPE_MAGICAL,
			damage_flags 	= DOTA_DAMAGE_FLAG_NONE,
			attacker 		= self:GetCaster(),
			ability 		= self:GetAbility()
		})
	else
		self:Destroy()
		return
	end
	
	self.unit_counter			= 0
	
	self:StartIntervalThink(self.jump_delay)
end
function item_mjolnir_modifier_tinkerer:OnIntervalThink()
	self.zapped = false
	
	for _, enemy in pairs(FindUnitsInRadius(
            self:GetCaster():GetTeamNumber(),
            self.current_unit:GetAbsOrigin(),
            nil,
            self.radius,
            DOTA_UNIT_TARGET_TEAM_ENEMY,
            DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS,
            FIND_CLOSEST,
            false)) do
		if not self.units_affected[enemy] then
			enemy:EmitSound("Hero_Zuus.ArcLightning.Target")
			
			self.lightning_particle = ParticleManager:CreateParticle("particles/units/heroes/hero_zuus/zuus_arc_lightning_.vpcf", PATTACH_ABSORIGIN_FOLLOW, self.current_unit)
			ParticleManager:SetParticleControlEnt(self.lightning_particle, 0, self.current_unit, PATTACH_POINT_FOLLOW, "attach_hitloc", self.current_unit:GetAbsOrigin(), true)
			ParticleManager:SetParticleControlEnt(self.lightning_particle, 1, enemy, PATTACH_POINT_FOLLOW, "attach_hitloc", enemy:GetAbsOrigin(), true)
			ParticleManager:SetParticleControl(self.lightning_particle, 62, Vector(2, 0, 2))
			ParticleManager:ReleaseParticleIndex(self.lightning_particle)
		
			self.unit_counter						= self.unit_counter + 1
			self.current_unit						= enemy
			self.units_affected[enemy]	            = 1

			self.zapped								= true
			
			ApplyDamage({
				victim 			= enemy,
				damage 			= self.arc_damage,
				damage_type		= DAMAGE_TYPE_MAGICAL,
				damage_flags 	= DOTA_DAMAGE_FLAG_NONE,
				attacker 		= self:GetCaster(),
				ability 		= self:GetAbility()
			})
			
			break
		end
	end
        
		if self.unit_counter >= self.jump_count or not self.zapped then
			self:StartIntervalThink(-1)
			self:Destroy()
	    end
end