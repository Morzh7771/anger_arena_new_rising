modifier_medical_tractate = class({})


function modifier_medical_tractate:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_HEALTH_BONUS,
		MODIFIER_PROPERTY_MANA_BONUS,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
	}
 
	return funcs
end

function modifier_medical_tractate:GetAttributes()
	local attrs = {
			MODIFIER_ATTRIBUTE_PERMANENT,
		}

	return attrs
end

function modifier_medical_tractate:IsHidden()
	return true
end

function modifier_medical_tractate:IsPurgable()
	return false
end
function modifier_medical_tractate:RemoveOnDeath()
    return false
end

function modifier_medical_tractate:GetModifierHealthBonus(params)
	if not self:GetCaster() then return 0 end
	self:GetCaster().medical_tractates = self:GetCaster().medical_tractates or 0

	return self.health_bonus*self:GetCaster().medical_tractates
end

function modifier_medical_tractate:OnCreated(event)
	self.health_bonus = 400;
	self.mana_bonus = 200;
	self.armor_bonus = 5;
end

function modifier_medical_tractate:GetModifierManaBonus(event)
	if not self:GetCaster() then return 0 end
	self:GetCaster().medical_tractates = self:GetCaster().medical_tractates or 0
	
	return self.mana_bonus*self:GetCaster().medical_tractates
end

function modifier_medical_tractate:GetModifierPhysicalArmorBonus(event)
	if self:GetCaster():IsHero() then
		return 0
	else 
		return self.armor_bonus
	end
end

modifier_medical_tractate_2 = class({})


function modifier_medical_tractate_2:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_HEALTH_BONUS,
		MODIFIER_PROPERTY_MANA_BONUS,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
	}
 
	return funcs
end

function modifier_medical_tractate_2:GetAttributes()
	local attrs = {
			MODIFIER_ATTRIBUTE_PERMANENT,
		}

	return attrs
end

function modifier_medical_tractate_2:IsHidden()
	return true
end

function modifier_medical_tractate_2:IsPurgable()
	return false
end
function modifier_medical_tractate_2:RemoveOnDeath()
    return false
end

function modifier_medical_tractate_2:GetModifierHealthBonus(params)
	if not self:GetCaster() then return 0 end
	self:GetCaster().medical_tractates2 = self:GetCaster().medical_tractates2 or 0

	return self.health_bonus*self:GetCaster().medical_tractates2
end

function modifier_medical_tractate_2:OnCreated(event)
	self.health_bonus = 4000;
	self.mana_bonus = 2000;
	self.armor_bonus = 50;
end

function modifier_medical_tractate_2:GetModifierManaBonus(event)
	if not self:GetCaster() then return 0 end
	self:GetCaster().medical_tractates2 = self:GetCaster().medical_tractates2 or 0
	
	return self.mana_bonus*self:GetCaster().medical_tractates2
end

function modifier_medical_tractate_2:GetModifierPhysicalArmorBonus(event)
	if self:GetCaster():IsHero() then
		return 0
	else 
		return self.armor_bonus
	end
end

