-- Spike: Resurrection Power. Порт из Angel Arena Global.
-- Пассивка: реген % макс. HP и сопротивление эффектам. Каждые thresshold_pct% макс. HP
-- полученного урона - автоматически на passive_duration срабатывает усиленная версия.
-- Активка: усиленная версия (x multiplier%) на active_duration.

spike_heal = class({})

LinkLuaModifier("modifier_spike_heal", "heroes/spike/spike_heal", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_spike_heal_active", "heroes/spike/spike_heal", LUA_MODIFIER_MOTION_NONE)

function spike_heal:Precache(context)
	PrecacheResource("particle", "particles/world_shrine/dire_shrine_active_flash.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/bloodseeker/bloodseeker_eztzhok_weapon/bloodseeker_bloodrage_eztzhok.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_bloodseeker.vsndevts", context)
end

function spike_heal:GetIntrinsicModifierName()
	return "modifier_spike_heal"
end

function spike_heal:OnSpellStart()
	local caster = self:GetCaster()
	caster:AddNewModifier(caster, self, "modifier_spike_heal_active", { duration = self:GetSpecialValueFor("active_duration") })
end

function spike_heal:PlayEffects()
	local caster = self:GetCaster()
	caster:EmitSound("Hero_Bloodseeker.BloodRite.Cast")
	local pfx = ParticleManager:CreateParticle("particles/world_shrine/dire_shrine_active_flash.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:ReleaseParticleIndex(pfx)
end

--------------------------------------------------------------------------------

modifier_spike_heal = class({})

function modifier_spike_heal:IsHidden() return true end
function modifier_spike_heal:IsPurgable() return false end
function modifier_spike_heal:RemoveOnDeath() return false end

function modifier_spike_heal:OnCreated()
	self.damage_taken = 0
	self:OnRefresh()
end

function modifier_spike_heal:OnRefresh()
	local ability = self:GetAbility()
	if not ability then return end
	self.regen = ability:GetSpecialValueFor("heal_per_sec")
	self.status_resist = ability:GetSpecialValueFor("status_resist")
	self.threshold = ability:GetSpecialValueFor("thresshold_pct") / 100
	self.passive_duration = ability:GetSpecialValueFor("passive_duration")
end

function modifier_spike_heal:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE,
		MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
	}
end

function modifier_spike_heal:GetModifierHealthRegenPercentage()
	if self:GetParent():PassivesDisabled() then return 0 end
	return self.regen
end

function modifier_spike_heal:GetModifierStatusResistanceStacking()
	if self:GetParent():PassivesDisabled() then return 0 end
	return self.status_resist
end

function modifier_spike_heal:OnTakeDamage(params)
	if not IsServer() then return end

	local parent = self:GetParent()
	if params.unit ~= parent or parent:PassivesDisabled() or not parent:IsAlive() then return end
	if not self.threshold or self.threshold <= 0 then return end

	local step = parent:GetMaxHealth() * self.threshold
	self.damage_taken = self.damage_taken + params.damage

	if self.damage_taken >= step then
		self.damage_taken = self.damage_taken % step
		parent:AddNewModifier(parent, self:GetAbility(), "modifier_spike_heal_active", { duration = self.passive_duration })
	end
end

--------------------------------------------------------------------------------

modifier_spike_heal_active = class({})

function modifier_spike_heal_active:IsHidden() return false end
function modifier_spike_heal_active:IsPurgable() return true end

function modifier_spike_heal_active:OnCreated()
	local ability = self:GetAbility()
	if not ability then return end

	local mult = ability:GetSpecialValueFor("multiplier") / 100
	self.regen = ability:GetSpecialValueFor("heal_per_sec") * mult
	self.status_resist = ability:GetSpecialValueFor("status_resist") * mult

	if IsServer() then ability:PlayEffects() end
end

modifier_spike_heal_active.OnRefresh = modifier_spike_heal_active.OnCreated

function modifier_spike_heal_active:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE,
		MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING,
	}
end

function modifier_spike_heal_active:GetModifierHealthRegenPercentage() return self.regen end
function modifier_spike_heal_active:GetModifierStatusResistanceStacking() return self.status_resist end

function modifier_spike_heal_active:GetEffectName()
	return "particles/econ/items/bloodseeker/bloodseeker_eztzhok_weapon/bloodseeker_bloodrage_eztzhok.vpcf"
end

function modifier_spike_heal_active:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end
