LinkLuaModifier("modifier_item_unknown_amulet_stats", "items/item_unknown_amulet.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_unknown_amulet_abilites", "items/item_unknown_amulet.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_unknown_amulet_disarmor", "items/item_unknown_amulet.lua", LUA_MODIFIER_MOTION_NONE)

item_unknown_amulet = class({
	GetIntrinsicModifierName = function (self) return "modifier_item_unknown_amulet_stats" end,
	OnSpellStart = function (self)
        if self:GetSecondaryCharges() > 3 then
            self:SetSecondaryCharges(1)
        else self:SetSecondaryCharges(self:GetSecondaryCharges() + 1)
        end
        print(self:GetSecondaryCharges())
    end,
    GetAbilityTextureName = function (self)
        if self:GetSecondaryCharges() == 0 then
            return "unknown_amulet4"
        else
            return "unknown_amulet" .. (self:GetSecondaryCharges())
        end
    end,
    OnDestroy =  function (self)
        self:RemoveAllModifiersByName("modifier_item_unknown_amulet_abilites")
    end,
})

modifier_item_unknown_amulet_stats = class({
	IsPassive = function() return false end,
    IsHidden = function() return false end,
    IsPurgable = function() return false end,
    DestroyOnExpire = function() return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_PERMANENT end,
    DeclareFunctions = function(self) return {
        --MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE,
        --MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE,
        MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
        MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
        MODIFIER_PROPERTY_BASEATTACK_BONUSDAMAGE,
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
        MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
        MODIFIER_PROPERTY_TOOLTIP,
    } end,
    OnTooltip = function(self) return self.def end,
    GetAbilityTextureName = function (self) return "unknown_amulet4" end,
    OnCreated = function (self,kv)
        self.ef_hp = 0
        self.def = 0
        self.all_damage_def_per_charge = self:GetAbility():GetSpecialValueFor("all_damage_def_per_charge") / 100
        self.hand_damage_per_charge = self:GetAbility():GetSpecialValueFor("hand_damage_per_charge")
        self.spell_amp_pre_charge = self:GetAbility():GetSpecialValueFor("spell_amp_pre_charge")
        self.stat_damage =  self:GetAbility():GetSpecialValueFor("stat_damage") / 100
    	self:StartIntervalThink(0.3)
	end,
	OnIntervalThink = function (self)
        self.item_stats = self:GetAbility():GetSpecialValueFor("stats")
		self.primary_attribute_pct = self:GetAbility():GetSpecialValueFor("charge_primary_attribute") * self:GetAbility():GetCurrentCharges()
        self.mode = self:GetAbility():GetSecondaryCharges()
    	self:GetParent():CalculateStatBonus(true)
	end,

	GetModifierBonusStats_Strength = function (self)
		if self.mode == 1 then
    	    return self.primary_attribute_pct + self.item_stats
    	    elseif self.mode == 4 then
    	    return self.item_stats + self.primary_attribute_pct / 3
            else 
                return self.item_stats
    	   end
	end,
	GetModifierBonusStats_Agility = function (self)
		if self.mode == 2  then
    	    return self.primary_attribute_pct + self.item_stats
    	    elseif self.mode == 4 then
    	        return self.item_stats + self.primary_attribute_pct / 3
            else   
                return self.item_stats
    	end
	end,
	GetModifierBonusStats_Intellect = function (self)
		if self.mode == 3  then
    	    return self.primary_attribute_pct + self.item_stats
    	elseif self.mode == 4 then
    	    return self.item_stats + self.primary_attribute_pct / 3
        else 
            return self.item_stats
    	end
	end,
    GetModifierIncomingDamage_Percentage = function (self)
        if self:GetAbility():GetSecondaryCharges() == 1 then
            self.ef_hp = (self:GetAbility():GetCurrentCharges() * self.all_damage_def_per_charge * self:GetParent():GetMaxHealth()) + self:GetParent():GetMaxHealth()
            self.def = ((self:GetParent():GetMaxHealth() / self.ef_hp) - 1) * 100
            return self.def
        end
    end,  
    OnAttackLanded = function (self, kv)
        if self:GetAbility():GetSecondaryCharges() == 2 then
        if self:GetParent() ~= kv.attacker then return end
        local polus = 1
        local charge_disarmor_const = self:GetAbility():GetSpecialValueFor("charge_disarmor_const") * self:GetAbility():GetCurrentCharges()
        local charge_disarmor =  ((100 - self:GetAbility():GetSpecialValueFor("charge_disarmor"))/100)^self:GetAbility():GetCurrentCharges()
        local target_ef_hp =  kv.target:GetPhysicalArmorValue(false) * 0.06 * kv.target:GetMaxHealth()
        local working = target_ef_hp * charge_disarmor
        local magatron  = (working/kv.target:GetMaxHealth())*(50/3)
        local final = (kv.target:GetPhysicalArmorValue(false) - magatron) + charge_disarmor_const
        if kv.target:GetPhysicalArmorValue(false) < 0 then 
            polus = -1
        end
            if kv.target:HasModifier("modifier_item_unknown_amulet_disarmor") then 
                local modifier = kv.target:FindModifierByName("modifier_item_unknown_amulet_disarmor")
                modifier:ForceRefresh() 
            else  
                kv.target:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_item_unknown_amulet_disarmor", {duration = self:GetAbility():GetSpecialValueFor("duration")})
                kv.target:SetModifierStackCount("modifier_item_unknown_amulet_disarmor",kv.attacker,final*polus)
               end
        end
    end,
    GetModifierSpellAmplify_Percentage = function (self)
        if self:GetAbility():GetSecondaryCharges() == 3 then
            return self:GetAbility():GetCurrentCharges() * self.spell_amp_pre_charge
         end 
    end,
    GetModifierBaseAttack_BonusDamage = function (self)
        if self:GetAbility():GetSecondaryCharges() == 4 then
            return (self:GetParent():GetStrength() + self:GetParent():GetAgility() + self:GetParent():GetIntellect()) * self.stat_damage * self:GetAbility():GetCurrentCharges()
        end
    end,
})

modifier_item_unknown_amulet_disarmor = class({ 
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return true end,
    DestroyOnExpire = function (self) return true end,
    GetAttributes = function (self) return  MODIFIER_ATTRIBUTE_PERMANENT end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
    }end,
    GetModifierPhysicalArmorBonus = function (self) return -self:GetStackCount() end,
})