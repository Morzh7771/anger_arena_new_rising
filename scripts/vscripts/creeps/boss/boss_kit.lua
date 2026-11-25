-- Общие детали боссов с механиками (Леорик, Хранитель Часов, Чумной Жнец).
--   BossKit:Telegraph   - круг на земле с обратным отсчётом (как у Лича 1х6)
--   BossKit:Enemies     - враги в радиусе
--   BossKit:PctDamage   - чистый урон в % от макс. HP цели
--   BossKit:KillCredit  - кому засчитать убийство (герой-хозяин самона/иллюзии)
--   modifier_boss_kit_pips - юнит ломается N ударами любого героя, урон не важен

BossKit = BossKit or {}

LinkLuaModifier("modifier_boss_kit_pips", "creeps/boss/boss_kit", LUA_MODIFIER_MOTION_NONE)

local TELEGRAPH = "particles/units/heroes/hero_snapfire/hero_snapfire_ultimate_calldown.vpcf"

-- Телеграфы отдаются хэндлом { idx = ... }, а не голым индексом: круг гаснет
-- сам по таймеру, а скилл часто снимает его ещё раз в OnSpellStart /
-- OnAbilityPhaseInterrupted. С голым индексом второе снятие освобождало уже
-- чужой партикл, которому движок выдал тот же номер. Хэндл гасится один раз.
local function Handle(idx)
	return { idx = idx }
end

local function Kill(h, immediate)
	if not h or h.dead then return end
	h.dead = true
	ParticleManager:DestroyParticle(h.idx, immediate == true)
	ParticleManager:ReleaseParticleIndex(h.idx)
end

-- Круг на точке на delay секунд. Вернёт хэндл (можно снять раньше StopParticle).
function BossKit:Telegraph(pos, radius, delay)
	local idx = ParticleManager:CreateParticle(TELEGRAPH, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(idx, 0, pos)
	ParticleManager:SetParticleControl(idx, 1, Vector(radius, 0, -radius))
	ParticleManager:SetParticleControl(idx, 2, Vector(delay, 0, 0))

	local h = Handle(idx)
	Timers:CreateTimer(delay, function() Kill(h) end)

	return h
end

-- Тот же круг, но едет за юнитом (метка на герое).
-- Не гаснет сам: снимать StopParticle.
function BossKit:TelegraphFollow(unit, radius, delay)
	local idx = ParticleManager:CreateParticle(TELEGRAPH, PATTACH_ABSORIGIN_FOLLOW, unit)
	ParticleManager:SetParticleControl(idx, 1, Vector(radius, 0, -radius))
	ParticleManager:SetParticleControl(idx, 2, Vector(delay, 0, 0))
	return Handle(idx)
end

-- Красная линия-прицел от from до to шириной width (куда полетит снаряд /
-- куда прыгнет босс). Ванильный range_finder_cone: CP1 начало, CP2 конец,
-- CP3 ширина, CP4 цвет. Сама гаснет через duration (если задан).
local LINE = "particles/ui_mouseactions/range_finder_cone.vpcf"

function BossKit:TelegraphLine(from, to, width, duration)
	local idx = ParticleManager:CreateParticle(LINE, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(idx, 0, from)
	ParticleManager:SetParticleControl(idx, 1, from)
	ParticleManager:SetParticleControl(idx, 2, to)
	ParticleManager:SetParticleControl(idx, 3, Vector(width, width, 0))
	ParticleManager:SetParticleControl(idx, 4, Vector(255, 0, 0))
	ParticleManager:SetParticleControl(idx, 6, Vector(1, 0, 0))

	local h = Handle(idx)

	if duration then
		Timers:CreateTimer(duration, function() Kill(h, true) end)
	end

	return h
end

-- Линия от юнита до цели, едет за обоими (прыжок в героя).
function BossKit:TelegraphLineTo(caster, target, width, duration)
	local h = self:TelegraphLine(caster:GetAbsOrigin(), target:GetAbsOrigin(), width, nil)
	local t = 0
	Timers:CreateTimer(0, function()
		if h.dead then return end
		if t >= duration or caster:IsNull() or target:IsNull() then
			Kill(h, true)
			return
		end
		ParticleManager:SetParticleControl(h.idx, 1, caster:GetAbsOrigin())
		ParticleManager:SetParticleControl(h.idx, 2, target:GetAbsOrigin())
		t = t + FrameTime()
		return FrameTime()
	end)
	return h
end

-- Снимает телеграф-хэндл (один раз, сколько ни зови) или обычный индекс.
function BossKit:StopParticle(idx)
	if not idx then return end
	if type(idx) == "table" then return Kill(idx) end
	ParticleManager:DestroyParticle(idx, false)
	ParticleManager:ReleaseParticleIndex(idx)
end

function BossKit:Enemies(caster, pos, radius)
	return FindUnitsInRadius(caster:GetTeamNumber(), pos, nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
		FIND_ANY_ORDER, false)
end

function BossKit:EnemyHeroes(caster, pos, radius)
	return FindUnitsInRadius(caster:GetTeamNumber(), pos, nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS,
		FIND_ANY_ORDER, false)
end

-- Урон от боссов-механик идёт процентом от здоровья цели: скиллы видны
-- заранее, поэтому бьют честно и одинаково больно на любой стадии игры.
-- Крипам и самонам срезаем потолком, чтобы босс не выносил их одним кругом зря.
local CREEP_DAMAGE_CAP = 1500

function BossKit:PctDamage(caster, ability, target, pct)
	if not target or target:IsNull() or not target:IsAlive() then return 0 end

	local damage = target:GetMaxHealth() * pct / 100
	if not target:IsHero() then damage = math.min(damage, CREEP_DAMAGE_CAP) end

	return ApplyDamage({
		victim = target,
		attacker = caster,
		damage = damage,
		damage_type = DAMAGE_TYPE_PURE,
		damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,
		ability = ability,
	})
end

-- Самон или иллюзия добили - убийство и награда уходят их герою.
function BossKit:KillCredit(attacker)
	if not attacker or attacker:IsNull() then return nil end
	if attacker.IsRealHero and attacker:IsRealHero() then return attacker end

	local pid = attacker.GetPlayerOwnerID and attacker:GetPlayerOwnerID() or -1
	if pid and pid >= 0 then
		local hero = PlayerResource:GetSelectedHeroEntity(pid)
		if hero then return hero end
	end

	return attacker
end

-- Есть ли на юните дебафы (минус броня и т.п.) - ИИ зовёт диспел только тогда.
function BossKit:HasDebuffs(unit)
	for _, m in pairs(unit:FindAllModifiers()) do
		if m.IsDebuff and m:IsDebuff() then return true end
	end
	return false
end

-- Сильный диспел себя: снимает дебафы и станы (ответ боссов на минус броню
-- вместо обратки урона).
function BossKit:Dispel(unit)
	unit:Purge(false, true, false, true, true)
	local fx = ParticleManager:CreateParticle("particles/generic_gameplay/generic_purge.vpcf", PATTACH_ABSORIGIN_FOLLOW, unit)
	ParticleManager:ReleaseParticleIndex(fx)
end

-- Сколько раз уже убивали слот этого босса (ставит спавнер в unit.aa_boss_deaths;
-- пока босс не в спавнере - 0).
function BossKit:Deaths(unit)
	return unit.aa_boss_deaths or 0
end

-- Ставит юнит-«ломалку»: hits ударов любого героя - и он разрушен.
-- onBroken(attacker) зовётся один раз.
function BossKit:MakePips(unit, owner, ability, hits, onBroken)
	unit.aa_pips_broken = onBroken
	unit:AddNewModifier(owner, ability, "modifier_boss_kit_pips", { hits = hits })
end

--------------------------------------------------------------------------------

modifier_boss_kit_pips = modifier_boss_kit_pips or class({})
local pips = modifier_boss_kit_pips

function pips:IsHidden()   return true end
function pips:IsPurgable() return false end

function pips:OnCreated(kv)
	self.hits = kv.hits or 3
	if not IsServer() then return end
	self.left = self.hits
	self:SetStackCount(self.hits)
end

function pips:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL,
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL,
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE,
		MODIFIER_PROPERTY_HEALTHBAR_PIPS,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end

function pips:GetAbsoluteNoDamageMagical()  return 1 end
function pips:GetAbsoluteNoDamagePhysical() return 1 end
function pips:GetAbsoluteNoDamagePure()     return 1 end
function pips:GetModifierHealthBarPips()    return self:GetStackCount() > 0 and self.hits or 0 end

function pips:OnAttackLanded(params)
	if not IsServer() then return end

	local parent = self:GetParent()
	if params.target ~= parent then return end

	local attacker = params.attacker
	if not attacker or attacker:IsNull() then return end
	if attacker:GetTeamNumber() == parent:GetTeamNumber() then return end
	if self.left <= 0 then return end

	self.left = self.left - 1
	self:SetStackCount(self.left)

	if self.left > 0 then
		parent:SetHealth(math.max(1, parent:GetMaxHealth() * self.left / self.hits))
		return
	end

	local cb = parent.aa_pips_broken
	parent.aa_pips_broken = nil

	if cb then cb(attacker) end

	if not parent:IsNull() and parent:IsAlive() then
		parent:Kill(nil, attacker)
	end
end
