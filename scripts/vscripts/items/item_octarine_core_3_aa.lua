item_octarine_core_3_aa = item_octarine_core_3_aa or class({})

LinkLuaModifier ("modifier_item_octarine_core_3_aa", "items/item_octarine_core_3_aa.lua", LUA_MODIFIER_MOTION_NONE)

function item_octarine_core_3_aa:GetIntrinsicModifierName()
    return "modifier_item_octarine_core_3_aa"
end

modifier_item_octarine_core_3_aa = class({})

function modifier_item_octarine_core_3_aa:IsHidden()
    return true
end

function modifier_item_octarine_core_3_aa:OnCreated()
    local ability = self:GetAbility()

    if not ability then return end

    self.bonus_health     = ability:GetSpecialValueFor("bonus_health")
    self.bonus_mana     = ability:GetSpecialValueFor("bonus_mana")
    self.bonus_mana_regen = ability:GetSpecialValueFor("bonus_mana_regen")
    self.bonus_cooldown = ability:GetSpecialValueFor("bonus_cooldown")

    self.duration_ward = ability:GetSpecialValueFor("duration")
end

function modifier_item_octarine_core_3_aa:DeclareFunctions()
    return {
    MODIFIER_PROPERTY_HEALTH_BONUS,
    MODIFIER_PROPERTY_MANA_BONUS,
    MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
    MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE,
    }
end

function modifier_item_octarine_core_3_aa:GetModifierPercentageCooldown()
    if self:GetParent():HasItemInInventory("item_octarine_core") then
      return 0
    end
    return self.bonus_cooldown
end

function modifier_item_octarine_core_3_aa:GetModifierPercentageCooldown()
    if self:GetParent():HasItemInInventory("item_octarine_core_2") then
      return 0
    end
    return self.bonus_cooldown
end

function modifier_item_octarine_core_3_aa:GetPriority()
	return MODIFIER_PRIORITY_HIGH
end

function modifier_item_octarine_core_3_aa:GetModifierConstantManaRegen()
	return self.bonus_mana_regen
end

function modifier_item_octarine_core_3_aa:GetModifierManaBonus()
	return self.bonus_mana
end

function modifier_item_octarine_core_3_aa:GetModifierHealthBonus()
	return self.bonus_health
end


function item_octarine_core_3_aa:OnSpellStart()
	local point 	= self:GetCursorPosition()
	local caster 	= self:GetCaster()
	local duration 	= self:GetDuration()
	local ability 	= "item_octarine_core_3_aa"

	PrecacheUnitByNameAsync("npc_dota_observer_wards", function(...)
		local cr = CreateUnitByName("npc_dota_observer_wards", point, true, caster, caster, caster:GetTeamNumber() )
		cr:AddNewModifier(caster, nil, "modifier_kill", {duration = 180})
		cr:AddNewModifier(caster, nil, "modifier_item_buff_ward", {duration = 180})
		cr:AddNewModifier(caster, nil, "modifier_obs_ward_custom", {duration = 180})
	end)
end

modifier_obs_ward_custom = modifier_obs_ward_custom or class({})

function modifier_obs_ward_custom:IsHidden()
    return true
end

function modifier_obs_ward_custom:CheckState()
	local state = {
		[MODIFIER_STATE_NO_TEAM_SELECT]	= true,
		[MODIFIER_STATE_STUNNED]	= true,
		[MODIFIER_STATE_NO_TEAM_MOVE_TO]	= true,
	}
	return state
end