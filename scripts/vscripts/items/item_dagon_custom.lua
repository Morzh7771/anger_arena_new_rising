LinkLuaModifier("modifier_item_dagon_custom", "items/item_dagon_custom", LUA_MODIFIER_MOTION_NONE)

item_dagon_custom = class({
    GetIntrinsicModifierName = function (self) return "modifier_item_dagon_custom" end,
    GetAOERadius = function (self) return self:GetSpecialValueFor("aoe_radius") end,
})

function item_dagon_custom:OnSpellStart()
    if not IsServer() then return end
    local point = self:GetCursorTarget():GetAbsOrigin()
    local int = self:GetSpecialValueFor("stat_primary_damage_pct")/100

    self:GetCursorTarget():EmitSound("DOTA_Item.Dagon5.Target")

    if self:GetCursorTarget():TriggerSpellAbsorb(self) then return end

    print(self:GetCaster():GetPrimaryStatValue())
    local radius = self:GetSpecialValueFor("aoe_radius")
    local damage_kv = self:GetSpecialValueFor("damage")
    local damage = damage_kv + (self:GetCaster():GetPrimaryStatValue()/3 * int)
    self:GetCaster():EmitSound("DOTA_Item.Dagon.Activate")
    local enemies = FindUnitsInRadius( self:GetCaster():GetTeamNumber(), point, nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, 0, FIND_CLOSEST, false )
    for _, enemy in pairs(enemies) do

            local dagon_pfx = ParticleManager:CreateParticle("particles/items_fx/dagon.vpcf", PATTACH_RENDERORIGIN_FOLLOW, self:GetCaster())
            ParticleManager:SetParticleControlEnt(dagon_pfx, 0, self:GetCaster(), PATTACH_POINT_FOLLOW, "attach_attack1", self:GetCaster():GetAbsOrigin(), false)
            ParticleManager:SetParticleControlEnt(dagon_pfx, 1, enemy, PATTACH_POINT_FOLLOW, "attach_hitloc", enemy:GetAbsOrigin(), false)
            ParticleManager:SetParticleControl(dagon_pfx, 2, Vector(damage, 0, 0))
            ParticleManager:SetParticleControl(dagon_pfx, 3, Vector(0.3, 0, 0))
            ParticleManager:ReleaseParticleIndex(dagon_pfx)

            local damage = ApplyDamage({ attacker = self:GetCaster(), victim = enemy, ability = self, damage = damage, damage_type = DAMAGE_TYPE_MAGICAL })
            
            if enemy == self:GetCursorTarget() then 
                self:GetCaster():Heal(damage*self:GetSpecialValueFor("active_heal")/100, self)
            end

            if enemy:IsIllusion() and not enemy:HasModifier("modifier_chaos_knight_phantasm_illusion") then
                enemy:Kill(self, self:GetCaster())
            end

    end
end

modifier_item_dagon_custom = class({
    IsHidden = function (self) return true end,
    IsPurgable = function (self) return false end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
        MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_EVENT_ON_TAKEDAMAGE
    } end,
    GetModifierBonusStats_Strength = function (self) if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("bonus_stats") end end,
    GetModifierBonusStats_Agility = function (self) if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("bonus_stats") end end,
    GetModifierBonusStats_Intellect = function (self) if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("bonus_stats") end end,
})

function modifier_item_dagon_custom:OnTakeDamage(params)
    if params.unit == self:GetParent() then return end
    if params.attacker ~= self:GetParent() then return end
    if params.inflictor == nil then return end
    if self:GetParent():IsIllusion() then return end
    if not params.unit then return end
    if bit.band(params.damage_flags, DOTA_DAMAGE_FLAG_REFLECTION) == DOTA_DAMAGE_FLAG_REFLECTION then return end
    if params.unit:IsIllusion() then return end
    if (params.unit:GetAbsOrigin() - self:GetParent():GetAbsOrigin()):Length2D() > 2000 then return end

    self.lifesteal = self:GetAbility():GetSpecialValueFor("spell_lifesteal")/100

    local lifesteal = self.lifesteal


    local heal = params.damage * lifesteal


    self:GetParent():Heal(heal, self:GetAbility())

    local particle = ParticleManager:CreateParticle( "particles/items3_fx/octarine_core_lifesteal.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent() )
    ParticleManager:ReleaseParticleIndex( particle )
end


