modifier_aa_hero = class({})
LinkLuaModifier("bonus_str_tome", "modifiers/modifier_aa_hero", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("bonus_agi_tome", "modifiers/modifier_aa_hero", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("bonus_int_tome", "modifiers/modifier_aa_hero", LUA_MODIFIER_MOTION_NONE)
bonus_str_tome = class({
	IsHidden = function (self) 
		if self:GetStackCount() > 1 then return false else return true end end,
	IsPurgable = function (self) return false end,
	RemoveOnDeath = function (self) return false end,
	GetTexture = function (self)
		if self:GetName() == "bonus_str_tome" then return "../items/tome_str_6" end
		if self:GetName() == "bonus_agi_tome" then return "../items/tome_agi_6" end
		if self:GetName() == "bonus_int_tome" then return "../items/tome_int_6" end
	end,
})
bonus_agi_tome = bonus_str_tome
bonus_int_tome = bonus_str_tome

function modifier_aa_hero:IsHidden()
	return true
end
function modifier_aa_hero:IsPurgable()
	return false
end
function modifier_aa_hero:RemoveOnDeath()
    return false
end

function modifier_aa_hero:OnCreated()
	self.limit = 700
	self.int = 0
    self:StartIntervalThink(1.0)
	if not self:GetParent():IsIllusion() then  
		self:GetParent():AddNewModifier(self:GetParent(),nil,'bonus_str_tome',{duration = -1})
		self:GetParent():AddNewModifier(self:GetParent(),nil,'bonus_agi_tome',{duration = -1})
		self:GetParent():AddNewModifier(self:GetParent(),nil,'bonus_int_tome',{duration = -1})
	end
end

function modifier_aa_hero:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_MOVESPEED_LIMIT,
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_IGNORE_MOVESPEED_LIMIT,
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
		MODIFIER_EVENT_ON_DEATH,
	}
	return funcs
end
function modifier_aa_hero:OnDeath(data)
	if data.unit == self:GetParent() then
		if self:GetParent():FindModifierByName('bonus_str_tome'):GetStackCount() > 10 then
			self:GetParent():FindModifierByName('bonus_str_tome'):SetStackCount(self:GetParent():FindModifierByName('bonus_str_tome'):GetStackCount() * (1 - 20/100))
		end
		if self:GetParent():FindModifierByName('bonus_agi_tome'):GetStackCount() > 10 then
			self:GetParent():FindModifierByName('bonus_agi_tome'):SetStackCount(self:GetParent():FindModifierByName('bonus_agi_tome'):GetStackCount() * (1 - 20/100))
		end
		if self:GetParent():FindModifierByName('bonus_int_tome'):GetStackCount() > 10 then
			self:GetParent():FindModifierByName('bonus_int_tome'):SetStackCount(self:GetParent():FindModifierByName('bonus_int_tome'):GetStackCount() * (1 - 20/100))
		end
	end
end
function modifier_aa_hero:GetModifierIgnoreMovespeedLimit()
    return 1
end
function modifier_aa_hero:GetModifierBonusStats_Strength() if self:GetParent():HasModifier("bonus_str_tome") and self:GetParent():FindModifierByName('bonus_str_tome'):GetStackCount() > 1 then return self:GetParent():FindModifierByName('bonus_str_tome'):GetStackCount() end end
function modifier_aa_hero:GetModifierBonusStats_Agility() if self:GetParent():HasModifier("bonus_agi_tome") and self:GetParent():FindModifierByName('bonus_agi_tome'):GetStackCount() > 1 then return self:GetParent():FindModifierByName('bonus_agi_tome'):GetStackCount() end end
function modifier_aa_hero:GetModifierBonusStats_Intellect() if self:GetParent():HasModifier("bonus_int_tome") and self:GetParent():FindModifierByName('bonus_int_tome'):GetStackCount() > 1 then return self:GetParent():FindModifierByName('bonus_int_tome'):GetStackCount() end end

function modifier_aa_hero:GetModifierMoveSpeed_Limit( params )
	if self:GetParent():HasModifier("modifier_spirit_breaker_charge_of_darkness") 
	or self:GetParent():HasModifier("modifier_bloodseeker_thirst_speed") 
	or self:GetParent():HasModifier("modifier_primal_beast_trample")
	or self:GetParent():HasModifier("modifier_spirit_breaker_bulldoze") 
	or self:GetParent():HasModifier("modifier_weaver_shukuchi") 
	or self:GetParent():HasModifier("modifier_dark_seer_surge")  then
    	return 99999999
	else 
		return 700
	end
end
function modifier_aa_hero:GetModifierMoveSpeedBonus_Percentage()
	if(0.05 * self:GetParent():GetAgility()>35) then
		return 35
	else
		return (0.05 * self:GetParent():GetAgility())
	end
end
function modifier_aa_hero:OnIntervalThink()
    local int = self:GetParent():GetIntellect()
	if int ~= self.int then
		self.int = int
		local resist = 0.1 * int
		self:GetParent():SetBaseMagicalResistanceValue(25 - resist)
	end
end
