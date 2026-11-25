modifier_huntress_aim_shot = modifier_huntress_aim_shot or class({})

-- Стойка Aim Shot: атакует свой цикл ниже, обычная атака ни разу не вылетает.
-- Автоатаку выбирает движок по настройке игрока: пока цикл свободен, Huntress не
-- обезоружена, и движок сам решает, бить ли ближайшего. Как только он начал
-- замах (OnAttackStart), цикл забирает цель и вешает обезоруживание
-- (modifier_huntress_aim_shot_busy) - замах движка срывается до выстрела.
-- Приказ атаки (клик, атака с движением, автоатака движка) -> подойти
-- на дальность, замах анимацией атаки, выпустить пронзающую стрелу
-- (huntress_aim_shot:FireArrow). Урон и все проки - только у стрелы, поэтому
-- от неё можно уйти, а настоящей атаки, которая что-то навешивала бы, нет.
-- Стрелять можно и по бесплотным (Ghost и т.п.): стрела летит, но урона не наносит.

-- стойка замедляет атаку (BAT выше базового) - modifier_bat берёт её как есть
modifier_huntress_aim_shot.AA_BAT_FORCE = true

-- BAT героя из hero_data.txt (AttackRate): штраф стойки прибавляется к нему
local HERO_BAT = 1.7

local THINK = 0.03
local MOVE_REPEAT = 0.25      -- как часто переотдавать погоню за целью
local FACE_DEG = 15           -- насколько надо смотреть на цель, чтобы начать замах
local ACQUIRE_BONUS = 200     -- атака с движением цепляет врагов чуть дальше дальности атаки

function modifier_huntress_aim_shot:IsDebuff() return false end
function modifier_huntress_aim_shot:IsPurgable() return false end
function modifier_huntress_aim_shot:IsHidden() return false end
function modifier_huntress_aim_shot:RemoveOnDeath() return false end

function modifier_huntress_aim_shot:GetEffectName()
    return "particles/huntress/huntress_aim_shot/huntress_aim_shot.vpcf"
end

function modifier_huntress_aim_shot:GetEffectAttachType()
    return PATTACH_OVERHEAD_FOLLOW
end

-- пока цикл занят (цель, атака с движением, замах) - обычная атака запрещена
modifier_huntress_aim_shot_busy = modifier_huntress_aim_shot_busy or class({})
function modifier_huntress_aim_shot_busy:IsHidden() return true end
function modifier_huntress_aim_shot_busy:IsPurgable() return false end
function modifier_huntress_aim_shot_busy:RemoveOnDeath() return true end
function modifier_huntress_aim_shot_busy:CheckState() return { [MODIFIER_STATE_DISARMED] = true } end

function modifier_huntress_aim_shot:SyncBusy()
    local parent = self:GetParent()
    local busy = self.target ~= nil or self.attackMove ~= nil or self.windupEnd ~= nil
    local has = parent:HasModifier("modifier_huntress_aim_shot_busy")
    if busy and not has then
        parent:AddNewModifier(parent, self:GetAbility(), "modifier_huntress_aim_shot_busy", {})
    elseif not busy and has then
        parent:RemoveModifierByName("modifier_huntress_aim_shot_busy")
    end
end

-- движок начал обычную атаку (автоатака по настройке игрока или его приказ мимо фильтра):
-- цель забираем себе, замах движка срывает обезоруживание
function modifier_huntress_aim_shot:OnAttackStart(params)
    if not IsServer() then return end
    local parent = self:GetParent()
    if params.attacker ~= parent or parent.aa_aim_shot_arrow or parent:IsIllusion() then return end
    if not params.target or params.target:IsNull() then return end
    if self.target ~= params.target then
        self:CancelWindup()
        self.target = params.target
    end
    self:SyncBusy()
end

function modifier_huntress_aim_shot:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_BASE_ATTACK_TIME_CONSTANT,
        MODIFIER_PROPERTY_ATTACK_RANGE_BONUS,
        MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
        MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE,
        MODIFIER_EVENT_ON_ATTACK_START,
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

-- крит - удар стрелы (PerformAttack из OnProjectileHit)
function modifier_huntress_aim_shot:GetModifierPreAttack_CriticalStrike(params)
    if not IsServer() then return end
    local parent = self:GetParent()
    if params.target and params.attacker == parent and parent.aa_aim_shot_arrow then
        return self:GetAbility():GetSpecialValueFor("crit_damage_pct")
    end
end

-- падение урона стрелы за пробитые цели (множитель ставит OnProjectileHit на время PerformAttack)
function modifier_huntress_aim_shot:GetModifierTotalDamageOutgoing_Percentage(params)
    if not IsServer() then return 0 end
    local parent = self:GetParent()
    if params.attacker ~= parent or params.inflictor then return 0 end
    local mult = parent.aa_aim_shot_arrow_mult
    if mult and mult < 1 then return (mult - 1) * 100 end
    return 0
end

--------------------------------------------------------------------------------
-- цикл атаки

function modifier_huntress_aim_shot:OnCreated()
    if not IsServer() then return end
    local parent = self:GetParent()
    if parent:IsIllusion() then return end

    self.nextAttack = 0
    self.lastMove = 0

    -- включили посреди атаки - продолжаем по той же цели
    local cur = parent.GetAttackTarget and parent:GetAttackTarget()
    if cur and not cur:IsNull() then self.target = cur end

    self:SyncBusy()
    self:StartIntervalThink(THINK)
end

function modifier_huntress_aim_shot:OnDestroy()
    if not IsServer() then return end
    local parent = self:GetParent()
    if parent:IsIllusion() then return end
    self:CancelWindup()
    parent:RemoveModifierByName("modifier_huntress_aim_shot_busy")

    -- выключили стойку с целью - дальше обычная атака по ней
    if self:IsTargetOk(self.target) and parent:IsAlive() then
        self:Internal(function() parent:MoveToTargetToAttack(self.target) end)
    end
end

-- свои приказы герою: фильтр приказов их пропускает
function modifier_huntress_aim_shot:Internal(fn)
    local parent = self:GetParent()
    parent.aa_aim_internal_order = true
    pcall(fn)
    parent.aa_aim_internal_order = nil
end

function modifier_huntress_aim_shot:IsTargetOk(t)
    local parent = self:GetParent()
    return t ~= nil and not t:IsNull() and t:IsAlive()
        and t:GetTeamNumber() ~= parent:GetTeamNumber()
        and parent:CanEntityBeSeenByMyTeam(t)
        and not t:IsInvulnerable()
end

function modifier_huntress_aim_shot:SetAttackTarget(t)
    if self.target ~= t then self:CancelWindup() end
    self.target = t
    self.attackMove = nil
    self.hold = false
    self:SyncBusy()
end

function modifier_huntress_aim_shot:SetAttackMove(pos)
    self:CancelWindup()
    self.target = nil
    self.attackMove = pos
    self.hold = false
    self:SyncBusy()
    local parent = self:GetParent()
    self:Internal(function() parent:MoveToPosition(pos) end)
end

function modifier_huntress_aim_shot:ClearOrders(hold)
    self:CancelWindup()
    self.target = nil
    self.attackMove = nil
    self.hold = hold == true
    self:SyncBusy()
end

function modifier_huntress_aim_shot:CancelWindup()
    if not self.windupEnd then return end
    self.windupEnd = nil
    local parent = self:GetParent()
    if parent and not parent:IsNull() then parent:FadeGesture(ACT_DOTA_ATTACK) end
end

function modifier_huntress_aim_shot:Acquire(radius)
    local parent = self:GetParent()
    local list = FindUnitsInRadius(parent:GetTeamNumber(), parent:GetAbsOrigin(), nil, radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS + DOTA_UNIT_TARGET_FLAG_NOT_ATTACK_IMMUNE
            + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_CLOSEST, false)
    return list[1]
end

function modifier_huntress_aim_shot:AttackRange()
    local parent = self:GetParent()
    return parent:Script_GetAttackRange()
end

function modifier_huntress_aim_shot:OnIntervalThink()
    local parent = self:GetParent()
    local ability = self:GetAbility()
    if not ability or ability:IsNull() then return end
    if not parent:IsAlive() then self:ClearOrders(); return end

    -- оглушён, в хексе, кастует - замах сбивается, цель остаётся
    if parent:IsStunned() or parent:IsHexed() or parent:IsFrozen() or parent:IsChanneling()
        or parent:GetCurrentActiveAbility() ~= nil then
        self:CancelWindup()
        return
    end

    local now = GameRules:GetGameTime()

    -- замах дошёл до точки выстрела
    if self.windupEnd then
        if not self:IsTargetOk(self.target) then
            self:CancelWindup()
        elseif now >= self.windupEnd then
            self.windupEnd = nil
            parent:EmitSound("Hero_Mirana.Attack")
            ability:FireArrow(self.target)
        end
        return
    end

    local range = self:AttackRange()

    if not self:IsTargetOk(self.target) then
        self.target = nil

        if self.attackMove then
            self.target = self:Acquire(range + ACQUIRE_BONUS)
            if not self.target then
                if (parent:GetAbsOrigin() - self.attackMove):Length2D() < 50 then
                    self.attackMove = nil
                elseif parent:IsIdle() then
                    -- цель умерла - идём дальше к точке атаки с движением
                    local pos = self.attackMove
                    self:Internal(function() parent:MoveToPosition(pos) end)
                end
                return
            end
        end

        -- цели нет - свободны, автоатаку решает движок
        if not self.target then self:SyncBusy(); return end
    end

    local t = self.target
    local delta = t:GetAbsOrigin() - parent:GetAbsOrigin()
    delta.z = 0
    local dist = delta:Length2D() - parent:GetHullRadius() - t:GetHullRadius()

    if dist > range then
        if self.hold then self.target = nil; return end
        if now - self.lastMove >= MOVE_REPEAT then
            self.lastMove = now
            self:Internal(function() parent:MoveToNPC(t) end)
        end
        return
    end

    -- в дальности: стоим и разворачиваемся к цели
    if parent:IsMoving() then self:Internal(function() parent:Stop() end) end

    local fwd = parent:GetForwardVector()
    local want = delta:Normalized()
    local angle = math.deg(math.acos(math.max(-1, math.min(1, fwd.x * want.x + fwd.y * want.y))))

    if angle > FACE_DEG then
        parent:FaceTowards(t:GetAbsOrigin())
        return
    end

    if now < self.nextAttack then return end

    -- замах: анимация атаки ускоряется скоростью атаки, как у обычной
    local speed = math.max(0.1, parent:GetAttackSpeed(false))
    self.windupEnd = now + parent:GetAttackAnimationPoint() / speed
    self.nextAttack = now + parent:GetSecondsPerAttack(false)
    parent:StartGestureWithPlaybackRate(ACT_DOTA_ATTACK, speed)
end

--------------------------------------------------------------------------------
-- фильтр приказов (AngelArena:ExecuteOrderFilterCustom). false - приказ
-- забрала стойка, nil - пусть идёт как обычно.
-- файл модификатора грузится в своей области видимости: в _G явно, иначе
-- addon_game_mode.lua функцию не видит и приказы мимо стойки
function _G.HuntressAimShotOrder(unit, ord, target)
    if not unit or unit:IsNull() or unit:IsIllusion() or unit.aa_aim_internal_order then return nil end
    local mod = unit:FindModifierByName("modifier_huntress_aim_shot")
    if not mod or not mod.SetAttackTarget then return nil end

    local t = ord.order_type

    if t == DOTA_UNIT_ORDER_ATTACK_TARGET then
        if target and target.GetTeamNumber and target:GetTeamNumber() ~= unit:GetTeamNumber() then
            mod:SetAttackTarget(target)
            return false
        end
        return nil
    end

    if t == DOTA_UNIT_ORDER_ATTACK_MOVE then
        mod:SetAttackMove(Vector(ord.position_x, ord.position_y, ord.position_z))
        return false
    end

    if t == DOTA_UNIT_ORDER_HOLD_POSITION then
        mod:ClearOrders(true)
    elseif t == DOTA_UNIT_ORDER_MOVE_TO_POSITION or t == DOTA_UNIT_ORDER_MOVE_TO_TARGET
        or t == DOTA_UNIT_ORDER_STOP or t == DOTA_UNIT_ORDER_MOVE_TO_DIRECTION
        or t == DOTA_UNIT_ORDER_PATROL or t == DOTA_UNIT_ORDER_PICKUP_ITEM
        or t == DOTA_UNIT_ORDER_PICKUP_RUNE then
        mod:ClearOrders(false)
    end
    -- касты и прочее цель не сбрасывают: после каста стрельба продолжится

    return nil
end

-- старые вызовы из предметов/скиллов: настоящих атак в стойке больше нет
function modifier_huntress_aim_shot:IsRealAttack(record) return false end

function _G.HuntressAimShotIsNullAttack(unit, record) return false end
