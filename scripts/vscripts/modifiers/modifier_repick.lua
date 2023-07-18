modifier_repick = class({})

function modifier_repick:IsHidden()
	return false
end

function modifier_repick:IsPurgable()
	return false
end

function modifier_repick:RemoveOnDeath()
    return false
end
