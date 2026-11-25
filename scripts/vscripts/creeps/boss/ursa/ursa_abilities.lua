-- Урса (npc_aa_ursa_boss). Earthshock, Fury Swipes, Enrage как в доте.
-- Подход: менять, кого она бьёт; в Enrage не бить, а отойти.

require("creeps/boss/boss_kit")

LinkLuaModifier("modifier_ursa_boss_slow",         "creeps/boss/ursa/ursa_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ursa_boss_swipes",       "creeps/boss/ursa/ursa_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ursa_boss_swipes_stack", "creeps/boss/ursa/ursa_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ursa_boss_enrage",       "creeps/boss/ursa/ursa_abilities", LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- Earthshock: удар лапой о землю, урон и замедление вокруг.
--------------------------------------------------------------------------------
ursa_boss_earthshock = ursa_boss_earthshock or class({})
local es = ursa_boss_earthshock

function es:OnAbilityPhaseStart()
	if not IsServer() then return true end
	self.mark = BossKit:TelegraphFollow(self:GetCaster(), self:GetSpecialValueFor("radius"), self:GetCastPoint())
	return true
end

function es:OnAbilityPhaseInterrupted()
	BossKit:StopParticle(self.mark)
	self.mark = nil
end

function es:OnSpellStart()
	BossKit:StopParticle(self.mark)
	self.mark = nil
	local caster = self:GetCaster()
	local r = self:GetSpecialValueFor("radius")

	for _, v in pairs(BossKit:Enemies(caster, caster:GetAbsOrigin(), r)) do
		BossKit:PctDamage(caster, self, v, self:GetSpecialValueFor("damage_pct"))
		v:AddNewModifier(caster, self, "modifier_ursa_boss_slow", { duration = self:GetSpecialValueFor("slow_duration") })
	end

	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_ursa/ursa_earthshock.vpcf", PATTACH_ABSORIGIN, caster)
	ParticleManager:SetParticleControl(fx, 1, Vector(r, r, r))
	ParticleManager:ReleaseParticleIndex(fx)
	caster:EmitSound("Hero_Ursa.Earthshock")
end

modifier_ursa_boss_slow = modifier_ursa_boss_slow or class({})
function modifier_ursa_boss_slow:IsDebuff() return true end
function modifier_ursa_boss_slow:GetTexture() return "ursa_earthshock" end
function modifier_ursa_boss_slow:GetEffectName() return "particles/units/heroes/hero_ursa/ursa_earthshock_modifier.vpcf" end
function modifier_ursa_boss_slow:DeclareFunctions() return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE } end
function modifier_ursa_boss_slow:GetModifierMoveSpeedBonus_Percentage()
	local a = self:GetAbility()
	return a and -a:GetSpecialValueFor("slow") or 0
end

--------------------------------------------------------------------------------
-- Fury Swipes: каждый удар по тому же герою +% его HP.
--------------------------------------------------------------------------------
ursa_boss_fury_swipes = ursa_boss_fury_swipes or class({})
function ursa_boss_fury_swipes:GetIntrinsicModifierName() return "modifier_ursa_boss_swipes" end

modifier_ursa_boss_swipes = modifier_ursa_boss_swipes or class({})
local sw = modifier_ursa_boss_swipes

function sw:IsHidden()   return true end
function sw:IsPurgable() return false end
function sw:DeclareFunctions() return { MODIFIER_EVENT_ON_ATTACK_LANDED } end

function sw:OnAttackLanded(params)
	if not IsServer() then return end
	local p = self:GetParent()
	if params.attacker ~= p then return end
	local t = params.target
	if not t or t:IsNull() or t:IsBuilding() then return end

	local ab = self:GetAbility()
	local stack = t:FindModifierByNameAndCaster("modifier_ursa_boss_swipes_stack", p)
	local n = stack and stack:GetStackCount() or 0

	if n > 0 then
		BossKit:PctDamage(p, ab, t, ab:GetSpecialValueFor("pct_per_stack") * n)
	end

	stack = t:AddNewModifier(p, ab, "modifier_ursa_boss_swipes_stack", { duration = ab:GetSpecialValueFor("stack_duration") })
	if stack then stack:SetStackCount(n + 1) end
end

modifier_ursa_boss_swipes_stack = modifier_ursa_boss_swipes_stack or class({})
function modifier_ursa_boss_swipes_stack:IsDebuff() return true end
function modifier_ursa_boss_swipes_stack:IsPurgable() return false end
function modifier_ursa_boss_swipes_stack:GetTexture() return "ursa_fury_swipes" end
function modifier_ursa_boss_swipes_stack:GetEffectName() return "particles/units/heroes/hero_ursa/ursa_fury_swipes_debuff.vpcf" end
function modifier_ursa_boss_swipes_stack:GetEffectAttachType() return PATTACH_OVERHEAD_FOLLOW end

--------------------------------------------------------------------------------
-- Enrage: снимает дебафы, по ней почти не проходит урон, тело красное.
--------------------------------------------------------------------------------
ursa_boss_enrage = ursa_boss_enrage or class({})

function ursa_boss_enrage:OnSpellStart()
	local caster = self:GetCaster()
	BossKit:Dispel(caster)
	caster:AddNewModifier(caster, self, "modifier_ursa_boss_enrage", { duration = self:GetSpecialValueFor("duration") })
	caster:EmitSound("Hero_Ursa.Enrage")
end

modifier_ursa_boss_enrage = modifier_ursa_boss_enrage or class({})
local en = modifier_ursa_boss_enrage

function en:IsPurgable() return false end
function en:GetTexture() return "ursa_enrage" end
function en:GetEffectName() return "particles/units/heroes/hero_ursa/ursa_enrage_buff.vpcf" end
function en:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function en:DeclareFunctions()
	return { MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE, MODIFIER_PROPERTY_MODEL_SCALE }
end
function en:GetModifierIncomingDamage_Percentage() return -self:GetAbility():GetSpecialValueFor("damage_reduction") end
function en:GetModifierModelScale() return 20 end
