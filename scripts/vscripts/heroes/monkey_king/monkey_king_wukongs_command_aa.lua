--[[
	Wukong's Command - арена Monkey King. По мотивам версии из мода 1х6, но
	поведение дотовское:

	  каст в точку (дальность cast_range), после каста вокруг точки встают кольца
	  солдат: num_first_soldiers на first_radius и num_second_soldiers на
	  second_radius (с талантом - третье кольцо);
	  солдаты неуязвимы, стоят на месте и бьют ближайшего врага в своей дальности
	  атаки (сначала героев), раз в attack_speed секунд, уроном атаки MK;
	  пока MK внутри внешнего кольца, у него +bonus_armor брони;
	  арена кончается по duration, при смерти MK или если он вышел за внешнее
	  кольцо (end_on_leave, с допуском leave_grace сек.).

	Солдаты - ПУЛ героев-юнитов MK, как в 1х6:
	  у юнита-существа с моделью MK движок не играл анимацию атаки, а иллюзии
	  (14-21 штука с копиями всех модификаторов) страшно лагали. Поэтому
	  солдат - герой того же имени, создаётся один раз и потом переиспользуется:
	  между аренами спрятан (modifier_..._soldier_base в режиме "в запасе":
	  без отрисовки, вне игры, неуязвим).
	  Чтобы логика мода не считала солдат настоящими героями, база солдата
	  даёт MODIFIER_PROPERTY_TEMPEST_DOUBLE (IsTempestDouble() == true: без
	  деления опыта, дуэлей, урн и т.п.), а OnNPCSpawned пропускает их по
	  флагу AA_SPAWNING_MK_SOLDIER / unit.aa_mk_soldier.
	  При выходе солдат догоняет уровень MK, получает копии его предметов и
	  добивку урона до урона атаки MK.
]]

LinkLuaModifier("modifier_monkey_king_wukongs_command_aa_thinker", "heroes/monkey_king/monkey_king_wukongs_command_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_monkey_king_wukongs_command_aa_soldier", "heroes/monkey_king/monkey_king_wukongs_command_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_monkey_king_wukongs_command_aa_soldier_base", "heroes/monkey_king/monkey_king_wukongs_command_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_monkey_king_wukongs_command_aa_buff", "heroes/monkey_king/monkey_king_wukongs_command_aa", LUA_MODIFIER_MOTION_NONE)

monkey_king_wukongs_command_aa = class({})

function monkey_king_wukongs_command_aa:Precache(context)
	-- НЕЛЬЗЯ PrecacheUnitByNameSync своего героя: прекеш героя зовёт Precache
	-- его способностей, а этот снова героя - бесконечная рекурсия и краш игры
	-- (был при взятии MK). Вещи героя для солдат догружаются асинхронно, когда
	-- способность появляется у героя (модификатор аганима, OnCreated).
	PrecacheResource("model", "models/heroes/monkey_king/monkey_king.vmdl", context)
	PrecacheResource("particle", "particles/units/heroes/hero_monkey_king/monkey_king_fur_army_cast.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_monkey_king/monkey_king_furarmy_ring.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_monkey_king/monkey_king_fur_army_positions.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_monkey_king/monkey_king_fur_army_attack.vpcf", context)
	PrecacheResource("particle", "particles/status_fx/status_effect_monkey_king_fur_army.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_monkey_king.vsndevts", context)
end

function monkey_king_wukongs_command_aa:GetCastRange(location, target)
	if self:GetCaster():HasScepter() then
		return self:GetSpecialValueFor("cast_range_scepter")
	end

	return self:GetSpecialValueFor("cast_range")
end

function monkey_king_wukongs_command_aa:GetCooldown(level)
	if self:GetCaster():HasScepter() then
		return self:GetSpecialValueFor("cooldown_scepter")
	end

	return self.BaseClass.GetCooldown(self, level)
end

function monkey_king_wukongs_command_aa:GetIntrinsicModifierName()
	return "modifier_monkey_king_wukongs_command_aa_scepter"
end

local SOLDIER_MODIFIER = "modifier_monkey_king_wukongs_command_aa_soldier"
local BASE_MODIFIER = "modifier_monkey_king_wukongs_command_aa_soldier_base"

-- новый солдат в пул (герой того же имени, что и кастер - работает и у Рубика)
function monkey_king_wukongs_command_aa:CreatePoolSoldier()
	local caster = self:GetCaster()

	AA_SPAWNING_MK_SOLDIER = true
	local ok, soldier = pcall(CreateUnitByName, caster:GetUnitName(), caster:GetAbsOrigin(), false, caster, caster, caster:GetTeamNumber())
	AA_SPAWNING_MK_SOLDIER = false

	if not ok or not soldier then return end

	soldier.aa_mk_soldier = true
	soldier:SetOwner(caster)

	-- способности героя солдату не нужны
	for i = soldier:GetAbilityCount() - 1, 0, -1 do
		local ability = soldier:GetAbilityByIndex(i)

		if ability then soldier:RemoveAbilityByHandle(ability) end
	end

	soldier:AddNewModifier(caster, self, BASE_MODIFIER, {})

	return soldier
end

function monkey_king_wukongs_command_aa:GetFreeSoldier()
	self.pool = self.pool or {}

	for i = #self.pool, 1, -1 do
		local soldier = self.pool[i]

		if not soldier or soldier:IsNull() then
			table.remove(self.pool, i)
		elseif not soldier:HasModifier(SOLDIER_MODIFIER) then
			return soldier
		end
	end

	local soldier = self:CreatePoolSoldier()

	if soldier then table.insert(self.pool, soldier) end

	return soldier
end

-- готовим солдата к выходу: уровень, копии предметов, урон MK
function monkey_king_wukongs_command_aa:PrepareSoldier(soldier)
	local caster = self:GetCaster()

	while soldier:GetLevel() < caster:GetLevel() do
		soldier:HeroLevelUp(false)
	end

	-- старые копии предметов долой, кладём текущие предметы MK
	for slot = 0, 8 do
		local item = soldier:GetItemInSlot(slot)

		if item then UTIL_Remove(item) end
	end

	for slot = 0, 5 do
		local item = caster:GetItemInSlot(slot)

		if item and not item:IsNull() then
			local copy = CreateItem(item:GetAbilityName(), nil, nil)

			if copy then
				copy:SetPurchaser(nil)
				copy:SetSellable(false)
				copy:SetDroppable(false)

				if item:GetCurrentCharges() > 0 then
					copy:SetCurrentCharges(item:GetCurrentCharges())
				end

				local added = soldier:AddItem(copy)

				if added and added:GetItemSlot() ~= slot then
					soldier:SwapItems(added:GetItemSlot(), slot)
				end
			end
		end
	end

	-- статы обновятся на следующем кадре - тогда добиваем урон до урона MK
	Timers:CreateTimer(FrameTime(), function()
		if not soldier or soldier:IsNull() or caster:IsNull() then return end

		local base = soldier:FindModifierByName(BASE_MODIFIER)

		if base then
			base.bonus_damage = 0
			base.bonus_damage = caster:GetAverageTrueAttackDamage(nil) - soldier:GetAverageTrueAttackDamage(nil)
		end
	end)
end

-- from - откуда выбегает, point - где встанет. Солдат сам возвращается в пул
-- по окончании duration (или когда арена снимет с него модификатор).
function monkey_king_wukongs_command_aa:SpawnSoldier(from, point, duration)
	local soldier = self:GetFreeSoldier()

	if not soldier then return end

	self:PrepareSoldier(soldier)

	FindClearSpaceForUnit(soldier, from, false)
	soldier:AddNewModifier(self:GetCaster(), self, SOLDIER_MODIFIER, {
		x = point.x,
		y = point.y,
		duration = duration,
	})

	return soldier
end

function monkey_king_wukongs_command_aa:GetAOERadius()
	local third = self:GetSpecialValueFor("third_radius")

	if third > 0 then return third end

	return self:GetSpecialValueFor("second_radius")
end

function monkey_king_wukongs_command_aa:OnAbilityPhaseStart()
	local caster = self:GetCaster()

	caster:EmitSound("Hero_MonkeyKing.FurArmy.Channel")
	caster:StartGesture(ACT_DOTA_MK_FUR_ARMY)

	self.cast_fx = ParticleManager:CreateParticle("particles/units/heroes/hero_monkey_king/monkey_king_fur_army_cast.vpcf", PATTACH_ABSORIGIN, caster)

	return true
end

function monkey_king_wukongs_command_aa:ClearCastFx(immediate)
	if self.cast_fx then
		ParticleManager:DestroyParticle(self.cast_fx, immediate)
		ParticleManager:ReleaseParticleIndex(self.cast_fx)
		self.cast_fx = nil
	end
end

function monkey_king_wukongs_command_aa:OnAbilityPhaseInterrupted()
	local caster = self:GetCaster()

	caster:StopSound("Hero_MonkeyKing.FurArmy.Channel")
	caster:FadeGesture(ACT_DOTA_MK_FUR_ARMY)

	self:ClearCastFx(true)
end

function monkey_king_wukongs_command_aa:OnSpellStart()
	local caster = self:GetCaster()

	self:ClearCastFx(false)
	caster:FadeGesture(ACT_DOTA_MK_FUR_ARMY)
	caster:StopSound("Hero_MonkeyKing.FurArmy.Channel")

	-- прошлая арена ещё стоит - снимаем
	if self.thinker and not self.thinker:IsNull() then
		self.thinker:RemoveModifierByName("modifier_monkey_king_wukongs_command_aa_thinker")
	end

	self.thinker = CreateModifierThinker(caster, self, "modifier_monkey_king_wukongs_command_aa_thinker",
		{ duration = self:GetSpecialValueFor("duration") }, self:GetCursorPosition(), caster:GetTeamNumber(), false)
end

---------------------------------------------------------------------------------------------------
-- Арена: ставит солдат, следит за MK
---------------------------------------------------------------------------------------------------

modifier_monkey_king_wukongs_command_aa_thinker = class({})

function modifier_monkey_king_wukongs_command_aa_thinker:IsHidden() return true end
function modifier_monkey_king_wukongs_command_aa_thinker:IsPurgable() return false end

local function Rotate(radius, index, count, offset)
	local angle = math.rad((index - offset) * 360 / count)

	return Vector(math.sin(angle), math.cos(angle), 0) * radius
end

function modifier_monkey_king_wukongs_command_aa_thinker:OnCreated()
	if not IsServer() then return end

	local ability = self:GetAbility()
	local caster = self:GetCaster()

	self.center = self:GetParent():GetAbsOrigin()
	self.soldiers = {}
	self.outside_time = 0

	self.outer_radius = ability:GetSpecialValueFor("second_radius")

	local rings = {
		{ ability:GetSpecialValueFor("first_radius"), ability:GetSpecialValueFor("num_first_soldiers"), 0.5 },
		{ ability:GetSpecialValueFor("second_radius"), ability:GetSpecialValueFor("num_second_soldiers"), 0.25 },
	}

	local third_radius = ability:GetSpecialValueFor("third_radius")
	local third_count = ability:GetSpecialValueFor("num_third_soldiers")

	if third_radius > 0 and third_count > 0 then
		table.insert(rings, { third_radius, third_count, 0 })
		self.outer_radius = third_radius
	end

	self.end_on_leave = ability:GetSpecialValueFor("end_on_leave") == 1
	self.leave_grace = ability:GetSpecialValueFor("leave_grace")

	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_monkey_king/monkey_king_furarmy_ring.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, self.center)
	ParticleManager:SetParticleControl(fx, 1, Vector(self.outer_radius, self.outer_radius, self.outer_radius))
	self:AddParticle(fx, false, false, -1, false, false)

	-- FurArmy - петля; на всю арену она резала уши, поэтому только на старте
	local parent = self:GetParent()

	parent:EmitSound("Hero_MonkeyKing.FurArmy")
	Timers:CreateTimer(2, function()
		if parent and not parent:IsNull() then parent:StopSound("Hero_MonkeyKing.FurArmy") end
	end)

	-- солдаты выбегают от MK к своим местам по одному, как в доте
	self.queue = {}

	for _, ring in ipairs(rings) do
		for i = 1, ring[2] do
			table.insert(self.queue, self.center + Rotate(ring[1], i, ring[2], ring[3]))
		end
	end

	self.think = 0.05
	self:StartIntervalThink(self.think)
end

function modifier_monkey_king_wukongs_command_aa_thinker:SpawnSoldier(point)
	local soldier = self:GetAbility():SpawnSoldier(self:GetCaster():GetAbsOrigin(), point, self:GetRemainingTime())

	if soldier then table.insert(self.soldiers, soldier) end
end

function modifier_monkey_king_wukongs_command_aa_thinker:OnIntervalThink()
	local caster = self:GetCaster()

	if #self.queue > 0 then
		self:SpawnSoldier(table.remove(self.queue, 1))
	end

	if not caster or caster:IsNull() or not caster:IsAlive() then
		self:Destroy()
		return
	end

	local inside = (caster:GetAbsOrigin() - self.center):Length2D() <= self.outer_radius

	if inside then
		self.outside_time = 0

		if not caster:HasModifier("modifier_monkey_king_wukongs_command_aa_buff") then
			caster:AddNewModifier(caster, self:GetAbility(), "modifier_monkey_king_wukongs_command_aa_buff", {})
		end
	else
		caster:RemoveModifierByName("modifier_monkey_king_wukongs_command_aa_buff")

		self.outside_time = self.outside_time + self.think

		if self.end_on_leave and self.outside_time > self.leave_grace then
			self:Destroy()
			return
		end
	end
end

function modifier_monkey_king_wukongs_command_aa_thinker:OnDestroy()
	if not IsServer() then return end

	local caster = self:GetCaster()

	if caster and not caster:IsNull() then
		caster:RemoveModifierByName("modifier_monkey_king_wukongs_command_aa_buff")
	end

	-- солдаты обратно в пул
	for _, soldier in ipairs(self.soldiers) do
		if soldier and not soldier:IsNull() then
			soldier:RemoveModifierByName(SOLDIER_MODIFIER)
		end
	end

	self.soldiers = {}

	local parent = self:GetParent()

	parent:StopSound("Hero_MonkeyKing.FurArmy")
	EmitSoundOnLocationWithCaster(self.center, "Hero_MonkeyKing.FurArmy.End", caster)

	UTIL_Remove(parent)
end

---------------------------------------------------------------------------------------------------
-- Солдат
---------------------------------------------------------------------------------------------------

modifier_monkey_king_wukongs_command_aa_soldier = class({})

function modifier_monkey_king_wukongs_command_aa_soldier:IsHidden() return true end
function modifier_monkey_king_wukongs_command_aa_soldier:IsPurgable() return false end

function modifier_monkey_king_wukongs_command_aa_soldier:GetStatusEffectName()
	return "particles/status_fx/status_effect_monkey_king_fur_army.vpcf"
end

function modifier_monkey_king_wukongs_command_aa_soldier:StatusEffectPriority()
	return MODIFIER_PRIORITY_ILLUSION
end

function modifier_monkey_king_wukongs_command_aa_soldier:OnCreated(params)
	local ability = self:GetAbility()

	self.attack_rate = ability and ability:GetSpecialValueFor("attack_speed") or 1.1
	self.move_speed = ability and ability:GetSpecialValueFor("move_speed") or 700
	self.standing = false

	if not IsServer() then return end

	local parent = self:GetParent()
	local caster = self:GetCaster()

	self.spot = GetGroundPosition(Vector(params.x, params.y, 0), nil)

	-- уровень, предметы и урон MK солдат получил в PrepareSoldier
	parent:RemoveNoDraw()
	parent:SetForwardVector(caster:GetForwardVector())

	self.spot_fx = ParticleManager:CreateParticle("particles/units/heroes/hero_monkey_king/monkey_king_fur_army_positions.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(self.spot_fx, 0, self.spot)
	self:AddParticle(self.spot_fx, false, false, -1, false, false)

	parent:MoveToPosition(self.spot)

	self:StartIntervalThink(0.1)
end

function modifier_monkey_king_wukongs_command_aa_soldier:OnIntervalThink()
	local parent = self:GetParent()

	if not self.standing then
		if (parent:GetAbsOrigin() - self.spot):Length2D() > 20 then
			parent:MoveToPosition(self.spot)
			return
		end

		self.standing = true
		FindClearSpaceForUnit(parent, self.spot, false)
	end

	self:UpdateTarget()
end

-- ближайший враг в дальности атаки; герои в приоритете
function modifier_monkey_king_wukongs_command_aa_soldier:FindTarget()
	local parent = self:GetParent()
	local range = parent:Script_GetAttackRange() + parent:GetHullRadius()
	local flags = DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS + DOTA_UNIT_TARGET_FLAG_NOT_ATTACK_IMMUNE

	local heroes = FindUnitsInRadius(parent:GetTeamNumber(), parent:GetAbsOrigin(), nil, range,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO, flags, FIND_CLOSEST, false)

	if heroes[1] then return heroes[1] end

	local units = FindUnitsInRadius(parent:GetTeamNumber(), parent:GetAbsOrigin(), nil, range,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_BASIC, flags, FIND_CLOSEST, false)

	return units[1]
end

function modifier_monkey_king_wukongs_command_aa_soldier:UpdateTarget()
	local parent = self:GetParent()
	local target = self.target
	local range = parent:Script_GetAttackRange() + parent:GetHullRadius() + 35

	local valid = target and not target:IsNull() and target:IsAlive()
		and (target:GetAbsOrigin() - parent:GetAbsOrigin()):Length2D() <= range
		and parent:CanEntityBeSeenByMyTeam(target)
		and not target:IsAttackImmune()

	if not valid then
		target = self:FindTarget()
		self.target = target

		if target then
			local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_monkey_king/monkey_king_fur_army_attack.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent)
			ParticleManager:ReleaseParticleIndex(fx)
		end
	end

	-- стадия для клиента (self.standing есть только на сервере): 1 - стоит без цели, 2 - бьёт
	if IsServer() then self:SetStackCount(target and 2 or 1) end

	if target then
		parent:SetForceAttackTarget(target)
	else
		parent:SetForceAttackTarget(nil)
		parent:Stop()
	end
end

function modifier_monkey_king_wukongs_command_aa_soldier:OnDestroy()
	if not IsServer() then return end

	local parent = self:GetParent()

	if not parent or parent:IsNull() then return end

	-- обратно в пул: прячется (база включает режим "в запасе"), не умирает
	parent:SetForceAttackTarget(nil)
	parent:Stop()
	parent:AddNoDraw()
end

---------------------------------------------------------------------------------------------------
-- База солдата из пула: висит всегда. Делает его не-героем для логики мода
-- (Tempest Double), добивает урон до урона MK и, пока солдат не на арене,
-- прячет его.
---------------------------------------------------------------------------------------------------

modifier_monkey_king_wukongs_command_aa_soldier_base = class({})

function modifier_monkey_king_wukongs_command_aa_soldier_base:IsHidden() return true end
function modifier_monkey_king_wukongs_command_aa_soldier_base:IsPurgable() return false end
function modifier_monkey_king_wukongs_command_aa_soldier_base:RemoveOnDeath() return false end
function modifier_monkey_king_wukongs_command_aa_soldier_base:IsPermanent() return true end

function modifier_monkey_king_wukongs_command_aa_soldier_base:OnCreated()
	self.bonus_damage = 0

	if not IsServer() then return end

	self:GetParent():AddNoDraw()
end

function modifier_monkey_king_wukongs_command_aa_soldier_base:IsReserve()
	return not self:GetParent():HasModifier(SOLDIER_MODIFIER)
end

function modifier_monkey_king_wukongs_command_aa_soldier_base:CheckState()
	local state = {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_UNSELECTABLE] = true,
		[MODIFIER_STATE_UNTARGETABLE] = true,
		[MODIFIER_STATE_NOT_ON_MINIMAP] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
	}

	if self:IsReserve() then
		state[MODIFIER_STATE_OUT_OF_GAME] = true
		state[MODIFIER_STATE_STUNNED] = true
		state[MODIFIER_STATE_DISARMED] = true
	end

	return state
end

function modifier_monkey_king_wukongs_command_aa_soldier_base:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_TEMPEST_DOUBLE,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL,
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL,
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE,
		MODIFIER_PROPERTY_DISABLE_AUTOATTACK,
	}
end

function modifier_monkey_king_wukongs_command_aa_soldier_base:GetModifierTempestDouble() return 1 end
function modifier_monkey_king_wukongs_command_aa_soldier_base:GetModifierPreAttack_BonusDamage() return self.bonus_damage or 0 end
function modifier_monkey_king_wukongs_command_aa_soldier_base:GetAbsoluteNoDamagePhysical() return 1 end
function modifier_monkey_king_wukongs_command_aa_soldier_base:GetAbsoluteNoDamageMagical() return 1 end
function modifier_monkey_king_wukongs_command_aa_soldier_base:GetAbsoluteNoDamagePure() return 1 end
function modifier_monkey_king_wukongs_command_aa_soldier_base:GetDisableAutoAttack() return 1 end

---------------------------------------------------------------------------------------------------
-- Аганим (как в доте): раз в scepter_spawn_interval сек. рядом с MK появляется
-- солдат на scepter_spawn_duration сек. Не появляется, пока MK мёртв, невидим,
-- сидит на дереве или рядом нет врагов.
---------------------------------------------------------------------------------------------------

LinkLuaModifier("modifier_monkey_king_wukongs_command_aa_scepter", "heroes/monkey_king/monkey_king_wukongs_command_aa", LUA_MODIFIER_MOTION_NONE)

modifier_monkey_king_wukongs_command_aa_scepter = class({})

function modifier_monkey_king_wukongs_command_aa_scepter:IsHidden() return true end
function modifier_monkey_king_wukongs_command_aa_scepter:IsPurgable() return false end
function modifier_monkey_king_wukongs_command_aa_scepter:RemoveOnDeath() return false end

function modifier_monkey_king_wukongs_command_aa_scepter:OnCreated()
	if not IsServer() then return end

	self.next_spawn = 0
	self:StartIntervalThink(0.25)

	-- солдаты - герои-юниты того же имени с дефолтными вещами: догружаем их
	-- заранее, иначе под солдатами висит красное ERROR. Только асинхронно и
	-- вне Precache (см. комментарий в Precache способности). Один раз на героя.
	local name = self:GetParent():GetUnitName()

	AA_MK_SOLDIER_PRECACHED = AA_MK_SOLDIER_PRECACHED or {}

	if not AA_MK_SOLDIER_PRECACHED[name] then
		AA_MK_SOLDIER_PRECACHED[name] = true
		PrecacheUnitByNameAsync(name, function() end)
	end
end

function modifier_monkey_king_wukongs_command_aa_scepter:OnIntervalThink()
	local caster = self:GetParent()
	local ability = self:GetAbility()

	if not ability or ability:IsNull() or ability:GetLevel() < 1 then return end
	if not caster:IsRealHero() or not caster:HasScepter() then return end
	if not caster:IsAlive() or caster:IsInvisible() then return end
	if caster:HasModifier("modifier_monkey_king_bounce_perch") or caster:HasModifier("modifier_monkey_king_tree_dance_hidden") then return end

	local now = GameRules:GetGameTime()

	if now < self.next_spawn then return end

	-- враги рядом: иначе солдат постоит впустую
	local enemies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, ability:GetSpecialValueFor("scepter_spawn_search"),
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS, FIND_ANY_ORDER, false)

	if #enemies == 0 then return end

	self.next_spawn = now + ability:GetSpecialValueFor("scepter_spawn_interval")

	local point = caster:GetAbsOrigin() + RandomVector(RandomFloat(150, 250))

	ability:SpawnSoldier(caster:GetAbsOrigin(), point, ability:GetSpecialValueFor("scepter_spawn_duration"))
end

function modifier_monkey_king_wukongs_command_aa_soldier:CheckState()
	return {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_UNSELECTABLE] = true,
		[MODIFIER_STATE_UNTARGETABLE] = true,
		[MODIFIER_STATE_NOT_ON_MINIMAP] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY] = true,
		[MODIFIER_STATE_CANNOT_BE_MOTION_CONTROLLED] = true,
		[MODIFIER_STATE_ROOTED] = self.standing,
	}
end

function modifier_monkey_king_wukongs_command_aa_soldier:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_FIXED_ATTACK_RATE,
		MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE,
		MODIFIER_PROPERTY_TRANSLATE_ACTIVITY_MODIFIERS,
	}
end

function modifier_monkey_king_wukongs_command_aa_soldier:GetModifierFixedAttackRate()
	return self.attack_rate
end

function modifier_monkey_king_wukongs_command_aa_soldier:GetModifierMoveSpeed_Absolute()
	return self.move_speed
end

-- стойка солдата только без цели: с ней на модели не играет анимация атаки
function modifier_monkey_king_wukongs_command_aa_soldier:GetActivityTranslationModifiers()
	local stage = self:GetStackCount()

	if stage == 0 then return "run_fast" end -- ещё бежит на позицию
	if stage == 2 then return end           -- бьёт: обычная анимация атаки

	return "fur_army_soldier"
end

---------------------------------------------------------------------------------------------------
-- Броня MK внутри арены
---------------------------------------------------------------------------------------------------

modifier_monkey_king_wukongs_command_aa_buff = class({})

function modifier_monkey_king_wukongs_command_aa_buff:IsPurgable() return false end

function modifier_monkey_king_wukongs_command_aa_buff:GetTexture()
	return "monkey_king_wukongs_command"
end

function modifier_monkey_king_wukongs_command_aa_buff:OnCreated()
	local ability = self:GetAbility()

	self.armor = ability and ability:GetSpecialValueFor("bonus_armor") or 0
end

function modifier_monkey_king_wukongs_command_aa_buff:DeclareFunctions()
	return { MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS }
end

function modifier_monkey_king_wukongs_command_aa_buff:GetModifierPhysicalArmorBonus()
	return self.armor
end
