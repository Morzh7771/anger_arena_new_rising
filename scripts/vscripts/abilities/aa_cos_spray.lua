-- Граффити премиума: способность на невидимом юните-кастере (lib/cosmetics/caster.lua).
-- Прицел и кулдаун движковые, сам спрей ставит CosmeticsSocial:DoSpray (lib/cosmetics/social.lua).

aa_cos_spray = class({})

function aa_cos_spray:OnSpellStart()
	if not IsServer() then return end

	local caster = self:GetCaster()
	local pid = caster:GetPlayerOwnerID()

	if CosmeticsSocial == nil or not CosmeticsSocial.DoSpray then return end

	local ok = CosmeticsSocial:DoSpray(pid, self:GetCursorPosition())

	-- отказ (нет премиума и т.п.) - кулдаун не тратим
	if not ok then self:EndCooldown() end
end
