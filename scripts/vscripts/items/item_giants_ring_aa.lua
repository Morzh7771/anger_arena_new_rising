-- Giant's Ring (нейтралка): как ванильный, но без беспрепятственного передвижения
-- и без бонуса дальности атаки - крупнее модель и урон вокруг от силы.
LinkLuaModifier("modifier_item_giants_ring_aa", "items/item_giants_ring_aa", LUA_MODIFIER_MOTION_NONE)

item_giants_ring = class({})

function item_giants_ring:GetIntrinsicModifierName()
	return "modifier_item_giants_ring_aa"
end

local THINK = 0.5

modifier_item_giants_ring_aa = class({
	IsHidden = function() return true end,
	IsPurgable = function() return false end,
	RemoveOnDeath = function() return false end,
	DeclareFunctions = function() return {
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_MODEL_SCALE,
	} end,
})

function modifier_item_giants_ring_aa:GetModifierBonusStats_Strength()
	return self:GetAbility() and self:GetAbility():GetSpecialValueFor("bonus_strength") or 0
end

function modifier_item_giants_ring_aa:GetModifierMoveSpeedBonus_Constant()
	return self:GetAbility() and self:GetAbility():GetSpecialValueFor("movement_speed") or 0
end

function modifier_item_giants_ring_aa:GetModifierModelScale()
	return self:GetAbility() and self:GetAbility():GetSpecialValueFor("model_scale") or 0
end

function modifier_item_giants_ring_aa:OnCreated()
	if not IsServer() then return end
	self:StartIntervalThink(THINK)
end

function modifier_item_giants_ring_aa:OnIntervalThink()
	local parent = self:GetParent()
	local ability = self:GetAbility()
	if not ability or ability:IsNull() or not parent:IsAlive() or parent:IsIllusion() then return end
	if not parent.GetStrength then return end

	local damage = parent:GetStrength() * ability:GetSpecialValueFor("pct_str_damage_per_second") / 100 * THINK
	if damage <= 0 then return end
	local radius = ability:GetSpecialValueFor("damage_radius") + parent:GetHullRadius()

	local enemies = FindUnitsInRadius(parent:GetTeamNumber(), parent:GetAbsOrigin(), nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	for _, enemy in pairs(enemies) do
		ApplyDamage({ victim = enemy, attacker = parent, damage = damage, damage_type = DAMAGE_TYPE_MAGICAL, ability = ability })
	end
end
