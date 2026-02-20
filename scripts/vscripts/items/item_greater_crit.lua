item_greater_crit = class({
    Precache = function (self, context) 
        PrecacheResource("particle", "particles/items/azrael_crossbow/azrael_crossbow_bolt.vpcf", context)
        PrecacheResource("particle", "particles/hw_fx/greevil_orange_lava_puddle_impact_burst.vpcf", context)
    end,
    GetIntrinsicModifierName = function (self) return 'modifier_greater_crit' end
})

item_greater_crit_2 = item_greater_crit

LinkLuaModifier('modifier_greater_crit', 'items/item_greater_crit', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_greater_crit_crippled', 'items/item_greater_crit', LUA_MODIFIER_MOTION_NONE)

function item_greater_crit_2:GetCastRange( vLocation, hTarget )
    return self:GetCaster():Script_GetAttackRange() + self:GetSpecialValueFor( "min_cast_range" )
end

function item_greater_crit:OnSpellStart()
    local caster   = self:GetCaster()
    local target   = self:GetCursorTarget()

    if target:TriggerSpellAbsorb(self) then
		return 
	end

    caster:StartGesture(ACT_DOTA_ATTACK)

    local info = {
        Target = target,
        Source = caster,
        Ability = self,
        EffectName = "particles/items/azrael_crossbow/azrael_crossbow_bolt.vpcf",
        bDodgeable = false,
        bProvidesVision = true,
        iMoveSpeed = self:GetSpecialValueFor('projectile_speed'),
        iVisionRadius = 150,
        bVisibleToEnemies = true,
        iSourceAttachment = DOTA_PROJECTILE_ATTACHMENT_ATTACK_1
    }

    ProjectileManager:CreateTrackingProjectile( info )

    EmitSoundOn("Hero_Mirana.ArrowCast", caster)
    --EmitSoundOnLocationWithCaster(self:GetCaster():GetAbsOrigin(), "sounds/weapons/hero/mirana/miranaarrowlaunch1.vsnd", self:GetCaster())
end

function item_greater_crit:OnProjectileHit(target, location)
    if not IsServer() then return end
    if not target then return end

    local caster = self:GetCaster()
    if not caster or caster:IsNull() then return end

    local dmg = caster:GetAverageTrueAttackDamage(caster) * self:GetSpecialValueFor('crit_multiplier') / 100

    ApplyDamage({
        victim = target,
        attacker = caster,
        damage = dmg,
        damage_type = DAMAGE_TYPE_PHYSICAL,
        ability = self,
    })

    EmitSoundOnLocationWithCaster(target:GetAbsOrigin(), "DOTA_Item.HeavensHalberd.Activate", caster)

    local p = ParticleManager:CreateParticle(
        "particles/hw_fx/greevil_orange_lava_puddle_impact_burst.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        target
    )
    ParticleManager:SetParticleControl(p, 3, target:GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(p)

    SendOverheadEventMessage(nil, OVERHEAD_ALERT_CRITICAL, target, dmg, nil)

    if target:IsMagicImmune() then return end

    target:AddNewModifier(caster, self, "modifier_greater_crit_crippled", {
        duration = self:GetSpecialValueFor("cripple_duration") * (1 - target:GetStatusResistance())
    })
end

-------------------------------------------------------------------

modifier_greater_crit = class({
    IsHidden = function (self) return true end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE
    } end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end
})

function modifier_greater_crit:GetModifierPreAttack_CriticalStrike(params)
    if self:LegitimateAttack(params) then
        local chance = self:GetAbility():GetSpecialValueFor("crit_chance") / 100

        local stacked_chance = 1 - math.pow((1 - chance), #self:GetParent():FindAllModifiersByName('modifier_greater_crit'))

        local proc = (RandomInt(1, 100) + math.random()) / 100

        if proc <= stacked_chance then
            self.record = params.record
            return self:GetAbility():GetSpecialValueFor("crit_multiplier")
        end
    end
end

function modifier_greater_crit:GetModifierPreAttack_BonusDamage() return self:GetAbility():GetSpecialValueFor('bonus_damage') end

function modifier_greater_crit:LegitimateAttack(params)
    local target = params.unit or params.target
    local hero = self:GetParent()

    if
    IsServer()
            and params.attacker == hero
            and target:GetTeamNumber() ~= hero:GetTeamNumber()
            and (not target:IsBuilding())
            and (not target:IsOther())
            and ((params.inflictor == nil) or (params.inflictor:GetAbilityName() == "item_bfury"))
    then
        return true
    else
        return false
    end
end

-------------------------------------------------------------------

modifier_greater_crit_crippled = class({
    IsHidden = function (self) return false end,
    IsBuff = function (self) return false end,
    IsDebuff = function (self) return true end,
    GetTexture = function (self) return ("../items/" .. (self:GetAbility():GetAbilityTextureName() or "")) end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE
    } end,
    CheckState = function (self) return {
        [MODIFIER_STATE_MUTED ] = true
    } end,
    GetModifierMoveSpeed_Absolute = function (self) return self:GetAbility():GetSpecialValueFor('cripple_ms') end
})