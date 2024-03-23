LinkLuaModifier("modifier_item_khanda_custom", "items/item_khanda_custom", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_khanda_custom_debuff", "items/item_khanda_custom", LUA_MODIFIER_MOTION_NONE)

item_khanda = class({
    GetIntrinsicModifierName = function (self) return "modifier_item_khanda_custom" end
})

item_khanda_2 = item_khanda
item_khanda_3 = item_khanda

modifier_item_khanda_custom = class({
    IsHidden = function (self) return true end,
    IsPurgable = function (self) return false end,
    IsPurgeException = function (self) return false end,
    IsPurgable = function (self) return false end,
    RemoveOnDeath = function (self) return false end,
    DeclareFunctions = function (self)
        return
        {
            MODIFIER_EVENT_ON_TAKEDAMAGE,
            MODIFIER_PROPERTY_MANA_BONUS,
            MODIFIER_PROPERTY_HEALTH_BONUS,
            MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
            MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
            MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
            MODIFIER_EVENT_ON_SPELL_TARGET_READY,
            MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
            MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE
        }
    end,
    GetModifierPreAttack_BonusDamage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_damage") end,
    GetModifierManaBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_mana") end,
    GetModifierHealthBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_health") end,
    GetModifierBonusStats_Strength = function (self) return self:GetAbility():GetSpecialValueFor("bonus_all_stats") end,
    GetModifierBonusStats_Agility = function (self) return self:GetAbility():GetSpecialValueFor("bonus_all_stats") end,
    GetModifierBonusStats_Intellect = function (self) return self:GetAbility():GetSpecialValueFor("bonus_all_stats") end
})

function modifier_item_khanda_custom:OnSpellTargetReady(params)
	if not IsServer() then return end
	if params.unit ~= self:GetParent() then return end
	if params.unit:GetTeamNumber() == params.target:GetTeamNumber() then return end
	if not self:GetParent():IsRealHero() then return end
	if self:GetAbility():IsCooldownReady() == false then return end
	if self:GetParent():HasModifier("modifier_item_manaflare_lens_custom") then return end

    self:DealDamage(params)
end

function modifier_item_khanda_custom:OnTakeDamage(params)
	if not IsServer() then return end
	if params.attacker ~= self:GetParent() then return end
	if params.unit:GetTeamNumber() == params.attacker:GetTeamNumber() then return end
	if params.unit == self:GetParent() then return end
	if not self:GetParent():IsRealHero() then return end
	if params.inflictor == nil then return end
	if params.inflictor == self:GetAbility() then return end
	if params.inflictor:IsItem() then return end
	if self:GetAbility():IsCooldownReady() == false then return end
	if not self:GetAbility():IsFullyCastable() then return end
	if self:GetParent():HasModifier("modifier_item_manaflare_lens_custom") then return end

    self:DealDamage(params)
end

function modifier_item_khanda_custom:GetModifierPreAttack_CriticalStrike(params)
    if self:LegitimateAttack(params) then
        local chance = self:GetAbility():GetSpecialValueFor("crit_chance") / 100

        local stacked_chance = 1 - math.pow((1 - chance), #self:GetParent():FindAllModifiersByName('modifier_item_khanda_custom'))

        local proc = (RandomInt(1, 100) + math.random()) / 100

        if proc <= stacked_chance then
            self.record = params.record
            return self:GetAbility():GetSpecialValueFor("crit_multiplier")
        end
    end
end

function modifier_item_khanda_custom:DealDamage(params)
    local target = params.target or params.unit

    local damage = self:GetAbility():GetSpecialValueFor("spell_crit_flat") + self:GetAbility():GetSpecialValueFor("spell_crit_multiplier") / 100 * self:GetParent():GetAverageTrueAttackDamage(self:GetParent())
    SendOverheadEventMessage(target, 4, target, damage, nil)

    self:GetAbility():UseResources(true, false, false, true)
    ApplyDamage({attacker = self:GetCaster(), victim = target, ability = self:GetAbility(), damage = damage, damage_type = DAMAGE_TYPE_MAGICAL})
    target:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_item_khanda_custom_debuff", {duration = self:GetAbility():GetSpecialValueFor("slow_duration")})

    local particle = ParticleManager:CreateParticle("particles/items_fx/khanda_target.vpcf", PATTACH_ABSORIGIN_FOLLOW, params.unit)
    ParticleManager:SetParticleControlEnt(particle, 0, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)
    ParticleManager:ReleaseParticleIndex(particle)

    local particle_2 = ParticleManager:CreateParticle("particles/items_fx/khanda.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
    ParticleManager:SetParticleControlEnt(particle_2, 0, self:GetParent(), PATTACH_POINT_FOLLOW, "attach_hitloc", self:GetParent():GetAbsOrigin(), true)
    ParticleManager:SetParticleControlEnt(particle_2, 1, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)
    ParticleManager:ReleaseParticleIndex(particle_2)

    target:EmitSound("Item.Phylactery.Target")
end

modifier_item_khanda_custom_debuff = class({
    GetTexture = function (self) return "buffs/manaflare" end,
    GetModifierMoveSpeedBonus_Percentage = function (self) return self:GetAbility():GetSpecialValueFor("slow") end,
    DeclareFunctions = function (self)
        return
        {
            MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE
        }
    end
})