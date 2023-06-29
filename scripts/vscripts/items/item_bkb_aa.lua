item_bkb_aa_1 = item_bkb_aa_1 or class({})
item_bkb_aa_2 = item_bkb_aa_1 or class({})
item_bkb_aa_3 = item_bkb_aa_1 or class({})

LinkLuaModifier( "modifier_item_bkb_aa", "items/item_bkb_aa.lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_generic_debuff_immune", "modifiers/modifier_generic_debuff_immune.lua", LUA_MODIFIER_MOTION_NONE )

function item_bkb_aa_1:GetIntrinsicModifierName()
	return "modifier_item_bkb_aa"
end
function item_bkb_aa_1:OnSpellStart()
	self.caster = self:GetCaster()
	self.duration = self:GetSpecialValueFor("duration")
	self.caster:AddNewModifier(self.caster, self, "modifier_generic_debuff_immune", {effect = 1 , duration = self.duration})
	self.caster:Purge( false, true, false, false, false )
end


---------------------------------------------------------------------
--Modifiers
if modifier_item_bkb_aa == nil then
	modifier_item_bkb_aa = class({})
end
function modifier_item_bkb_aa:IsHidden() return true end
function modifier_item_bkb_aa:OnCreated(params)
	if IsServer() then
	end
end
function modifier_item_bkb_aa:OnRefresh(params)
	if IsServer() then
	end
end
function modifier_item_bkb_aa:OnDestroy()
	if IsServer() then
	end
end
function modifier_item_bkb_aa:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE 
	}
end

function modifier_item_bkb_aa:GetModifierBonusStats_Strength()
	return self:GetAbility():GetSpecialValueFor("bonus_strength")
end
function modifier_item_bkb_aa:GetModifierPreAttack_BonusDamage()
	return self:GetAbility():GetSpecialValueFor("bonus_damage")
end