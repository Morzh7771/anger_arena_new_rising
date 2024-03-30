--function StrangeAmuletStart( event )
--	local caster = event.caster
--	local ability = event.ability
--	local radius = event.Radius
--	local charges = caster:GetStrength() 
--	local duration = event.Duration
--	ability:SetCurrentCharges(ability:GetCurrentCharges() + 1)
--	if ability:GetCurrentCharges() == 0 then return end
--	
--	while(caster:HasModifier("modifier_strange_amulet_activate_str")) do
--		caster:RemoveModifierByName("modifier_strange_amulet_activate_str")
--	end
--	
--	ability:ApplyDataDrivenModifier(caster, caster, "modifier_strange_amulet_activate_str", { duration = duration })	
--	caster:SetModifierStackCount("modifier_strange_amulet_activate_str", ability, charges)
--	caster:CalculateStatBonus(true)
--end
--
--function CheckCharges(event)
--	local caster = event.caster
--	local ability = event.ability
--	local charges = ability:GetCurrentCharges()
--	if charges == 0 then 
--		caster:RemoveModifierByName("modifier_strange_amulet_bonus")
--		return
--	end
--	if not caster:HasModifier("modifier_strange_amulet_bonus") then
--		ability:ApplyDataDrivenModifier(caster, caster, "modifier_strange_amulet_bonus", {})
--	end
--	caster:SetModifierStackCount("modifier_strange_amulet_bonus", ability, charges)
--	caster:CalculateStatBonus(true)	
--end












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
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
        MODIFIER_PROPERTY_BASEDAMAGEOUTGOING_PERCENTAGE,
        MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
    } end,
    OnCreated = function (self,kv)
        self.ef_hp = 0
        self.def = 0
        self.hand_damage = 0
        self.spell_amp = 0
        self.all_damage_def_per_charge = self:GetAbility():GetSpecialValueFor("all_damage_def_per_charge") / 100
        self.hand_damage_per_charge = self:GetAbility():GetSpecialValueFor("hand_damage_per_charge")
        self.spell_amp_pre_charge = self:GetAbility():GetSpecialValueFor("spell_amp_pre_charge")
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
        end
        --Agility Mode
        if self:GetAbility():GetSecondaryCharges() == 2 then
            self.hand_damage = self:GetAbility():GetCurrentCharges() *  self.hand_damage_per_charge
        end
        --Intellect Mode
        if self:GetAbility():GetSecondaryCharges() == 3 then
            self.spell_amp = self:GetAbility():GetCurrentCharges() * self.spell_amp_pre_charge
        end
        --Univ Mode
        if self:GetAbility():GetSecondaryCharges() == 4 then
        end
        print(self.item_stats)
	end,
	GetModifierBonusStats_Strength = function (self)
		if self.mode == 1 then
    	    return self.primary_attribute_pct + self.item_stats
    	elseif self.mode == 4 then
    	    return self.item_stats + self.primary_attribute_pct / 3
            else return self.item_stats
    	   end
	end,
	GetModifierBonusStats_Agility = function (self)
		if self.mode == 2  then
    	    return self.primary_attribute_pct + self.item_stats
    	elseif self.mode == 4 then
    	    return self.item_stats + self.primary_attribute_pct / 3
            else return self.item_stats
    	end
	end,
	GetModifierBonusStats_Intellect = function (self)
		if self.mode == 3  then
    	    return self.primary_attribute_pct + self.item_stats
    	elseif self.mode == 4 then
    	    return self.item_stats + self.primary_attribute_pct / 3 
        else return self.item_stats
    	end
	end,
    GetModifierIncomingDamage_Percentage = function (self)
        if self:GetAbility():GetSecondaryCharges() == 1 then
            return self.def
            elseif self:GetAbility():GetSecondaryCharges() == 4 then
                return self.def / 3 
            end
    end,  
    GetModifierBaseDamageOutgoing_Percentage = function (self)
        if self:GetAbility():GetSecondaryCharges() == 2 then
            return self.hand_damage
            elseif self:GetAbility():GetSecondaryCharges() == 4 then 
                return self.hand_damage / 3 
            end 

    end,
    GetModifierSpellAmplify_Percentage = function (self)
        if self:GetAbility():GetSecondaryCharges() == 3 then
            return self.spell_amp 
            elseif self:GetAbility():GetSecondaryCharges() == 4 then 
                return self.spell_amp / 3 
            end 
    end,
})