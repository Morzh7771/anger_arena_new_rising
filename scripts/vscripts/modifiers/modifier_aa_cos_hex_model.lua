-- Косметика премиума: модель превращения поверх ванильного хекса 1-го уровня
-- (lib/cosmetics/events_fx.lua, фильтр modifier_sheepstick_debuff). Механики нет - только модель.
-- Приоритет выше ванильного дебаффа, чтобы его овца не перебила выбранную модель.

modifier_aa_cos_hex_model = class({})

function modifier_aa_cos_hex_model:IsHidden() return true end
function modifier_aa_cos_hex_model:IsPurgable() return true end
function modifier_aa_cos_hex_model:GetPriority() return MODIFIER_PRIORITY_SUPER_ULTRA end

function modifier_aa_cos_hex_model:OnCreated(kv)
	if not IsServer() then return end

	self.model = kv.model

	self:SetHasCustomTransmitterData(true)
	self:StartIntervalThink(0.1)
end

-- дебафф сняли раньше (развеяли) - снимаемся и мы
function modifier_aa_cos_hex_model:OnIntervalThink()
	if not self:GetParent():HasModifier("modifier_sheepstick_debuff") then self:Destroy() end
end

function modifier_aa_cos_hex_model:AddCustomTransmitterData()
	return { model = self.model }
end

function modifier_aa_cos_hex_model:HandleCustomTransmitterData(data)
	self.model = data.model
end

function modifier_aa_cos_hex_model:DeclareFunctions()
	return { MODIFIER_PROPERTY_MODEL_CHANGE }
end

function modifier_aa_cos_hex_model:GetModifierModelChange()
	return self.model
end
