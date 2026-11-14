--[[
	Фамильяры Визажа на Lua. Движковый visage_summon_familiars на уровнях выше
	дотовских (4-7) не собирал юнитов ("entity class is NULL"), поэтому призыв
	и все способности птиц повторены здесь по описанию из доты:

	  visage_summon_familiars            - призыв (Alt-каст: отзыв всех птиц)
	  visage_stone_form_self_cast        - D: ближайшая к Визажу птица уходит в камень
	  visage_summon_familiars_stone_form - каменная форма птицы
	  visage_summon_familiars_recall     - отзыв птицы к Визажу

	Модификатор modifier_visage_familiar_lua на каждой птице:
	  плащ Визажа (защита по числу слоёв, пока птица в радиусе плаща),
	  инвиз, пока на Визаже Silent as the Grave с аганимом,
	  бонус урона, пока на Визаже бонус Silent as the Grave,
	  снижение брони от таланта, дальность атаки из способности.

	Модификаторы связаны с клиентом в addon_init.lua.
]]

local UNIT_NAME = "npc_dota_visage_familiar1"
local UNIT_BASE_ATTACK_RANGE = 180 -- AttackRange в unit.txt

LinkLuaModifier("modifier_visage_familiar_lua", "heroes/visage/visage_familiars", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_visage_familiar_invis_lua", "heroes/visage/visage_familiars", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_visage_familiar_stone_lua", "heroes/visage/visage_familiars", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_visage_familiar_recall_lua", "heroes/visage/visage_familiars", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_visage_familiar_armor_reduction_lua", "heroes/visage/visage_familiars", LUA_MODIFIER_MOTION_NONE)

local FAMILIAR_ABILITIES = {
	"visage_summon_familiars_stone_form",
	"visage_summon_familiars_recall",
}

local function IsAlive(unit)
	return unit and not unit:IsNull() and unit:IsAlive()
end

-- живые птицы героя
local function GetFamiliars(hero)
	local result = {}

	for _, unit in ipairs(hero.aa_visage_familiars or {}) do
		if IsAlive(unit) then table.insert(result, unit) end
	end

	hero.aa_visage_familiars = result

	return result
end

-- уровни способностей птиц и D-кнопки идут за уровнем ульты
local function SyncLevels(hero)
	local ult = hero:FindAbilityByName("visage_summon_familiars")
	if not ult then return end

	local level = ult:GetLevel()

	for _, name in ipairs({ "visage_stone_form_self_cast", "visage_summon_familiars_stone_form" }) do
		local ability = hero:FindAbilityByName(name)
		if ability and ability:GetLevel() ~= level then ability:SetLevel(level) end
	end

	for _, familiar in ipairs(GetFamiliars(hero)) do
		for _, name in ipairs(FAMILIAR_ABILITIES) do
			local ability = familiar:FindAbilityByName(name)
			if ability then
				ability:SetLevel(name == "visage_summon_familiars_recall" and 1 or math.max(level, 1))
			end
		end
	end
end

local function GetOwnerHero(familiar)
	return familiar.aa_visage_owner
end

-- отзыв птицы: recall_duration секунд стоит без действий, потом прыгает к Визажу
local function Recall(familiar, hero, duration)
	if not IsAlive(familiar) then return end
	if familiar:HasModifier("modifier_visage_familiar_recall_lua") then return end

	familiar:Stop()
	familiar:AddNewModifier(hero, nil, "modifier_visage_familiar_recall_lua", { duration = duration })
	familiar:EmitSound("Hero_Visage.SummonFamiliars.Recall")
end

--------------------------------------------------------------------------------
-- Призыв
--------------------------------------------------------------------------------

visage_summon_familiars = class({})

function visage_summon_familiars:OnUpgrade()
	SyncLevels(self:GetCaster())
end

function visage_summon_familiars:IsAltCast()
	local ok, state = pcall(function() return self:GetAltCastState() end)
	return ok and state == true
end

function visage_summon_familiars:OnSpellStart()
	local hero = self:GetCaster()

	-- Alt-каст: отозвать всех птиц, без отката и маны
	if self:IsAltCast() then
		local familiars = GetFamiliars(hero)

		if #familiars > 0 then
			self:EndCooldown()
			self:RefundManaCost()

			local duration = self:GetSpecialValueFor("recall_duration")

			for _, familiar in ipairs(familiars) do
				Recall(familiar, hero, duration)
			end

			return
		end
	end

	-- старые птицы исчезают
	for _, familiar in ipairs(GetFamiliars(hero)) do
		familiar:ForceKill(false)
	end

	hero.aa_visage_familiars = {}
	hero:EmitSound("Hero_Visage.SummonFamiliars.Cast")

	local count = self:GetSpecialValueFor("familiar_count")
	local forward = hero:GetForwardVector()
	local right = hero:GetRightVector()

	for i = 1, count do
		local side = (i % 2 == 0) and 1 or -1
		local offset = right * side * 120 * math.ceil(i / 2) + forward * 100
		local familiar = CreateUnitByName(UNIT_NAME, hero:GetAbsOrigin() + offset, true, hero, hero, hero:GetTeamNumber())

		if familiar then
			self:SetupFamiliar(familiar, hero)
			table.insert(hero.aa_visage_familiars, familiar)
		else
			print("[visage_summon_familiars] cannot create " .. UNIT_NAME)
		end
	end

	SyncLevels(hero)
end

function visage_summon_familiars:SetupFamiliar(familiar, hero)
	familiar.aa_visage_owner = hero
	familiar:SetOwner(hero)
	familiar:SetControllableByPlayer(hero:GetPlayerOwnerID(), true)
	familiar:SetForwardVector(hero:GetForwardVector())

	local hp = self:GetSpecialValueFor("familiar_hp")
	local damage = self:GetSpecialValueFor("familiar_attack_damage")
	local bounty = self:GetSpecialValueFor("familiar_bounty")

	familiar:SetBaseMaxHealth(hp)
	familiar:SetMaxHealth(hp)
	familiar:SetPhysicalArmorBaseValue(self:GetSpecialValueFor("familiar_armor"))
	familiar:SetBaseDamageMin(damage)
	familiar:SetBaseDamageMax(damage)
	familiar:SetBaseMoveSpeed(self:GetSpecialValueFor("familiar_base_movespeed"))
	familiar:SetMinimumGoldBounty(bounty)
	familiar:SetMaximumGoldBounty(bounty)

	familiar:AddNewModifier(hero, self, "modifier_visage_familiar_lua", {})

	familiar:CalculateGenericBonuses()
	familiar:SetHealth(familiar:GetMaxHealth())

	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_visage/visage_summon_familiars.vpcf", PATTACH_ABSORIGIN_FOLLOW, familiar)
	ParticleManager:ReleaseParticleIndex(fx)
end

--------------------------------------------------------------------------------
-- Каменная форма (способность птицы)
--------------------------------------------------------------------------------

visage_summon_familiars_stone_form = class({})

local function StartStoneForm(familiar, ability)
	if not IsAlive(familiar) then return false end
	if familiar:HasModifier("modifier_visage_familiar_stone_lua") then return false end
	if familiar:HasModifier("modifier_visage_familiar_recall_lua") then return false end

	local delay = ability:GetSpecialValueFor("stun_delay")
	local stone = ability:GetSpecialValueFor("stone_duration")

	familiar:Stop()
	familiar:AddNewModifier(familiar, ability, "modifier_visage_familiar_stone_lua", { duration = delay + stone })
	familiar:EmitSound("Visage_Familiar.StoneForm.Cast")

	return true
end

function visage_summon_familiars_stone_form:CastFilterResult()
	local caster = self:GetCaster()
	if caster:IsRealHero() then return UF_FAIL_CUSTOM end
	return UF_SUCCESS
end

function visage_summon_familiars_stone_form:GetCustomCastError()
	return "#dota_hud_error_cant_cast_on_self"
end

function visage_summon_familiars_stone_form:OnSpellStart()
	StartStoneForm(self:GetCaster(), self)
end

--------------------------------------------------------------------------------
-- D: ближайшая к Визажу птица уходит в камень
--------------------------------------------------------------------------------

visage_stone_form_self_cast = class({})

function visage_stone_form_self_cast:GetNearest()
	local hero = self:GetCaster()
	local origin = hero:GetAbsOrigin()
	local best, best_dist

	for _, familiar in ipairs(GetFamiliars(hero)) do
		local stone = familiar:FindAbilityByName("visage_summon_familiars_stone_form")

		if stone and stone:IsCooldownReady()
			and not familiar:HasModifier("modifier_visage_familiar_stone_lua")
			and not familiar:HasModifier("modifier_visage_familiar_recall_lua")
			and not familiar:IsStunned() and not familiar:IsSilenced() then
			local dist = (familiar:GetAbsOrigin() - origin):Length2D()

			if not best_dist or dist < best_dist then
				best, best_dist = familiar, dist
			end
		end
	end

	return best
end

-- через сколько секунд освободится хоть одна птица (nil - птиц нет)
local function StoneWait(hero)
	local best

	for _, familiar in ipairs(GetFamiliars(hero)) do
		local stone = familiar:FindAbilityByName("visage_summon_familiars_stone_form")

		if stone then
			local wait = stone:GetCooldownTimeRemaining()

			for _, name in ipairs({ "modifier_visage_familiar_stone_lua", "modifier_visage_familiar_recall_lua" }) do
				local modifier = familiar:FindModifierByName(name)
				if modifier then wait = math.max(wait, modifier:GetRemainingTime()) end
			end

			if not best or wait < best then best = wait end
		end
	end

	return best
end

-- все птицы заняты: кнопка D уходит в откат до ближайшей свободной птицы
local function SyncSelfCastCooldown(hero)
	local self_cast = hero:FindAbilityByName("visage_stone_form_self_cast")
	if not self_cast or self_cast:GetLevel() < 1 then return end

	local wait = StoneWait(hero)
	if not wait or wait <= 0.05 then return end

	if math.abs(self_cast:GetCooldownTimeRemaining() - wait) > 0.2 then
		self_cast:EndCooldown()
		self_cast:StartCooldown(wait)
	end
end

function visage_stone_form_self_cast:OnSpellStart()
	local familiar = self:GetNearest()

	if not familiar then
		SyncSelfCastCooldown(self:GetCaster())
		return
	end

	local stone = familiar:FindAbilityByName("visage_summon_familiars_stone_form")

	if StartStoneForm(familiar, stone) then
		stone:StartCooldown(stone:GetEffectiveCooldown(stone:GetLevel()))
	end

	SyncSelfCastCooldown(self:GetCaster())
end

--------------------------------------------------------------------------------
-- Отзыв птицы
--------------------------------------------------------------------------------

visage_summon_familiars_recall = class({})

function visage_summon_familiars_recall:OnSpellStart()
	local familiar = self:GetCaster()
	local hero = GetOwnerHero(familiar)

	if hero and not hero:IsNull() then
		Recall(familiar, hero, self:GetSpecialValueFor("recall_duration"))
	end
end

--------------------------------------------------------------------------------
-- Основной модификатор птицы
--------------------------------------------------------------------------------

modifier_visage_familiar_lua = class({})

function modifier_visage_familiar_lua:IsHidden() return true end
function modifier_visage_familiar_lua:IsPurgable() return false end
function modifier_visage_familiar_lua:RemoveOnDeath() return true end

function modifier_visage_familiar_lua:OnCreated()
	self.cloak = 0
	self.grave_damage = 0

	local ability = self:GetAbility()
	self.range_bonus = ability and (ability:GetSpecialValueFor("familiar_attack_range") - UNIT_BASE_ATTACK_RANGE) or 0

	if not IsServer() then return end

	self:SetHasCustomTransmitterData(true)
	self:OnIntervalThink()
	self:StartIntervalThink(0.1)
end

function modifier_visage_familiar_lua:AddCustomTransmitterData()
	return { cloak = self.cloak, grave_damage = self.grave_damage, range_bonus = self.range_bonus }
end

function modifier_visage_familiar_lua:HandleCustomTransmitterData(data)
	self.cloak = data.cloak
	self.grave_damage = data.grave_damage
	self.range_bonus = data.range_bonus
end

-- защита плащом: слои Визажа * damage_reduction, пока птица в радиусе плаща
function modifier_visage_familiar_lua:CalcCloak(hero)
	local cloak = hero:FindAbilityByName("visage_gravekeepers_cloak")
	if not cloak or cloak:GetLevel() < 1 or hero:PassivesDisabled() or not hero:IsAlive() then return 0 end

	local radius = cloak:GetSpecialValueFor("radius")
	if (hero:GetAbsOrigin() - self:GetParent():GetAbsOrigin()):Length2D() > radius then return 0 end

	local modifier = hero:FindModifierByName("modifier_visage_gravekeepers_cloak")
	if not modifier then return 0 end

	local layers = math.min(modifier:GetStackCount(), cloak:GetSpecialValueFor("max_layers"))
	local value = layers * cloak:GetSpecialValueFor("damage_reduction")
	local cap = cloak:GetSpecialValueFor("max_damage_reduction")

	if cap > 0 then value = math.min(value, cap) end

	return value
end

function modifier_visage_familiar_lua:OnIntervalThink()
	local parent = self:GetParent()
	local hero = self:GetCaster()

	if not hero or hero:IsNull() then return end

	SyncSelfCastCooldown(hero)

	local cloak = self:CalcCloak(hero)

	-- Silent as the Grave: бонус урона и (с аганимом) инвиз вместе с Визажем
	local grave = hero:FindAbilityByName("visage_silent_as_the_grave")
	local grave_damage = 0

	if grave and hero:HasModifier("modifier_visage_silent_as_the_grave_bonus") then
		grave_damage = grave:GetSpecialValueFor("bonus_damage")
	end

	local flight = hero:FindModifierByName("modifier_visage_silent_as_the_grave")
	local invis = parent:FindModifierByName("modifier_visage_familiar_invis_lua")

	if flight and hero:HasScepter() and not parent:HasModifier("modifier_visage_familiar_stone_lua") then
		if not invis then
			parent:AddNewModifier(hero, nil, "modifier_visage_familiar_invis_lua", {})
		end
	elseif invis then
		invis:Destroy()
	end

	if cloak ~= self.cloak or grave_damage ~= self.grave_damage then
		self.cloak = cloak
		self.grave_damage = grave_damage
		self:SendBuffRefreshToClients()
	end
end

function modifier_visage_familiar_lua:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
		MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE,
		MODIFIER_PROPERTY_ATTACK_RANGE_BONUS,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end

function modifier_visage_familiar_lua:GetModifierIncomingDamage_Percentage()
	return -(self.cloak or 0)
end

function modifier_visage_familiar_lua:GetModifierDamageOutgoing_Percentage()
	return self.grave_damage or 0
end

function modifier_visage_familiar_lua:GetModifierAttackRangeBonus()
	return self.range_bonus or 0
end

-- талант: каждое попадание птицы снижает броню цели
function modifier_visage_familiar_lua:OnAttackLanded(params)
	if not IsServer() then return end
	if params.attacker ~= self:GetParent() then return end

	local ability = self:GetAbility()
	if not ability then return end

	local per_hit = ability:GetSpecialValueFor("armor_reduction_per_hit")
	local duration = ability:GetSpecialValueFor("armor_reduction_duration")
	local target = params.target

	if per_hit <= 0 or duration <= 0 or not target or target:IsNull() or target:IsBuilding() then return end

	local debuff = target:FindModifierByName("modifier_visage_familiar_armor_reduction_lua")
		or target:AddNewModifier(self:GetCaster(), ability, "modifier_visage_familiar_armor_reduction_lua", { duration = duration })

	if debuff then
		debuff:SetDuration(duration, true)
		debuff:SetStackCount(debuff:GetStackCount() + 1)
		debuff.per_hit = per_hit
	end
end

--------------------------------------------------------------------------------
-- Снижение брони от таланта
--------------------------------------------------------------------------------

modifier_visage_familiar_armor_reduction_lua = class({})

function modifier_visage_familiar_armor_reduction_lua:IsDebuff() return true end
function modifier_visage_familiar_armor_reduction_lua:IsPurgable() return true end
function modifier_visage_familiar_armor_reduction_lua:GetTexture() return "visage_summon_familiars" end

function modifier_visage_familiar_armor_reduction_lua:OnCreated()
	local ability = self:GetAbility()
	self.per_hit = ability and ability:GetSpecialValueFor("armor_reduction_per_hit") or 1
end

function modifier_visage_familiar_armor_reduction_lua:DeclareFunctions()
	return { MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS }
end

function modifier_visage_familiar_armor_reduction_lua:GetModifierPhysicalArmorBonus()
	return -self:GetStackCount() * (self.per_hit or 1)
end

--------------------------------------------------------------------------------
-- Инвиз птицы (Silent as the Grave с аганимом)
--------------------------------------------------------------------------------

modifier_visage_familiar_invis_lua = class({})

function modifier_visage_familiar_invis_lua:IsHidden() return false end
function modifier_visage_familiar_invis_lua:IsPurgable() return false end
function modifier_visage_familiar_invis_lua:GetTexture() return "visage_silent_as_the_grave" end

function modifier_visage_familiar_invis_lua:CheckState()
	return { [MODIFIER_STATE_INVISIBLE] = true }
end

function modifier_visage_familiar_invis_lua:DeclareFunctions()
	return { MODIFIER_PROPERTY_INVISIBILITY_LEVEL }
end

function modifier_visage_familiar_invis_lua:GetModifierInvisibilityLevel()
	return 1
end

--------------------------------------------------------------------------------
-- Каменная форма: stun_delay падает, потом оглушение по области,
-- неуязвимость и hp_regen до конца
--------------------------------------------------------------------------------

modifier_visage_familiar_stone_lua = class({})

function modifier_visage_familiar_stone_lua:IsHidden() return false end
function modifier_visage_familiar_stone_lua:IsPurgable() return false end
function modifier_visage_familiar_stone_lua:GetTexture() return "visage_summon_familiars_stone_form" end

function modifier_visage_familiar_stone_lua:OnCreated()
	local ability = self:GetAbility()

	self.landed = false
	self.regen = ability and ability:GetSpecialValueFor("hp_regen") or 0

	if not IsServer() or not ability then return end

	self.radius = ability:GetSpecialValueFor("stun_radius")
	self.damage = ability:GetSpecialValueFor("stun_damage")
	self.stun = ability:GetSpecialValueFor("stun_duration")

	self:StartIntervalThink(ability:GetSpecialValueFor("stun_delay"))
end

-- таймер над головой: сколько секунд птица ещё будет камнем
-- (цифры как у таймера Unstable Concoction, раз в полсекунды)
function modifier_visage_familiar_stone_lua:ShowTimer()
	local left = self:GetRemainingTime()
	if left <= 0 then return end

	self.timer_half = not self.timer_half

	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_alchemist/alchemist_unstable_concoction_timer.vpcf", PATTACH_OVERHEAD_FOLLOW, self:GetParent())
	ParticleManager:SetParticleControl(fx, 1, Vector(1, math.floor(left), self.timer_half and 8 or 1))
	ParticleManager:SetParticleControl(fx, 2, Vector(left < 1 and 1 or 2, 0, 0))
	ParticleManager:ReleaseParticleIndex(fx)
end

function modifier_visage_familiar_stone_lua:OnIntervalThink()
	if self.landed then
		self:ShowTimer()
		return
	end

	self:StartIntervalThink(0.5)
	self:ShowTimer()

	local parent = self:GetParent()
	local ability = self:GetAbility()

	self.landed = true
	self:SetStackCount(1) -- клиенту: уже камень

	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_visage/visage_stone_form.vpcf", PATTACH_ABSORIGIN, parent)
	ParticleManager:SetParticleControl(fx, 0, parent:GetAbsOrigin())
	ParticleManager:SetParticleControl(fx, 1, Vector(self.radius, self.radius, self.radius))
	ParticleManager:ReleaseParticleIndex(fx)

	local owner = GetOwnerHero(parent) or parent
	local enemies = FindUnitsInRadius(parent:GetTeamNumber(), parent:GetAbsOrigin(), nil, self.radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

	for _, enemy in ipairs(enemies) do
		ApplyDamage({
			victim = enemy,
			attacker = owner,
			damage = self.damage,
			damage_type = DAMAGE_TYPE_MAGICAL,
			ability = ability,
		})

		if IsAlive(enemy) then
			enemy:AddNewModifier(owner, ability, "modifier_stunned", { duration = self.stun * (1 - enemy:GetStatusResistance()) })
		end
	end
end

function modifier_visage_familiar_stone_lua:CheckState()
	local state = {
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_SILENCED] = true,
		[MODIFIER_STATE_MUTED] = true,
	}

	if self:GetStackCount() > 0 then
		state[MODIFIER_STATE_INVULNERABLE] = true
		state[MODIFIER_STATE_FROZEN] = true
	end

	return state
end

function modifier_visage_familiar_stone_lua:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
		MODIFIER_PROPERTY_VISUAL_Z_DELTA,
	}
end

function modifier_visage_familiar_stone_lua:GetModifierConstantHealthRegen()
	if self:GetStackCount() > 0 then return self.regen end
	return 0
end

-- птица опускается на землю
function modifier_visage_familiar_stone_lua:GetVisualZDelta()
	return -60
end

function modifier_visage_familiar_stone_lua:GetStatusEffectName()
	return "particles/status_fx/status_effect_earth_spirit_petrify.vpcf"
end

--------------------------------------------------------------------------------
-- Отзыв: recall_duration без действий, затем к Визажу
--------------------------------------------------------------------------------

modifier_visage_familiar_recall_lua = class({})

function modifier_visage_familiar_recall_lua:IsHidden() return false end
function modifier_visage_familiar_recall_lua:IsPurgable() return false end
function modifier_visage_familiar_recall_lua:GetTexture() return "visage_summon_familiars" end

-- эффект отзыва из доты (тот же, что у Recall Кипера - его же грузит server.dll)
function modifier_visage_familiar_recall_lua:GetEffectName()
	return "particles/units/heroes/hero_keeper_of_the_light/keeper_of_the_light_recall.vpcf"
end

function modifier_visage_familiar_recall_lua:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_visage_familiar_recall_lua:CheckState()
	return {
		[MODIFIER_STATE_COMMAND_RESTRICTED] = true,
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_ROOTED] = true,
	}
end

function modifier_visage_familiar_recall_lua:OnDestroy()
	if not IsServer() then return end

	local parent = self:GetParent()
	local hero = self:GetCaster()

	if self:GetRemainingTime() > 0.05 then return end -- сняли раньше (смерть и т.п.)
	if not IsAlive(parent) or not hero or hero:IsNull() or not hero:IsAlive() then return end

	local poof = "particles/units/heroes/hero_keeper_of_the_light/keeper_of_the_light_recall_poof.vpcf"
	local fx = ParticleManager:CreateParticle(poof, PATTACH_ABSORIGIN, parent)
	ParticleManager:ReleaseParticleIndex(fx)

	local pos = hero:GetAbsOrigin() - hero:GetForwardVector() * 100
	FindClearSpaceForUnit(parent, pos, true)
	parent:Stop()

	fx = ParticleManager:CreateParticle(poof, PATTACH_ABSORIGIN, parent)
	ParticleManager:ReleaseParticleIndex(fx)
end
