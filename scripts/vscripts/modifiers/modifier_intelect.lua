modifier_intelect = class({})

function modifier_intelect:IsHidden()
	return true
end
function modifier_intelect:IsPurgable()
	return false
end
function modifier_intelect:RemoveOnDeath()
    return false
end

function modifier_intelect:OnCreated()
    self:StartIntervalThink(1.0)
end

function modifier_intelect:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_MOVESPEED_LIMIT,
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_IGNORE_MOVESPEED_LIMIT
	}
	return funcs
end
function modifier_intelect:GetModifierIgnoreMovespeedLimit()
    return 1
end
function modifier_intelect:GetModifierMoveSpeed_Limit( params )
	return 700
end
function modifier_intelect:GetModifierMoveSpeedBonus_Percentage()
	return (0.05 * self:GetParent():GetAgility())
end
function modifier_intelect:OnIntervalThink()
    local int = self:GetParent():GetIntellect()
	if int ~= self.int then
		self.int = int
		local resist = 0.1 * int
		self:GetParent():SetBaseMagicalResistanceValue(25 - resist)
	end
end
