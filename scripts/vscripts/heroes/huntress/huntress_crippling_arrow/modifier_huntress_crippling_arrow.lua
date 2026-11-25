modifier_huntress_crippling_arrow = modifier_huntress_crippling_arrow or class({})

--------------------------------------------------------------------------------
function modifier_huntress_crippling_arrow:IsHidden()
    return true
end

--------------------------------------------------------------------------------
function modifier_huntress_crippling_arrow:IsPurgable()
    return false
end

--------------------------------------------------------------------------------
function modifier_huntress_crippling_arrow:OnCreated(kv)
    self.duration_slow = self:GetAbility():GetSpecialValueFor("duration_slow")
end

--------------------------------------------------------------------------------
function modifier_huntress_crippling_arrow:OnRefresh(kv)
    self.duration_slow = self:GetAbility():GetSpecialValueFor("duration_slow")
end

--------------------------------------------------------------------------------
function modifier_huntress_crippling_arrow:DeclareFunctions()
    return { MODIFIER_EVENT_ON_ATTACK_LANDED, MODIFIER_PROPERTY_PROCATTACK_BONUS_DAMAGE_PHYSICAL }
end

-- каждая атака добавляет физический урон от ловкости
-- настоящая атака в стойке Aim Shot урон не наносит (урон и проки несёт стрела)
local function IsAimShotRealAttack(caster, record)
    local aim = caster:FindModifierByName("modifier_huntress_aim_shot")
    return aim and aim.IsRealAttack and not caster:IsIllusion() and aim:IsRealAttack(record)
end

-- каждая атака добавляет физический урон от ловкости
function modifier_huntress_crippling_arrow:GetModifierProcAttack_BonusDamage_Physical(params)
    if not IsServer() then return 0 end
    local caster = self:GetParent()
    if caster:PassivesDisabled() or params.target:IsBuilding() then return 0 end
    if IsAimShotRealAttack(caster, params.record) then return 0 end
    return caster:GetAgility() * self:GetAbility():GetSpecialValueFor("damage_agi_pct") / 100
end

--------------------------------------------------------------------------------
function modifier_huntress_crippling_arrow:OnAttackLanded(params)
    if not IsServer() then return end
    local caster = self:GetParent()
    if params.attacker ~= caster or caster:PassivesDisabled() then return end
    if IsAimShotRealAttack(caster, params.record) then return end

    local ability = self:GetAbility()
    if not ability:IsCooldownReady() then return end

    params.target:AddNewModifier(caster, ability, "modifier_huntress_crippling_arrow_slow", { duration = self.duration_slow })

    if RollPercentage(ability:GetSpecialValueFor("chance_root")) then
        local duration = ability:GetSpecialValueFor("duration_root")
        if ability:GetSpecialValueFor("stun_instead") > 0 then
            duration = duration * ability:GetSpecialValueFor("stun_duration_pct") / 100
            params.target:AddNewModifier(caster, ability, "modifier_huntress_crippling_arrow_stun", { duration = duration })
        else
            params.target:AddNewModifier(caster, ability, "modifier_huntress_crippling_arrow_root", { duration = duration })
        end
        ability:StartCooldown(ability:GetCooldown(ability:GetLevel() - 1))
    end
end
