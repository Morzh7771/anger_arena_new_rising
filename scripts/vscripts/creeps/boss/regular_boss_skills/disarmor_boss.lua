disarmor_boss = disarmor_boss or class({})

local ability = disarmor_boss

LinkLuaModifier( "modifier_disarmor_regular_boss", 		'creeps/boss/regular_boss_skills/modifiers/disarmor_regular_boss', 		LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_possessed_rebel_debuff", 'creeps/boss/possessed/modifiers/modifier_possessed_rebel_debuff', 	LUA_MODIFIER_MOTION_NONE )

function ability:GetIntrinsicModifierName()
	return "modifier_disarmor_regular_boss"
end