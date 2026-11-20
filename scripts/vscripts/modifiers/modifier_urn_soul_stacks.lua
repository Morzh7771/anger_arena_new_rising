-- Стаки Soul Keeper (lib/urn_charges.lua), как в 1х6: каждый стак +URN_SOUL_KEEPER_PCT %
-- к урону и лечению урны/вессела (считает items/item_urn_aa.lua).
-- Висит на герое навсегда: общие для урны и всех весселов, не спадают при смерти и продаже.
-- Без урны/вессела в инвентаре только скрыт.

URN_SOUL_KEEPER_PCT = 6


modifier_urn_soul_stacks = class({})

function modifier_urn_soul_stacks:IsPurgable() return false end
function modifier_urn_soul_stacks:RemoveOnDeath() return false end
function modifier_urn_soul_stacks:IsPermanent() return true end
function modifier_urn_soul_stacks:GetTexture() return "item_spirit_vessel" end

-- виден, только пока есть урна или вессел (их пассивка видна и на клиенте)
function modifier_urn_soul_stacks:IsHidden()
	local parent = self:GetParent()
	return not (parent and not parent:IsNull() and parent:HasModifier("modifier_item_urn_aa_passive"))
end

function modifier_urn_soul_stacks:DeclareFunctions()
	return { MODIFIER_PROPERTY_TOOLTIP }
end

function modifier_urn_soul_stacks:OnTooltip()
	return self:GetStackCount() * URN_SOUL_KEEPER_PCT
end
