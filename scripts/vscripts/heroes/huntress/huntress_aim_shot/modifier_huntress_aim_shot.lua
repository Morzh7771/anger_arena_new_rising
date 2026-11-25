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
        -- падение урона за пробитые цели - прямо в крите: свойство исходящего урона
        -- на удар стрелы не срабатывало (урон по всем целям был одинаковый), а так
        -- сниженная цифра ещё и видна над целью. Ниже 100% крит движок не берёт.
        local crit = self:GetAbility():GetSpecialValueFor("crit_damage_pct")
        local mult = parent.aa_aim_shot_arrow_mult or 1
        return math.max(100, crit * mult)
    end
end

-- падение урона стрелы за пробитые цели (множитель ставит OnProjectileHit на время PerformAttack)
function modifier_huntress_aim_shot:GetModifierTotalDamageOutgoing_Percentage(params)
    if not IsServer() then return 0 end
    local parent = self:GetParent()
    if params.attacker ~= parent or params.inflictor then return 0 end
    -- остаток снижения, который не влез в крит (крит не ниже 100%)
    local mult = parent.aa_aim_shot_arrow_mult
    if mult and mult < 1 then
        local crit = self:GetAbility():GetSpecialValueFor("crit_damage_pct")
        if crit * mult < 100 then return (crit * mult / 100 - 1) * 100 end
    end
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
    self.moveTo = nil
    self.engineMove = nil
    self.hold = false
    self:SyncBusy()
end

function modifier_huntress_aim_shot:SetAttackMove(pos)
    self:CancelWindup()
    self.target = nil
    self.attackMove = pos
    self.moveTo = nil
    self.engineMove = nil
    self.hold = false
    self:SyncBusy()
    local parent = self:GetParent()
    self:Internal(function() parent:MoveToPosition(pos) end)
end

-- шаг очереди с Shift: просто дойти до точки
function modifier_huntress_aim_shot:SetMoveTo(pos)
    self:CancelWindup()
    self.target = nil
    self.attackMove = nil
    self.moveTo = pos
    self.engineMove = nil
    self:SyncBusy()
    local parent = self:GetParent()
    self:Internal(function() parent:MoveToPosition(pos) end)
end

-- hold - Hold Position; engineMovePos - обычный приказ движения ушёл движку
-- (за ним может встать очередь с Shift, ждём, пока дойдёт)
function modifier_huntress_aim_shot:ClearOrders(hold, engineMovePos)
    self:CancelWindup()
    self.target = nil
    self.attackMove = nil
    self.moveTo = nil
    self.queue = {}
    self.aggro = false
    self.engineMove = engineMovePos
    self.engineMoveAt = GameRules:GetGameTime()
    self.hold = hold == true
    self:SyncBusy()
end

function modifier_huntress_aim_shot:HasTask()
    return self.target ~= nil or self.attackMove ~= nil or self.moveTo ~= nil or self.engineMove ~= nil
        or (self.queue ~= nil and #self.queue > 0)
end

-- очередь с Shift: { kind = "target"|"amove"|"move", target, pos }
function modifier_huntress_aim_shot:Enqueue(e)
    self.queue = self.queue or {}
    table.insert(self.queue, e)
end

-- текущий шаг кончился: следующий из очереди. Очередь пуста после атаки -
-- режим «бить всё, что подошло» (как стоять после A-клика), до приказа движения/стопа
function modifier_huntress_aim_shot:NextTask(wasAttack)
    self.target = nil
    self.attackMove = nil
    self.moveTo = nil
    self.engineMove = nil
    local e = self.queue and table.remove(self.queue, 1)
    if e then
        if e.kind == "target" then
            if self:IsTargetOk(e.target) then self:SetAttackTarget(e.target) else return self:NextTask(wasAttack) end
        elseif e.kind == "amove" then self:SetAttackMove(e.pos)
        else self:SetMoveTo(e.pos) end
        return
    end
    if wasAttack then self.aggro = true end
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

-- Hurricane Pike: двойной выстрел пики срабатывает на конце обычной атаки, а в стойке
-- её нет - поэтому вторую стрелу выпускаем здесь, по той же перезарядке пики
local PIKE_DELAY = 0.15

function modifier_huntress_aim_shot:PikeDoubleShot(target)
    local parent = self:GetParent()
    if parent:HasModifier("modifier_item_hurricane_pike_aa_cd") then return end
    local pike = parent:FindModifierByName("modifier_item_hurricane_pike_aa")
    local item = pike and pike:GetAbility()
    if not item or item:IsNull() then return end

    parent:AddNewModifier(parent, item, "modifier_item_hurricane_pike_aa_cd",
        { duration = item:GetSpecialValueFor("double_attack_cd") * parent:GetCooldownReduction() })

    local ability = self:GetAbility()
    Timers:CreateTimer(PIKE_DELAY, function()
        if parent:IsNull() or not parent:IsAlive() or not ability or ability:IsNull() then return end
        if not parent:HasModifier("modifier_huntress_aim_shot") then return end
        if not target or target:IsNull() or not target:IsAlive() then return end
        parent:EmitSound("Hero_Mirana.Attack")
        ability:FireArrow(target)
    end)
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
            self:PikeDoubleShot(self.target)
        end
        return
    end

    local range = self:AttackRange()

    -- обычный приказ движения у движка: ждём, пока дойдёт, потом очередь
    if self.engineMove then
        -- движок мог ещё не начать движение в первый тик - ждём 0.3 с простоя
        local arrived = (parent:GetAbsOrigin() - self.engineMove):Length2D() < 50
        if arrived or (parent:IsIdle() and now - (self.engineMoveAt or 0) > 0.3) then self:NextTask(false) end
        return
    end

    -- шаг очереди «дойти до точки»
    if self.moveTo then
        if (parent:GetAbsOrigin() - self.moveTo):Length2D() < 50 then
            self:NextTask(false)
        elseif parent:IsIdle() then
            local pos = self.moveTo
            self:Internal(function() parent:MoveToPosition(pos) end)
        end
        return
    end

    if not self:IsTargetOk(self.target) then
        local hadTarget = self.target ~= nil and not self.attackMove
        self.target = nil

        if self.attackMove then
            self.target = self:Acquire(range + ACQUIRE_BONUS)
            if not self.target then
                if (parent:GetAbsOrigin() - self.attackMove):Length2D() < 50 then
                    self:NextTask(true)
                elseif parent:IsIdle() then
                    -- цель умерла - идём дальше к точке атаки с движением
                    local pos = self.attackMove
                    self:Internal(function() parent:MoveToPosition(pos) end)
                end
                return
            end
        elseif hadTarget then
            -- явная цель умерла - следующий шаг очереди или «бить всё рядом»
            self:NextTask(true)
            if self.target or self.attackMove or self.moveTo then return end
        end

        -- после атаки стоим и бьём всё, что подошло (с Hold - только в дальности)
        if not self.target and self.aggro then
            self.target = self:Acquire(self.hold and range or (range + ACQUIRE_BONUS))
            if self.target then self:SyncBusy() end
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
    local queued = ord.queue == 1 or ord.queue == true
    local pos = Vector(ord.position_x or 0, ord.position_y or 0, ord.position_z or 0)

    -- Shift: пока стойка чем-то занята, приказ встаёт в её очередь
    if queued and mod:HasTask() then
        if t == DOTA_UNIT_ORDER_ATTACK_TARGET and target and target.GetTeamNumber
            and target:GetTeamNumber() ~= unit:GetTeamNumber() and target:GetUnitName() ~= "npc_teleport" then
            mod:Enqueue({ kind = "target", target = target })
            return false
        elseif t == DOTA_UNIT_ORDER_ATTACK_MOVE then
            mod:Enqueue({ kind = "amove", pos = pos })
            return false
        elseif t == DOTA_UNIT_ORDER_MOVE_TO_POSITION then
            mod:Enqueue({ kind = "move", pos = pos })
            return false
        end
        return nil
    end

    if t == DOTA_UNIT_ORDER_ATTACK_TARGET then
        -- клик по порталу - вход в портал (фильтр приказов дальше), не выстрел
        if target and target.GetUnitName and target:GetUnitName() == "npc_teleport" then return nil end
        if target and target.GetTeamNumber and target:GetTeamNumber() ~= unit:GetTeamNumber() then
            mod:SetAttackTarget(target)
            return false
        end
        return nil
    end

    if t == DOTA_UNIT_ORDER_ATTACK_MOVE then
        mod:SetAttackMove(pos)
        return false
    end

    if t == DOTA_UNIT_ORDER_HOLD_POSITION then
        mod:ClearOrders(true)
    elseif t == DOTA_UNIT_ORDER_MOVE_TO_POSITION then
        -- обычный клик в землю ведёт движок; Shift-приказы после него ждут в очереди стойки
        mod:ClearOrders(false, pos)
    elseif t == DOTA_UNIT_ORDER_MOVE_TO_TARGET
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
