BaseClass = class({})

-- Сгенерировано: ресурсы, на которые ссылается этот скрипт.
-- Движок зовёт этот метод при прекеше юнита со способностью, поэтому
-- партиклы приезжают вместе с героем (пик/репик), а не на старте карты.
function BaseClass:Precache(context)
	PrecacheResource("model", "models/props_structures/rock_golem/tower_radiant_rock_golem.vmdl", context)
	PrecacheResource("particle", "particles/econ/world/towers/ti10_radiant_tower/ti10_radiant_tower_destruction_debris.vpcf", context)
	PrecacheResource("particle", "particles/econ/world/towers/ti10_radiant_tower/ti10_radiant_tower_destruction_sparkle.vpcf", context)
end

guardian_of_the_ancients_command_height = BaseClass
guardian_of_the_ancients_command_height_stop = class({})
LinkLuaModifier( "modifier_guardian_of_the_ancients_command_height", "heroes/guardian_of_the_ancients/command_height", LUA_MODIFIER_MOTION_NONE)

function BaseClass:OnSpellStart()
    if not self:GetCaster():FindAbilityByName( "guardian_of_the_ancients_command_height_stop" ) then
		local ability = self:GetCaster():AddAbility( "guardian_of_the_ancients_command_height_stop" )
		ability:SetLevel( 1 )
        ability:StartCooldown(1)
	end
    self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_guardian_of_the_ancients_command_height", {duration = self:GetSpecialValueFor("duration")})
    --self:GetCaster():FindAbilityByName("guardian_of_the_ancients_command_height_stop"):SetLevel(1)
end


modifier_guardian_of_the_ancients_command_height = class({
    IsHidden = function(self) return true end,
    IsDebuff = function(self) return false end,
    IsPurgable = function(self) return false end,
    CheckState = function(self) 
        if self:GetAbility():GetSpecialValueFor('invul') == 1 then
            return{
                [MODIFIER_STATE_MAGIC_IMMUNE] = true,
            }
        end 
    end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE,
        MODIFIER_PROPERTY_ATTACK_RANGE_BONUS,
        MODIFIER_PROPERTY_MODEL_CHANGE,
        MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
        MODIFIER_PROPERTY_BASEDAMAGEOUTGOING_PERCENTAGE,
        MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
        MODIFIER_EVENT_ON_ATTACK_START,
    } end,
    -- у модели башни свои активности: в покое TOWER_IDLE, замах - TOWER_ATTACK
    -- (обычные ACT_DOTA_ATTACK у неё нет, поэтому замаха не было)
    GetOverrideAnimation = function (self) return ACT_DOTA_CUSTOM_TOWER_IDLE end,
    OnAttackStart = function (self, params)
        if not IsServer() or params.attacker ~= self:GetParent() then return end
        local parent = self:GetParent()
        parent:RemoveGesture(ACT_DOTA_CUSTOM_TOWER_ATTACK)
        parent:StartGestureWithPlaybackRate(ACT_DOTA_CUSTOM_TOWER_ATTACK, math.max(1, 1 / math.max(0.1, parent:GetSecondsPerAttack(false))))
    end,
    GetModifierBaseDamageOutgoing_Percentage = function (self) return self:GetAbility():GetSpecialValueFor('bonus_damage_pct') end,
    GetModifierMoveSpeed_Absolute = function (self) return self:GetAbility():GetSpecialValueFor('ms') end,
    GetModifierAttackRangeBonus = function (self) return self:GetAbility():GetSpecialValueFor('attack_range') end,
    GetModifierModelChange = function (self) return "models/props_structures/rock_golem/tower_radiant_rock_golem.vmdl" end,
    GetModifierIncomingDamage_Percentage = function (self)
        if self:GetAbility():GetSpecialValueFor('invul') == 1 then
            return self:GetAbility():GetSpecialValueFor('damage_reduction') 
        end 
    end,
})
function modifier_guardian_of_the_ancients_command_height:OnCreated()
    if not IsServer() then return end
    self:GetParent():SetAttackCapability(DOTA_UNIT_CAP_RANGED_ATTACK)
    self:PlayEffects()
    self:GetParent():SwapAbilities( "guardian_of_the_ancients_command_height", "guardian_of_the_ancients_command_height_stop", false, true )

end
function modifier_guardian_of_the_ancients_command_height:OnDestroy()
    if not IsServer() then return end
    self:GetParent():SetAttackCapability(DOTA_UNIT_CAP_MELEE_ATTACK)
    self:PlayEffects()
    self:GetParent():SwapAbilities( "guardian_of_the_ancients_command_height", "guardian_of_the_ancients_command_height_stop", true, false )
end
function modifier_guardian_of_the_ancients_command_height:PlayEffects()
    local hParent = self:GetParent()

    local sParticle2 = 'particles/econ/world/towers/ti10_radiant_tower/ti10_radiant_tower_destruction_debris.vpcf'
    self.nParticle2 = ParticleManager:CreateParticle( sParticle2, PATTACH_CUSTOMORIGIN, hParent )
    ParticleManager:SetParticleControlEnt( self.nParticle2, 0, hParent, PATTACH_POINT_FOLLOW, 'attach_hitloc', hParent:GetOrigin(), false )
    ParticleManager:SetParticleControl( self.nParticle2, 15, Vector( 110, 181, 203 ) )
    ParticleManager:ReleaseParticleIndex( self.nParticle2 )

    local sParticle1 = 'particles/econ/world/towers/ti10_radiant_tower/ti10_radiant_tower_destruction_sparkle.vpcf'
    self.nParticle1 = ParticleManager:CreateParticle( sParticle1, PATTACH_CUSTOMORIGIN, hParent )
    ParticleManager:SetParticleControlEnt( self.nParticle1, 0, hParent, PATTACH_POINT_FOLLOW, 'attach_hitloc', hParent:GetOrigin(), false )
    ParticleManager:SetParticleControl( self.nParticle1, 15, Vector( 110, 181, 203 ) )
    -- PlayEffects зовётся и на OnCreated, и на OnDestroy, то есть по два
    -- индекса за каждое включение способности, и ни один не освобождался
    ParticleManager:ReleaseParticleIndex( self.nParticle1 )
end

function guardian_of_the_ancients_command_height_stop:OnSpellStart()
	local mod = self:GetCaster():FindModifierByName( "modifier_guardian_of_the_ancients_command_height" )
	if not mod then return end
	mod:Destroy()
end
