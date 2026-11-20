-- Общий модификатор для активок нейтралов: замедление, бонус брони и магсопротивления.
-- Передаётся через AddNewModifier params: slow (%, отрицательное), armor, magic (%).
modifier_neutral_creep_active = modifier_neutral_creep_active or class({})
local mod = modifier_neutral_creep_active

function mod:IsHidden() return false end
function mod:IsPurgable() return true end
function mod:IsDebuff() return (self.slow or 0) < 0 end

function mod:OnCreated(params)
	self.slow = params.slow or 0
	self.armor = params.armor or 0
	self.magic = params.magic or 0
end

function mod:OnRefresh(params)
	self:OnCreated(params)
end

function mod:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
	}
end

function mod:GetModifierMoveSpeedBonus_Percentage() return self.slow end
function mod:GetModifierPhysicalArmorBonus() return self.armor end
function mod:GetModifierMagicalResistanceBonus() return self.magic end
