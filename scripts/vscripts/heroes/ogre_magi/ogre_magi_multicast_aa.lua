-- Мультикаст Огра: своя версия вместо ванильной.
-- Поведение повторяет доту (Огненный удар - в ту же цель, Поджог/Жажда крови/
-- Огненный щит - по случайным целям рядом, задержка multicast_delay), но:
--   * до x6 повторов;
--   * сила умножает шансы с убывающей отдачей (см. GetStrengthMult):
--     каждые str_odds_double силы добавляют ещё одно "удвоение" отношения
--     шанса к промаху, 100% недостижимо.
-- Ванильные заклинания повторяются через OnSpellStart с подменой курсора,
-- OnSpellStart не порождает событие каста, так что рекурсии нет.

LinkLuaModifier("modifier_ogre_magi_multicast_aa", "heroes/ogre_magi/ogre_magi_multicast_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ogre_magi_multicast_aa_cast", "heroes/ogre_magi/ogre_magi_multicast_aa", LUA_MODIFIER_MOTION_NONE)

local MAX_TIMES = 6
local COUNTER_FX = "particles/units/heroes/hero_ogre_magi_aa/ogre_magi_multicast_aa.vpcf"

-- Как способность ищет цели для повторов.
--   same   - та же цель (Огненный удар)
--   enemy  - случайные враги в радиусе (Поджог)
--   ally   - случайные союзники в радиусе (Жажда крови, Огненный щит)
local SPELLS = {
	ogre_magi_fireblast           = { mode = "same" },
	ogre_magi_unrefined_fireblast = { mode = "same" },
	ogre_magi_ignite              = { mode = "enemy", radius = "ignite_multicast_aoe",     debuff = "modifier_ogre_magi_ignite" },
	ogre_magi_bloodlust           = { mode = "ally",  radius = "multicast_bloodlust_aoe",  debuff = "modifier_ogre_magi_bloodlust", delay = 0 },
	ogre_magi_smash               = { mode = "ally",  radius = "multicast_fireshield_aoe", debuff = "modifier_ogre_magi_smash_buff", delay = 0 },
}

local DEFAULT_DELAY = 0.6

ogre_magi_multicast_aa = class({})

function ogre_magi_multicast_aa:Precache(context)
	PrecacheResource("particle", COUNTER_FX, context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ogre_magi.vsndevts", context)
end

function ogre_magi_multicast_aa:GetIntrinsicModifierName()
	return "modifier_ogre_magi_multicast_aa"
end

-- Множитель шансов от силы: 1 + сила / str_odds_double.
-- Умножается не сам шанс, а отношение "сработает : не сработает"
-- (p / (100 - p)), поэтому шанс никогда не доходит до 100%,
-- и чем он выше, тем меньше прибавка от новой силы.
function ogre_magi_multicast_aa:GetStrengthMult()
	local caster = self:GetCaster()
	if not caster or not caster.GetStrength then return 1 end
	local per = self:GetSpecialValueFor("str_odds_double")
	if per <= 0 then return 1 end
	return 1 + math.max(0, caster:GetStrength()) / per
end

-- Итоговый шанс ступени "N раз". 0, если ступень на этом уровне не открыта.
-- Базовое значение берём без override (его подменяет наш же модификатор для
-- тултипа), талант на шанс прибавляем сами.
function ogre_magi_multicast_aa:GetTimesChance(times, level)
	level = level or (self:GetLevel() - 1)
	local base = self:GetLevelSpecialValueNoOverride("multicast_" .. times .. "_times", level)
	if base <= 0 then return 0 end
	local talent = self:GetCaster():FindAbilityByName("special_bonus_unique_ogre_magi_multicast_chance")
	if talent and talent:GetLevel() > 0 then
		base = base + self:GetSpecialValueFor("talent_chance")
	end
	if base >= 100 then return 100 end
	local odds = base / (100 - base) * self:GetStrengthMult()
	-- округление до 0.1, чтобы тултип был читаемым
	return math.floor(1000 * odds / (1 + odds) + 0.5) / 10
end

-- Сколько раз сработает заклинание всего (1 = без мультикаста).
-- Как в доте: сначала бросаем старшую ступень, потом ниже.
function ogre_magi_multicast_aa:RollTimes()
	for times = MAX_TIMES, 2, -1 do
		local chance = self:GetTimesChance(times)
		if chance > 0 and RandomFloat(0, 100) < chance then
			return times
		end
	end
	return 1
end

--------------------------------------------------------------------------------

modifier_ogre_magi_multicast_aa = class({})

function modifier_ogre_magi_multicast_aa:IsHidden() return true end
function modifier_ogre_magi_multicast_aa:IsPurgable() return false end
function modifier_ogre_magi_multicast_aa:RemoveOnDeath() return false end

function modifier_ogre_magi_multicast_aa:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ABILITY_START,
		MODIFIER_EVENT_ON_ABILITY_FULLY_CAST,
		MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL,
		MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL_VALUE,
	}
end

-- В тултипе показываем шансы уже с бонусом от силы.
function modifier_ogre_magi_multicast_aa:GetModifierOverrideAbilitySpecial(data)
	if data.ability ~= self:GetAbility() then return 0 end
	local key = data.ability_special_value
	if key and key:match("^multicast_%d_times$") then return 1 end
	return 0
end

function modifier_ogre_magi_multicast_aa:GetModifierOverrideAbilitySpecialValue(data)
	local times = tonumber(data.ability_special_value:match("^multicast_(%d)_times$"))
	return self:GetAbility():GetTimesChance(times, data.ability_special_level)
end

-- Готова ли у юнита защита от заклинаний: Linken (и передача), Mirror Shield,
-- контрспелл Антимага, блок бездны-воина, отражение древнего дракона.
local function AbilityReady(ability)
	return ability and not ability:IsNull() and ability:GetLevel() > 0 and ability:IsCooldownReady()
end

local function HasReadySpellBlock(unit)
	if unit:HasModifier("modifier_item_sphere_target") then return true end
	-- заряды блока у Abyss Warrior: модификатор живёт, пока они есть
	if unit:HasModifier("modifier_abyss_warrior_charged_attack_linken") then return true end
	-- активный контрспелл АМа
	if unit:HasModifier("modifier_antimage_counterspell") then return true end
	-- отражение дракона - по кулдауну способности
	if not unit:PassivesDisabled() then
		local dragon = unit:FindModifierByName("modifier_ancient_dragon_small_reflect")
		if dragon and AbilityReady(dragon:GetAbility()) then return true end
	end
	for slot = DOTA_ITEM_SLOT_1, DOTA_ITEM_SLOT_6 do
		local item = unit:GetItemInSlot(slot)
		if item then
			local name = item:GetAbilityName()
			if (name:find("^item_sphere") or name == "item_mirror_shield_aa") and item:IsCooldownReady() then
				return true
			end
		end
	end
	return false
end

-- До OnSpellStart запоминаем, была ли у вражеской цели готова линка: если была,
-- первый каст её собьёт (сразу или когда долетит снаряд), и тогда ни один
-- повтор в эту цель уже не идёт.
function modifier_ogre_magi_multicast_aa:OnAbilityStart(params)
	if not IsServer() then return end
	if params.unit ~= self:GetParent() then return end
	local target = params.target
	local blocked = false
	if target and not target:IsNull() and target.GetTeamNumber
		and target:GetTeamNumber() ~= self:GetParent():GetTeamNumber() then
		blocked = HasReadySpellBlock(target)
	end
	self.start_snapshot = { ability = params.ability, target = target, blocked = blocked }
end

function modifier_ogre_magi_multicast_aa:OnAbilityFullyCast(params)
	if not IsServer() then return end
	local parent = self:GetParent()
	if params.unit ~= parent then return end

	local ability = self:GetAbility()
	local cast = params.ability
	if not cast then return end
	if ability:GetLevel() <= 0 then return end
	if parent:PassivesDisabled() or parent:IsIllusion() then return end

	local target = params.target
	local mode, radius, debuff, delay
	if cast:IsItem() then
		-- Предметы, как в доте: только направленные на существо. Повторы
		-- уходят в других врагов (или союзников, если цель союзник) вокруг Огра.
		if not self:CanMulticastItem(cast, target) then return end
		mode = target:GetTeamNumber() == parent:GetTeamNumber() and "ally" or "enemy"
		radius = ability:GetSpecialValueFor("item_multicast_aoe")
		delay = 0 -- предметы повторяются мгновенно
	else
		local info = SPELLS[cast:GetAbilityName()]
		if not info then return end
		mode, debuff, delay = info.mode, info.debuff, info.delay
		radius = info.radius and cast:GetSpecialValueFor(info.radius) or 0
		if delay == nil then
			delay = cast:GetSpecialValueFor("multicast_delay")
			if delay <= 0 then delay = DEFAULT_DELAY end
		end
	end

	local snap = self.start_snapshot
	self.start_snapshot = nil
	local blocked = snap and snap.ability == cast and snap.target == target and snap.blocked

	local times = ability:RollTimes()
	if times <= 1 then return end
	-- В ту же цель с сбитой линкой повторять нечего.
	if blocked and mode == "same" then return end

	parent:AddNewModifier(parent, ability, "modifier_ogre_magi_multicast_aa_cast", {
		cast = cast:entindex(),
		target = target and target:entindex() or -1,
		times = times,
		delay = delay,
		mode = mode,
		radius = radius > 0 and radius or 700,
		debuff = debuff or "",
		blocked = blocked and 1 or 0,
	})
end

-- Предмет мультикастится, если он направлен на существо, не поддерживается
-- (channel) и не тратит заряды: OnSpellStart у предметов с зарядами
-- списал бы лишние заряды за каждый повтор.
function modifier_ogre_magi_multicast_aa:CanMulticastItem(item, target)
	if not target or target:IsNull() or not target.GetTeamNumber then return false end
	if target == self:GetParent() then return false end
	local behavior = item:GetBehaviorInt()
	if bit.band(behavior, DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) == 0 then return false end
	if bit.band(behavior, DOTA_ABILITY_BEHAVIOR_CHANNELLED) ~= 0 then return false end
	if item:GetInitialCharges() > 0 or item:GetCurrentCharges() > 0 then return false end
	return true
end

--------------------------------------------------------------------------------
-- Очередь повторов одного каста.

modifier_ogre_magi_multicast_aa_cast = class({})

function modifier_ogre_magi_multicast_aa_cast:IsHidden() return true end
function modifier_ogre_magi_multicast_aa_cast:IsPurgable() return false end
function modifier_ogre_magi_multicast_aa_cast:RemoveOnDeath() return false end
function modifier_ogre_magi_multicast_aa_cast:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end

function modifier_ogre_magi_multicast_aa_cast:OnCreated(kv)
	if not IsServer() then return end
	self.cast = EntIndexToHScript(kv.cast)
	self.target = kv.target ~= -1 and EntIndexToHScript(kv.target) or nil
	self.times = kv.times
	self.blocked = kv.blocked == 1 -- исходная цель сбила линку: ей повторов нет
	self.done = 1 -- первый каст уже был сам
	if not self.cast then self:Destroy() return end
	self.info = {
		mode = kv.mode,
		radius = kv.radius,
		debuff = kv.debuff ~= "" and kv.debuff or nil,
	}

	-- Цели, уже получившие заклинание в этой серии (для ally/enemy).
	self.hit = {}
	if self.target then self.hit[self.target:entindex()] = true end

	if kv.delay <= 0 then
		-- Мгновенные повторы (как Жажда крови в доте): все сразу.
		for _ = 2, self.times do self:CastOnce() end
		self:Destroy()
		return
	end
	self:StartIntervalThink(kv.delay)
end

function modifier_ogre_magi_multicast_aa_cast:OnIntervalThink()
	if not self:CastOnce() or self.done >= self.times then
		self:Destroy()
	end
end

function modifier_ogre_magi_multicast_aa_cast:IsValidTarget(unit)
	local cast = self.cast
	local parent = self:GetParent()
	if not unit or unit:IsNull() or not unit:IsAlive() then return false end
	if unit:IsOutOfGame() then return false end
	return UnitFilter(unit, cast:GetAbilityTargetTeam(), cast:GetAbilityTargetType(),
		cast:GetAbilityTargetFlags(), parent:GetTeamNumber()) == UF_SUCCESS
end

-- Случайная цель в радиусе: сначала те, у кого нет эффекта и кого ещё не
-- задели в этой серии, герои вперёд остальных; если таких нет - любая.
function modifier_ogre_magi_multicast_aa_cast:PickTarget()
	local info = self.info
	local parent = self:GetParent()
	local radius = info.radius

	local team = info.mode == "ally" and DOTA_UNIT_TARGET_TEAM_FRIENDLY or DOTA_UNIT_TARGET_TEAM_ENEMY
	local units = FindUnitsInRadius(parent:GetTeamNumber(), parent:GetAbsOrigin(), nil, radius,
		team, self.cast:GetAbilityTargetType(), self.cast:GetAbilityTargetFlags(),
		FIND_ANY_ORDER, false)

	local fresh_heroes, fresh, any = {}, {}, {}
	for _, unit in ipairs(units) do
		if self:IsValidTarget(unit) and not (self.blocked and unit == self.target) then
			table.insert(any, unit)
			local untouched = not self.hit[unit:entindex()]
				and not (info.debuff and unit:HasModifier(info.debuff))
			if untouched then
				if unit:IsRealHero() then
					table.insert(fresh_heroes, unit)
				else
					table.insert(fresh, unit)
				end
			end
		end
	end

	local pool = #fresh_heroes > 0 and fresh_heroes or (#fresh > 0 and fresh or any)
	-- Больше некого - в пул попадает исходная цель, если она в радиусе
	-- и не сбила линку (её отсекает фильтр выше).
	if #pool == 0 then return nil end
	return pool[RandomInt(1, #pool)]
end

-- Один повтор. false - серию надо прервать.
function modifier_ogre_magi_multicast_aa_cast:CastOnce()
	local parent = self:GetParent()
	local cast = self.cast
	if not cast or cast:IsNull() or not parent:IsAlive() then return false end

	local target
	if self.info.mode == "same" then
		if not self:IsValidTarget(self.target) then return false end
		target = self.target
	else
		target = self:PickTarget()
		if not target then return false end
	end
	self.hit[target:entindex()] = true

	self.done = self.done + 1
	self:ShowCounter(target)

	local old_target = parent:GetCursorCastTarget()
	parent:SetCursorCastTarget(target)
	cast:OnSpellStart()
	parent:SetCursorCastTarget(old_target)
	return true
end

-- Счётчик x2, x3... над головой Огра и звук, как в доте.
function modifier_ogre_magi_multicast_aa_cast:ShowCounter(target)
	local parent = self:GetParent()
	-- Своя копия ванильной частицы (particles/units/heroes/hero_ogre_magi_aa),
	-- в её текстуре есть цифры до 6. CP1: x - число, y - 1 на последнем
	-- повторе (цифра крупнее), 2 на остальных, z - размер надписи 0..3.
	local fx = ParticleManager:CreateParticle(COUNTER_FX, PATTACH_OVERHEAD_FOLLOW, parent)
	local size = math.min(3, (self.done - 2) * 3 / (MAX_TIMES - 2))
	ParticleManager:SetParticleControl(fx, 1, Vector(self.done, self.done >= self.times and 1 or 2, size))
	ParticleManager:ReleaseParticleIndex(fx)
	-- Звуков в доте три: x1..x3. Дальше - самый громкий.
	parent:EmitSound("Hero_OgreMagi.Fireblast.x" .. math.min(self.done - 1, 3))
end
