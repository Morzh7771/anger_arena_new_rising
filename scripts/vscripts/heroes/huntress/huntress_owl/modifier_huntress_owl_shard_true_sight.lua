modifier_huntress_owl_shard_true_sight = modifier_huntress_owl_shard_true_sight or class({})

function modifier_huntress_owl_shard_true_sight:OnCreated(kv)
    if IsServer() then
        self:StartIntervalThink(0.1)
    end
end

function modifier_huntress_owl_shard_true_sight:IsAura()
    return true
end

function modifier_huntress_owl_shard_true_sight:IsHidden()
    return true
end

function modifier_huntress_owl_shard_true_sight:IsPurgable()
    return false
end

function modifier_huntress_owl_shard_true_sight:RemoveOnDeath()
    return false
end

function modifier_huntress_owl_shard_true_sight:GetAuraRadius()
    return self:GetAbility():GetSpecialValueFor("shard_true_sight_radius")
end

function modifier_huntress_owl_shard_true_sight:GetAuraSearchTeam()
    return DOTA_UNIT_TARGET_TEAM_ENEMY
end

function modifier_huntress_owl_shard_true_sight:GetAuraSearchType()
    return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
end

function modifier_huntress_owl_shard_true_sight:GetAuraSearchFlags()
    return DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES
end

function modifier_huntress_owl_shard_true_sight:GetModifierAura()
    return "modifier_truesight"
end

function modifier_huntress_owl_shard_true_sight:OnIntervalThink()
    if not IsServer() then return end

    local owl = self:GetParent()
    local caster = self:GetCaster()

    if not caster:HasShard() then
        self:Destroy()
        return
    end
end
