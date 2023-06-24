modifier_intelect = class({})

function modifier_intelect:IsHidden()
	return false
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
function modifier_intelect:OnIntervalThink()
    local int = self:GetParent():GetIntellect()
	if int ~= self.int then
		self.int = int
		local resist = 0.1 * int
		self:GetParent():SetBaseMagicalResistanceValue(25 - resist)
	end
end
