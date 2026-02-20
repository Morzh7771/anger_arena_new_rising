local forbidden_modifiers = {
	--"modifier_pangolier_swashbuckle_stunned",
	--"modifier_pangolier_swashbuckle",
	--"modifier_pangolier_swashbuckle_attack",
	--"modifier_monkey_king_boundless_strike_crit",
}

DOTA_DAMAGE_FLAG_MAGIC_SPLASH = 1048576

LinkLuaModifier( "modifier_item_magic_splash", "items/item_magic_splash.lua", LUA_MODIFIER_MOTION_NONE )

item_magic_splash = class({
    Precache = function (self, context) 
        PrecacheResource("particle", "particles/units/heroes/hero_warlock/warlock_fatal_bonds_pulse.vpcf", context)
    end,
    GetIntrinsicModifierName = function (self)
    	return "modifier_item_magic_splash"
    end,
    OnCreated = function (self)

    end
})

item_magic_splash_2 = item_magic_splash
item_magic_splash_3 = item_magic_splash

modifier_item_magic_splash = class({
    IsHidden = function (self)
    	return true
    end,
    DeclareFunctions = function (self)
        return {
            MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
            MODIFIER_EVENT_ON_TAKEDAMAGE
        }
    end,
    GetModifierBonusStats_Intellect = function (self)
        return self:GetAbility():GetSpecialValueFor("int")
    end
})

function modifier_item_magic_splash:OnTakeDamage(params)
    if self:GetParent():IsIllusion() then return end
    if params.attacker ~= self:GetParent() then return end
    if params.unit == self:GetParent() then return end
    if not params.unit then return end
    --if not params.inflictor or params.inflictor:IsNull() then return end
    --if bit.band(params.damage_flags, DOTA_DAMAGE_FLAG_REFLECTION) > 0 then return end
    if not ((params.damage_type == DAMAGE_TYPE_MAGICAL) or (params.damage_type == DAMAGE_TYPE_PURE)) then return end
    if params.damage_flags and Util:testflag(params.damage_flags, DOTA_DAMAGE_FLAG_MAGIC_SPLASH) then return end
    if params.damage_flags and Util:testflag(params.damage_flags, DOTA_DAMAGE_FLAG_REFLECTION) then return end
    if params.inflictor:GetName() == "batrider_sticky_napalm" then return end
    if params.inflictor:GetName() == "lina_combustion" then return end 
    if params.inflictor:GetName() == "jakiro_liquid_ice" then return end

    if params.inflictor:GetName() == "item_piercing_blade" then return end
    if params.inflictor:GetName() == "item_piercing_blade2" then return end
    if params.inflictor:GetName() == "item_piercing_blade3" then return end

    local caster = params.attacker
    local target = params.unit
    local radius = self:GetAbility():GetSpecialValueFor( "splash_aoe" )

    if not IsValidEntity(caster) or not IsValidEntity(target) then return end
    if not target:IsCreep() and not target:IsHero() then return end

    for _, modifier_name in pairs(forbidden_modifiers) do
        if caster:HasModifier(modifier_name) then return end
    end

    local team = caster:GetTeamNumber()
    local position = target:GetAbsOrigin()
    local units_in_radius = FindUnitsInRadius(
            team,
            position,
            nil,
            radius,
            DOTA_UNIT_TARGET_TEAM_ENEMY,
            DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_CREEP,
            DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
            0,
            false)
    if not units_in_radius then return end
    local splash_damage_creep = self:GetAbility():GetSpecialValueFor("splash_pct_creep")
    local splash_damage_hero = self:GetAbility():GetSpecialValueFor("splash_pct_hero")
    local splash_damage_illusion = self:GetAbility():GetSpecialValueFor("splash_pct_illusion")

    for _,x in pairs(units_in_radius) do
        if x ~= params.target or x:IsIllusion() then
            local dmg = 0
            local magic_pierce = self:GetAbility():GetSpecialValueFor('magic_pierce')
            local dmg_ref = params.original_damage / 100 * (100 - (x:GetBaseMagicalResistanceValue() / 100 * (100 - magic_pierce)))

            if x:IsCreep() then
                dmg = dmg_ref / 100 * splash_damage_creep
            end
            if x:IsIllusion() then
                dmg = dmg_ref / 100 * splash_damage_illusion
            end
            if x:IsHero() then
                dmg = dmg_ref / 100 * splash_damage_hero
            end
            if x:GetUnitName() == "npc_tree_thinker" then
                return
            end
            ApplyDamage({ victim = x,
                          attacker = caster,
                          damage = dmg,
                          damage_type = DAMAGE_TYPE_MAGICAL,
                          damage_flags = DOTA_DAMAGE_FLAG_IGNORES_MAGIC_ARMOR + DOTA_DAMAGE_FLAG_MAGIC_SPLASH,
                          ability = params.ability}) --deal damage

            local magic_splash_pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_warlock/warlock_fatal_bonds_pulse.vpcf", PATTACH_RENDERORIGIN_FOLLOW, self:GetCaster())
            ParticleManager:SetParticleControlEnt(magic_splash_pfx, 0, target, PATTACH_POINT_FOLLOW, "attach_attack1", target:GetAbsOrigin(), false)
            ParticleManager:SetParticleControlEnt(magic_splash_pfx, 1, x, PATTACH_POINT_FOLLOW, "attach_hitloc", x:GetAbsOrigin(), false)
            ParticleManager:SetParticleControl(magic_splash_pfx, 2, Vector(damage, 0, 0))
            ParticleManager:SetParticleControl(magic_splash_pfx, 3, Vector(0.3, 0, 0))
            ParticleManager:ReleaseParticleIndex(magic_splash_pfx)
        end
    end
end