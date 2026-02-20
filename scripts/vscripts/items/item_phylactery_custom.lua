LinkLuaModifier("modifier_item_phylactery_custom", "items/item_phylactery_custom", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_phylactery_custom_debuff", "items/item_phylactery_custom", LUA_MODIFIER_MOTION_NONE)

item_phylactery = class({
    Precache = function (self, context) 
        PrecacheResource("particle", "particles/items_fx/phylactery_target.vpcf", context)
        PrecacheResource("particle", "particles/items_fx/phylactery.vpcf", context)
    end,
    GetIntrinsicModifierName = function (self) return "modifier_item_phylactery_custom" end
})

item_phylactery_2 = item_phylactery

modifier_item_phylactery_custom = class({
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
            MODIFIER_PROPERTY_CAST_RANGE_BONUS_STACKING,
            MODIFIER_EVENT_ON_SPELL_TARGET_READY
        }
    end,
    GetModifierManaBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_mana") end,
    GetModifierHealthBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_health") end,
    GetModifierBonusStats_Strength = function (self) return self:GetAbility():GetSpecialValueFor("bonus_all_stats") end,
    GetModifierBonusStats_Agility = function (self) return self:GetAbility():GetSpecialValueFor("bonus_all_stats") end,
    GetModifierBonusStats_Intellect = function (self) return self:GetAbility():GetSpecialValueFor("bonus_all_stats") end
})

function modifier_item_phylactery_custom:GetModifierCastRangeBonusStacking()
    if self:GetCaster():HasModifier("modifier_item_aether_lens") then return end

	return self:GetAbility():GetSpecialValueFor("cast_range_bonus")
end

function modifier_item_phylactery_custom:OnSpellTargetReady(params)
	if not IsServer() then return end
	if params.unit ~= self:GetParent() then return end
	if params.unit:GetTeamNumber() == params.target:GetTeamNumber() then return end
	if not self:GetParent():IsRealHero() then return end
	if self:GetAbility():IsCooldownReady() == false then return end
	if self:GetParent():HasModifier("modifier_item_manaflare_lens_custom") then return end
	if self:GetParent():HasModifier("modifier_item_khanda_custom") then return end

    self:DealDamage(params)
end
function modifier_item_phylactery_custom:OnTakeDamage(params)
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
	if self:GetParent():HasModifier("modifier_item_khanda_custom") then return end

    self:DealDamage(params)
end

function modifier_item_phylactery_custom:DealDamage(params)
    local target = params.target or params.unit

    local damage = self:GetAbility():GetSpecialValueFor("bonus_spell_damage")
    SendOverheadEventMessage(target, 4, target, damage, nil)

    self:GetAbility():UseResources(true, false, false, true)
    ApplyDamage({attacker = self:GetCaster(), victim = target, ability = self:GetAbility(), damage = damage, damage_type = DAMAGE_TYPE_MAGICAL})
    target:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_item_phylactery_custom_debuff", {duration = self:GetAbility():GetSpecialValueFor("slow_duration")})

    local particle = ParticleManager:CreateParticle("particles/items_fx/phylactery_target.vpcf", PATTACH_ABSORIGIN_FOLLOW, params.unit)
    ParticleManager:SetParticleControlEnt(particle, 0, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)
    ParticleManager:ReleaseParticleIndex(particle)

    local particle_2 = ParticleManager:CreateParticle("particles/items_fx/phylactery.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
    ParticleManager:SetParticleControlEnt(particle_2, 0, self:GetParent(), PATTACH_POINT_FOLLOW, "attach_hitloc", self:GetParent():GetAbsOrigin(), true)
    ParticleManager:SetParticleControlEnt(particle_2, 1, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)
    ParticleManager:ReleaseParticleIndex(particle_2)

    target:EmitSound("Item.Phylactery.Target")
end

modifier_item_phylactery_custom_debuff = class({
    GetTexture = function (self) return "buffs/manaflare" end,
    GetModifierMoveSpeedBonus_Percentage = function (self) return self:GetAbility():GetSpecialValueFor("slow") end,
    DeclareFunctions = function (self)
        return
        {
            MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE
        }
    end
})