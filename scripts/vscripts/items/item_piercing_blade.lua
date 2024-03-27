item_piercing_blade = class({})
item_piercing_blade2 = class({})
item_piercing_blade3 = class({})
require('lib/common_abilities/damage_to_exp')
LinkLuaModifier("modifier_item_piercing_blade", "items/item_piercing_blade", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_piercing_blade_debuf", "items/item_piercing_blade", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_piercing_blade_cd", "items/item_piercing_blade", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_piercing_blade_pure_damage", "items/item_piercing_blade", LUA_MODIFIER_MOTION_NONE)

function item_piercing_blade:GetIntrinsicModifierName()
	return "modifier_item_piercing_blade"
end

function item_piercing_blade2:GetIntrinsicModifierName()
	return "modifier_item_piercing_blade"
end

function item_piercing_blade3:GetIntrinsicModifierName()
	return "modifier_item_piercing_blade"
end

function item_piercing_blade:OnSpellStart()
    if not self:GetCaster():HasModifier("modifier_piercing_blade_pure_damage") then
        self:GetCaster():AddNewModifier(self:GetCaster(),self,'modifier_piercing_blade_pure_damage',{duration = self:GetSpecialValueFor("active_duration")})
    end
end
function item_piercing_blade2:OnSpellStart()
    if not self:GetCaster():HasModifier("modifier_piercing_blade_pure_damage") then
        self:GetCaster():AddNewModifier(self:GetCaster(),self,'modifier_piercing_blade_pure_damage',{duration = self:GetSpecialValueFor("active_duration")})
    end
end
function item_piercing_blade3:OnSpellStart()
    if not self:GetCaster():HasModifier("modifier_piercing_blade_pure_damage") then
        self:GetCaster():AddNewModifier(self:GetCaster(),self,'modifier_piercing_blade_pure_damage',{duration = self:GetSpecialValueFor("active_duration")})
    end
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
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
    }
    return func
end
function mod:OnCreated()
    self.pure_dmg = self:GetAbility():GetSpecialValueFor("pure_dmg")
    self.pure_dmg_stack = self:GetAbility():GetSpecialValueFor("pure_dmg_stack")
    self.pure_dmg_duration = self:GetAbility():GetSpecialValueFor("pure_dmg_duration")
    self.pure_dmg_cd = self:GetAbility():GetSpecialValueFor("pure_dmg_cd")
    --self:CommonInitDamageToExp(  self:GetAbility(),  self:GetAbility():GetSpecialValueFor("pure_dmg_cd") )
end
function mod:GetModifierTotalDamageOutgoing_Percentage()
    return self.pure_dmg
end
function mod:OnTakeDamage(params)
    if not IsServer() then return end
    if not self:GetParent():IsRealHero() then return end
	if params.attacker ~= self:GetParent() then return end
	if params.unit:GetTeamNumber() == params.attacker:GetTeamNumber() then return end
	if params.unit == self:GetParent() then return end
    if params.inflictor ~= nil then
        if params.inflictor:GetAbilityName() == "batrider_sticky_napalm" then return end
    end
    if BossSpawner:IsBoss(params.unit) == nil then if not params.unit:IsRealHero() then return end end 
	if params.inflictor == self:GetAbility() then return end
    if not params.attacker:IsAlive() then return end
    local modifier = params.unit:FindModifierByName("modifier_item_piercing_blade_debuf") or nil
    local stack = 0
    if not self:GetParent():HasModifier("modifier_piercing_blade_cd") then
        if modifier == nil then
            if BossSpawner:IsBoss(params.unit) == nil then
                params.unit:AddNewModifier(self:GetCaster(),self:GetAbility(),"modifier_item_piercing_blade_debuf",{duration = self.pure_dmg_duration}):IncrementStackCount()
                stack = 1
            end
        else
            modifier:IncrementStackCount()
            stack = modifier:GetStackCount()
            modifier:ForceRefresh()
        end
        --self:ProcessDamageToExp( self:GetParent(), self:GetAbility(), params.damage )
        self:GetParent():AddNewModifier(self:GetParent(),self:GetAbility(),'modifier_piercing_blade_cd',{duration = self.pure_dmg_cd})
    else
        if modifier == nil then
            stack = 0
        else 
            stack = modifier:GetStackCount() 
        end
    end
    
    local damage = params.original_damage/100*(self.pure_dmg + self.pure_dmg_stack*stack)
   -- print('damage')
    ApplyDamage({attacker = self:GetCaster(), victim = params.unit, ability = self:GetAbility(), damage = damage, damage_type = DAMAGE_TYPE_PURE, damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,})
end


function mod:GetModifierPreAttack_BonusDamage()
	if self:GetAbility() then
		return self:GetAbility():GetSpecialValueFor("bonus_damage")
	end
end

function mod:GetModifierConstantHealthRegen()
	if self:GetAbility() then
		return self:GetAbility():GetSpecialValueFor("bonus_health_regen")
	end
end

function mod:GetModifierConstantManaRegen()
	if self:GetAbility() then
		return self:GetAbility():GetSpecialValueFor("bonus_mana_regen")
	end
end

modifier_item_piercing_blade_debuf = class({
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
    IsDebuff = function (self) return true end,
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return false end,
})

modifier_piercing_blade_cd = class({
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
    IsDebuff = function (self) return false end,
    IsHidden = function (self) return false end,
})

modifier_piercing_blade_pure_damage = class({
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
    IsDebuff = function (self) return false end,
    IsHidden = function (self) return false end,
    DeclareFunctions = function (self) return {MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE} end,
})

function modifier_piercing_blade_pure_damage:GetModifierTotalDamageOutgoing_Percentage( params )
    print(params.damage_type)
    if params.attacker ~= self:GetParent() then return end
    if IsValidEntity(params.inflictor) and params.inflictor ~= self:GetAbility() or params.damage_category == DOTA_DAMAGE_CATEGORY_ATTACK then 
        print("...........................")  
            local damage = self:GetAbility():GetSpecialValueFor("active_pure_dmg")/100 * params.original_damage
            if not params.target:IsMagicImmune() then
                local damageTable = {
                    victim = params.target,
                    attacker = self:GetParent(),
                    damage = damage,
                    damage_type = DAMAGE_TYPE_PURE,
                    damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION + DOTA_DAMAGE_FLAG_NO_DAMAGE_MULTIPLIERS + DOTA_DAMAGE_FLAG_NO_SPELL_LIFESTEAL,
                    ability =  self:GetAbility(), --Optional.
                }
            self:Destroy()
            ApplyDamage( damageTable )
            return -200
        end
    end
end
