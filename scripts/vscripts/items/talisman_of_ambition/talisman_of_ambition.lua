item_talisman_of_ambition = class({
	GetIntrinsicModifierName = function (self) return 'modifier_talisman_of_ambition' end,
	GetTexture = function(self) return "talisman_of_ambition" end,
}) 

LinkLuaModifier( "modifier_talisman_of_ambition", 'items/talisman_of_ambition/modifiers/modifier_talisman_of_ambition', LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_talisman_of_ambition_active", 'items/talisman_of_ambition/modifiers/modifier_talisman_of_ambition_active', LUA_MODIFIER_MOTION_NONE )
--------------------------------------------------------------------------------

function item_talisman_of_ambition:OnSpellStart()
	local original_target = self:GetCursorTarget()
	if PlayerResource:IsDisableHelpSetForPlayerID(self:GetCaster():GetPlayerOwnerID(), original_target:GetPlayerOwnerID() ) then
		return 
	end
	original_target:AddNewModifier(self:GetCaster(), self, "modifier_talisman_of_ambition_active", {duration = self:GetSpecialValueFor("duration")})
end
