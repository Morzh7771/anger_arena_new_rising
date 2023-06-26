LinkLuaModifier( "modifier_item_null_talisman_custom", "item_null_talisman_custom.lua", LUA_MODIFIER_MOTION_NONE )
--Abilities
if item_null_talisman_custom == nil then
	item_null_talisman_custom = class({})
end
function item_null_talisman_custom:GetIntrinsicModifierName()
	return "modifier_item_null_talisman_custom"
end
---------------------------------------------------------------------
--Modifiers
if modifier_item_null_talisman_custom == nil then
	modifier_item_null_talisman_custom = class({})
end
function modifier_item_null_talisman_custom:OnCreated(params)
	if IsServer() then
	end
end
function modifier_item_null_talisman_custom:OnRefresh(params)
	if IsServer() then
	end
end
function modifier_item_null_talisman_custom:OnDestroy()
	if IsServer() then
	end
end
function modifier_item_null_talisman_custom:DeclareFunctions()
	return {
	}
end