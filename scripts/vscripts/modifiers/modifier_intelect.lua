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
	self.limit = 700
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
	--print(self:GetParent():FindModifierByName("modifier_spirit_breaker_charge_of_darkness"),'чарж')
	--print(self:GetParent():FindModifierByName("modifier_bloodseeker_thirst_speed"),'сикер')
	if self:GetParent():GetUnitName() == "npc_dota_hero_spirit_breaker" then
		--print('чарж')
    	return 99999999
	end
	if self:GetParent():GetUnitName() == "npc_dota_hero_bloodseeker" then
		--print('сикер')
		return 99999999
	end
	print('все')
	return 700
end
function modifier_intelect:GetModifierMoveSpeedBonus_Percentage()
	return (0.05 * self:GetParent():GetAgility())
end
function modifier_intelect:OnIntervalThink()
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
