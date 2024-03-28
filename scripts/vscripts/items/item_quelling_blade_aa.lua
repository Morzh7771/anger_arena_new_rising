LinkLuaModifier("modifier_item_quelling_blade_aa", "items/item_quelling_blade_aa", LUA_MODIFIER_MOTION_NONE)

item_quelling_blade_aa = class({
	GetIntrinsicModifierName = function(self) return "modifier_item_quelling_blade_aa" end,
	OnSpellStart = function(self)
		local target = self:GetCursorTarget()
		GridNav:DestroyTreesAroundPoint(target:GetAbsOrigin(), 10, true)
	end,
})

modifier_item_quelling_blade_aa 	= class ({})

function modifier_item_quelling_blade_aa:AllowIllusionDuplicate()	return false end
function modifier_item_quelling_blade_aa:IsPurgable()				return false end
function modifier_item_quelling_blade_aa:RemoveOnDeath()			return false end
function modifier_item_quelling_blade_aa:GetAttributes() 			return MODIFIER_ATTRIBUTE_PERMANENT end
function modifier_item_quelling_blade_aa:IsHidden()					return true end

function modifier_item_quelling_blade_aa:OnCreated()
	self.quelling_bonus_const					= self:GetAbility():GetSpecialValueFor("quelling_bonus")
	self.quelling_bonus_ranged_coef				= self:GetAbility():GetSpecialValueFor("quelling_bonus_ranged_coef") / 100
	self.quelling_bonus_pct						= self:GetCaster():GetAverageTrueAttackDamage(self:GetParent()) * self:GetAbility():GetSpecialValueFor("quelling_bonus_pct") / 100
	self.quelling_bonus_summ					= self.quelling_bonus_const + self.quelling_bonus_pct

	if IsServer() then
	end
end
function modifier_item_quelling_blade_aa:OnRefresh(params)
	if IsServer() then
	end
end
function modifier_item_quelling_blade_aa:OnDestroy()
	if IsServer() then
	end
end
function modifier_item_quelling_blade_aa:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_PROCATTACK_BONUS_DAMAGE_PHYSICAL,
	}
	return funcs
end

function modifier_item_quelling_blade_aa:GetModifierProcAttack_BonusDamage_Physical( keys )
	if not IsServer() then return end
	if keys.target and not keys.target:IsHero() and not keys.target:IsOther() and not keys.target:IsBuilding() and keys.target:GetTeamNumber() ~= self:GetParent():GetTeamNumber() then
		
		if self:GetParent():IsRangedAttacker() then 
			return self.quelling_bonus_summ * self.quelling_bonus_ranged_coef
		else 
			return self.quelling_bonus_summ
		end
	end
end