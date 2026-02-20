LinkLuaModifier('modifier_mirror_shield_aa', 'items/item_mirror_shield_aa', LUA_MODIFIER_MOTION_NONE)

item_mirror_shield_aa = class({
	Precache = function (self, context) 
		PrecacheResource("particle", "particles/units/heroes/hero_antimage/antimage_spellshield_reflect.vpcf", context)
		PrecacheResource("particle", "particles/items/reflection_shard/immunity_sphere_yellow.vpcf", context)
		PrecacheResource("particle", "particles/units/heroes/hero_antimage/antimage_spellshield.vpcf", context)
	end,
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
	

function modifier_mirror_shield_aa:OnCreated(params)
	if IsServer() then
		local parent = self:GetParent()
		parent:EmitSound("Hero_Antimage.Counterspell.Cast")
		if self.nPreviewFX == nil then
		  --self.nPreviewFX = ParticleManager:CreateParticle("particles/items/reflection_shard/reflection_shield.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent)
		  self.nPreviewFX = ParticleManager:CreateParticle("particles/units/heroes/hero_antimage/antimage_spellshield_reflect.vpcf", PATTACH_CUSTOMORIGIN_FOLLOW, parent)
		end
	
		if parent.stored_reflected_spells == nil then
		  parent.stored_reflected_spells = {}
		end
	  end
end

function modifier_mirror_shield_aa:GetReflectSpell(kv)
	if IsServer() then
		local parent = self:GetParent()
	
		local ability_name = kv.ability:GetAbilityName()
		local target = kv.ability:GetCaster()
		local ability_level = kv.ability:GetLevel()
		local ability_behaviour = kv.ability:GetBehavior()
		
		if type(ability_behaviour) == 'userdata' then
		  ability_behaviour = tonumber(tostring(ability_behaviour))
		end
	
		local exception_list = {
		  ["rubick_spell_steal"] = true,
		  ["morphling_replicate"] = true,
		  ["morphling_hybrid"] = true,
		  ["morphling_morph_replicate"] = true
		  --["grimstroke_soul_chain"] = true, -- uncomment this if Grimstroke Soul Bind becomes buggy
		  --["legion_commander_duel"] = true, -- uncomment this if Legion Commander's Duel becomes buggy
		}
	
		-- Do not reflect allied spells for any reason
		if target:GetTeamNumber() == parent:GetTeamNumber() then
		  return nil
		end
	
		-- If this is a reflected ability from other Reflection shard, do nothing
		-- (reflecting reflected spells should not be possible)
		if kv.ability.reflected_spell then
		  return nil
		end
	
		local reflecting_modifiers = {
		  "modifier_item_lotus_orb_active", -- Lotus Orb active
		  "modifier_item_mirror_shield",    -- Mirror Shield
		  "modifier_antimage_counterspell", -- Anti-Mage Counter Spell active
		}
		-- Check for reflecting modifiers
		local found = false
		for i = 1, #reflecting_modifiers do
		  if target:HasModifier(reflecting_modifiers[i]) then
			found = true
			break
		  end
		end
	
		-- If target has reflecting modifiers do nothing to prevent infinite loops
		-- (reflecting reflected spells should not be possible)
		if found then
		  return nil
		end
	
		-- If ability is on the exception list do nothing
		if exception_list[ability_name] then
		  return nil
		end
	
		-- If ability is channeling, dont reflect it because channeling abilities are buggy as hell
		if bit.band(ability_behaviour, DOTA_ABILITY_BEHAVIOR_CHANNELLED) == DOTA_ABILITY_BEHAVIOR_CHANNELLED then
		  return nil
		end
	
		-- Check if the parent already has the reflected ability
		local old = false
		for _,ability in pairs(parent.stored_reflected_spells) do
		  if ability and not ability:IsNull() then
			if ability:GetAbilityName() == ability_name then
			  old = true
			  break
			end
		  end
		end
	
		-- Reflect Sound
		parent:EmitSound("Hero_Antimage.Counterspell.Target")
	
		-- Reflect particle
		local burst = ParticleManager:CreateParticle("particles/items/reflection_shard/immunity_sphere_yellow.vpcf", PATTACH_ABSORIGIN, parent)
		Timers:CreateTimer(1.5, function()
		  ParticleManager:DestroyParticle(burst, false)
		  ParticleManager:ReleaseParticleIndex(burst)
		end)
	
		local reflect_ability
		local parent_ability
		if old then
		  reflect_ability = parent:FindAbilityByName(ability_name)
		else
		  parent_ability = parent:FindAbilityByName(ability_name)
		  if parent_ability then
			-- This is a rare case (Rubick stole the spell and then casted that same spell on the target he stole it from and target has reflection shard buff)
			-- when parent already has the kv.ability naturally (it wasn't added or stolen), then it should not be stolen or hidden because that would mess up things
			-- We shouldn't duplicate abilities if the parent already has the kv.ability
			parent:SetCursorCastTarget(target) -- Set the target for the spell.
			parent_ability:OnSpellStart() -- Cast the spell back (to Rubick).
			return -- Don't do other stuff
		  end
		  reflect_ability = parent:AddAbility(ability_name) -- Add the spell to the parent for the first time
		  if reflect_ability then
			reflect_ability:SetStolen(true) -- Just to be safe with some interactions.
			reflect_ability:SetHidden(true) -- Hide the ability on the parent.
			reflect_ability.reflected_spell = true  -- Tag this ability as reflected
			table.insert(parent.stored_reflected_spells, reflect_ability) -- Store the spell reference for future use.
		  end
		end
	
		if not reflect_ability then
		  -- If reflect_ability becomes nil for some reason, don't do other stuff
		  --print("reflect_ability not found")
		  return
		end
	
		reflect_ability:SetLevel(ability_level)       -- Set level to be the same as the level of the original ability
		parent:SetCursorCastTarget(target)            -- Set the target for the spell.
		reflect_ability:OnSpellStart()                -- Cast the spell.
	  end
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