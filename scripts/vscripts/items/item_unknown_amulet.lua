LinkLuaModifier("modifier_item_unknown_amulet_stats", "items/item_unknown_amulet.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_unknown_amulet_abilites", "items/item_unknown_amulet.lua", LUA_MODIFIER_MOTION_NONE)

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
        MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
        MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE,
        MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
        MODIFIER_PROPERTY_BASEATTACK_BONUSDAMAGE,
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
        MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
    } end,
    OnCreated = function (self,kv)
        self.ef_hp = 0
        self.def = 0
        self.hand_damage = 0
        self.spell_amp = 0
        self.base_damage = 0
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
        --Strength Mode
        if self:GetAbility():GetSecondaryCharges() == 1 then
            self.ef_hp = (self:GetAbility():GetCurrentCharges() * self.all_damage_def_per_charge * self:GetParent():GetMaxHealth()) + self:GetParent():GetMaxHealth()
            self.def = ((self:GetParent():GetMaxHealth() / self.ef_hp) - 1) * 100
            print(self.def)
        end
        --Agility Mode
        if self:GetAbility():GetSecondaryCharges() == 2 then
            self.hand_damage = self:GetAbility():GetCurrentCharges() *  self.hand_damage_per_charge
            print(self.hand_damage)
        end
        --Intellect Mode
        if self:GetAbility():GetSecondaryCharges() == 3 then
            self.spell_amp = self:GetAbility():GetCurrentCharges() * self.spell_amp_pre_charge
            print(self.spell_amp)
        end
        --Univ Mode
        if self:GetAbility():GetSecondaryCharges() == 4 then
            self.base_damage = (self:GetParent():GetStrength() + self:GetParent():GetAgility() + self:GetParent():GetIntellect()) * self.stat_damage * self:GetAbility():GetCurrentCharges()
            print(self.base_damage)
        end
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
            return self.def
        end
    end,  
    GetModifierDamageOutgoing_Percentage = function (self)
        if self:GetAbility():GetSecondaryCharges() == 2 then
            return self.hand_damage
        end 

    end,
    GetModifierSpellAmplify_Percentage = function (self)
        if self:GetAbility():GetSecondaryCharges() == 3 then
            return self.spell_amp 
         end 
    end,
    GetModifierBaseAttack_BonusDamage = function (self)
        if self:GetAbility():GetSecondaryCharges() == 4 then
            return self.base_damage
        end
    end,
})