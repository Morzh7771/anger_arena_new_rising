BaseClass = class({})
guardian_of_the_ancients_command_height = BaseClass

LinkLuaModifier( "modifier_guardian_of_the_ancients_command_height", "heroes/guardian_of_the_ancients/command_height", LUA_MODIFIER_MOTION_NONE)

function BaseClass:OnSpellStart()
    print(self:GetSpecialValueFor('invul'))
    self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_guardian_of_the_ancients_command_height", {duration = self:GetSpecialValueFor("duration")})

    
end


modifier_guardian_of_the_ancients_command_height = class({
    IsHidden = function(self) return true end,
    IsDebuff = function(self) return false end,
    IsPurgable = function(self) return false end,
    CheckState = function(self) 
        if self:GetAbility():GetSpecialValueFor('invul') == 1 then
            return{
                [MODIFIER_STATE_MAGIC_IMMUNE] = true,
                [MODIFIER_STATE_INVULNERABLE] = false,
                [MODIFIER_STATE_OUT_OF_GAME] = false,
                [MODIFIER_STATE_NO_HEALTH_BAR] = false,
            }
        end 
    end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE,
        MODIFIER_PROPERTY_ATTACK_RANGE_BONUS,
        MODIFIER_PROPERTY_MODEL_CHANGE,
        MODIFIER_PROPERTY_INCOMING_PHYSICAL_DAMAGE_PERCENTAGE,
    } end,
    GetModifierMoveSpeed_Absolute = function (self) return self:GetAbility():GetSpecialValueFor('ms') end,
    GetModifierAttackRangeBonus = function (self) return self:GetAbility():GetSpecialValueFor('attack_range') end,
    GetModifierModelChange = function (self) return "models/props_structures/tower_good.vmdl" end,
    GetModifierIncomingPhysicalDamage_Percentage = function (self) return self:GetAbility():GetSpecialValueFor('damage_reduction') end,
    
})
function modifier_guardian_of_the_ancients_command_height:OnCreated()
    self:GetParent():SetAttackCapability(DOTA_UNIT_CAP_RANGED_ATTACK)
    local hParent = self:GetParent()
    local sParticle2 = 'particles/econ/world/towers/ti10_radiant_tower/ti10_radiant_tower_destruction_debris.vpcf'
    self.nParticle2 = ParticleManager:CreateParticle( sParticle2, PATTACH_CUSTOMORIGIN, hParent )
    ParticleManager:SetParticleControlEnt( self.nParticle2, 0, hParent, PATTACH_POINT_FOLLOW, 'attach_hitloc', hParent:GetOrigin(), false )
    ParticleManager:SetParticleControl( self.nParticle2, 15, Vector( 110, 181, 203 ) )
    local sParticle1 = 'particles/econ/world/towers/ti10_radiant_tower/ti10_radiant_tower_destruction_sparkle.vpcf'
    self.nParticle1 = ParticleManager:CreateParticle( sParticle1, PATTACH_CUSTOMORIGIN, hParent )
    ParticleManager:SetParticleControlEnt( self.nParticle1, 0, hParent, PATTACH_POINT_FOLLOW, 'attach_hitloc', hParent:GetOrigin(), false )
    ParticleManager:SetParticleControl( self.nParticle1, 15, Vector( 110, 181, 203 ) )
end
function modifier_guardian_of_the_ancients_command_height:OnDestroy()
    self:GetParent():SetAttackCapability(DOTA_UNIT_CAP_MELEE_ATTACK)
    local hParent = self:GetParent()
    local sParticle2 = 'particles/econ/world/towers/ti10_radiant_tower/ti10_radiant_tower_destruction_debris.vpcf'
    self.nParticle2 = ParticleManager:CreateParticle( sParticle2, PATTACH_CUSTOMORIGIN, hParent )
    ParticleManager:SetParticleControlEnt( self.nParticle2, 0, hParent, PATTACH_POINT_FOLLOW, 'attach_hitloc', hParent:GetOrigin(), false )
    ParticleManager:SetParticleControl( self.nParticle2, 15, Vector( 110, 181, 203 ) )
    local sParticle1 = 'particles/econ/world/towers/ti10_radiant_tower/ti10_radiant_tower_destruction_sparkle.vpcf'
    self.nParticle1 = ParticleManager:CreateParticle( sParticle1, PATTACH_CUSTOMORIGIN, hParent )
    ParticleManager:SetParticleControlEnt( self.nParticle1, 0, hParent, PATTACH_POINT_FOLLOW, 'attach_hitloc', hParent:GetOrigin(), false )
    ParticleManager:SetParticleControl( self.nParticle1, 15, Vector( 110, 181, 203 ) )

end