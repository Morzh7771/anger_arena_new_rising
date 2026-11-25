-- Spike: Thorn Armor (врождённая). +(bonus_armor + armor_per_level × уровень) брони.
-- Враг, ударивший Спайка в ближнем бою, получает физический урон = броня Спайка × armor_damage_mult.

spike_thorn_armor = class({})

LinkLuaModifier("modifier_spike_thorn_armor", "heroes/spike/spike_thorn_armor", LUA_MODIFIER_MOTION_NONE)

function spike_thorn_armor:GetIntrinsicModifierName()
	return "modifier_spike_thorn_armor"
end

modifier_spike_thorn_armor = class({})

function modifier_spike_thorn_armor:IsHidden() return true end
function modifier_spike_thorn_armor:IsPurgable() return false end
function modifier_spike_thorn_armor:RemoveOnDeath() return false end

function modifier_spike_thorn_armor:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end

function modifier_spike_thorn_armor:GetModifierPhysicalArmorBonus()
	local parent = self:GetParent()
	local ability = self:GetAbility()
	if not ability or parent:PassivesDisabled() then return 0 end
	return ability:GetSpecialValueFor("bonus_armor") + ability:GetSpecialValueFor("armor_per_level") * parent:GetLevel()
end

function modifier_spike_thorn_armor:OnAttackLanded(params)
	if not IsServer() then return end

	local parent = self:GetParent()
	local attacker = params.attacker
	local ability = self:GetAbility()

	if params.target ~= parent or not ability or parent:PassivesDisabled() then return end
	if not attacker or attacker:IsNull() or attacker:IsRangedAttacker() or attacker:IsBuilding() then return end
	if attacker:GetTeamNumber() == parent:GetTeamNumber() or attacker:IsInvulnerable() then return end

	local armor = math.max(0, parent:GetPhysicalArmorValue(false))

	ApplyDamage({
		victim			= attacker,
		attacker		= parent,
		damage			= armor * ability:GetSpecialValueFor("armor_damage_mult"),
		damage_type		= DAMAGE_TYPE_PHYSICAL,
		ability			= ability,
		damage_flags	= DOTA_DAMAGE_FLAG_REFLECTION + DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,
	})
end
