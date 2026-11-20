-- Сатир: снимает баффы с героя и замедляет его на короткое время.
neutral_satyr_purge_active = neutral_satyr_purge_active or class({})
local ability = neutral_satyr_purge_active

function ability:OnSpellStart()
	local target = self:GetCursorTarget()
	if not target or target:IsNull() then return end

	target:Purge(true, false, false, false, false)
	target:AddNewModifier(self:GetCaster(), self, "modifier_neutral_creep_active", {
		duration = self:GetSpecialValueFor("duration"),
		slow = self:GetSpecialValueFor("slow"),
	})
end
