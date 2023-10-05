
if modifier_creep_level == nil then
	modifier_creep_level = class({})
end

function modifier_creep_level:IsHidden()
	return false
end

function modifier_creep_level:IsPurgable()
	return false
end

function modifier_creep_level:IsDebuff() 
	return false
end

function modifier_stuck_count:GetTexture()
	return "bear"
end