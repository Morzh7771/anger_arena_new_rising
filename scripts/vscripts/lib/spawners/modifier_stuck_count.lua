
if modifier_stuck_count == nil then
	modifier_stuck_count = class({})
end

function modifier_stuck_count:IsHidden()
	return false
end

function modifier_stuck_count:IsPurgable()
	return false
end

function modifier_stuck_count:IsDebuff() 
	return false
end

function modifier_stuck_count:CheckState()
    return {
        [MODIFIER_STATE_CANNOT_MISS] = true,
    }
end

function modifier_stuck_count:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_EVASION_CONSTANT
	}
end

function modifier_stuck_count:GetModifierEvasion_Constant()
	return 25
end

function modifier_stuck_count:GetTexture()
	return "bear"
end