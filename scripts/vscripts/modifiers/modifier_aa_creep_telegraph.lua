-- Предупреждение о касте крипа (2026-11-22, фарм). Схема как у Ксена в 1x6
-- (modifiers/creeps/modifier_neutral_cast.lua).
-- Крипы кастуют сразу (каст поинт 0-0.4), увернуться невозможно. Теперь любой
-- каст способности нейтрала (наш ИИ, движковый neutral_chance_to_cast, ИИ мегакрипов)
-- перехватывается: крип стоит TELEGRAPH_TIME сек с анимацией каста, потом каст
-- повторяется уже без перехвата. Что видно игроку:
--   * всегда - жёлтый "!" над крипом (ванильный generic_has_quest);
--   * скилл в цель - такой же "!" над жертвой, зоны нет;
--   * удар в точку - красная зона в точке, заполняется к моменту удара (можно уйти);
--   * удар вокруг себя (стомп, хлопок) - та же зона вокруг крипа.
-- Зона - particles/generic/red_zone.vpcf из 1x6 (CP0 центр, CP1 радиус и скорость
-- заполнения, CP2 время), текстуры ванильные.
-- Оглушение/безмолвие/хекс во время замаха отменяют каст.
-- Вешается в addon_game_mode на всех крипов кемпов, не на приручённых и не на боссов.

modifier_aa_creep_telegraph = class({})

LinkLuaModifier("modifier_aa_creep_windup", "modifiers/modifier_aa_creep_telegraph", LUA_MODIFIER_MOTION_NONE)

TELEGRAPH_TIME = 0.6

local FX_MARK = "particles/generic_gameplay/generic_has_quest.vpcf"
local FX_ZONE = "particles/generic/red_zone.vpcf"
local MIN_RADIUS = 150

LinkLuaModifier("modifier_aa_creep_telegraph_hub", "modifiers/modifier_aa_creep_telegraph", LUA_MODIFIER_MOTION_NONE)

function modifier_aa_creep_telegraph:IsHidden() return true end
function modifier_aa_creep_telegraph:IsPurgable() return false end
function modifier_aa_creep_telegraph:RemoveOnDeath() return true end

-- ОДИН слушатель на всех крипов. MODIFIER_EVENT_* в доте глобальные: событие
-- получает каждый модификатор, который его объявил, на любой юнит карты, и сам
-- отсеивает чужие. Пока событие было объявлено здесь, каждый каст любого юнита
-- звал этот модификатор на всех 100-400 живых крипах. Теперь событие объявлено
-- только у modifier_aa_creep_telegraph_hub (один на карту, на thinker'е), а он
-- по p.unit находит модификатор кастующего крипа в таблице. Обработчик тот же.
--
-- Проверка по логу: в сводке [AA.perf] раз в минуту строка
--   "замахи крипов: хабов N, событий E, замахов W, докастов R, сорвано C"
-- N всегда 1. Событий много (любой каст на карте), замахи и докасты растут
-- вместе: каждый замах кончается докастом или срывом (стан/сайленс/хекс).
-- Если хабов больше 1 - один каст разошёлся бы на несколько хабов, и крип
-- вечно перезапускал бы замах, вообще не кастуя. Поэтому раздаёт только
-- активный хаб (TelegraphHub.active), остальные молчат.
TelegraphHub = TelegraphHub or { byUnit = {} }
TelegraphHub.stats = TelegraphHub.stats or { hubs = 0, events = 0, windups = 0, recasts = 0, cancels = 0 }

local function EnsureHub(owner)
	local hub = TelegraphHub.active
	if hub and not hub:IsNull() then return end

	-- без хозяина: с крипом-хозяином thinker мог пропасть вместе с крипом.
	-- OnCreated хаба срабатывает прямо внутри вызова и ставит TelegraphHub.active;
	-- если без хозяина движок thinker не создал - создаём от крипа
	pcall(CreateModifierThinker, nil, nil, "modifier_aa_creep_telegraph_hub", {},
		Vector(0, 0, 0), DOTA_TEAM_NEUTRALS, false)

	if not TelegraphHub.active and owner then
		CreateModifierThinker(owner, nil, "modifier_aa_creep_telegraph_hub", {},
			Vector(0, 0, 0), DOTA_TEAM_NEUTRALS, false)
	end
end

function modifier_aa_creep_telegraph:OnCreated()
	if not IsServer() then return end
	TelegraphHub.byUnit[self:GetParent():entindex()] = self
	-- хаб проверяется при каждом новом крипе: если thinker пропал, создастся заново
	EnsureHub(self:GetParent())
end

function modifier_aa_creep_telegraph:OnDestroy()
	if not IsServer() then return end
	local idx = self:GetParent():entindex()
	if TelegraphHub.byUnit[idx] == self then TelegraphHub.byUnit[idx] = nil end
end

modifier_aa_creep_telegraph_hub = class({})

function modifier_aa_creep_telegraph_hub:IsHidden() return true end
function modifier_aa_creep_telegraph_hub:IsPurgable() return false end
function modifier_aa_creep_telegraph_hub:RemoveOnDeath() return false end

function modifier_aa_creep_telegraph_hub:DeclareFunctions()
	return { MODIFIER_EVENT_ON_ABILITY_START }
end

function modifier_aa_creep_telegraph_hub:OnCreated()
	if not IsServer() then return end
	TelegraphHub.active = self
	TelegraphHub.stats.hubs = TelegraphHub.stats.hubs + 1
	print("[AA.telegraph] хаб замахов создан, всего за игру: " .. TelegraphHub.stats.hubs)
end

function modifier_aa_creep_telegraph_hub:OnDestroy()
	if not IsServer() then return end
	if TelegraphHub.active == self then TelegraphHub.active = nil end
end

function modifier_aa_creep_telegraph_hub:OnAbilityStart(p)
	if not IsServer() then return end
	-- раздаёт только один хаб, даже если их как-то стало больше
	if TelegraphHub.active ~= self then return end
	TelegraphHub.stats.events = TelegraphHub.stats.events + 1
	local unit = p.unit
	if not unit or unit:IsNull() then return end

	local mod = TelegraphHub.byUnit[unit:entindex()]
	if not mod then return end

	if mod:IsNull() then
		TelegraphHub.byUnit[unit:entindex()] = nil
		return
	end

	mod:OnAbilityStart(p)
end

-- радиус зоны: AoE способности или её типовые ключи
local function AbilityRadius(ab)
	local r = ab.GetAOERadius and ab:GetAOERadius() or 0
	if r and r > 0 then return r end
	for _, k in ipairs({ "radius", "aoe", "area_of_effect", "aoe_radius", "impact_radius", "damage_radius", "stomp_radius" }) do
		local v = ab:GetSpecialValueFor(k)
		if v and v > 0 then return v end
	end
	return 0
end

function modifier_aa_creep_telegraph:OnAbilityStart(p)
	if not IsServer() then return end
	local parent = self:GetParent()
	if p.unit ~= parent then return end
	local ab = p.ability
	if not ab or ab:IsNull() or ab:IsItem() then return end
	if parent:IsDominated() or parent:GetPlayerOwnerID() >= 0 then return end

	-- повторный каст после замаха - пропускаем
	if ab.aa_telegraph_ok then
		ab.aa_telegraph_ok = nil
		TelegraphHub.stats.recasts = TelegraphHub.stats.recasts + 1
		return
	end
	-- во время замаха любые другие касты гасим
	if parent:HasModifier("modifier_aa_creep_windup") then parent:Stop() return end

	local b = ab:GetBehaviorInt()
	local target = ab:GetCursorTarget()
	local pos = ab:GetCursorPosition()
	local kind
	if bit.band(b, DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) ~= 0 and target then
		kind = "unit"
	elseif bit.band(b, DOTA_ABILITY_BEHAVIOR_POINT) ~= 0 then
		kind = "point"
	else
		kind = "none"
	end

	-- каст на себя/союзника (бафф) - без предупреждения
	if kind == "unit" and target:GetTeamNumber() == parent:GetTeamNumber() then return end

	parent:Stop()
	TelegraphHub.stats.windups = TelegraphHub.stats.windups + 1
	parent:AddNewModifier(parent, ab, "modifier_aa_creep_windup", {
		duration = TELEGRAPH_TIME,
		kind = kind,
		target = target and target:entindex() or -1,
		x = pos.x, y = pos.y, z = pos.z,
	})
end

--------------------------------------------------------------------------------
-- Замах: крип стоит и не поворачивается, играет анимацию каста, показывает "!" и зону

modifier_aa_creep_windup = class({})

function modifier_aa_creep_windup:IsHidden() return true end
function modifier_aa_creep_windup:IsPurgable() return false end

function modifier_aa_creep_windup:CheckState()
	return { [MODIFIER_STATE_ROOTED] = true, [MODIFIER_STATE_DISARMED] = true }
end

function modifier_aa_creep_windup:DeclareFunctions()
	return { MODIFIER_PROPERTY_DISABLE_TURNING }
end

function modifier_aa_creep_windup:GetModifierDisableTurning() return 1 end

local function Mark(unit, self)
	local fx = ParticleManager:CreateParticle(FX_MARK, PATTACH_OVERHEAD_FOLLOW, unit)
	self:AddParticle(fx, false, false, -1, false, true)
end

function modifier_aa_creep_windup:OnCreated(kv)
	if not IsServer() then return end
	local parent = self:GetParent()
	local ab = self:GetAbility()
	self.kind = kv.kind
	self.target = kv.target ~= -1 and EntIndexToHScript(kv.target) or nil
	self.pos = Vector(kv.x, kv.y, kv.z)

	-- развернуться к цели до блокировки поворота
	if self.target and not self.target:IsNull() then
		parent:FaceTowards(self.target:GetAbsOrigin())
	elseif self.kind == "point" then
		parent:FaceTowards(self.pos)
	end

	self.act = ab.GetCastAnimation and ab:GetCastAnimation() or 0
	if not self.act or self.act == 0 then self.act = ACT_DOTA_CAST_ABILITY_1 end
	parent:StartGestureWithPlaybackRate(self.act, 0.6)

	Mark(parent, self)

	if self.kind == "unit" then
		-- скилл в цель: "!" и над жертвой, без зоны
		if self.target and not self.target:IsNull() then Mark(self.target, self) end
	else
		-- удар в точку или вокруг себя: зона, заполняется к удару
		local radius = AbilityRadius(ab)
		if self.kind == "point" or radius > 0 then
			radius = math.max(radius, MIN_RADIUS)
			local center = self.kind == "point" and self.pos or parent:GetAbsOrigin()
			local t = self:GetDuration()
			local fx = ParticleManager:CreateParticle(FX_ZONE, PATTACH_WORLDORIGIN, nil)
			ParticleManager:SetParticleControl(fx, 0, center)
			ParticleManager:SetParticleControl(fx, 1, Vector(radius, 0, -radius / t))
			ParticleManager:SetParticleControl(fx, 2, Vector(t, 0, 0))
			self:AddParticle(fx, false, false, -1, false, false)
		end
	end

	self:StartIntervalThink(FrameTime())
end

-- контроль во время замаха отменяет каст (знаки и зона пропадают)
function modifier_aa_creep_windup:OnIntervalThink()
	local parent = self:GetParent()
	if parent:IsStunned() or parent:IsSilenced() or parent:IsHexed() then
		if not self.cancelled then TelegraphHub.stats.cancels = TelegraphHub.stats.cancels + 1 end
		self.cancelled = true
		self:Destroy()
	end
end

function modifier_aa_creep_windup:OnDestroy()
	if not IsServer() then return end
	local parent = self:GetParent()
	local ab = self:GetAbility()
	parent:FadeGesture(self.act or ACT_DOTA_CAST_ABILITY_1)
	if self.cancelled or not parent:IsAlive() or not ab or ab:IsNull() or not ab:IsFullyCastable() then return end

	ab.aa_telegraph_ok = true
	if self.kind == "unit" then
		if not self.target or self.target:IsNull() or not self.target:IsAlive() then ab.aa_telegraph_ok = nil return end
		parent:CastAbilityOnTarget(self.target, ab, -1)
	elseif self.kind == "point" then
		parent:CastAbilityOnPosition(self.pos, ab, -1)
	else
		parent:CastAbilityNoTarget(ab, -1)
	end
	-- если каст не начался (цель ушла и т.п.) - флаг не должен висеть
	Timers:CreateTimer(2, function()
		if ab and not ab:IsNull() then ab.aa_telegraph_ok = nil end
	end)
end
