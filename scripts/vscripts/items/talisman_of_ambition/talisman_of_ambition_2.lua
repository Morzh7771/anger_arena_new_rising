item_talisman_of_ambition_2 = class({
    GetIntrinsicModifierName = function(self) return "modifier_talisman_of_ambition_2" end,
    GetTexture = function(self) return "talisman_of_ambition_2" end,
}) 
LinkLuaModifier( "modifier_talisman_of_ambition_2", 'items/talisman_of_ambition/modifiers/modifier_talisman_of_ambition_2', LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_talisman_of_ambition_active_2", 'items/talisman_of_ambition/modifiers/modifier_talisman_of_ambition_active_2', LUA_MODIFIER_MOTION_NONE )


function item_talisman_of_ambition_2:OnSpellStart()
	local caster 			= self:GetCaster() 
	local original_target	= self:GetCursorTarget()
	
	if PlayerResource:IsDisableHelpSetForPlayerID(caster:GetPlayerOwnerID(), original_target:GetPlayerOwnerID() ) then
		return 
	end

	original_target:AddNewModifier(caster, self, "modifier_talisman_of_ambition_active_2", { duration = self:GetSpecialValueFor("duration")})
end

function item_talisman_of_ambition_2:Precache()
	PrecacheResource("particle", "particles/status_fx/status_effect_blur.vpcf", context)
end