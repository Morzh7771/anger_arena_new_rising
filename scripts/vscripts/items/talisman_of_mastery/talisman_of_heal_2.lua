item_talisman_of_heal_2 = item_talisman_of_heal_2 or class({})

LinkLuaModifier( "modifier_talisman_of_heal_2_cd", 'items/talisman_of_mastery/talisman_of_heal_2', LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_talisman_of_heal_2", 'items/talisman_of_mastery/talisman_of_heal_2', LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_talisman_of_heal_2_buff", 'items/talisman_of_mastery/talisman_of_heal_2', LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_talisman_of_heal_2_active", 'items/talisman_of_mastery/talisman_of_heal_2', LUA_MODIFIER_MOTION_NONE )

require('lib/common_abilities/damage_to_exp')

modifier_talisman_of_heal_2_cd = class({
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
    IsDebuff = function (self) return false end,
    IsHidden = function (self) return false end,
})

modifier_talisman_of_heal_2 = CommonAbilities:ConstructModifier( modifier_talisman_of_heal_2, CommonAbilities.DamageToExp )

local mod = modifier_talisman_of_heal_2

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
	self.bonusAttack = ability:GetSpecialValueFor("bonus_attack")
	self.bonusHpReg  = ability:GetSpecialValueFor("bonus_hp_regen")
	self.bonusMpReg  = ability:GetSpecialValueFor("bonus_mp_regen")
	self.bonusStr    = ability:GetSpecialValueFor("bonus_all")
	self.bonusAgl    = ability:GetSpecialValueFor("bonus_all")
	self.bonusInt    = ability:GetSpecialValueFor("bonus_all")
	self.bonusHp    = ability:GetSpecialValueFor("bonus_health")

	self:CommonInitDamageToExp( ability, self:GetAbility():GetSpecialValueFor('minder_cd') )
end

mod.OnRefresh = mod.OnRefresh

function mod:DeclareFunctions() return
{
	MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
	MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
	MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
	MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
	MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
	MODIFIER_PROPERTY_HEALTH_BONUS,
	MODIFIER_EVENT_ON_TAKEDAMAGE,
	MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
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

function mod:GetModifierConstantHealthRegen( params ) return self.bonusHpReg end
function mod:GetModifierConstantManaRegen( params ) return self.bonusMpReg end
function mod:GetModifierBonusStats_Strength( params ) return self.bonusStr end
function mod:GetModifierBonusStats_Agility( params ) return self.bonusAgl end
function mod:GetModifierBonusStats_Intellect( params ) return self.bonusInt end
function mod:GetModifierHealthBonus( params ) return self.bonusHp end
function mod:GetModifierPreAttack_BonusDamage( params ) return self.bonusAttack end

function mod:OnTakeDamage(params)
    if not IsServer() then return end
    if not self:GetParent():IsRealHero() then return end
	if params.attacker ~= self:GetParent() then return end
	if params.unit:GetTeamNumber() == params.attacker:GetTeamNumber() then return end
	if params.unit == self:GetParent() then return end
    if BossSpawner:IsBoss(params.unit) == nil then if not params.unit:IsRealHero() then return end end 
    if not self:GetParent():HasModifier("modifier_talisman_of_heal_2_cd") then
        self:ProcessDamageToExp( self:GetParent(), self:GetAbility(), params.damage )
        --self:GetParent():AddNewModifier(self:GetParent(),self:GetAbility(),'modifier_talisman_of_heal_2_cd',{duration = self:GetAbility():GetSpecialValueFor('minder_cd')})
    end
end

function item_talisman_of_heal_2:GetIntrinsicModifierName()
	return "modifier_talisman_of_heal_2"
end
function item_talisman_of_heal_2:OnSpellStart()
	if not IsServer() then return end
    local caster = self:GetCaster()
	caster:AddNewModifier(caster, self, "modifier_talisman_of_heal_2_active", { duration = self:GetSpecialValueFor("duration_active") })
end
function item_talisman_of_heal_2:OnHeroLevelUp()
	if not IsServer() then return end
	local item = self:GetParent():FindItemInInventory("item_talisman_of_heal_2")
	if not item or item:IsInBackpack() then return end 
	local heal = self:GetSpecialValueFor("replenish_health")*self:GetCaster():GetMaxHealth()/100 
	local mana = self:GetSpecialValueFor("replenish_mana")*self:GetCaster():GetMaxMana()/100 

	self:GetCaster():GiveMana(mana)
	SendOverheadEventMessage(nil, OVERHEAD_ALERT_MANA_ADD, self:GetCaster(), mana, nil)
	self:GetCaster():Heal(heal, self:GetCaster())
	SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, self:GetCaster(), heal, nil)
	
	local caster = self:GetCaster()
	caster:AddNewModifier( caster, self, "modifier_talisman_of_heal_2_buff", {duration = self:GetSpecialValueFor("duration")} )
	
end
modifier_talisman_of_heal_2_buff = class({ 
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
function modifier_talisman_of_heal_2_buff:OnAttacked(params)
    if params.target == self:GetParent() and params.attacker:IsHero() then  
		self:GetParent():RemoveModifierByName("modifier_talisman_of_heal_2_buff")
	end
end

modifier_talisman_of_heal_2_active = class({
    IsBuff = function(self)return true end,
	IsDebuff = function(self) return false end,
	IsPurgable  = function(self) return true end,
	IsHidden = function(self) return false end,
    RemoveOnDeath  = function(self) return true end,
	DestroyOnExpire = function(self) return true end,
    GetStatusEffectName = function(self) return "particles/status_fx/status_effect_blur.vpcf" end,
    GetTexture  = function(self) return "talisman_of_heal_2" end,
    OnDestroy = function(self)
        if not IsServer() then return end
        ParticleManager:DestroyParticle(self.particleDamnedEye, false)
        Timers:RemoveTimer("item_talisman_of_heal_2" .. tostring(self:GetParent():entindex()))
    end,
})

function modifier_talisman_of_heal_2_active:OnCreated(kv)
    if not IsServer() then return end
    local caster = self:GetParent()

    self.particleDamnedEye = ParticleManager:CreateParticle("particles/damned_eye/damned_eye.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
    ParticleManager:SetParticleControlEnt(self.particleDamnedEye, 0, caster, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)

    if not caster:IsRealHero() then
        caster = caster:GetPlayerOwner()
        if not IsValidEntity(caster) then return end
        caster = caster:GetAssignedHero()
    end
    local heal_stat = caster:GetPrimaryStatValue() * self:GetAbility():GetSpecialValueFor("heal_per_main_stat") 
    if caster:GetPrimaryAttribute() == DOTA_ATTRIBUTE_ALL then heal_stat = heal_stat / 3 end
    self.allHeal = heal_stat + self:GetAbility():GetSpecialValueFor("heal_const")
    caster = self:GetParent()
    self:SetStackCount(self.allHeal)
    Timers:CreateTimer("item_talisman_of_heal_2" .. tostring(caster:entindex()), {
        useGameTime = true,
        endTime = 0,
        callback = function()
            caster:Heal(self.allHeal / 100, self)
            self:SetStackCount(self:GetStackCount() - (self.allHeal / 100))
            return kv.duration / 100
        end
    })
end
