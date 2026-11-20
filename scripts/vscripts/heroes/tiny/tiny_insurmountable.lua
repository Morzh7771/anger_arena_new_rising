-- Insurmountable на Lua: как ванильная врождёнка Тини (сопротивление замедлению и статус-резист
-- от бонусной силы), но статус-резист от неё не выше max_status_resist (50%).

LinkLuaModifier("modifier_tiny_insurmountable_lua", "heroes/tiny/tiny_insurmountable", LUA_MODIFIER_MOTION_NONE)

tiny_insurmountable = class({})

function tiny_insurmountable:GetIntrinsicModifierName()
	return "modifier_tiny_insurmountable_lua"
end

--------------------------------------------------------------------------------
modifier_tiny_insurmountable_lua = class({
	IsHidden = function() return true end,
	IsPurgable = function() return false end,
	RemoveOnDeath = function() return false end,
})

function modifier_tiny_insurmountable_lua:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_SLOW_RESISTANCE_STACKING,
		MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING,
	}
end

-- вся сила героя, как в доте
function modifier_tiny_insurmountable_lua:Strength()
	local parent = self:GetParent()
	if not parent.GetStrength or parent:PassivesDisabled() then return 0 end
	return math.max(0, parent:GetStrength())
end

function modifier_tiny_insurmountable_lua:GetModifierSlowResistance_Stacking()
	local ability = self:GetAbility()
	if not ability then return 0 end
	return self:Strength() * ability:GetSpecialValueFor("str_to_slow_resist_pct") / 100
end

-- ванильное значение x = сила * str_to_status_resist_pct / 100, сглаженное как у силы героя
-- (modifier_aa_hero): limit * x / (x + limit). На малой силе почти как в доте,
-- к limit (50%) только стремится и никогда его не достигает.
function modifier_tiny_insurmountable_lua:GetModifierStatusResistanceStacking()
	local ability = self:GetAbility()
	if not ability then return 0 end
	local x = self:Strength() * ability:GetSpecialValueFor("str_to_status_resist_pct") / 100
	local limit = ability:GetSpecialValueFor("max_status_resist")
	if x <= 0 or limit <= 0 then return 0 end
	return limit * x / (x + limit)
end
