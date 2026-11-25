-- Gun Joe: Machine Gun / Rifle. Порт из Angel Arena Global.
-- Два связанных тогла: включение одного выключает другой. Прокачка одного качает второй.
-- Machine Gun: быстрый BAT, меньше дальность и урон. Rifle: медленный BAT, больше дальность и урон.

LinkLuaModifier("modifier_gun_joe_machine_gun", "heroes/gun_joe/gun_joe_guns", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_gun_joe_rifle", "heroes/gun_joe/gun_joe_guns", LUA_MODIFIER_MOTION_NONE)

local function make_gun(linked_name, modifier_name)
	local ability = class({})

	function ability:ResetToggleOnRespawn()
		return false
	end

	function ability:OnUpgrade()
		if not IsServer() then return end
		local linked = self:GetCaster():FindAbilityByName(linked_name)
		if linked and linked:GetLevel() ~= self:GetLevel() then
			linked:SetLevel(self:GetLevel())
		end
	end

	function ability:OnToggle()
		local caster = self:GetCaster()
		caster:RemoveModifierByName(modifier_name)

		if not self:GetToggleState() then return end

		local linked = caster:FindAbilityByName(linked_name)
		if linked and linked:GetToggleState() then
			linked:ToggleAbility()
		end

		caster:AddNewModifier(caster, self, modifier_name, {})

	end

	return ability
end

gun_joe_machine_gun = make_gun("gun_joe_rifle", "modifier_gun_joe_machine_gun")
gun_joe_rifle = make_gun("gun_joe_machine_gun", "modifier_gun_joe_rifle")

--------------------------------------------------------------------------------

local function make_gun_modifier(damage_key)
	local mod = class({})

	function mod:IsHidden() return false end
	function mod:IsPurgable() return false end
	function mod:RemoveOnDeath() return false end

	function mod:OnCreated()
		local ability = self:GetAbility()
		if not ability then return end
		self.range = ability:GetSpecialValueFor("attack_range")
		self.bat = ability:GetSpecialValueFor("bat")
		self.damage = ability:GetSpecialValueFor(damage_key)
	end

	mod.OnRefresh = mod.OnCreated

	function mod:DeclareFunctions()
		return {
			MODIFIER_PROPERTY_ATTACK_RANGE_BONUS,
			MODIFIER_PROPERTY_BASE_ATTACK_TIME_CONSTANT,
			MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE,
		}
	end

	function mod:GetModifierAttackRangeBonus() return self.range end
	function mod:GetModifierBaseAttackTimeConstant() return self.bat end
	-- Как в Global: множитель на весь исходящий урон, не только на атаки
	function mod:GetModifierTotalDamageOutgoing_Percentage() return self.damage end

	return mod
end

modifier_gun_joe_machine_gun = make_gun_modifier("damage_decrease_pct")
modifier_gun_joe_rifle = make_gun_modifier("damage_increase_pct")
