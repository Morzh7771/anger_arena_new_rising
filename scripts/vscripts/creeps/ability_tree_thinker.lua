ability_tree_thinker = ability_tree_thinker or class({})
LinkLuaModifier( "modifier_ability_tree_thinker", "creeps/ability_tree_thinker", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------

function ability_tree_thinker:GetIntrinsicModifierName()
	return "modifier_ability_tree_thinker"
end


modifier_ability_tree_thinker = modifier_ability_tree_thinker or class({})

function modifier_ability_tree_thinker:IsHidden()
	return false
end

function modifier_ability_tree_thinker:IsPurgable()
	return false
end

function modifier_ability_tree_thinker:CheckState() return {
	[MODIFIER_STATE_STUNNED] 				= true,
    [MODIFIER_STATE_MAGIC_IMMUNE ] 		    = true,
	[MODIFIER_STATE_NO_UNIT_COLLISION] 		= true,
	[MODIFIER_STATE_TRUESIGHT_IMMUNE] 		= true,
    [MODIFIER_STATE_NO_HEALTH_BAR  ]        = true,
    [MODIFIER_STATE_FLYING ] 		        = true,
    [MODIFIER_STATE_NOT_ON_MINIMAP  ]       = true,
} end
