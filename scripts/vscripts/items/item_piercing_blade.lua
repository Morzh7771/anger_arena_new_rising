item_piercing_blade = class({})
item_piercing_blade2 = class({})
item_piercing_blade3 = class({})
require('lib/common_abilities/damage_to_exp')
LinkLuaModifier("modifier_item_piercing_blade", "items/item_piercing_blade", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_piercing_blade_debuf", "items/item_piercing_blade", LUA_MODIFIER_MOTION_NONE)

function item_piercing_blade:GetIntrinsicModifierName()
	return "modifier_item_piercing_blade"
end

function item_piercing_blade2:GetIntrinsicModifierName()
	return "modifier_item_piercing_blade"
end

function item_piercing_blade3:GetIntrinsicModifierName()
	return "modifier_item_piercing_blade"
end

modifier_item_piercing_blade = CommonAbilities:ConstructModifier( modifier_item_piercing_blade, CommonAbilities.DamageToExp )
local mod = modifier_item_piercing_blade

function mod:IsDebuff() return false end
function mod:IsHidden() return true end
function mod:IsPurgable() return false end

function mod:DeclareFunctions()
    local func = {
        MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE,  
        MODIFIER_EVENT_ON_TAKEDAMAGE,
        MODIFIER_PROPERTY_MANA_BONUS,
		MODIFIER_PROPERTY_HEALTH_BONUS,
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,

    }
    return func
end
function mod:OnCreated()
    self.pure_dmg = self:GetAbility():GetSpecialValueFor("pure_dmg")
    self.pure_dmg_stack = self:GetAbility():GetSpecialValueFor("pure_dmg_stack")
    self.pure_dmg_duration = self:GetAbility():GetSpecialValueFor("pure_dmg_duration")
    self.pure_dmg_cd = self:GetAbility():GetSpecialValueFor("pure_dmg_cd")
    self:CommonInitDamageToExp(  self:GetAbility(),  self:GetAbility():GetCooldown(  self:GetAbility():GetLevel() - 1 ) )
end
function mod:GetModifierTotalDamageOutgoing_Percentage()
    return -self.pure_dmg
end
function mod:OnTakeDamage(params)
    if not IsServer() then return end
    print(BossSpawner:IsBoss(params.unit))
	if params.attacker ~= self:GetParent() then return end
	if params.unit:GetTeamNumber() == params.attacker:GetTeamNumber() then return end
	if params.unit == self:GetParent() then return end
    if params.inflictor and params.inflictor:GetAbilityName() ~= "batrider_sticky_napalm" then return end
	if not self:GetParent():IsRealHero() then return end
    if BossSpawner:IsBoss(params.unit) == nil then 
        if not params.unit:IsRealHero() then
            return 
        end
    end 
	if params.inflictor == self:GetAbility() then return end

    local modifier = params.unit:FindModifierByNameAndCaster("modifier_item_piercing_blade_debuf", self:GetAbility():GetCaster())
    local stack = 0
    if self:GetAbility():IsCooldownReady() then
        if modifier == nil then
            if BossSpawner:IsBoss(params.unit) == nil then
                params.unit:AddNewModifier(self:GetCaster(),self:GetAbility(),"modifier_item_piercing_blade_debuf",{duration = self.pure_dmg_duration})
                stack = 1
            end
        else
            modifier:IncrementStackCount()
            stack = modifier:GetStackCount()
            modifier:ForceRefresh()
        end
        self:ProcessDamageToExp( self:GetParent(), self:GetAbility(), params.damage )
        self:GetAbility():UseResources(false, false, false, true)
    else
        stack = modifier:GetStackCount()
    end
    
    local damage = params.original_damage/100*(self.pure_dmg + self.pure_dmg_stack*stack)
    ApplyDamage({attacker = self:GetCaster(), victim = params.unit, ability = self:GetAbility(), damage = damage, damage_type = DAMAGE_TYPE_PURE, damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,})
end


function mod:GetModifierManaBonus()
	if self:GetAbility() then
		return self:GetAbility():GetSpecialValueFor("bonus_mp")
	end
end

function mod:GetModifierHealthBonus()
	if self:GetAbility() then
		return self:GetAbility():GetSpecialValueFor("bonus_hp")
	end
end

function mod:GetModifierBonusStats_Strength()
	if self:GetAbility() then
		return self:GetAbility():GetSpecialValueFor("bonus_all_stats")
	end
end

function mod:GetModifierBonusStats_Agility()
	if self:GetAbility() then
		return self:GetAbility():GetSpecialValueFor("bonus_all_stats")
	end
end

function mod:GetModifierBonusStats_Intellect()
	if self:GetAbility() then
		return self:GetAbility():GetSpecialValueFor("bonus_all_stats")
	end
end

modifier_item_piercing_blade_debuf = class({})

function modifier_item_piercing_blade_debuf:IsDebuff() return true end
function modifier_item_piercing_blade_debuf:IsHidden() return false end
function modifier_item_piercing_blade_debuf:IsPurgable() return false end

function modifier_item_piercing_blade_debuf:OnCreated( kv )
	self:SetStackCount(1)
end