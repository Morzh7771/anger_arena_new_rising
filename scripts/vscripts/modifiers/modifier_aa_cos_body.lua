-- Скин героя и снаряд атаки премиума (lib/cosmetics/events_fx.lua TickBody).
--   status     - шейдер модели (GetStatusEffectName), самый низкий приоритет: игровые
--                статусы (лёд, ульты, дебаффы) всегда видны поверх скина;
--   projectile - снаряд атаки дальника, приоритет модификатора самый низкий: умения/орбы,
--                которые меняют снаряд, перебивают его;
--   particle/point - партикл на теле (скины aaf), на точке крепления модели.
-- Клиенту пути нужны для шейдера - отдаём через transmitter-данные.

modifier_aa_cos_body = class({})

function modifier_aa_cos_body:IsHidden() return true end
function modifier_aa_cos_body:IsPurgable() return false end
function modifier_aa_cos_body:RemoveOnDeath() return false end
function modifier_aa_cos_body:IsPermanent() return true end
function modifier_aa_cos_body:GetPriority() return MODIFIER_PRIORITY_LOW end

function modifier_aa_cos_body:OnCreated(kv)
	if not IsServer() then return end

	self.status = kv.status or ""
	self.projectile = kv.projectile or ""

	self:SetHasCustomTransmitterData(true)

	if kv.particle and kv.particle ~= "" then
		local parent = self:GetParent()
		local idx

		if kv.point and kv.point ~= "" then
			idx = ParticleManager:CreateParticle(kv.particle, PATTACH_POINT_FOLLOW, parent)
			ParticleManager:SetParticleControlEnt(idx, 0, parent, PATTACH_POINT_FOLLOW, kv.point, parent:GetAbsOrigin(), true)
		else
			idx = ParticleManager:CreateParticle(kv.particle, PATTACH_ABSORIGIN_FOLLOW, parent)
		end

		self:AddParticle(idx, false, false, -1, false, false)
	end
end

function modifier_aa_cos_body:AddCustomTransmitterData()
	return { status = self.status, projectile = self.projectile }
end

function modifier_aa_cos_body:HandleCustomTransmitterData(data)
	self.status = data.status or ""
	self.projectile = data.projectile or ""
end

function modifier_aa_cos_body:GetStatusEffectName()
	if self.status and self.status ~= "" then return self.status end
end

function modifier_aa_cos_body:StatusEffectPriority()
	return 1
end

function modifier_aa_cos_body:DeclareFunctions()
	return { MODIFIER_PROPERTY_PROJECTILE_NAME }
end

function modifier_aa_cos_body:GetModifierProjectileName()
	if self.projectile and self.projectile ~= "" then return self.projectile end
end
