LinkLuaModifier( "modifier_infinite_branch", 'items/item_infinite_branch', LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_infinite_branch_useless", 'items/item_infinite_branch', LUA_MODIFIER_MOTION_NONE )

modifier_infinite_branch_useless = class({
	IsHidden = function() return true end,
    IsPurgable = function() return false end,
    DestroyOnExpire = function() return false end,
})

item_infinite_branch = class({
	GetIntrinsicModifierName = function (self) return "modifier_infinite_branch" end,
	OnSpellStart = function(self)
		if not IsServer() then return end
		self.caster = self:GetCaster()
		local time = self:GetSpecialValueFor("time")
		local item = self:GetParent():FindItemInInventory("item_infinite_branch")
		local charges = item:GetCurrentCharges()
		local step = self:GetSpecialValueFor("step") * (math.floor(GameRules:GetDOTATime(false,false) / time) + 1)
		if charges > 0 then
			item:SetCurrentCharges(charges + step)
		end
		self.caster:AddNewModifier(self.caster, self, "modifier_infinite_branch_useless", {effect = 1 , duration = 0})
		self:GetParent():RemoveAllModifiersByName("modifier_infinite_branch_useless")
	end,
})

modifier_infinite_branch = class({
	IsHidden = function() return true end,
    IsPurgable = function() return false end,
    DestroyOnExpire = function() return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_PERMANENT end,
    DeclareFunctions = function(self) 
    	local funcs = {
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
		}
		return funcs
	end,
	GetModifierBonusStats_Strength = function(self) return self:GetParent():FindItemInInventory("item_infinite_branch"):GetCurrentCharges() end,
	GetModifierBonusStats_Agility = function(self) return self:GetParent():FindItemInInventory("item_infinite_branch"):GetCurrentCharges() end,
	GetModifierBonusStats_Intellect = function(self) return self:GetParent():FindItemInInventory("item_infinite_branch"):GetCurrentCharges() end,
})

