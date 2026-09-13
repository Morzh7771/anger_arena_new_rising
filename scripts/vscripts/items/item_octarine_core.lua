item_octarine_core = item_octarine_core or class({})
item_octarine_core_2 = item_octarine_core
item_octarine_core_3 = item_octarine_core

LinkLuaModifier ("modifier_item_octarine_core", "items/item_octarine_core.lua", LUA_MODIFIER_MOTION_NONE)

function item_octarine_core:GetIntrinsicModifierName()
    return "modifier_item_octarine_core"
end

-- Прекеш варда делаем ОДИН раз за матч.
--
-- Раньше PrecacheUnitByNameAsync стоял прямо в касте: каждое использование
-- октарина докидывало ресурсы в список загруженных. Список у движка один на
-- матч и индексируется unsigned short, то есть упирается в 32767 - в этот
-- потолок мод уже упирался на старте карты (см. Precache в addon_game_mode).
-- К поздней игре сотни кастов в сумме подтачивают тот же лимит.
local wards_precached = false

function item_octarine_core:OnSpellStart()
	local point 	= self:GetCursorPosition()
	local caster 	= self:GetCaster()
	local duration 	= self:GetSpecialValueFor("duration")

	local function PlantWard()
		local cr = CreateUnitByName("npc_dota_observer_wards", point, true, caster, caster, caster:GetTeamNumber() )
		cr:AddNewModifier(caster, nil, "modifier_kill", {duration = duration})
		cr:AddNewModifier(caster, nil, "modifier_item_buff_ward", {duration = duration})
		cr:AddNewModifier(caster, nil, "modifier_obs_ward_custom", {duration = duration})
	end

	if wards_precached then
		PlantWard()
		return
	end

	PrecacheUnitByNameAsync("npc_dota_observer_wards", function(...)
		wards_precached = true
		PlantWard()
	end)
end

modifier_item_octarine_core = class({
    IsHidden = function () return true end,
    DeclareFunctions = function ()
    	return {
            MODIFIER_PROPERTY_HEALTH_BONUS,
            MODIFIER_PROPERTY_MANA_BONUS,
            MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
            MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE,
            }
    end,
    GetPriority = function (self) return MODIFIER_PRIORITY_SUPER_ULTRA end,
    GetModifierPercentageCooldown = function (self) return self:GetAbility():GetSpecialValueFor('bonus_cooldown') end,
    GetModifierConstantManaRegen = function (self) return self:GetAbility():GetSpecialValueFor('bonus_mana_regen') end,
    GetModifierManaBonus = function (self) return self:GetAbility():GetSpecialValueFor('bonus_mana') end,
    GetModifierHealthBonus = function (self) return self:GetAbility():GetSpecialValueFor('bonus_health') end
})

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