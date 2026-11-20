-- Огр: укрепляет собственную кожу - бонус брони и магсопротивления на время.
neutral_ogre_armor_active = neutral_ogre_armor_active or class({})
local ability = neutral_ogre_armor_active

function ability:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget() or caster

	target:AddNewModifier(caster, self, "modifier_neutral_creep_active", {
		duration = self:GetSpecialValueFor("duration"),
		armor = self:GetSpecialValueFor("armor"),
		magic = self:GetSpecialValueFor("magic"),
	})
end
