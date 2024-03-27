LinkLuaModifier("modifier_item_bfury_aa", "items/item_bfury_aa", LUA_MODIFIER_MOTION_NONE)

item_bfury_aa = class({})
item_bfury_aa_2 = item_bfury_aa

function item_bfury_aa:GetIntrinsicModifierName()
	return "modifier_item_bfury_aa"
end

function item_bfury_aa:OnSpellStart()
local target = self:GetCursorTarget()

--if target.CutDown then
	--target:CutDown(self:GetCaster():GetTeamNumber())
GridNav:DestroyTreesAroundPoint(target:GetAbsOrigin(), 10, true)
--end 

end

modifier_item_bfury_aa	= class({})

function modifier_item_bfury_aa:AllowIllusionDuplicate()	return false end
function modifier_item_bfury_aa:IsPurgable()		return false end
function modifier_item_bfury_aa:RemoveOnDeath()	return false end
function modifier_item_bfury_aa:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end
function modifier_item_bfury_aa:IsHidden()	return true end

function modifier_item_bfury_aa:OnCreated()
	self.damage_bonus			= self:GetAbility():GetSpecialValueFor("bonus_damage")
	self.hp_regen			= self:GetAbility():GetSpecialValueFor("bonus_health_regen")
	self.mp_regen	= self:GetAbility():GetSpecialValueFor("bonus_mana_regen")
	self.damage_bonus_creep_quelling = self:GetAbility():GetSpecialValueFor("quelling_bonus")

	self.damage_bonus_creep_quelling_ranged = self:GetAbility():GetSpecialValueFor("quelling_bonus_ranged")

	self.start_width = self:GetAbility():GetSpecialValueFor("cleave_starting_width")
	self.end_width = self:GetAbility():GetSpecialValueFor("cleave_ending_width")
	self.cleave_distance = self:GetAbility():GetSpecialValueFor("cleave_distance")
end



function modifier_item_bfury_aa:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
		MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
		MODIFIER_PROPERTY_PROCATTACK_BONUS_DAMAGE_PHYSICAL,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
	}

	return funcs
end

function modifier_item_bfury_aa:GetModifierPreAttack_BonusDamage(keys)
	return self.damage_bonus
end

function modifier_item_bfury_aa:GetModifierProcAttack_BonusDamage_Physical( keys )
	if not IsServer() then return end
	if keys.target and not keys.target:IsHero() and not keys.target:IsOther() and not keys.target:IsBuilding() and keys.target:GetTeamNumber() ~= self:GetParent():GetTeamNumber() then
		
		if self:GetParent():IsRangedAttacker() then 
			return self.damage_bonus_creep_quelling_ranged
		else 
			return self.damage_bonus_creep_quelling
		end
	end
end

function modifier_item_bfury_aa:GetModifierConstantManaRegen()
	return self.mp_regen
end

function modifier_item_bfury_aa:GetModifierConstantHealthRegen()
	return self.hp_regen
end
function modifier_item_bfury_aa:GetModifierBonusStats_Strength()
	return	self:GetAbility():GetSpecialValueFor("bonus_str")
end
function modifier_item_bfury_aa:GetModifierBonusStats_Agility()
	return	self:GetAbility():GetSpecialValueFor("bonus_agi")
end

function modifier_item_bfury_aa:OnAttackLanded( params )
if not IsServer() then return end
if self:GetParent() ~= params.attacker then return end
if self:GetParent():IsRangedAttacker() then return end
if not params.target:IsHero() and not params.target:IsCreep() then return end


local k = self:GetAbility():GetSpecialValueFor("cleave_damage_percent")
if params.target:IsCreep() then 
	k = self:GetAbility():GetSpecialValueFor("cleave_damage_percent_creep")
end 


params.target:EmitSound("DOTA_Item.BattleFury")

DoCleaveAttack(self:GetParent(), params.target, self:GetAbility(), params.damage*k/100, self.start_width, self.end_width, self.cleave_distance, "particles/items_fx/battlefury_cleave.vpcf")


end