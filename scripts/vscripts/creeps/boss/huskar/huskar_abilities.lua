-- Хускар (npc_aa_huskar_boss). Копья, Inner Fire, Berserker's Blood, Life Break
-- как в доте. Inner Vitality - замах 1 с, потом снимает дебафы и лечит.
-- Подход: сбивать замах Vitality, добивать резко.

require("creeps/boss/boss_kit")

LinkLuaModifier("modifier_huskar_boss_spears",      "creeps/boss/huskar/huskar_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_huskar_boss_spears_burn", "creeps/boss/huskar/huskar_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_huskar_boss_blood",       "creeps/boss/huskar/huskar_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_huskar_boss_vitality",    "creeps/boss/huskar/huskar_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_huskar_boss_break_slow",  "creeps/boss/huskar/huskar_abilities", LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- Горящие копья: каждая атака +1 стак горения (% HP в секунду за стак).
--------------------------------------------------------------------------------
huskar_boss_spears = huskar_boss_spears or class({})
function huskar_boss_spears:GetIntrinsicModifierName() return "modifier_huskar_boss_spears" end

modifier_huskar_boss_spears = modifier_huskar_boss_spears or class({})
local sp = modifier_huskar_boss_spears

function sp:IsHidden()   return true end
function sp:IsPurgable() return false end
function sp:DeclareFunctions() return { MODIFIER_EVENT_ON_ATTACK_LANDED } end

function sp:OnAttackLanded(params)
	if not IsServer() then return end
	local p = self:GetParent()
	if params.attacker ~= p then return end
	local t = params.target
	if not t or t:IsNull() or t:IsBuilding() then return end

	local ab = self:GetAbility()
	local m = t:FindModifierByNameAndCaster("modifier_huskar_boss_spears_burn", p)
	local n = math.min((m and m:GetStackCount() or 0) + 1, ab:GetSpecialValueFor("max_stacks"))

	m = t:AddNewModifier(p, ab, "modifier_huskar_boss_spears_burn", { duration = ab:GetSpecialValueFor("duration") })
	if m then m:SetStackCount(n) end
	t:EmitSound("Hero_Huskar.Burning_Spear")
end

modifier_huskar_boss_spears_burn = modifier_huskar_boss_spears_burn or class({})
local burn = modifier_huskar_boss_spears_burn

function burn:IsDebuff() return true end
function burn:GetTexture() return "huskar_burning_spear" end
function burn:GetEffectName() return "particles/units/heroes/hero_huskar/huskar_burning_spear_debuff.vpcf" end

function burn:OnCreated()
	if not IsServer() then return end
	self:StartIntervalThink(1)
end

function burn:OnIntervalThink()
	local ab = self:GetAbility()
	local c = self:GetCaster()
	if not ab or ab:IsNull() or c:IsNull() then return end
	BossKit:PctDamage(c, ab, self:GetParent(), ab:GetSpecialValueFor("pct_per_stack") * self:GetStackCount())
end

--------------------------------------------------------------------------------
-- Inner Fire: огненное кольцо, урон и отброс от Хускара.
--------------------------------------------------------------------------------
huskar_boss_inner_fire = huskar_boss_inner_fire or class({})
local fire = huskar_boss_inner_fire

function fire:OnAbilityPhaseStart()
	if not IsServer() then return true end
	self.mark = BossKit:TelegraphFollow(self:GetCaster(), self:GetSpecialValueFor("radius"), self:GetCastPoint())
	return true
end

function fire:OnAbilityPhaseInterrupted()
	BossKit:StopParticle(self.mark)
	self.mark = nil
end

function fire:OnSpellStart()
	BossKit:StopParticle(self.mark)
	self.mark = nil
	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()
	local r = self:GetSpecialValueFor("radius")

	for _, v in pairs(BossKit:Enemies(caster, origin, r)) do
		BossKit:PctDamage(caster, self, v, self:GetSpecialValueFor("damage_pct"))
		v:AddNewModifier(caster, self, "modifier_knockback", {
			center_x = origin.x, center_y = origin.y, center_z = origin.z,
			knockback_duration = 0.4, knockback_distance = self:GetSpecialValueFor("knockback"),
			knockback_height = 50, should_stun = 1, duration = 0.4,
		})
		v:AddNewModifier(caster, self, "modifier_disarmed", { duration = self:GetSpecialValueFor("disarm") })
	end

	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_huskar/huskar_inner_fire.vpcf", PATTACH_ABSORIGIN, caster)
	ParticleManager:SetParticleControl(fx, 1, Vector(r, r, r))
	ParticleManager:ReleaseParticleIndex(fx)
	caster:EmitSound("Hero_Huskar.Inner_Fire.Cast")
end

--------------------------------------------------------------------------------
-- Berserker's Blood: чем меньше HP, тем быстрее бьёт.
--------------------------------------------------------------------------------
huskar_boss_berserkers_blood = huskar_boss_berserkers_blood or class({})
function huskar_boss_berserkers_blood:GetIntrinsicModifierName() return "modifier_huskar_boss_blood" end

modifier_huskar_boss_blood = modifier_huskar_boss_blood or class({})
local blood = modifier_huskar_boss_blood

function blood:IsHidden()   return true end
function blood:IsPurgable() return false end
function blood:GetEffectName() return "particles/units/heroes/hero_huskar/huskar_berserkers_blood_glow.vpcf" end
function blood:DeclareFunctions() return { MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT } end
function blood:GetModifierAttackSpeedBonus_Constant()
	local p = self:GetParent()
	return (100 - p:GetHealthPercent()) * self:GetAbility():GetSpecialValueFor("as_per_pct")
end

--------------------------------------------------------------------------------
-- Inner Vitality: замах 1 с (видно свечение), затем снимает дебафы и лечит.
--------------------------------------------------------------------------------
huskar_boss_inner_vitality = huskar_boss_inner_vitality or class({})
local vit = huskar_boss_inner_vitality

function vit:OnAbilityPhaseStart()
	if not IsServer() then return true end
	self.fx = ParticleManager:CreateParticle("particles/units/heroes/hero_huskar/huskar_inner_vitality_cast.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetCaster())
	return true
end

function vit:OnAbilityPhaseInterrupted()
	BossKit:StopParticle(self.fx)
	self.fx = nil
end

function vit:OnSpellStart()
	BossKit:StopParticle(self.fx)
	self.fx = nil

	local caster = self:GetCaster()
	BossKit:Dispel(caster)
	local heal = caster:GetMaxHealth() * self:GetSpecialValueFor("heal_pct") / 100
	caster:Heal(heal, self)
	SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, caster, heal, nil)
	caster:AddNewModifier(caster, self, "modifier_huskar_boss_vitality", { duration = self:GetSpecialValueFor("duration") })
	caster:EmitSound("Hero_Huskar.Cauterize.Heal")
end

modifier_huskar_boss_vitality = modifier_huskar_boss_vitality or class({})
local vm = modifier_huskar_boss_vitality

function vm:IsPurgable() return true end
function vm:GetTexture() return "huskar_inner_vitality" end
function vm:GetEffectName() return "particles/units/heroes/hero_huskar/huskar_inner_vitality.vpcf" end
function vm:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end
function vm:DeclareFunctions() return { MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE } end
function vm:GetModifierHealthRegenPercentage() return self:GetAbility():GetSpecialValueFor("regen_pct") end

--------------------------------------------------------------------------------
-- Life Break: прыжок в героя, % его HP и замедление.
--------------------------------------------------------------------------------
huskar_boss_life_break = huskar_boss_life_break or class({})
local lb = huskar_boss_life_break

function lb:OnAbilityPhaseStart()
	if not IsServer() then return true end
	local t = self:GetCursorTarget()
	if t then BossKit:TelegraphLineTo(self:GetCaster(), t, 150, self:GetCastPoint()) end
	return true
end

function lb:OnSpellStart()
	local caster = self:GetCaster()
	local t = self:GetCursorTarget()
	if not t then return end

	local dir = t:GetAbsOrigin() - caster:GetAbsOrigin()
	dir.z = 0
	FindClearSpaceForUnit(caster, t:GetAbsOrigin() - dir:Normalized() * 100, true)
	caster:FaceTowards(t:GetAbsOrigin())

	BossKit:PctDamage(caster, self, t, self:GetSpecialValueFor("damage_pct"))
	t:AddNewModifier(caster, self, "modifier_huskar_boss_break_slow", { duration = self:GetSpecialValueFor("slow_duration") })

	t:EmitSound("Hero_Huskar.Life_Break.Impact")
	caster:EmitSound("Hero_Huskar.Life_Break")
	caster:MoveToTargetToAttack(t)
end

modifier_huskar_boss_break_slow = modifier_huskar_boss_break_slow or class({})
function modifier_huskar_boss_break_slow:IsDebuff() return true end
function modifier_huskar_boss_break_slow:GetTexture() return "huskar_life_break" end
function modifier_huskar_boss_break_slow:GetStatusEffectName() return "particles/status_fx/status_effect_huskar_lifebreak.vpcf" end
function modifier_huskar_boss_break_slow:DeclareFunctions() return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE } end
function modifier_huskar_boss_break_slow:GetModifierMoveSpeedBonus_Percentage()
	local a = self:GetAbility()
	return a and -a:GetSpecialValueFor("slow") or 0
end
