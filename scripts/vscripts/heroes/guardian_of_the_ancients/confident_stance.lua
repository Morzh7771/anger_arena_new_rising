local DMG
BaseClass = class ({
    ResetToggleOnRespawn = function(self) return true end,
    IsHiddenWhenStolen = function(self) return false end,
    IsRefreshable = function(self) return true end,
    IsNetherWardStealable = function(self) return false end,
})
guardian_of_the_ancients_confident_stance = BaseClass
LinkLuaModifier( "guardian_of_the_ancients_confident_stance_on", "heroes/guardian_of_the_ancients/confident_stance", LUA_MODIFIER_MOTION_NONE)    

function BaseClass:OnToggle()
    if not IsServer() then return end
	self:StartCooldown(2)
	local caster = self:GetCaster()
	caster:EmitSound("Hero_TrollWarlord.BerserkersRage.Toggle")
	if self:GetToggleState() then
		caster:AddNewModifier(caster, self, "guardian_of_the_ancients_confident_stance_on", {})
        
	else
		caster:RemoveModifierByName("guardian_of_the_ancients_confident_stance_on")
	end
end

guardian_of_the_ancients_confident_stance_on = class({
    IsHidden = function(self) return false end,
    DeclareFunctions = function(self)return {
		MODIFIER_PROPERTY_FIXED_ATTACK_RATE,
		MODIFIER_PROPERTY_BASEATTACK_BONUSDAMAGE,
        MODIFIER_PROPERTY_BASEDAMAGEOUTGOING_PERCENTAGE,
	}end,
    GetModifierFixedAttackRate = function(self) 
        if self:GetAbility():GetSpecialValueFor("atack_rate") ~= 0 and self:GetParent():HasModifier("modifier_guardian_of_the_ancients_command_height") then
            return  self:GetAbility():GetSpecialValueFor("atack_rate_ult") 
        else
            return  self:GetAbility():GetSpecialValueFor("atack_rate_base")
        end
    end,
    GetModifierBaseAttack_BonusDamage = function(self) return self:GetAbility():GetSpecialValueFor('damage_const_bonus') * (self:GetParent():GetIncreasedAttackSpeed()*100) end,
    GetHeroEffectName = function (self) return "particles/units/heroes/hero_sven/sven_gods_strength_hero_effect.vpcf" end,
    GetStatusEffectName = function (self) return "particles/status_fx/status_effect_gods_strength.vpcf" end,
})
function guardian_of_the_ancients_confident_stance_on:OnCreated()
    if IsServer() then
		local nFXIndex = ParticleManager:CreateParticle( "particles/units/heroes/hero_sven/sven_spell_gods_strength_ambient.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent() )
		ParticleManager:SetParticleControlEnt( nFXIndex, 0, self:GetParent(), PATTACH_POINT_FOLLOW, "attach_weapon" , self:GetParent():GetOrigin(), true )
		ParticleManager:SetParticleControlEnt( nFXIndex, 2, self:GetParent(), PATTACH_POINT_FOLLOW, "attach_head" , self:GetParent():GetOrigin(), true )
		self:AddParticle( nFXIndex, false, false, -1, false, true )
	end
end
function guardian_of_the_ancients_confident_stance_on:GetModifierBaseDamageOutgoing_Percentage() 
    if self:GetAbility():GetSpecialValueFor('damage_amp_bonus') > 0 then
        local attackspeed = math.floor(self:GetParent():GetIncreasedAttackSpeed() * 100)
        local pct = self:GetAbility():GetSpecialValueFor('damage_amp_bonus') / 100
        local total = (attackspeed * pct) * 100
        return math.max(total,0)
    end
end
