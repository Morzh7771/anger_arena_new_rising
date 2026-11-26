-- Поводок босса. Вешает BossSpawner:SpawnBoss и тест aa_boss.
--   Пит - круг LEASH вокруг точки спавна. Вышел за него - бросает бой и бежит
--   обратно: проходит сквозь юнитов, +SPEED_PCT% скорости, урона не получает,
--   не кастует и не бьёт, ИИ молчит (SimpleAI:OnTick смотрит aa_leash_returning).
--   Вернулся в пит (RESUME_RANGE) и в пите есть враждебный герой - снова дерётся
--   с ближайшим. Героев нет - идёт до точки спавна.
--   За пределами пита урона не получает в любом случае: босса нельзя
--   вытащить и убить в стороне.
-- Точка берётся из слота босса (ротация её двигает), иначе - место спавна.

modifier_boss_leash = modifier_boss_leash or class({})
local mod = modifier_boss_leash

local LEASH           = 1000
local NO_DAMAGE_RANGE = LEASH
local RESUME_RANGE    = 900  -- запас, чтобы не дёргался на границе пита
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
		local hero = dist <= RESUME_RANGE and self:HeroInPit()

		if hero then
			self:SetReturning(false)
			parent:MoveToTargetToAttack(hero)
		elseif dist <= HOME_RANGE then
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

-- ближайший к боссу живой видимый враждебный герой внутри пита
function mod:HeroInPit()
	local parent = self:GetParent()
	local list = FindUnitsInRadius(parent:GetTeamNumber(), self:Home(), nil, LEASH,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_NO_INVIS + DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE,
		FIND_CLOSEST, false)

	for _, u in ipairs(list) do
		if u:IsAlive() and not u:IsIllusion() and parent:CanEntityBeSeenByMyTeam(u) then
			return u
		end
	end
end

function mod:OnDestroy()
	if not IsServer() then return end
	self:GetParent().aa_leash_returning = nil
end

function mod:CheckState()
	if self:GetStackCount() == 1 then
		return {
			[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
			[MODIFIER_STATE_SILENCED]          = true,
			[MODIFIER_STATE_MUTED]             = true,
			[MODIFIER_STATE_DISARMED]          = true,
		}
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
