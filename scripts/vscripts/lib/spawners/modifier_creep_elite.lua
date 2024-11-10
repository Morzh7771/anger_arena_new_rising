modifier_creep_elite = class({})

function modifier_creep_elite:DeclareFunctions()
	return {MODIFIER_PROPERTY_MODEL_SCALE}
end

function modifier_creep_elite:IsHidden()
	return true
end
function modifier_creep_elite:IsDebuff()
	return false
end
function modifier_creep_elite:RemoveOnDeath()
	return true
end
function modifier_creep_elite:IsPurgable()
	return false
end
function modifier_creep_elite:GetModifierModelScale()
	return 30
end
--просто и со вкусом particles/items_fx/aura_assault.vpcf говно
--просто и со вкусом particles/items_fx/aura_shivas.vpcf  говно
--просто и со вкусом particles/items_fx/aura_endurance.vpcf  говно
--просто и со вкусом particles/items_fx/aura_vlads.vpcf   говно

--просто и со вкусом particles/creature/solidity_aura.vpcf  говно
--просто и со вкусом particles/creature/speed_aura.vpcf  говно
--просто и со вкусом particles/creature/magic_resist_aura.vpcf  говно
--просто и со вкусом particles/creature/health_aura.vpcf  говно

--просто и со вкусом particles/creature/lifesteal_aura.vpcf  говно
--просто и со вкусом particles/creature/acid_aura.vpcf  говно
--просто и со вкусом particles/creature/armor_aura.vpcf  говно
--просто и со вкусом particles/creature/evasion_aura.vpcf  говно

--просто и со вкусом particles/creature/frost_aura.vpcf  говно
--просто и со вкусом particles/creature/attack_speed_aura.vpcf  говно
--просто и со вкусом particles/creature/blade_aura.vpcf  говно
--просто и со вкусом particles/creature/bubble_aura.vpcf  говно

--просто и со вкусом particles/creature/damage_aura.vpcf говно

function modifier_creep_elite:OnCreated(event)
	local hero = self:GetParent()
	self.particle = ParticleManager:CreateParticle("particles/econ/events/fall_2022/agh/agh_aura_fall2022_lvl2.vpcf", PATTACH_ABSORIGIN_FOLLOW, hero)
	ParticleManager:SetParticleControl(self.particle, 0, hero:GetAbsOrigin())
end
