--[[
	Усиление суммона от характеристик хозяина. Коэффициенты - scripts/npc/summon_power.kv.

	  ловкость  -> броня (% от героя), скорость атаки (% от бонуса героя),
	               скорость бега и % игнорирования брони цели;
	  интеллект -> урон атаки (% от урона героя);
	  сила      -> ХП (% от ХП героя) и сопротивление урону.

	Считается на сервере раз в update_interval и передаётся клиенту, чтобы
	панель характеристик суммона показывала те же числа.
]]

modifier_summon_power = class({})

local CONFIG

local function Config()
	if not CONFIG then
		local kv = LoadKeyValues("scripts/npc/summon_power.kv") or {}
		-- значения лежат внутри корневого блока "summon_power"; раньше их
		-- читали из корня, все коэффициенты были 0 и бафф не давал ничего
		CONFIG = kv.summon_power or kv
	end

	return CONFIG
end

local function Num(key)
	return tonumber(Config()[key]) or 0
end

function modifier_summon_power:IsPurgable() return false end
function modifier_summon_power:RemoveOnDeath() return true end
function modifier_summon_power:GetTexture() return "beastmaster_inner_beast" end

if IsServer() then require('lib/summon_utils') end

-- Модификатор выдаётся двумя путями:
--   1) постоянный модификатор способности summon_power_passive, прописанной
--      юнитам героев (heroes/*/unit.txt) - caster тут сам юнит;
--   2) lib/summon_power.lua при появлении прочих суммонов - caster тут герой.
-- Хозяина ищем сами, пока не найдём; пока он не найден или юнит не суммон -
-- бафф пустой.
function modifier_summon_power:OnCreated()
	self.armor = 0
	self.attack_speed = 0
	self.move_speed = 0
	self.pierce = 0
	self.damage = 0
	self.health = 0
	self.resist = 0
	self.magic_resist = 0
	if not IsServer() then return end

	self:SetHasCustomTransmitterData(true)

	-- Без бонуса ХП (2026-11-14) - только то, что в доте живёт ПО УДАРАМ (здоровье = число
	-- ударов, герой снимает 2, крип 1): бонус ХП превращал их в юниты с полоской ХП.
	--   зомби Андаинга - лезут из надгробия десятками (было и раньше);
	--   змейки Шамана и большая змея с шарда (класс npc_dota_shadowshaman_serpentward, юниты
	--   *shadow_shaman_ward*), варды Пугны (*pugna_nether_ward*);
	--   скелеты Клинкза;
	--   любой юнит с базовым здоровьем <= HIT_BASED_MAX_HP (это число ударов).
	-- Варды Веномансера и Death Ward живут по ХП - им бонус ХП положен, их не трогаем.
	-- Остальной бафф (урон, скорость атаки, резисты) всем остаётся.
	local pname = string.lower(self:GetParent():GetUnitName() or "")
	local pclass = string.lower(self:GetParent():GetClassname() or "")
	local HIT_BASED_MAX_HP = 20

	self.no_health = string.find(pname, "undying_zombie", 1, true) ~= nil
		or string.find(pname, "shadow_shaman_ward", 1, true) ~= nil
		or string.find(pclass, "serpentward", 1, true) ~= nil
		or string.find(pname, "pugna_nether_ward", 1, true) ~= nil
		or self:GetParent():GetBaseMaxHealth() <= HIT_BASED_MAX_HP
		-- скелеты Клинкза: в KV 1000 ХП, но удары считает сам класс npc_dota_clinkz_skeleton_archer
		or string.find(pclass, "clinkz_skeleton", 1, true) ~= nil
		or string.find(pname, "clinkz_skeleton", 1, true) ~= nil

	-- первый пересчёт кадром позже: владельца способности часто ставят
	-- сразу после создания юнита, а клиент в кадр создания модификатор не знает
	self.first_think = true
	self:StartIntervalThink(FrameTime())
end

function modifier_summon_power:GetHero()
	if self.hero and not self.hero:IsNull() then return self.hero end

	local parent = self:GetParent()
	local caster = self:GetCaster()
	local hero

	if caster and not caster:IsNull() and caster ~= parent and caster.IsRealHero and caster:IsRealHero() then
		hero = caster
	elseif SummonUtils:IsPowerTarget(parent) then
		hero = SummonUtils:GetOwnerHero(parent)
	end

	if not hero or hero:IsNull() or hero == parent then return nil end

	self.hero = hero

	-- остальное, что суммону положено от хозяина (Pierce и т.п.)
	SummonUtils:FireSpawned(parent, hero)

	return hero
end

function modifier_summon_power:OnIntervalThink()
	local hero = self:GetHero()

	if not hero then
		-- хозяина нет полсекунды - юнит не суммон героя (или исключён), бафф не нужен
		self.wait = (self.wait or 0) + 1
		if self.wait >= 15 then self:Destroy() end
		return
	end

	self:Recalculate(hero)

	if self.first_think then
		self.first_think = false
		self:SetStackCount(1) -- видимый бафф только у тех, кому он реально даёт статы

		local parent = self:GetParent()
		parent:CalculateGenericBonuses()
		parent:SetHealth(parent:GetMaxHealth())

		local interval = Num("update_interval")
		self:StartIntervalThink(interval > 0 and interval or 1)
	end
end

function modifier_summon_power:IsHidden()
	return self:GetStackCount() == 0
end

function modifier_summon_power:Recalculate(hero)
	local agi = hero:GetAgility()
	local str = hero:GetStrength()
	local int = hero:GetIntellect(false)

	local values = {
		armor = hero:GetPhysicalArmorValue(false) * Num("armor_pct") / 100,
		attack_speed = hero:GetIncreasedAttackSpeed(false) * 100 * Num("attack_speed_pct") / 100,
		move_speed = agi * Num("move_speed_per_agi"),
		pierce = math.min(agi * Num("armor_pierce_per_agi"), Num("armor_pierce_max")),
		damage = hero:GetAverageTrueAttackDamage(nil) * Num("damage_pct") / 100 + int * Num("damage_per_int"),
		-- зомби Андаинга лезут из надгробия десятками: бонус ХП им не даём
		health = self.no_health and 0 or hero:GetMaxHealth() * Num("health_pct") / 100,
		resist = math.min(str * Num("damage_resist_per_str"), Num("damage_resist_max")),
		magic_resist = math.min(int * Num("magic_resist_per_int"), Num("magic_resist_max")),
	}

	-- ничего не поменялось - ни пересылки клиенту, ни пересчёта статов
	local changed = false

	for key, value in pairs(values) do
		if math.abs((self[key] or 0) - value) >= 0.01 then changed = true end
	end

	if not changed then return end

	local old_health = self.health

	for key, value in pairs(values) do self[key] = value end

	self:SendBuffRefreshToClients()

	-- движок кэширует статы юнита и пересчитывал их только по событию
	-- (например, атаке суммона) - до первой тычки бонуса не было видно
	local parent = self:GetParent()
	local pct = parent:GetHealthPercent()

	parent:CalculateGenericBonuses()

	-- ХП сменилось: держим тот же процент здоровья
	if math.abs(self.health - old_health) >= 1 then
		parent:SetHealth(math.max(1, parent:GetMaxHealth() * pct / 100))
	end
end


function modifier_summon_power:AddCustomTransmitterData()
	return {
		armor = self.armor,
		attack_speed = self.attack_speed,
		move_speed = self.move_speed,
		pierce = self.pierce,
		damage = self.damage,
		health = self.health,
		resist = self.resist,
		magic_resist = self.magic_resist,
	}
end

function modifier_summon_power:HandleCustomTransmitterData(data)
	self.armor = data.armor
	self.attack_speed = data.attack_speed
	self.move_speed = data.move_speed
	self.pierce = data.pierce
	self.damage = data.damage
	self.health = data.health
	self.resist = data.resist
	self.magic_resist = data.magic_resist

	-- клиенту тоже: пересчитать статы под новые числа (панель статов)
	local parent = self:GetParent()
	if parent and not parent:IsNull() and parent.CalculateGenericBonuses then
		pcall(function() parent:CalculateGenericBonuses() end)
	end
end

function modifier_summon_power:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_EXTRA_HEALTH_BONUS,
		MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
		MODIFIER_PROPERTY_TOOLTIP,
		MODIFIER_PROPERTY_TOOLTIP2,
		MODIFIER_PROPERTY_IGNORE_PHYSICAL_ARMOR,
		MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS
	}
end


function modifier_summon_power:GetModifierPhysicalArmorBonus() return self.armor end
function modifier_summon_power:GetModifierAttackSpeedBonus_Constant() return self.attack_speed end
function modifier_summon_power:GetModifierMoveSpeedBonus_Constant() return self.move_speed end
function modifier_summon_power:GetModifierPreAttack_BonusDamage() return self.damage end
function modifier_summon_power:GetModifierExtraHealthBonus() return self.health end
function modifier_summon_power:GetModifierIncomingDamage_Percentage() return -self.resist end
function modifier_summon_power:GetModifierMagicalResistanceBonus() return self.magic_resist end
-- доля брони цели, которую игнорирует атака суммона (0..1)
function modifier_summon_power:GetModifierIgnorePhysicalArmor() return (self.pierce or 0) / 100 end

-- для описания модификатора: пробивание брони и сопротивление урону, %
function modifier_summon_power:OnTooltip() return self.pierce or 0 end
function modifier_summon_power:OnTooltip2() return self.resist or 0 end
