modifier_aa_hero = class({})

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
    self:StartIntervalThink(1.0)
end

function modifier_aa_hero:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_MOVESPEED_LIMIT,
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_IGNORE_MOVESPEED_LIMIT
	}
	return funcs
end
function modifier_aa_hero:GetModifierIgnoreMovespeedLimit()
    return 1
end
function modifier_aa_hero:GetModifierMoveSpeed_Limit( params )
	if self:GetParent():HasModifier("modifier_spirit_breaker_charge_of_darkness") 
	or self:GetParent():HasModifier("modifier_bloodseeker_thirst_speed") 
	or self:GetParent():HasModifier("modifier_primal_beast_trample")
	or self:GetParent():HasModifier("modifier_spirit_breaker_bulldoze") then
    	return 99999999
	else 
		return 700
	end
end
function modifier_aa_hero:GetModifierMoveSpeedBonus_Percentage()
	return (0.05 * self:GetParent():GetAgility())
end
function modifier_aa_hero:OnIntervalThink()
	--for _,v in ipairs(self:GetParent():FindAllModifiers()) do
		--print(v:GetName())
	--end
	
    local int = self:GetParent():GetIntellect()
	if int ~= self.int then
		self.int = int
		local resist = 0.1 * int
		self:GetParent():SetBaseMagicalResistanceValue(25 - resist)
	end
end
