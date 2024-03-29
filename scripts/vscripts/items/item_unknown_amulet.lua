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












LinkLuaModifier("modifier_item_unknown_amulet", "items/item_unknown_amulet.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_unknown_amulet_active", "items/item_unknown_amulet.lua", LUA_MODIFIER_MOTION_NONE)

item_unknown_amulet = class({
	GetIntrinsicModifierName = function (self) return "modifier_item_unknown_amulet" end,
	 OnChargeCountChanged = function (self)
	 	if self:GetCurrentCharges() == 0 then self:GetCaster():RemoveModifierByName("modifier_item_unknown_amulet") return end
	 	if not self:GetCaster():HasModifier("modifier_item_unknown_amulet") then self:AddNewModifier(self:GetCaster(), self:GetCaster(), "modifier_item_unknown_amulet", {}) end
	 	self:GetCaster():SetModifierStackCount("modifier_item_unknown_amulet", self, self:GetCurrentCharges())
	 	self:GetCaster():CalculateStatBonus(true)
    	print(self:GetCurrentCharges())
    end,
})

modifier_item_unknown_amulet_active = class({})

modifier_item_unknown_amulet = class({
	IsPassive = function() return false end,
    IsHidden = function() return false end,
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
    	self.str_bonus = self.primary_attribute_pct
    	self.agi_bonus = self.primary_attribute_pct
    	self.int_bonus = self.primary_attribute_pct
    	self:GetParent():CalculateStatBonus(true)
	end,
	GetModifierBonusStats_Strength = function (self)
		if self:GetParent():GetPrimaryAttribute() == DOTA_ATTRIBUTE_STRENGTH then
    	    return self.str_bonus
    	elseif self:GetParent():GetPrimaryAttribute() == DOTA_ATTRIBUTE_ALL then
    	    return self.str_bonus / 3
    	end
	end,
	GetModifierBonusStats_Agility = function (self)
		if self:GetParent():GetPrimaryAttribute() == DOTA_ATTRIBUTE_AGILITY  then
    	    return self.agi_bonus
    	elseif self:GetParent():GetPrimaryAttribute() == DOTA_ATTRIBUTE_ALL then
    	    return self.agi_bonus / 3
    	end
	end,
	GetModifierBonusStats_Intellect = function (self)
		if self:GetParent():GetPrimaryAttribute() == DOTA_ATTRIBUTE_INTELLECT  then
    	    return self.int_bonus
    	elseif self:GetParent():GetPrimaryAttribute() == DOTA_ATTRIBUTE_ALL then
    	    return self.int_bonus / 3 
    	end
	end,
})