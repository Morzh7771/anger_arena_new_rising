modifier_ability_shrine_restore_effect = class({})

--------------------------------------------------------------------------------
function modifier_ability_shrine_restore_effect:IsHidden()
    return false
end

--------------------------------------------------------------------------------
function modifier_ability_shrine_restore_effect:IsDebuff()
    return false
end

--------------------------------------------------------------------------------
function modifier_ability_shrine_restore_effect:OnCreated(kv)
    self.health_regen_const = self:GetAbility():GetSpecialValueFor("health_regen_const")
    self.mana_regen_const = self:GetAbility():GetSpecialValueFor("mana_regen_const")
    self.health_regen_pct = self:GetAbility():GetSpecialValueFor("health_regen_pct")
    self.mana_regen_pct = self:GetAbility():GetSpecialValueFor("mana_regen_pct")
end

--------------------------------------------------------------------------------
function modifier_ability_shrine_restore_effect:OnRefresh(kv)
    self.health_regen_const = self:GetAbility():GetSpecialValueFor("health_regen_const")
    self.mana_regen_const = self:GetAbility():GetSpecialValueFor("mana_regen_const")
    self.health_regen_pct = self:GetAbility():GetSpecialValueFor("health_regen_pct")
    self.mana_regen_pct = self:GetAbility():GetSpecialValueFor("mana_regen_pct")
end

function modifier_ability_shrine_restore_effect:DeclareFunctions()
    local funcs = {
        MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
        MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE,
        MODIFIER_PROPERTY_MANA_REGEN_TOTAL_PERCENTAGE,
        MODIFIER_EVENT_ON_ATTACKED,
    }
    return funcs
end

function modifier_ability_shrine_restore_effect:OnAttacked(params)
    if params.target == self:GetParent() then  
		self:GetParent():AddNewModifier(self:GetParent(),self:GetAbility(),"modifier_ability_shrine_restore_effect_toggle_off",{duration = 5})
	end
end

--------------------------------------------------------------------------------
function modifier_ability_shrine_restore_effect:GetModifierConstantHealthRegen(params)
    if not self:GetParent():HasModifier('modifier_ability_shrine_restore_effect_toggle_off') then 
        return self.health_regen_const
    end
end

--------------------------------------------------------------------------------
function modifier_ability_shrine_restore_effect:GetModifierConstantManaRegen(params)
    if not self:GetParent():HasModifier('modifier_ability_shrine_restore_effect_toggle_off') then 
        return self.mana_regen_const
    end
end

--------------------------------------------------------------------------------
function modifier_ability_shrine_restore_effect:GetModifierHealthRegenPercentage(params)
    if not self:GetParent():HasModifier('modifier_ability_shrine_restore_effect_toggle_off') then 
        return self.health_regen_pct
    end
end

--------------------------------------------------------------------------------
function modifier_ability_shrine_restore_effect:GetModifierTotalPercentageManaRegen(params)
    if not self:GetParent():HasModifier('modifier_ability_shrine_restore_effect_toggle_off') then  
        return self.mana_regen_pct
    end
end

--------------------------------------------------------------------------------
modifier_ability_shrine_restore_effect_toggle_off = class({
    isHidden = function (self) return false end,
    isDebuff = function (self) return false end,
    isPurgable = function (self) return false end,
})
