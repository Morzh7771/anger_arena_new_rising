-- Reaver Lord: Soul Collector. Порт из Angel Arena Global (там datadriven), переписано на Lua.
-- Души - стаки модификатора modifier_reaver_lord_soul на герое. Даются:
--   за souls_per_attacks атак по вражескому герою; за убийство героя (soul_per_hero_kill);
--   за каждые creeps_per_soul убитых не-героев. Каждое получение души обновляет таймер всех душ.

reaver_lord_soul_collector = class({})

LinkLuaModifier("modifier_reaver_lord_soul_collector", "heroes/reaver_lord/reaver_lord_soul_collector", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_reaver_lord_soul", "heroes/reaver_lord/reaver_lord_soul_collector", LUA_MODIFIER_MOTION_NONE)

function reaver_lord_soul_collector:GetIntrinsicModifierName()
	return "modifier_reaver_lord_soul_collector"
end

-- Общие хелперы для остальных скиллов героя
function ReaverLordGetSouls(unit)
	return unit:GetModifierStackCount("modifier_reaver_lord_soul", unit)
end

-- максимум душ растёт каждые 10 уровней героя
function ReaverLordGetMaxSouls(unit)
	local ability = unit:FindAbilityByName("reaver_lord_soul_collector")
	if not ability or ability:GetLevel() == 0 then return 0 end
	return ability:GetSpecialValueFor("max_souls") + math.floor(unit:GetLevel() / 10) * ability:GetSpecialValueFor("souls_per_10_levels")
end

function ReaverLordAddSouls(unit, count)
	local ability = unit:FindAbilityByName("reaver_lord_soul_collector")
	if not ability or ability:GetLevel() == 0 or count == 0 then return end

	local max_souls = ReaverLordGetMaxSouls(unit)
	local current = ReaverLordGetSouls(unit)
	local new_count = math.max(0, math.min(max_souls, current + count))

	if new_count <= 0 then
		unit:RemoveModifierByName("modifier_reaver_lord_soul")
		return
	end

	local mod = unit:AddNewModifier(unit, ability, "modifier_reaver_lord_soul", { duration = ability:GetSpecialValueFor("soul_duration") })
	if mod then mod:SetStackCount(new_count) end
end

--------------------------------------------------------------------------------

modifier_reaver_lord_soul_collector = class({})

function modifier_reaver_lord_soul_collector:IsHidden() return true end
function modifier_reaver_lord_soul_collector:IsPurgable() return false end
function modifier_reaver_lord_soul_collector:RemoveOnDeath() return false end

function modifier_reaver_lord_soul_collector:OnCreated()
	self.hero_attacks = 0
	self.creeps_killed = 0
end

function modifier_reaver_lord_soul_collector:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ATTACK_LANDED,
		MODIFIER_EVENT_ON_DEATH,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
	}
end

-- броня за каждую душу
function modifier_reaver_lord_soul_collector:GetModifierPhysicalArmorBonus()
	local parent = self:GetParent()
	if parent:PassivesDisabled() then return 0 end
	return ReaverLordGetSouls(parent) * self:GetAbility():GetSpecialValueFor("armor_per_soul")
end

function modifier_reaver_lord_soul_collector:OnAttackLanded(params)
	if not IsServer() then return end

	local parent = self:GetParent()
	if params.attacker ~= parent or parent:PassivesDisabled() or parent:IsIllusion() then return end

	local target = params.target
	if not target or not target:IsRealHero() or target:GetTeamNumber() == parent:GetTeamNumber() then return end

	self.hero_attacks = self.hero_attacks + 1
	if self.hero_attacks >= self:GetAbility():GetSpecialValueFor("souls_per_attacks") then
		self.hero_attacks = 0
		ReaverLordAddSouls(parent, 1)
	end
end

function modifier_reaver_lord_soul_collector:OnDeath(params)
	if not IsServer() then return end

	local parent = self:GetParent()
	if params.attacker ~= parent or parent:PassivesDisabled() or parent:IsIllusion() then return end

	local unit = params.unit
	if not unit or unit:GetTeamNumber() == parent:GetTeamNumber() then return end

	local ability = self:GetAbility()

	if unit:IsRealHero() then
		ReaverLordAddSouls(parent, ability:GetSpecialValueFor("soul_per_hero_kill"))
		return
	end

	if unit:IsIllusion() or unit:IsBuilding() then return end

	self.creeps_killed = self.creeps_killed + 1
	if self.creeps_killed >= ability:GetSpecialValueFor("creeps_per_soul") then
		self.creeps_killed = 0
		ReaverLordAddSouls(parent, 1)
	end
end

--------------------------------------------------------------------------------

modifier_reaver_lord_soul = class({})

function modifier_reaver_lord_soul:IsHidden() return false end
function modifier_reaver_lord_soul:IsDebuff() return false end
function modifier_reaver_lord_soul:IsPurgable() return false end

function modifier_reaver_lord_soul:GetTexture()
	return "custom/reaver_lord/reaver_lord_soul_collector"
end
