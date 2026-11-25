-- Joe Black: Reaper's Toll (врождённая). Заклинания Джо наносят больше урона врагам ниже
-- health_threshold% здоровья: +(damage_per_level × уровень)%.

joe_black_reapers_toll = class({})

LinkLuaModifier("modifier_joe_black_reapers_toll", "heroes/joe_black/joe_black_reapers_toll", LUA_MODIFIER_MOTION_NONE)

function joe_black_reapers_toll:GetIntrinsicModifierName()
	return "modifier_joe_black_reapers_toll"
end

modifier_joe_black_reapers_toll = class({})

function modifier_joe_black_reapers_toll:IsHidden() return true end
function modifier_joe_black_reapers_toll:IsPurgable() return false end
function modifier_joe_black_reapers_toll:RemoveOnDeath() return false end

function modifier_joe_black_reapers_toll:DeclareFunctions()
	return { MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE }
end

function modifier_joe_black_reapers_toll:GetModifierTotalDamageOutgoing_Percentage(params)
	if not IsServer() then return 0 end

	local parent = self:GetParent()
	local ability = self:GetAbility()
	local target = params.target

	if not ability or parent:PassivesDisabled() then return 0 end
	if not params.inflictor or params.damage_category ~= DOTA_DAMAGE_CATEGORY_SPELL then return 0 end
	if not target or target:IsNull() or target:GetHealthPercent() >= ability:GetSpecialValueFor("health_threshold") then return 0 end

	return ability:GetSpecialValueFor("damage_per_level") * parent:GetLevel()
end
