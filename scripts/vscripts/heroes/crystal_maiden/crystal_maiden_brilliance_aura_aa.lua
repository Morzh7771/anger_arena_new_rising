crystal_maiden_brilliance_aura_aa = class({})

function crystal_maiden_brilliance_aura_aa:GetIntrinsicModifierName() return "modifier_crystal_maiden_brilliance_aura_aa_emitter" end

LinkLuaModifier("modifier_crystal_maiden_brilliance_aura_aa", "heroes/crystal_maiden/crystal_maiden_brilliance_aura_aa.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_crystal_maiden_brilliance_aura_aa_emitter", "heroes/crystal_maiden/crystal_maiden_brilliance_aura_aa.lua", LUA_MODIFIER_MOTION_NONE)

modifier_crystal_maiden_brilliance_aura_aa_emitter = class({})
function modifier_crystal_maiden_brilliance_aura_aa_emitter:GetAuraRadius() return 25000 end
function modifier_crystal_maiden_brilliance_aura_aa_emitter:GetAuraSearchFlags() return DOTA_UNIT_TARGET_FLAG_NONE end
function modifier_crystal_maiden_brilliance_aura_aa_emitter:GetAuraSearchTeam() return DOTA_UNIT_TARGET_TEAM_FRIENDLY end
function modifier_crystal_maiden_brilliance_aura_aa_emitter:GetAuraSearchType() return DOTA_UNIT_TARGET_HERO end
function modifier_crystal_maiden_brilliance_aura_aa_emitter:GetModifierAura() return "modifier_crystal_maiden_brilliance_aura_aa" end

function modifier_crystal_maiden_brilliance_aura_aa_emitter:IsAura()
	if self:GetCaster():PassivesDisabled() then
		return false
	end

	if self:GetCaster():IsIllusion() then
		return false
	end

	return true
end

function modifier_crystal_maiden_brilliance_aura_aa_emitter:IsHidden() return true end
function modifier_crystal_maiden_brilliance_aura_aa_emitter:IsDebuff() return false end
function modifier_crystal_maiden_brilliance_aura_aa_emitter:IsPurgable() return false end

modifier_crystal_maiden_brilliance_aura_aa = class({})

function modifier_crystal_maiden_brilliance_aura_aa:OnCreated()
	self.caster = self:GetCaster()
	self.ability = self:GetAbility()
	self.parent = self:GetParent()
	self.mana_regen_share = self.ability:GetSpecialValueFor("mana_regen_share") / 100
	self.bonus_self = self.ability:GetSpecialValueFor("self_bonus")
	self.spellamp_const = self.ability:GetSpecialValueFor("spellamp_const")
	self.spellamp_mlp = self.ability:GetSpecialValueFor("spellamp_mlp") / 100

	if IsServer() then
		self:StartIntervalThink(0.2)
	end
end
function modifier_crystal_maiden_brilliance_aura_aa:OnIntervalThink()
	if IsServer() then
		if not self:GetAbility() then return end

		if self.parent then
			self:SetStackCount(self.spellamp_const + (self.caster:GetManaRegen() * self.spellamp_mlp))
		end
	end
end

function modifier_crystal_maiden_brilliance_aura_aa:OnRefresh()
	self:OnCreated()
end

function modifier_crystal_maiden_brilliance_aura_aa:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
		
		MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
	}
	return funcs
end

function modifier_crystal_maiden_brilliance_aura_aa:GetModifierConstantManaRegen()
	if not self:GetAbility() then return end

	if self.parent == self.caster then
		return self:GetAbility():GetSpecialValueFor("mana_regen") * self.bonus_self
	else
		return self:GetAbility():GetSpecialValueFor("mana_regen") + (self.caster:GetManaRegen() * self.mana_regen_share)
	end
end

function modifier_crystal_maiden_brilliance_aura_aa:GetModifierSpellAmplify_Percentage()

	if self.parent == self.caster then
		return self:GetStackCount() * self:GetAbility():GetSpecialValueFor("self_bonus")
	else
		return self:GetStackCount()
	end 
end

function modifier_crystal_maiden_brilliance_aura_aa:IsHidden() return false end
function modifier_crystal_maiden_brilliance_aura_aa:IsDebuff() return false end
function modifier_crystal_maiden_brilliance_aura_aa:IsPurgable() return false end