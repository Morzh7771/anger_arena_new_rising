modifier_huntress_aim_shot = modifier_huntress_aim_shot or class({})

-- стойка замедляет атаку (BAT выше базового) - modifier_bat берёт её как есть
modifier_huntress_aim_shot.AA_BAT_FORCE = true

-- BAT героя из hero_data.txt (AttackRate): штраф стойки прибавляется к нему
local HERO_BAT = 1.7

function modifier_huntress_aim_shot:IsDebuff() return false end
function modifier_huntress_aim_shot:IsPurgable() return false end
function modifier_huntress_aim_shot:IsHidden() return false end

-- выше всех: снаряд атаки прячем всегда, никакой предмет (Disperser и т.п.) не подменит
function modifier_huntress_aim_shot:GetPriority() return MODIFIER_PRIORITY_SUPER_ULTRA end

function modifier_huntress_aim_shot:GetEffectName()
    return "particles/huntress/huntress_aim_shot/huntress_aim_shot.vpcf"
end

function modifier_huntress_aim_shot:GetEffectAttachType()
    return PATTACH_OVERHEAD_FOLLOW
end

function modifier_huntress_aim_shot:OnCreated()
    -- записи настоящих атак: они не наносят урон, урон наносит только стрела
    self.real_records = {}
end

function modifier_huntress_aim_shot:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_BASE_ATTACK_TIME_CONSTANT,
        MODIFIER_PROPERTY_ATTACK_RANGE_BONUS,
        MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
        MODIFIER_PROPERTY_PROJECTILE_NAME,
        MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE,
        MODIFIER_EVENT_ON_ATTACK_RECORD,
        MODIFIER_EVENT_ON_ATTACK_RECORD_DESTROY,
        MODIFIER_EVENT_ON_ATTACK,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
    }
end

function modifier_huntress_aim_shot:GetModifierBaseAttackTimeConstant()
    local ability = self:GetAbility()
    if not ability or ability:IsNull() then return end
    return HERO_BAT + ability:GetSpecialValueFor("bat_penalty")
end

function modifier_huntress_aim_shot:GetModifierAttackRangeBonus()
    return self:GetAbility():GetSpecialValueFor("bonus_attack_range")
end

function modifier_huntress_aim_shot:GetModifierPreAttack_CriticalStrike(params)
    if not IsServer() then return end
    if params.target and params.attacker == self:GetParent() then
        return self:GetAbility():GetSpecialValueFor("crit_damage_pct")
    end
end

function modifier_huntress_aim_shot:GetModifierProjectileName()
    return "particles/dev/empty_particle.vpcf"
end

-- падение урона стрелы за пробитые цели (множитель ставит FireArrow на время PerformAttack)
function modifier_huntress_aim_shot:GetModifierTotalDamageOutgoing_Percentage(params)
    if not IsServer() then return 0 end
    local parent = self:GetParent()
    if params.attacker ~= parent or params.inflictor then return 0 end
    local mult = parent.aa_aim_shot_arrow_mult
    if mult and mult < 1 then return (mult - 1) * 100 end
    return 0
end

function modifier_huntress_aim_shot:OnAttackRecord(params)
    if not IsServer() then return end
    local parent = self:GetParent()
    if params.attacker ~= parent or parent.aa_aim_shot_arrow then return end
    self.real_records[params.record] = true
end

function modifier_huntress_aim_shot:OnAttackRecordDestroy(params)
    if not IsServer() then return end
    if params.attacker ~= self:GetParent() then return end
    self.real_records[params.record] = nil
end

-- настоящая атака: стрела по направлению цели (huntress_aim_shot:FireArrow)
function modifier_huntress_aim_shot:OnAttack(params)
    if not IsServer() then return end
    local parent = self:GetParent()
    if params.attacker ~= parent or parent.aa_aim_shot_arrow then return end
    if parent:IsIllusion() or not params.target then return end
    local ability = self:GetAbility()
    if ability and ability.FireArrow then ability:FireArrow(params.target) end
end

-- настоящая атака долетела: её урон гасит DamageFilter (addon_game_mode.lua),
-- от цели урон приходит только стрелой, от которой можно уйти
function modifier_huntress_aim_shot:OnAttackLanded(params)
    if not IsServer() then return end
    local parent = self:GetParent()
    if params.attacker ~= parent or not self.real_records[params.record] then return end
    if parent:IsIllusion() then return end
    parent.aa_aim_shot_null_victim = params.target and params.target:entindex()
end

-- свои проки (Crippling Arrow, чары) на настоящей атаке не срабатывают
function modifier_huntress_aim_shot:IsRealAttack(record)
    return self.real_records[record] == true
end

-- для проков из других файлов: атака героя в стойке, урон которой гасится
function HuntressAimShotIsNullAttack(unit, record)
    if not unit or unit:IsNull() or unit:IsIllusion() or not record then return false end
    local aim = unit:FindModifierByName("modifier_huntress_aim_shot")
    return aim ~= nil and aim.IsRealAttack ~= nil and aim:IsRealAttack(record)
end
