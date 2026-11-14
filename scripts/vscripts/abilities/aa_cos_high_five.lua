-- "Дай пять" премиума: способность на невидимом юните-кастере (lib/cosmetics/caster.lua).
-- Кулдаун движковый, поднятую руку и встречу двух рук ведёт CosmeticsSocial:DoHighFive.

aa_cos_high_five = class({})

function aa_cos_high_five:OnSpellStart()
	if not IsServer() then return end

	local pid = self:GetCaster():GetPlayerOwnerID()

	if CosmeticsSocial == nil or not CosmeticsSocial.DoHighFive then return end

	local ok = CosmeticsSocial:DoHighFive(pid)

	if not ok then self:EndCooldown() end
end
