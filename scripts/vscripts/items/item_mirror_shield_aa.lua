LinkLuaModifier('modifier_mirror_shield_aa', 'items/item_mirror_shield_aa', LUA_MODIFIER_MOTION_NONE)

item_mirror_shield_aa = class({
	GetIntrinsicModifierName = function (self) return 'modifier_mirror_shield_aa' end
	})

modifier_mirror_shield_aa = class({
	IsHidden = 			function (self) return true end,
	DeclareFunctions =	function (self) return
	{
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
		MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_REFLECT_SPELL,
		MODIFIER_PROPERTY_ABSORB_SPELL,
		MODIFIER_PROPERTY_MANA_BONUS
	}
	end,
	GetModifierBonusStats_Strength = function (self) 
		return self:GetAbility():GetSpecialValueFor('bonus_all_stats')
	end,
	GetModifierBonusStats_Agility = function (self) 
		return self:GetAbility():GetSpecialValueFor('bonus_all_stats')
	end,
	GetModifierBonusStats_Intellect = function (self)  
		return self:GetAbility():GetSpecialValueFor('bonus_all_stats')
	end,
	GetModifierConstantHealthRegen = function (self) 
		return self:GetAbility():GetSpecialValueFor('bonus_health_regen')
	end,
	GetModifierConstantManaRegen = function (self) 
		return self:GetAbility():GetSpecialValueFor('bonus_mana_regen')
	end,
	GetModifierPreAttack_BonusDamage = function (self) 
		return self:GetAbility():GetSpecialValueFor('bonus_damage')
	end,
	GetModifierPhysicalArmorBonus = function (self) 
		return self:GetAbility():GetSpecialValueFor('bonus_armor')
	end,
	GetModifierManaBonus = function (self)	
		return self:GetAbility():GetSpecialValueFor('bonus_mana')
	end
	})
	modifier_mirror_shield_aa.reflectSpell = nil

function modifier_mirror_shield_aa:OnCreated(params)
	self:GetParent().tOldSpells = {}
end

function modifier_mirror_shield_aa:GetReflectSpell(params)
	if not IsServer() then return end

	local caster = self:GetParent()
	if not caster or caster:IsNull() then return end

	local target = params.ability:GetCaster()
	if not target or target:IsNull() then return end

	if target:GetTeamNumber() == caster:GetTeamNumber() then return end
	if not self:GetAbility():IsFullyCastable() then return end

	local exception_spell =
	{
		["rubick_spell_steal"] = true,
		["morphling_replicate"] = true,
		["morphling_hybrid"] = true,
		["morphling_morph_replicate"] = true
	}

	local spell = params.ability:GetAbilityName()
	if exception_spell[spell] then return end

	local part = ParticleManager:CreateParticle("particles/units/heroes/hero_antimage/antimage_spellshield.vpcf", PATTACH_OVERHEAD_FOLLOW, caster)
	ParticleManager:SetParticleControlEnt(part, 0, caster, PATTACH_POINT_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
	caster:EmitSound("Item.LotusOrb.Activate")


	if params.ability.spell_shield_reflect then
		return nil
	end
	local ability
	local oldspell = false

	for _, hSpell in pairs(caster.tOldSpells) do
		if hSpell ~= nil and hSpell:GetAbilityName() == spell then
			old_spell = true
		break
		end
	end

	if old_spell then
		caster:FindAbilityByName(spell)
	else
		ability = caster:AddAbility(spell)
		ability:SetStolen(true)
		ability:SetHidden(true)
		ability.spell_shield_reflect = true
		ability:SetRefCountsModifiers(true)
	end
	ability:SetLevel(params.ability:GetLevel())
	caster:SetCursorCastTarget(target)
	ability:OnSpellStart()
	return 0
end

--if self.reflectSpell ~= nil then self:GetParent():RemoveAbility(self.reflectSpell:GetAbilityName()) end
	function modifier_mirror_shield_aa:GetAbsorbSpell(params)
		local caster = self:GetParent()
		if not self:GetAbility():IsFullyCastable() then return 0 end
		if self:GetParent():GetTeamNumber() == params.ability:GetCaster():GetTeamNumber() then return 0 end
		self:GetAbility():UseResources(false, false, false, true)
		local part = ParticleManager:CreateParticle("particles/units/heroes/hero_antimage/antimage_spellshield.vpcf", PATTACH_OVERHEAD_FOLLOW, caster)
		ParticleManager:SetParticleControlEnt(part, 0, caster, PATTACH_POINT_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
		caster:EmitSound("Item.LotusOrb.Activate")
		return 1
	end


--function modifier_mirror_shield_aa:GetReflectSpell(params)
--	if not IsServer() then return 0 end
--	if params.ability == nil then return 0 end
--	if not self:GetAbility():IsFullyCastable() then return 0 end
--
--	local sourceAbility = params.ability
--	local selfAbility = self:GetParent():AddAbility(sourceAbility:GetAbilityName())
--	selfAbility:SetLevel(sourceAbility:GetLevel())
--	selfAbility:SetStolen(true)
--	selfAbility:SetHidden(true)
--	self.reflectSpell = selfAbility
--	self:GetParent():SetCursorCastTarget(sourceAbility:GetCaster())
--	selfAbility:CastAbility()
--	self:GetParent():RemoveAbilityByHandle(selfAbility)
--	return 1
--end