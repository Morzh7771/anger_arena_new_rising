item_talisman_of_heal = item_talisman_of_heal or class({})

LinkLuaModifier( "modifier_talisman_of_heal", 'items/talisman_of_mastery/talisman_of_heal', LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_talisman_of_heal_buff", 'items/talisman_of_mastery/talisman_of_heal', LUA_MODIFIER_MOTION_NONE )

require('lib/common_abilities/damage_to_exp')

modifier_talisman_of_heal = CommonAbilities:ConstructModifier( modifier_talisman_of_heal, CommonAbilities.DamageToExp )

local mod = modifier_talisman_of_heal

function mod:IsHidden()         return true  end
function mod:IsPurgable()       return false end
function mod:DestroyOnExpire()  return false end
function mod:IsPurgable()       return false end
function mod:IsPurgeException() return false end

function mod:GetAttributes()
	return MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT
end
function mod:OnCreated( kv )
	local ability = self:GetAbility()

	if not ability then return end

	self.bonusHpReg  = ability:GetSpecialValueFor("bonus_hp_regen")
	self.bonusMpReg  = ability:GetSpecialValueFor("bonus_mp_regen")
	self.bonusStr    = ability:GetSpecialValueFor("bonus_all")
	self.bonusAgl    = ability:GetSpecialValueFor("bonus_all")
	self.bonusInt    = ability:GetSpecialValueFor("bonus_all")
	self.bonusHp    = ability:GetSpecialValueFor("bonus_health")
	self.bonusAttack = ability:GetSpecialValueFor("bonus_attack")

	self:CommonInitDamageToExp( ability, ability:GetCooldown( ability:GetLevel() - 1 ) )
end

mod.OnRefresh = mod.OnRefresh

function mod:DeclareFunctions() return
{
	MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
	MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
	MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
	MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
	MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
	MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
	MODIFIER_PROPERTY_HEALTH_BONUS,
	MODIFIER_EVENT_ON_TAKEDAMAGE,
}
end

function mod:OnTakeDamage( params )
	if not IsServer() then return end
	local parent = self:GetParent()
	
	if params.attacker ~= parent then return end

	local target = params.unit

	if not target:IsRealHero() or target:GetTeamNumber() == parent:GetTeamNumber() then return end

	local ability = self:GetAbility()

	if self:ProcessDamageToExp( parent, ability, params.damage ) then
		ability:UseResources(false, false,	false, true)
	end
end

function mod:GetModifierConstantHealthRegen( params )
	return self.bonusHpReg
end
function mod:GetModifierConstantManaRegen( params )
	return self.bonusMpReg
end
function mod:GetModifierBonusStats_Strength( params )
	return self.bonusStr
end
function mod:GetModifierBonusStats_Agility( params )
	return self.bonusAgl
end
function mod:GetModifierBonusStats_Intellect( params )
	return self.bonusInt
end
function mod:GetModifierPreAttack_BonusDamage( params )
	return self.bonusAttack
end
function mod:GetModifierHealthBonus( params )
	return self.bonusHp
end

function item_talisman_of_heal:GetIntrinsicModifierName()
	return "modifier_talisman_of_heal"
end

function item_talisman_of_heal:OnHeroLevelUp()
	if not IsServer() then return end
	local item = self:GetParent():FindItemInInventory("item_talisman_of_heal")
	if not item or item:IsInBackpack() then return end 
	local heal = self:GetSpecialValueFor("replenish_health")*self:GetCaster():GetMaxHealth()/100 
	local mana = self:GetSpecialValueFor("replenish_mana")*self:GetCaster():GetMaxMana()/100 

	self:GetCaster():GiveMana(mana)
	SendOverheadEventMessage(nil, OVERHEAD_ALERT_MANA_ADD, self:GetCaster(), mana, nil)
	self:GetCaster():Heal(heal, self:GetCaster())
	SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, self:GetCaster(), heal, nil)
	
	local caster = self:GetCaster()
	caster:AddNewModifier( caster, self, "modifier_talisman_of_heal_buff", {duration = self:GetSpecialValueFor("duration")} )
	
end
modifier_talisman_of_heal_buff = class({ 
	IsBuff = function(self)return true end,
	IsDebuff = function(self) return false end,
	IsPurgable  = function(self) return true end,
	IsHidden = function(self) return false end,
	GetTexture  = function(self) return "item_talisman_of_heal" end,
	DeclareFunctions = function(self) 
		return {
			MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
			MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
			MODIFIER_EVENT_ON_ATTACKED,
		}
	end,
	GetModifierConstantHealthRegen = function(self) return (self:GetAbility():GetSpecialValueFor('buff_health')*self:GetCaster():GetMaxHealth()/100) end,
	GetModifierConstantManaRegen = function(self) return (self:GetAbility():GetSpecialValueFor('buff_mana')*self:GetCaster():GetMaxMana()/100) end,
})
function modifier_talisman_of_heal_buff:OnAttacked(params)
    if params.target == self:GetParent() and params.attacker:IsHero() then  
		self:GetParent():RemoveModifierByName("modifier_talisman_of_heal_buff")
	end
end