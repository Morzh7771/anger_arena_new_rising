-- Chainmail (2026-11-26): item_chainmail_aa вместо ванильного item_chainmail везде
-- (магазин, все рецепты), ванильный удалён в dota_items.txt.
-- Пассивно +bonus_armor брони.
-- Clockwerk с врождённой rattletrap_armor_power_aa может съесть его (нажать предмет):
-- навсегда +4 брони и +5% к модели (до +25%).
-- Цена поедания в золоте: цена Chainmail * (уже съедено + 1) = 500, 1000, 1500...
-- Брони за съеденный - 4, модель +5% за штуку, до +25% (константы ниже).

LinkLuaModifier("modifier_item_chainmail_aa", "items/item_chainmail_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_chainmail_eaten", "items/item_chainmail_aa", LUA_MODIFIER_MOTION_NONE)

item_chainmail_aa = class({})

-- Работает и на клиенте (GetBehavior/GetGoldCost зовутся там же): только
-- FindAbilityByName, без HasAbility. Любая ошибка -> "есть нельзя", а не падение.
local function CanEat(unit)
	local ok, res = pcall(function()
		return unit ~= nil and not unit:IsNull()
			and unit:FindAbilityByName("rattletrap_armor_power_aa") ~= nil
	end)
	return ok and res == true
end

local function Eaten(unit)
	local ok, n = pcall(function() return unit:GetModifierStackCount("modifier_item_chainmail_eaten", unit) end)
	return (ok and n) or 0
end

function item_chainmail_aa:GetIntrinsicModifierName()
	return "modifier_item_chainmail_aa"
end

-- Clockwerk съедает одним нажатием (без цели)
function item_chainmail_aa:GetBehavior()
	if CanEat(self:GetCaster()) then
		return DOTA_ABILITY_BEHAVIOR_NO_TARGET + DOTA_ABILITY_BEHAVIOR_IMMEDIATE
	end
	return DOTA_ABILITY_BEHAVIOR_PASSIVE
end

-- цена поедания: цена Chainmail в магазине * номер (500, 1000, 1500...).
-- Золото списывает движок, цена видна в тултипе предмета
function item_chainmail_aa:GetGoldCost(level)
	local caster = self:GetCaster()
	if not CanEat(caster) then return 0 end
	return GetItemCost("item_chainmail_aa") * (Eaten(caster) + 1)
end

function item_chainmail_aa:OnSpellStart()
	local caster = self:GetCaster()
	if not CanEat(caster) then return end

	local mod = caster:FindModifierByName("modifier_item_chainmail_eaten")
		or caster:AddNewModifier(caster, nil, "modifier_item_chainmail_eaten", {})
	if mod then mod:SetStackCount(mod:GetStackCount() + 1) end

	caster:EmitSound("Hero_Rattletrap.Overclock.Cast")
	caster:RemoveItem(self)
	if caster.CalculateStatBonus then caster:CalculateStatBonus(true) end
end

--------------------------------------------------------------------------------
-- пассивная броня предмета (каждый Chain Mail отдельно)

modifier_item_chainmail_aa = class({})

function modifier_item_chainmail_aa:IsHidden() return true end
function modifier_item_chainmail_aa:IsPurgable() return false end
function modifier_item_chainmail_aa:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end

function modifier_item_chainmail_aa:OnCreated()
	local ab = self:GetAbility()
	self.armor = ab and ab:GetSpecialValueFor("bonus_armor") or 4
end

function modifier_item_chainmail_aa:DeclareFunctions()
	return { MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS }
end

function modifier_item_chainmail_aa:GetModifierPhysicalArmorBonus()
	return self.armor
end

--------------------------------------------------------------------------------
-- съеденные Chain Mail у Clockwerk: стаки = сколько съел

modifier_item_chainmail_eaten = class({})

local ARMOR_PER = 4
local SCALE_PER = 5
local SCALE_MAX = 25

function modifier_item_chainmail_eaten:IsHidden() return false end
function modifier_item_chainmail_eaten:IsPurgable() return false end
function modifier_item_chainmail_eaten:RemoveOnDeath() return false end
function modifier_item_chainmail_eaten:IsPermanent() return true end
function modifier_item_chainmail_eaten:GetTexture() return "item_chainmail" end

function modifier_item_chainmail_eaten:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_MODEL_SCALE,
		MODIFIER_PROPERTY_TOOLTIP,
		MODIFIER_PROPERTY_TOOLTIP2,
	}
end

-- тултип бафа: %dMODIFIER_PROPERTY_TOOLTIP% - цена следующего, TOOLTIP2 - сколько съедено
function modifier_item_chainmail_eaten:OnTooltip()
	return GetItemCost("item_chainmail_aa") * (self:GetStackCount() + 1)
end

function modifier_item_chainmail_eaten:OnTooltip2()
	return self:GetStackCount()
end

function modifier_item_chainmail_eaten:GetModifierPhysicalArmorBonus()
	return ARMOR_PER * self:GetStackCount()
end

function modifier_item_chainmail_eaten:GetModifierModelScale()
	return math.min(SCALE_MAX, SCALE_PER * self:GetStackCount())
end
