-- Осколки рун с нейтральных крипов (lib/creep_pickups.lua): короткие баффы.

local function Base(texture)
	local m = class({})
	function m:IsHidden() return false end
	function m:IsDebuff() return false end
	function m:IsPurgable() return true end
	function m:GetTexture() return texture end
	return m
end

-- скорость: +30% к скорости передвижения
modifier_creep_shard_haste = Base("rune_haste")
function modifier_creep_shard_haste:DeclareFunctions() return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE } end
function modifier_creep_shard_haste:GetModifierMoveSpeedBonus_Percentage() return 30 end
function modifier_creep_shard_haste:GetEffectName() return "particles/generic_gameplay/rune_haste_owner.vpcf" end

-- урон: +30% базового урона
modifier_creep_shard_damage = Base("rune_doubledamage")
function modifier_creep_shard_damage:DeclareFunctions() return { MODIFIER_PROPERTY_BASEDAMAGEOUTGOING_PERCENTAGE } end
function modifier_creep_shard_damage:GetModifierBaseDamageOutgoing_Percentage() return 30 end
function modifier_creep_shard_damage:GetEffectName() return "particles/generic_gameplay/rune_doubledamage_owner.vpcf" end

-- реген: 3% макс. здоровья и маны в секунду
modifier_creep_shard_regen = Base("rune_regen")
function modifier_creep_shard_regen:DeclareFunctions()
	return { MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE, MODIFIER_PROPERTY_MANA_REGEN_TOTAL_PERCENTAGE }
end
function modifier_creep_shard_regen:GetModifierHealthRegenPercentage() return 3 end
function modifier_creep_shard_regen:GetModifierTotalPercentageManaRegen() return 3 end
function modifier_creep_shard_regen:GetEffectName() return "particles/generic_gameplay/rune_regen_owner.vpcf" end
