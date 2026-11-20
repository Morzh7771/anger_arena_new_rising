require("lib/attack_potency")
-- Чары Angel Arena (item_aa_enhancement_*, нейтральный пассивный слот).
-- Свои предметы вместо ванильных item_enhancement_*: никаких механик, только статы.
-- Все чары - один класс и один модификатор, который читает ключи AbilityValues
-- предмета (neutral_items_stat.txt). Ключа у чары нет - GetSpecialValueFor даёт 0.
-- Значения читаются каждый раз (не кешируются): безделушка (modifier_aa_enchanters_bauble)
-- подменяет их через GetModifierOverrideAbilitySpecialValue.
--
-- Ключи:
--   movement_speed / movespeed_unique (не стакается с сапогами) / movespeed_pct
--   movespeed_limit_bonus - лимит скорости, считает modifier_aa_hero
--   bonus_mana, max_mana_pct, mana_regen, manacost_reduction
--   health_bonus, health_regen, max_health_pct, health_restoration
--   bonus_damage, max_health_to_damage_pct (% макс. HP к урону атаки), base_attack_damage
--   bonus_attack_speed, attack_speed_pct, bat_reduce (% BAT), bonus_attack_range(_melee)
--   armor, evasion, magic_res, status_resistance, slow_resist, knockback_resist, incoming_damage
--   bonus_night_vision, vision_pct, cast_range_bonus, cast_speed, cooldown_reduction
--   spell_amp, debuff_amp, attack_lifesteal, spell_lifesteal
--   intelligence_pct, primary_stat (+ primary_stat_pct % от базового; универсалу треть в каждый)
--   magic_damage_pct - % урона атаки отдельным магическим уроном по цели
--   bonus_gpm - золото в минуту

LinkLuaModifier("modifier_item_aa_enhancement", "items/item_aa_enhancement", LUA_MODIFIER_MOTION_NONE)

-- Знак для MODIFIER_PROPERTY_BASE_ATTACK_TIME_PERCENTAGE: снижение BAT на bat_reduce %.
-- Если в панели статов BAT с Crude/Manic вырос, а не упал - поменять на 1.
local BAT_PCT_SIGN = -1

local NAMES = {
	"quickened", "vital", "brawny", "tough", "alert", "mystical",
	"greedy", "crude", "nimble", "keen_eyed", "titanic",
	"timeless", "evolved", "fleetfooted", "vampiric",
	"hulking", "audacious", "feverish", "manic",
}

for _, name in ipairs(NAMES) do
	-- item_lua ищет класс по имени предмета
	_G["item_aa_enhancement_" .. name] = class({
		GetIntrinsicModifierName = function (self) return "modifier_item_aa_enhancement" end,
	})
end

modifier_item_aa_enhancement = class({})

local M = modifier_item_aa_enhancement

function M:IsHidden() return true end
function M:IsPurgable() return false end
function M:RemoveOnDeath() return false end
function M:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT end

function M:V(key)
	local ability = self:GetAbility()
	if not ability or ability:IsNull() then return 0 end
	return ability:GetSpecialValueFor(key)
end

-- Списком имён: константы, которых нет в Lua-API этой сборки, пропускаются, а не рвут таблицу (nil).
local DECLARED = {
	"MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT",
	"MODIFIER_PROPERTY_MOVESPEED_BONUS_UNIQUE",
	"MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE",
	"MODIFIER_PROPERTY_MANA_BONUS",
	"MODIFIER_PROPERTY_EXTRA_MANA_PERCENTAGE",
	"MODIFIER_PROPERTY_MANA_REGEN_CONSTANT",
	"MODIFIER_PROPERTY_MANACOST_PERCENTAGE_STACKING",
	"MODIFIER_PROPERTY_HEALTH_BONUS",
	"MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT",
	"MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE",
	"MODIFIER_PROPERTY_EXTRA_HEALTH_PERCENTAGE",
	"MODIFIER_PROPERTY_HEAL_AMPLIFY_PERCENTAGE_TARGET",
	"MODIFIER_PROPERTY_HP_REGEN_AMPLIFY_PERCENTAGE",
	"MODIFIER_PROPERTY_LIFESTEAL_AMPLIFY_PERCENTAGE",
	"MODIFIER_PROPERTY_SPELL_LIFESTEAL_AMPLIFY_PERCENTAGE",
	"MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE",
	"MODIFIER_PROPERTY_BASEDAMAGEOUTGOING_PERCENTAGE",
	"MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT",
	"MODIFIER_PROPERTY_ATTACKSPEED_PERCENTAGE",
	"MODIFIER_PROPERTY_BASE_ATTACK_TIME_PERCENTAGE",
	"MODIFIER_PROPERTY_ATTACK_RANGE_BONUS",
	"MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS",
	"MODIFIER_PROPERTY_EVASION_CONSTANT",
	"MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS",
	"MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING",
	"MODIFIER_PROPERTY_STATUS_RESISTANCE_CASTER",
	"MODIFIER_PROPERTY_SLOW_RESISTANCE_STACKING",
	"MODIFIER_PROPERTY_KNOCKBACK_AMPLIFICATION_PERCENTAGE",
	"MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE",
	"MODIFIER_PROPERTY_BONUS_NIGHT_VISION",
	"MODIFIER_PROPERTY_BONUS_VISION_PERCENTAGE",
	"MODIFIER_PROPERTY_CAST_RANGE_BONUS_STACKING",
	"MODIFIER_PROPERTY_CASTTIME_PERCENTAGE",
	"MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE",
	"MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE",
	"MODIFIER_PROPERTY_PHYSICAL_LIFESTEAL",
	"MODIFIER_PROPERTY_MAGICAL_LIFESTEAL",
	"MODIFIER_PROPERTY_STATS_STRENGTH_BONUS",
	"MODIFIER_PROPERTY_STATS_AGILITY_BONUS",
	"MODIFIER_PROPERTY_STATS_INTELLECT_BONUS",
	"MODIFIER_PROPERTY_STATS_INTELLECT_BONUS_PERCENTAGE",
	"MODIFIER_EVENT_ON_ATTACK_LANDED",
}

function M:DeclareFunctions()
	local list = {}
	for _, name in ipairs(DECLARED) do
		if _G[name] ~= nil then table.insert(list, _G[name]) end
	end
	return list
end

-- скорость
function M:GetModifierMoveSpeedBonus_Constant() return self:V("movement_speed") end
function M:GetModifierMoveSpeedBonus_Special_Boots() return self:V("movespeed_unique") end
function M:GetModifierMoveSpeedBonus_Percentage() return self:V("movespeed_pct") end

-- мана
function M:GetModifierManaBonus() return self:V("bonus_mana") end
function M:GetModifierExtraManaPercentage() return self:V("max_mana_pct") end
function M:GetModifierConstantManaRegen() return self:V("mana_regen") end
function M:GetModifierPercentageManacostStacking() return self:V("manacost_reduction") end

-- здоровье
function M:GetModifierHealthBonus() return self:V("health_bonus") end
function M:GetModifierConstantHealthRegen() return self:V("health_regen") end
function M:GetModifierHealthRegenPercentage() return self:V("max_health_regen_pct") end
function M:GetModifierExtraHealthPercentage() return self:V("max_health_pct") end
function M:GetModifierHealAmplify_PercentageTarget() return self:V("health_restoration") end
function M:GetModifierHPRegenAmplify_Percentage() return self:V("health_restoration") end
function M:GetModifierLifestealRegenAmplify_Percentage() return self:V("health_restoration") end
function M:GetModifierSpellLifestealRegenAmplify_Percentage() return self:V("health_restoration") end

-- атака
function M:GetModifierPreAttack_BonusDamage()
	local bonus = self:V("bonus_damage")
	local pct = self:V("max_health_to_damage_pct")
	if pct ~= 0 then
		bonus = bonus + self:GetParent():GetMaxHealth() * pct / 100
	end
	return bonus
end
function M:GetModifierBaseDamageOutgoing_Percentage() return self:V("base_attack_damage") end
function M:GetModifierAttackSpeedBonus_Constant() return self:V("bonus_attack_speed") end
function M:GetModifierAttackSpeedPercentage() return self:V("attack_speed_pct") end
function M:GetModifierBaseAttackTimePercentage() return BAT_PCT_SIGN * self:V("bat_reduce") end
function M:GetModifierAttackRangeBonus()
	if self:GetParent():IsRangedAttacker() then return self:V("bonus_attack_range") end
	return self:V("bonus_attack_range_melee")
end

-- защита
function M:GetModifierPhysicalArmorBonus() return self:V("armor") end
function M:GetModifierEvasion_Constant() return self:V("evasion") end
function M:GetModifierMagicalResistanceBonus() return self:V("magic_res") end
function M:GetModifierStatusResistanceStacking() return self:V("status_resistance") end
function M:GetModifierSlowResistance_Stacking() return self:V("slow_resist") end
-- сопротивление отталкиванию = отрицательное усиление отталкивания
function M:GetModifierKnockbackAmplification_Percentage() return -self:V("knockback_resist") end
function M:GetModifierIncomingDamage_Percentage() return self:V("incoming_damage") end

-- обзор, способности
function M:GetBonusNightVision() return self:V("bonus_night_vision") end
function M:GetBonusVisionPercentage() return self:V("vision_pct") end
function M:GetModifierCastRangeBonusStacking() return self:V("cast_range_bonus") end
function M:GetModifierPercentageCasttime() return self:V("cast_speed") end
function M:GetModifierPercentageCooldown() return self:V("cooldown_reduction") end
function M:GetModifierSpellAmplify_Percentage() return self:V("spell_amp") end
-- усиление дебаффов: враги будто с меньшим сопротивлением эффектам от владельца
function M:GetModifierStatusResistanceCaster() return -self:V("debuff_amp") end
function M:GetModifierProperty_PhysicalLifesteal() return self:V("attack_lifesteal") end
function M:GetModifierProperty_MagicalLifesteal() return self:V("spell_lifesteal") end

-- атрибуты
function M:GetModifierBonusStats_Intellect_Percentage() return self:V("intelligence_pct") end

-- основной атрибут: primary_stat плоско + primary_stat_pct % от базового, универсалу треть в каждый
function M:PrimaryBonus(attr, base)
	local flat = self:V("primary_stat")
	local pct = self:V("primary_stat_pct")
	if flat == 0 and pct == 0 then return 0 end

	local primary = self:GetParent():GetPrimaryAttribute()
	if primary == DOTA_ATTRIBUTE_ALL then
		return (flat + base * pct / 100) / 3
	end
	if primary ~= attr then return 0 end
	return flat + base * pct / 100
end
function M:GetModifierBonusStats_Strength()
	return self:PrimaryBonus(DOTA_ATTRIBUTE_STRENGTH, self:GetParent():GetBaseStrength())
end
function M:GetModifierBonusStats_Agility()
	return self:PrimaryBonus(DOTA_ATTRIBUTE_AGILITY, self:GetParent():GetBaseAgility())
end
function M:GetModifierBonusStats_Intellect()
	return self:PrimaryBonus(DOTA_ATTRIBUTE_INTELLECT, self:GetParent():GetBaseIntellect())
end

-- magic_damage_pct: % урона атаки магическим уроном по цели (не от иллюзий, не по зданиям)
function M:OnAttackLanded(kv)
	if not IsServer() then return end

	local parent = self:GetParent()
	if kv.attacker ~= parent or parent:IsIllusion() then return end

	-- % урона с действенностью атаки (как bonus_damage у Misericorde)
	local pct = self:V("magic_damage_pct") * AttackPotency:Get(parent, kv)
	if pct <= 0 then return end

	local target = kv.target
	if not target or target:IsNull() or target:IsBuilding() then return end

	local damage = parent:GetAverageTrueAttackDamage(target) * pct / 100
	if damage <= 0 then return end

	ApplyDamage({
		victim = target,
		attacker = parent,
		damage = damage,
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = self:GetAbility(),
		damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,
	})
end

-- bonus_gpm: золото раз в секунду, дробная часть копится
function M:OnCreated()
	if not IsServer() then return end
	self.gold_left = 0
	if self:V("bonus_gpm") ~= 0 then self:StartIntervalThink(1) end
end

function M:OnIntervalThink()
	local parent = self:GetParent()
	if not parent or parent:IsNull() or not parent:IsRealHero() or parent:IsTempestDouble() then return end

	self.gold_left = self.gold_left + self:V("bonus_gpm") / 60
	local gold = math.floor(self.gold_left)
	if gold <= 0 then return end
	self.gold_left = self.gold_left - gold

	local give = function () parent:ModifyGold(gold, true, 0) end
	if AATagGold then AATagGold("enhancement_greedy", give) else give() end
end
