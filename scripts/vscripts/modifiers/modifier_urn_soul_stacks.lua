-- Стаки Soul Keeper (lib/urn_charges.lua), как в 1х6: каждый стак +URN_SOUL_KEEPER_PCT %
-- к урону и лечению урны/вессела (считает items/item_urn_aa.lua).
-- Висит на герое, пока у него есть урна или вессел; без урны стаки пропадают.

URN_SOUL_KEEPER_PCT = 6


modifier_urn_soul_stacks = class({})

function modifier_urn_soul_stacks:IsPurgable() return false end
function modifier_urn_soul_stacks:RemoveOnDeath() return false end
function modifier_urn_soul_stacks:IsPermanent() return true end
function modifier_urn_soul_stacks:GetTexture() return "item_spirit_vessel" end

-- модификатор есть ровно тогда, когда у героя есть урна или вессел
-- (вешает и снимает пассивка урны, items/item_urn_aa.lua)
function modifier_urn_soul_stacks:IsHidden() return false end

function modifier_urn_soul_stacks:DeclareFunctions()
	return { MODIFIER_PROPERTY_TOOLTIP }
end

function modifier_urn_soul_stacks:OnTooltip()
	return self:GetStackCount() * URN_SOUL_KEEPER_PCT
end
