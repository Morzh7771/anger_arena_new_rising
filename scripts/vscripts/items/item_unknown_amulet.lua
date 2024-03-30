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
        if not IsServer() then return end
        self:GetCaster():RemoveAllModifiersByName("modifier_item_unknown_amulet_abilites")
        if self:GetSecondaryCharges() > 3 then
            self:SetSecondaryCharges(1)
        else self:SetSecondaryCharges(self:GetSecondaryCharges() + 1)
        end
        self:GetCaster():AddNewModifier(self:GetCaster(), self:GetCaster(), "modifier_item_unknown_amulet_abilites",{})
        print(self:GetSecondaryCharges())
    end,
})

modifier_item_unknown_amulet_abilites = class({
    IsHidden = function() return false end,
    IsPurgable = function() return false end,
    DestroyOnExpire = function() return false end,
    DeclareFunctions = function(self) return {
       MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
    } end,
    OnCreated = function (self)
        if not IsServer() then return end
        self.charges = self:GetAbility():GetSecondaryCharges()
        self.ef_hp = 0
        self:StartIntervalThink(0.3)
    end,
    GetModifierIncomingDamage_Percentage = function (self)
        if self.charges == 1 then
            return -100
        else
            return 0 
        end
    end,

    OnDestroy = function (self)
        print("Destroy")
    end,
    --OnIntervalThink = function (self)
    --    if self:GetParent():GetSecondaryCharges() == 0 then
    --        self.ef_hp = (self:GetParent():GetCurrentCharges() * 0.1 * self:GetParent():GetMaxHealth()) + self:GetParent():GetMaxHealth()
    --    end
    --    print(self.ef_hp)
    --end,
})

modifier_item_unknown_amulet_stats = class({
	IsPassive = function() return false end,
    IsHidden = function() return true end,
    IsPurgable = function() return false end,
    DestroyOnExpire = function() return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function(self) return {
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
    } end,
    OnCreated = function (self)
    	if not IsServer() then return end
    	self:StartIntervalThink(0.3)
	end,
	OnIntervalThink = function (self)
		if not IsServer() then return end
		self.primary_attribute_pct = self:GetAbility():GetSpecialValueFor("charge_primary_attribute") * self:GetAbility():GetCurrentCharges()
        self.mode = self:GetAbility():GetSecondaryCharges()
    	self:GetParent():CalculateStatBonus(true)
	end,
	GetModifierBonusStats_Strength = function (self)
		if self.mode == 1 then
    	    return self.primary_attribute_pct
    	elseif self.mode == 4 then
    	    return self.primary_attribute_pct / 3
    	end
	end,
	GetModifierBonusStats_Agility = function (self)
		if self.mode == 2  then
    	    return self.primary_attribute_pct
    	elseif self.mode == 4 then
    	    return self.primary_attribute_pct / 3
    	end
	end,
	GetModifierBonusStats_Intellect = function (self)
		if self.mode == 3  then
    	    return self.primary_attribute_pct
    	elseif self.mode == 4 then
    	    return self.primary_attribute_pct / 3 
    	end
	end,
})