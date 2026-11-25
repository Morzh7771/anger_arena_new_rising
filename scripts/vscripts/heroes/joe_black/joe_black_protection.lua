-- Joe Black: Unholy Protection. Порт из Angel Arena Frontier, цифры Angel Arena Global.
-- Снимает с союзника дебафы и режет входящий урон. Талант: ещё и иммунитет к дебафам.

joe_black_protection = class({})

LinkLuaModifier("modifier_joe_black_protection", "heroes/joe_black/joe_black_protection", LUA_MODIFIER_MOTION_NONE)

function joe_black_protection:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_spirit_breaker/spirit_breaker_haste_owner_status.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_vengefulspirit.vsndevts", context)
end

function joe_black_protection:OnSpellStart()
	local target = self:GetCursorTarget()

	target:Purge(false, true, false, true, true)
	target:AddNewModifier(self:GetCaster(), self, "modifier_joe_black_protection", { duration = self:GetSpecialValueFor("duration") })
	target:EmitSound("Hero_VengefulSpirit.WaveOfTerror")
end

--------------------------------------------------------------------------------

modifier_joe_black_protection = class({})

function modifier_joe_black_protection:IsHidden() return false end
function modifier_joe_black_protection:IsDebuff() return false end
function modifier_joe_black_protection:IsPurgable() return false end

function modifier_joe_black_protection:OnCreated()
	local ability = self:GetAbility()
	if not ability then return end

	self.reduction = -ability:GetSpecialValueFor("damage_reduction")
	self.debuff_immune = ability:GetSpecialValueFor("debuff_immunity") > 0
end

function modifier_joe_black_protection:OnRefresh()
	self:OnCreated()
end

function modifier_joe_black_protection:CheckState()
	if self.debuff_immune then
		return { [MODIFIER_STATE_DEBUFF_IMMUNE] = true }
	end
	return {}
end

function modifier_joe_black_protection:DeclareFunctions()
	return { MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE }
end

function modifier_joe_black_protection:GetModifierIncomingDamage_Percentage()
	return self.reduction
end

function modifier_joe_black_protection:GetEffectName()
	return "particles/units/heroes/hero_spirit_breaker/spirit_breaker_haste_owner_status.vpcf"
end

function modifier_joe_black_protection:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end
