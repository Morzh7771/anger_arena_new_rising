-- Clockwerk: Armor Power, своя Lua-версия (2026-11-26) вместо ванильной rattletrap_armor_power.
-- Пассивно: исходящий урон +damage_per_armor% за каждое очко брони.
-- Поедание Chainmail делает сам предмет item_chainmail_aa (items/item_chainmail_aa.lua):
-- он проверяет, что у героя есть эта способность. Стаки съеденных - modifier_item_chainmail_eaten.

rattletrap_armor_power_aa = class({})

LinkLuaModifier("modifier_rattletrap_armor_power_aa", "heroes/rattletrap/rattletrap_armor_power_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_chainmail_eaten", "items/item_chainmail_aa", LUA_MODIFIER_MOTION_NONE)

function rattletrap_armor_power_aa:GetIntrinsicModifierName()
	return "modifier_rattletrap_armor_power_aa"
end

modifier_rattletrap_armor_power_aa = class({})

function modifier_rattletrap_armor_power_aa:IsHidden() return true end
function modifier_rattletrap_armor_power_aa:IsPurgable() return false end
function modifier_rattletrap_armor_power_aa:RemoveOnDeath() return false end

-- баф съеденных Chainmail висит всегда (с 0), чтобы в тултипе была цена следующего
function modifier_rattletrap_armor_power_aa:OnCreated()
	if not IsServer() then return end
	local parent = self:GetParent()
	if parent:IsRealHero() and not parent:HasModifier("modifier_item_chainmail_eaten") then
		parent:AddNewModifier(parent, nil, "modifier_item_chainmail_eaten", {})
	end
end

function modifier_rattletrap_armor_power_aa:DeclareFunctions()
	return { MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE }
end

function modifier_rattletrap_armor_power_aa:GetModifierTotalDamageOutgoing_Percentage()
	local parent, ab = self:GetParent(), self:GetAbility()
	if not ab or parent:PassivesDisabled() then return 0 end
	local armor = parent:GetPhysicalArmorValue(false)
	if armor <= 0 then return 0 end
	return armor * ab:GetSpecialValueFor("damage_per_armor")
end
