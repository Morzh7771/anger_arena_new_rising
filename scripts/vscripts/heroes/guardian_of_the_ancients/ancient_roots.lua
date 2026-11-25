-- Guardian of the Ancients: Ancient Roots (врождённая). Постоял на месте root_delay сек. - получает
-- (damage_reduction + reduction_per_level × уровень)% снижения входящего урона, пока не сдвинется.
-- Работает в паре с Command Height (там герой и так стоит на месте).

guardian_of_the_ancients_ancient_roots = class({})

LinkLuaModifier("modifier_guardian_of_the_ancients_ancient_roots", "heroes/guardian_of_the_ancients/ancient_roots", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_guardian_of_the_ancients_ancient_roots_active", "heroes/guardian_of_the_ancients/ancient_roots", LUA_MODIFIER_MOTION_NONE)

function guardian_of_the_ancients_ancient_roots:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/guardian_of_the_ancients/guardian_ancient_roots_vines.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_treant/treant_bramble_root_dust.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_treant.vsndevts", context)
end

function guardian_of_the_ancients_ancient_roots:GetIntrinsicModifierName()
	return "modifier_guardian_of_the_ancients_ancient_roots"
end

--------------------------------------------------------------------------------
-- следит, стоит ли герой на месте

modifier_guardian_of_the_ancients_ancient_roots = class({})

function modifier_guardian_of_the_ancients_ancient_roots:IsHidden() return true end
function modifier_guardian_of_the_ancients_ancient_roots:IsPurgable() return false end
function modifier_guardian_of_the_ancients_ancient_roots:RemoveOnDeath() return false end

local THINK = 0.1

function modifier_guardian_of_the_ancients_ancient_roots:OnCreated()
	if not IsServer() then return end
	self.last_pos = self:GetParent():GetAbsOrigin()
	self.still_time = 0
	self:StartIntervalThink(THINK)
end

function modifier_guardian_of_the_ancients_ancient_roots:OnIntervalThink()
	local parent = self:GetParent()
	local ability = self:GetAbility()
	if not ability then return end

	local pos = parent:GetAbsOrigin()
	local moved = (pos - self.last_pos):Length2D() > 5
	self.last_pos = pos

	if moved or not parent:IsAlive() or parent:PassivesDisabled() then
		self.still_time = 0
		parent:RemoveModifierByName("modifier_guardian_of_the_ancients_ancient_roots_active")
		return
	end

	self.still_time = self.still_time + THINK
	if self.still_time >= ability:GetSpecialValueFor("root_delay") and not parent:HasModifier("modifier_guardian_of_the_ancients_ancient_roots_active") then
		parent:AddNewModifier(parent, ability, "modifier_guardian_of_the_ancients_ancient_roots_active", {})
	end
end

--------------------------------------------------------------------------------
-- сам бафф: снижение урона

modifier_guardian_of_the_ancients_ancient_roots_active = class({})

function modifier_guardian_of_the_ancients_ancient_roots_active:IsHidden() return false end
function modifier_guardian_of_the_ancients_ancient_roots_active:IsPurgable() return false end

function modifier_guardian_of_the_ancients_ancient_roots_active:DeclareFunctions()
	return { MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE }
end

function modifier_guardian_of_the_ancients_ancient_roots_active:GetModifierIncomingDamage_Percentage()
	local ability = self:GetAbility()
	if not ability then return 0 end
	return -(ability:GetSpecialValueFor("damage_reduction") + ability:GetSpecialValueFor("reduction_per_level") * self:GetParent():GetLevel())
end

-- лианы обвивают ноги: видно, что Страж вкопался
function modifier_guardian_of_the_ancients_ancient_roots_active:GetEffectName()
	return "particles/units/heroes/guardian_of_the_ancients/guardian_ancient_roots_vines.vpcf"
end

function modifier_guardian_of_the_ancients_ancient_roots_active:OnCreated()
	if not IsServer() then return end
	local parent = self:GetParent()
	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_treant/treant_bramble_root_dust.vpcf", PATTACH_ABSORIGIN, parent)
	ParticleManager:ReleaseParticleIndex(fx)
	parent:EmitSound("Hero_Treant.Overgrowth.Target")
end

function modifier_guardian_of_the_ancients_ancient_roots_active:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end
