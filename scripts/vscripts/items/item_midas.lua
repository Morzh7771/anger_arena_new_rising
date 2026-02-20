BaseClass = class({
	Precache = function (self, context) 
		PrecacheResource("particle", "particles/items2_fx/hand_of_midas.vpcf", context)
	end,
	GetIntrinsicModifierName = function (self) return "modifier_item_midas" end
})
item_advanced_midas = BaseClass
item_midas_aa = BaseClass
LinkLuaModifier('modifier_item_midas', 'items/item_midas', LUA_MODIFIER_MOTION_NONE)

function BaseClass:OnSpellStart(keys)
	local Target = self:GetCursorTarget()
	local Caster = self:GetCaster()
	local exp_mult = self:GetSpecialValueFor("xp_multiplier")
	local bonus_gold = self:GetSpecialValueFor("bonus_gold")

	if not Caster:IsRealHero() then
		Caster = Caster:GetPlayerOwner():GetAssignedHero() 
	end

	Caster:ModifyGold(bonus_gold, true, 0)

	if not Caster:IsTempestDouble() then
		Caster:AddExperience(Target:GetDeathXP() * exp_mult, 0, false, false) 
	end
	
	local midas_particle = ParticleManager:CreateParticle("particles/items2_fx/hand_of_midas.vpcf", PATTACH_ABSORIGIN_FOLLOW, Target)	
	ParticleManager:SetParticleControlEnt(midas_particle, 1, Caster, PATTACH_POINT_FOLLOW, "attach_hitloc", Caster:GetAbsOrigin(), false)
	Target:EmitSound("DOTA_Item.Hand_Of_Midas")

	Target:SetDeathXP(0)
	Target:Kill(self, Caster)
end


modifier_item_midas = class({
	IsHidden = function (self) return true end,
	DeclareFunctions = function (self) return{
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT
	}end,
	GetModifierAttackSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("bonus_attack_speed") end
})