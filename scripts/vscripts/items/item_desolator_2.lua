require("lib/attack_potency")
-- Desolator 2 (нейтральный, 5 разряд). Valve его удалила, возвращён как наш item_lua.
-- Логика взята из старого item_stygian_aa (git 1145b423): процент от брони цели,
-- стаки, ForceRefresh, учёт modifier_rebels_sword_disarmor. Добавлено базовое
-- плоское снижение брони (corruption_armor из старого KV desolator_2, -35).
--
-- Снижение = corruption_armor + disarmor_pct% от брони цели до снижения.
-- Стак хранится на модификаторе debuff'а и пересчитывается при каждой атаке.

LinkLuaModifier("modifier_item_desolator_2", "items/item_desolator_2", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_desolator_2_disarmor", "items/item_desolator_2", LUA_MODIFIER_MOTION_NONE)

item_desolator_2 = class({})

function item_desolator_2:Precache(context)
    PrecacheResource("particle", "particles/items_fx/desolator_projectile.vpcf", context)
end

function item_desolator_2:GetIntrinsicModifierName()
    return "modifier_item_desolator_2"
end

modifier_item_desolator_2 = class({
    IsHidden = function (self) return true end,
    IsBuff = function (self) return true end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_PROPERTY_PROJECTILE_NAME,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
    } end,
    -- снаряд как у ванильного Desolator (только дальникам, ближникам движок не берёт)
    GetModifierProjectileName = function (self)
        return "particles/items_fx/desolator_projectile.vpcf"
    end,
    GetModifierPreAttack_BonusDamage = function (self)
        return self:GetAbility():GetSpecialValueFor("bonus_dmg")
    end,
})

function modifier_item_desolator_2:OnAttackLanded(kv)
    if not IsServer() then return end
    local parent = self:GetParent()
    if parent ~= kv.attacker then return end

    local target = kv.target
    if not target or target:IsBuilding() then return end

    local ability = self:GetAbility()
    local base_armor = ability:GetSpecialValueFor("corruption_armor")
    local pct = ability:GetSpecialValueFor("disarmor_pct")
    local duration = ability:GetSpecialValueFor("duration")

    -- Броня цели уже включает наши и рыцарские стаки, поэтому прибавляем их
    -- обратно: процент берётся от брони до снижения.
    local armor = target:GetPhysicalArmorValue(false)
    local own = target:GetModifierStackCount("modifier_item_desolator_2_disarmor", parent)
    local sword = target:GetModifierStackCount("modifier_rebels_sword_disarmor", parent)
    -- снижение брони с действенностью атаки (иллюзии раньше не снимали вовсе);
    -- слабый удар не перезаписывает уже висящий сильный стак, только обновляет время
    local potency = AttackPotency:Get(parent, kv)
    local disarmor = math.floor((base_armor + (armor + own + sword) * pct / 100) * potency + 0.5)
    if potency < 1 and own > disarmor then disarmor = own end

    if target:HasModifier("modifier_item_desolator_2_disarmor") then
        target:FindModifierByName("modifier_item_desolator_2_disarmor"):ForceRefresh()
    else
        target:AddNewModifier(parent, ability, "modifier_item_desolator_2_disarmor", {duration = duration})
    end
    target:SetModifierStackCount("modifier_item_desolator_2_disarmor", parent, disarmor)
    target:EmitSound("Item_Desolator.Target")
end

modifier_item_desolator_2_disarmor = class({
    IsHidden = function (self) return false end,
    IsDebuff = function (self) return true end,
    IsPurgable = function (self) return true end,
    GetTexture = function (self) return "desolator_2" end,
    DestroyOnExpire = function (self) return true end,
    GetAttributes = function (self) return (MODIFIER_ATTRIBUTE_MULTIPLE + MODIFIER_ATTRIBUTE_PERMANENT) end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
    } end,
    GetModifierPhysicalArmorBonus = function (self) return -self:GetStackCount() end,
})
