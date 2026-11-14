item_piercing_blade = class({})
item_piercing_blade2 = class({})
item_piercing_blade3 = class({})
require('lib/common_abilities/damage_to_exp')
require('lib/summon_utils')
LinkLuaModifier("modifier_item_piercing_blade", "items/item_piercing_blade", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_piercing_blade_debuf", "items/item_piercing_blade", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_piercing_blade_cd", "items/item_piercing_blade", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_piercing_blade_stack_lock", "items/item_piercing_blade", LUA_MODIFIER_MOTION_NONE)
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

-- Pure power. Повторное применение обновляет длительность эффекта
-- (AddNewModifier на уже висящий модификатор его рефрешит).
local function PurePowerStart(item)
    local caster = item:GetCaster()
    caster:AddNewModifier(caster, item, 'modifier_piercing_blade_pure_damage', {duration = item:GetSpecialValueFor("active_duration")})
end
item_piercing_blade.OnSpellStart = PurePowerStart
item_piercing_blade2.OnSpellStart = PurePowerStart
item_piercing_blade3.OnSpellStart = PurePowerStart

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
-- Суммоны владельца получают копию этого же модификатора (caster - герой,
-- ability - сам предмет): Pierce работает на них полностью как на герое
-- (режет обычный урон, добавляет чистый, стаки, своя перезарядка), но статы
-- копия не даёт. Раздаёт копии и снимает их модификатор героя.
-- новые суммоны и так получают копию на спавне, это лишь страховка:
-- обход всех юнитов карты дорогой (надгробие Андаинга плодит десятки зомби)
local SUMMON_SYNC_INTERVAL = 2

function mod:IsSummonCopy()
    return self:GetParent() ~= self:GetCaster()
end

function mod:OnCreated()
    self.pure_dmg = self:GetAbility():GetSpecialValueFor("pure_dmg")
    self.pure_dmg_stack = self:GetAbility():GetSpecialValueFor("pure_dmg_stack")
    self.pure_dmg_duration = self:GetAbility():GetSpecialValueFor("pure_dmg_duration")
    self.pure_dmg_cd = self:GetAbility():GetSpecialValueFor("pure_dmg_cd")
    --self:CommonInitDamageToExp(  self:GetAbility(),  self:GetAbility():GetSpecialValueFor("pure_dmg_cd") )

    if IsServer() and not self:IsSummonCopy() and self:GetParent():IsRealHero() then
        self.summonCopies = {}
        -- уже живые суммоны получают эффект сразу при покупке
        self:OnIntervalThink()
        -- страховка на случай, если суммон появился мимо npc_spawned
        self:StartIntervalThink(SUMMON_SYNC_INTERVAL)
    end
end

-- выдать копию одному суммону
function mod:GiveCopy(summon)
    if self:FindCopyOn(summon) then return end
    local copy = summon:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_item_piercing_blade", {})
    if copy then table.insert(self.summonCopies, copy) end
end

-- новые суммоны получают Pierce в момент спавна (lib/summon_power.lua)
if IsServer() then
    SummonUtils:OnSummonSpawned("piercing_blade", function(summon, hero)
        for _, m in ipairs(hero:FindAllModifiersByName("modifier_item_piercing_blade")) do
            if m.summonCopies then m:GiveCopy(summon) end
        end
    end)
end

-- копия от этого же предмета уже висит на юните?
function mod:FindCopyOn(unit)
    for _, m in ipairs(unit:FindAllModifiersByName("modifier_item_piercing_blade")) do
        if m:GetAbility() == self:GetAbility() then return m end
    end
end

function mod:OnIntervalThink()
    local hero = self:GetParent()

    -- копии с погибших суммонов выкидываем, иначе список растёт бесконечно
    local alive = {}
    for _, copy in ipairs(self.summonCopies) do
        if copy and not copy:IsNull() then table.insert(alive, copy) end
    end
    self.summonCopies = alive

    for _, summon in ipairs(SummonUtils:FindSummons(hero)) do
        self:GiveCopy(summon)
    end
end

function mod:OnDestroy()
    if not IsServer() or not self.summonCopies then return end
    -- предмет продали или выложили: копии с суммонов снимаем
    for _, copy in ipairs(self.summonCopies) do
        if copy and not copy:IsNull() then copy:Destroy() end
    end
    self.summonCopies = nil
end

function mod:GetModifierTotalDamageOutgoing_Percentage()
    return  - self.pure_dmg
end
function mod:OnTakeDamage(params)
    if not IsServer() then return end
    if not self:GetParent():IsRealHero() and not self:IsSummonCopy() then return end
	if params.attacker ~= self:GetParent() then return end
	if params.unit:GetTeamNumber() == params.attacker:GetTeamNumber() then return end
	if params.unit == self:GetParent() then return end
    if params.inflictor ~= nil then
        if params.inflictor:GetAbilityName() == "batrider_sticky_napalm" 
        or params.inflictor:GetAbilityName() == "jakiro_liquid_ice"
        or params.inflictor:GetAbilityName() == "jakiro_liquid_fire"
        or params.inflictor:GetAbilityName() == "lina_combustion" then return end
    end
    if BossSpawner:IsBoss(params.unit) == nil then if not params.unit:IsRealHero() then return end end 
	if params.inflictor == self:GetAbility() then return end
    if not params.attacker:IsAlive() then return end
    local modifier = params.unit:FindModifierByName("modifier_item_piercing_blade_debuf") or nil
    local stack = 0
    -- Стаки накладываются по одному: пока на цели висит блокировка от
    -- прошлого стака, новый не вешается, сколько бы атакующих (герой и его
    -- суммоны) ни било одновременно. Раньше перезарядка была своя у каждого
    -- атакующего, и 4 собаки разом давали 4 стака.
    if not params.unit:HasModifier("modifier_item_piercing_blade_stack_lock") then
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
        params.unit:AddNewModifier(self:GetCaster(),self:GetAbility(),'modifier_item_piercing_blade_stack_lock',{duration = self.pure_dmg_cd})
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


function mod:GetModifierManaBonus()
	if self:GetAbility() and not self:IsSummonCopy() then
		return self:GetAbility():GetSpecialValueFor("bonus_mp")
	end
end

function mod:GetModifierHealthBonus()
	if self:GetAbility() and not self:IsSummonCopy() then
		return self:GetAbility():GetSpecialValueFor("bonus_hp")
	end
end

function mod:GetModifierBonusStats_Strength()
	if self:GetAbility() and not self:IsSummonCopy() then
		return self:GetAbility():GetSpecialValueFor("bonus_all_stats")
	end
end

function mod:GetModifierBonusStats_Agility()
	if self:GetAbility() and not self:IsSummonCopy() then
		return self:GetAbility():GetSpecialValueFor("bonus_all_stats")
	end
end

function mod:GetModifierBonusStats_Intellect()
	if self:GetAbility() and not self:IsSummonCopy() then
		return self:GetAbility():GetSpecialValueFor("bonus_all_stats")
	end
end

modifier_item_piercing_blade_debuf = class({
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
    IsDebuff = function (self) return true end,
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return false end,
})

-- Блокировка стака на цели: пока висит, Pierce не добавляет новый стак
-- (чистый урон по-прежнему идёт). Висит pure_dmg_cd сек.
modifier_item_piercing_blade_stack_lock = class({
    IsHidden = function (self) return true end,
    IsDebuff = function (self) return true end,
    IsPurgable = function (self) return false end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE end,
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
    -- отладочный print убран: горячий путь (каждый удар/лечение)
    if params.attacker ~= self:GetParent() then return end
    if IsValidEntity(params.inflictor) and params.inflictor ~= self:GetAbility() or params.damage_category == DOTA_DAMAGE_CATEGORY_ATTACK then 
        -- отладочный print убран: горячий путь (каждый удар/лечение)
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
