-- Поводок босса. Вешает BossSpawner:SpawnBoss и тест aa_boss.
--   Дальше LEASH от точки спавна - босс бросает бой и бежит домой: проходит
--   сквозь юнитов, +SPEED_PCT% скорости, урона не получает, ИИ молчит
--   (SimpleAI:OnTick смотрит aa_leash_returning). Возврат кончается у точки.
--   Дальше NO_DAMAGE_RANGE урона не получает в любом случае: босса нельзя
--   вытащить с пита и убить в стороне.
-- Точка берётся из слота босса (ротация её двигает), иначе - место спавна.

modifier_boss_leash = modifier_boss_leash or class({})
local mod = modifier_boss_leash

local LEASH           = 1300
local NO_DAMAGE_RANGE = 1100
local HOME_RANGE      = 100
local SPEED_PCT       = 100
local TICK            = 0.2

function mod:IsHidden()      return true  end
function mod:IsPurgable()    return false end
function mod:RemoveOnDeath() return true  end

function mod:OnCreated()
	if not IsServer() then return end
	self.spawn = self:GetParent():GetAbsOrigin()
	self.returning = false
	self:StartIntervalThink(TICK)
end

function mod:Home()
	local parent = self:GetParent()
	local boss = BossSpawner and BossSpawner.bossCurrent and BossSpawner.bossCurrent[parent]
	return (boss and boss.point) or self.spawn
end

function mod:Dist()
	return (self:GetParent():GetAbsOrigin() - self:Home()):Length2D()
end

function mod:SetReturning(on)
	local parent = self:GetParent()
	self.returning = on
	parent.aa_leash_returning = on or nil
	self:SetStackCount(on and 1 or 0)
end

function mod:OnIntervalThink()
	local parent = self:GetParent()
	if not parent:IsAlive() then return end

	-- телепорт ротации сам ставит босса на новую точку
	if parent:HasModifier("modifier_boss_rotation") then
		if self.returning then self:SetReturning(false) end
		return
	end

	local dist = self:Dist()

	if not self.returning and dist > LEASH then
		self:SetReturning(true)
		parent:Stop()
	end

	if self.returning then
		if dist <= HOME_RANGE then
			self:SetReturning(false)
			parent:Stop()
			local boss = BossSpawner and BossSpawner.bossCurrent and BossSpawner.bossCurrent[parent]
			if boss and boss.forward then parent:SetForwardVector(boss.forward) end
		else
			-- стан/рут сбивает приказ - повторяем каждый тик
			parent:MoveToPosition(self:Home())
		end
	end
end

function mod:OnDestroy()
	if not IsServer() then return end
	self:GetParent().aa_leash_returning = nil
end

function mod:CheckState()
	if self:GetStackCount() == 1 then
		return { [MODIFIER_STATE_NO_UNIT_COLLISION] = true }
	end
	return {}
end

function mod:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL,
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL,
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE,
	}
end

function mod:GetModifierMoveSpeedBonus_Percentage()
	return self:GetStackCount() == 1 and SPEED_PCT or 0
end

function mod:NoDamage()
	if not IsServer() then return 0 end
	if self.returning or self:Dist() > NO_DAMAGE_RANGE then return 1 end
	return 0
end

function mod:GetAbsoluteNoDamageMagical()  return self:NoDamage() end
function mod:GetAbsoluteNoDamagePhysical() return self:NoDamage() end
function mod:GetAbsoluteNoDamagePure()     return self:NoDamage() end
