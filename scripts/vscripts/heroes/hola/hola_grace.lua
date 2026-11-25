-- Hola: Grace. Порт из Angel Arena Frontier, цифры Angel Arena Global.
-- Мгновенно лечит цель и на время даёт регенерацию. Талант: бафф усиливает всё лечение цели.

require("heroes/hola/hola_divine_retribution")

hola_grace = class({})

LinkLuaModifier("modifier_hola_grace", "heroes/hola/hola_grace", LUA_MODIFIER_MOTION_NONE)

function hola_grace:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_omniknight/omniknight_purification.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_omniknight.vsndevts", context)
end

function hola_grace:OnSpellStart()
	self:Apply(self:GetCursorTarget())
end

-- Зовётся и из ульты (талант hola_rescue)
function hola_grace:Apply(target)
	target:AddNewModifier(self:GetCaster(), self, "modifier_hola_grace", { duration = self:GetSpecialValueFor("heal_duration") })
end

--------------------------------------------------------------------------------

modifier_hola_grace = class({})

function modifier_hola_grace:IsHidden() return false end
function modifier_hola_grace:IsDebuff() return false end
function modifier_hola_grace:IsPurgable() return true end

function modifier_hola_grace:OnCreated()
	local ability = self:GetAbility()
	if not ability then return end

	self.hp_regen = ability:GetSpecialValueFor("hp_regen")
	self.heal_amp = ability:GetSpecialValueFor("heal_amp")

	if not IsServer() then return end

	local parent = self:GetParent()
	local caster = self:GetCaster()
	local heal = ability:GetSpecialValueFor("heal") + caster:GetStrength() * ability:GetSpecialValueFor("heal_int_pct") / 100

	parent:Heal(heal, ability)
	HolaRetribution(caster, parent, heal)
	SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, parent, heal, nil)
	parent:EmitSound("Hero_Omniknight.Purification")

	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_omniknight/omniknight_purification.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:SetParticleControl(pfx, 1, Vector(300, 1, 1))
	ParticleManager:ReleaseParticleIndex(pfx)
end

function modifier_hola_grace:OnRefresh()
	self:OnCreated()
end

function modifier_hola_grace:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
		MODIFIER_PROPERTY_HEAL_AMPLIFY_PERCENTAGE_TARGET,
		MODIFIER_PROPERTY_HP_REGEN_AMPLIFY_PERCENTAGE,
		MODIFIER_PROPERTY_LIFESTEAL_AMPLIFY_PERCENTAGE,
		MODIFIER_PROPERTY_SPELL_LIFESTEAL_AMPLIFY_PERCENTAGE,
	}
end

function modifier_hola_grace:GetModifierConstantHealthRegen() return self.hp_regen end
function modifier_hola_grace:GetModifierHealAmplify_PercentageTarget() return self.heal_amp end
function modifier_hola_grace:GetModifierHPRegenAmplify_Percentage() return self.heal_amp end
function modifier_hola_grace:GetModifierLifestealRegenAmplify_Percentage() return self.heal_amp end
function modifier_hola_grace:GetModifierSpellLifestealRegenAmplify_Percentage() return self.heal_amp end

function modifier_hola_grace:GetEffectName()
	return "particles/units/heroes/hero_omniknight/omniknight_heavenly_grace_buff.vpcf"
end

function modifier_hola_grace:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end
