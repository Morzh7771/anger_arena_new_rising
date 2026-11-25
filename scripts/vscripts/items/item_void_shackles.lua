LinkLuaModifier('modifier_item_void_shackles_passive', 'items/item_void_shackles', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_item_void_shackles_root', 'items/item_void_shackles', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_item_void_shackles_nullify', 'items/item_void_shackles', LUA_MODIFIER_MOTION_NONE)

-- Цепи Пустоты: активка по точке. Как у Глейпнира: молния летит в точку
-- (даже если там никого), взрывается, рутит всех врагов в радиусе;
-- плюс Nullify (развеивание положительных эффектов + замедление).
-- Пассивка - статы из AbilityValues.

local PFX_PROJECTILE = "particles/items3_fx/gleipnir_projectile.vpcf"
local PFX_ROOT       = "particles/items3_fx/gleipnir_root.vpcf"
local PFX_FIZZLE     = "particles/items3_fx/gleipnir_fizzle.vpcf"
local PFX_NULLIFY    = "particles/items4_fx/nullifier_mute_debuff.vpcf"
local PFX_NULL_STATUS = "particles/status_fx/status_effect_nullifier.vpcf"
local PROJECTILE_SPEED = 1900

-- Вихри предметов, которые Цепи снимают (астралы и скиллы не трогаем)
local ESCAPE_MODIFIERS = {
    "modifier_eul_cyclone",
    "modifier_wind_waker",
}

local function HasEscapeModifier(unit)
    for _, mod_name in ipairs(ESCAPE_MODIFIERS) do
        if unit:HasModifier(mod_name) then return true end
    end
    return false
end

item_void_shackles = class({
    GetIntrinsicModifierName = function (self) return "modifier_item_void_shackles_passive" end,
})

function item_void_shackles:Precache(context)
    PrecacheResource("particle", PFX_PROJECTILE, context)
    PrecacheResource("particle", PFX_ROOT, context)
    PrecacheResource("particle", PFX_FIZZLE, context)
    PrecacheResource("particle", PFX_NULLIFY, context)
    PrecacheResource("particle", PFX_NULL_STATUS, context)
    PrecacheResource("soundfile", "soundevents/game_sounds_items.vsndevts", context)
end

function item_void_shackles:GetAOERadius()
    return self:GetSpecialValueFor("radius")
end

function item_void_shackles:OnSpellStart()
    local caster = self:GetCaster()
    local point = self:GetCursorPosition()
    caster:EmitSound("Item.Gleipnir.Cast")

    -- Невидимая цель в точке, чтобы молния летела туда даже в пустоту
    local thinker = CreateModifierThinker(caster, self, nil, {duration = 5}, point, caster:GetTeamNumber(), false)
    ProjectileManager:CreateTrackingProjectile({
        Target = thinker,
        Source = caster,
        Ability = self,
        EffectName = PFX_PROJECTILE,
        iMoveSpeed = PROJECTILE_SPEED,
        bDodgeable = false,
        bProvidesVision = true,
        iVisionRadius = 200,
        iVisionTeamNumber = caster:GetTeamNumber(),
        iSourceAttachment = DOTA_PROJECTILE_ATTACHMENT_HITLOCATION,
    })
end

function item_void_shackles:OnProjectileHit(target, location)
    if not target then return true end
    local caster = self:GetCaster()
    local point = target:GetAbsOrigin()
    local radius = self:GetSpecialValueFor("radius")
    local root_duration = self:GetSpecialValueFor("duration")
    local nullify_duration = self:GetSpecialValueFor("nullify_duration")

    if not target:IsNull() then UTIL_Remove(target) end

    AddFOWViewer(caster:GetTeamNumber(), point, radius, root_duration, false)

    -- Ищем и неуязвимых: того, кто в вихре Эула/Вин Вейкера, выбиваем оттуда
    local found = FindUnitsInRadius(caster:GetTeamNumber(), point, nil, radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_INVULNERABLE, FIND_ANY_ORDER, false)
    local enemies = {}
    for _, enemy in pairs(found) do
        if enemy:IsAlive() and not enemy:IsMagicImmune()
            and (HasEscapeModifier(enemy) or (not enemy:IsInvulnerable() and not enemy:IsOutOfGame())) then
            table.insert(enemies, enemy)
        end
    end

    if #enemies == 0 then
        local pfx = ParticleManager:CreateParticle(PFX_FIZZLE, PATTACH_WORLDORIGIN, nil)
        ParticleManager:SetParticleControl(pfx, 0, point)
        ParticleManager:ReleaseParticleIndex(pfx)
        EmitSoundOnLocationWithCaster(point, "Item.Gleipnir.Target", caster)
        return true
    end

    for _, enemy in pairs(enemies) do
        -- Линка блокирует всё: ни снятия вихря, ни рута, ни Nullify
        if not enemy:TriggerSpellAbsorb(self) then
            for _, mod_name in ipairs(ESCAPE_MODIFIERS) do
                if enemy:HasModifier(mod_name) then enemy:RemoveModifierByName(mod_name) end
            end
            enemy:EmitSound("Item.Gleipnir.Target")
            enemy:AddNewModifier(caster, self, "modifier_item_void_shackles_root", {duration = root_duration})
            enemy:AddNewModifier(caster, self, "modifier_item_void_shackles_nullify", {duration = nullify_duration})
        end
    end
    return true
end

-- Пассивка: статы из AbilityValues (движок для item_lua их сам не выдаёт)
modifier_item_void_shackles_passive = class({
    IsHidden = function (self) return true end,
    IsPurgable = function (self) return false end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function (self) return
    {
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_HEALTH_BONUS,
        MODIFIER_PROPERTY_MANA_BONUS,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_PROPERTY_AOE_BONUS_CONSTANT,
    }
    end,
    GetModifierBonusStats_Intellect = function (self) return self:GetAbility():GetSpecialValueFor("bonus_intellect") end,
    GetModifierHealthBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_hp") end,
    GetModifierManaBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_mana") end,
    GetModifierPreAttack_BonusDamage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_damage") end,
    GetModifierPhysicalArmorBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_armor") end,
    GetModifierAoeBonusConstant = function (self) return self:GetAbility():GetSpecialValueFor("bonus_aoe") end,
})

-- Рут: как у Глейпнира (молнии на ногах)
modifier_item_void_shackles_root = class({
    IsHidden = function (self) return false end,
    IsDebuff = function (self) return true end,
    IsPurgable = function (self) return true end,
    GetTexture = function (self) return "../items/void_shackles" end,
    GetEffectName = function (self) return PFX_ROOT end,
    GetEffectAttachType = function (self) return PATTACH_ABSORIGIN_FOLLOW end,
    CheckState = function (self) return
    {
        [MODIFIER_STATE_ROOTED] = true,
    }
    end,
})

-- Nullify: постоянное развеивание положительных эффектов + замедление передвижения,
-- фиолетовая дымка Nullifier
modifier_item_void_shackles_nullify = class({
    IsHidden = function (self) return false end,
    IsDebuff = function (self) return true end,
    IsPurgable = function (self) return false end,
    GetTexture = function (self) return "../items/void_shackles" end,
    GetEffectName = function (self) return PFX_NULLIFY end,
    GetEffectAttachType = function (self) return PATTACH_ABSORIGIN_FOLLOW end,
    GetStatusEffectName = function (self) return PFX_NULL_STATUS end,
    StatusEffectPriority = function (self) return MODIFIER_PRIORITY_NORMAL end,
    DeclareFunctions = function (self) return
    {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
    }
    end,
    GetModifierMoveSpeedBonus_Percentage = function (self) return -(self.slow_pct or 0) end,
})

function modifier_item_void_shackles_nullify:OnCreated()
    local ability = self:GetAbility()
    self.slow_pct = ability and ability:GetSpecialValueFor("slow_pct") or 0
    if not IsServer() then return end
    self:GetParent():Purge(true, false, false, false, false)
    self:StartIntervalThink(0.2)
end

function modifier_item_void_shackles_nullify:OnIntervalThink()
    self:GetParent():Purge(true, false, false, false, false)
end
