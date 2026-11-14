-- Windrun (Windranger) на Lua.
-- Значения - scripts/npc/heroes/windrunner/ability_data.txt (windrunner_windrun).
--   modifier_windrunner_windrun_passive - постоянный: универсальное уклонение
--     (universal_evasion, шанс проигнорировать любой урон).
--   modifier_windrunner_windrun - на время баффа: 100% уклонение от атак и
--     бонус скорости движения (movespeed_bonus_pct).

LinkLuaModifier("modifier_windrunner_windrun", "heroes/windrunner/windrunner_windrun", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_windrunner_windrun_passive", "heroes/windrunner/windrunner_windrun", LUA_MODIFIER_MOTION_NONE)

windrunner_windrun = class({})

function windrunner_windrun:Precache(context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_windrunner.vsndevts", context)
end

function windrunner_windrun:GetIntrinsicModifierName()
	return "modifier_windrunner_windrun_passive"
end

function windrunner_windrun:OnSpellStart()
	local caster = self:GetCaster()

	-- GetDuration учитывает AbilityDuration с талантом special_bonus_unique_windranger_4
	caster:AddNewModifier(caster, self, "modifier_windrunner_windrun", { duration = self:GetDuration() })
	caster:EmitSound("Ability.Windrun")
end

--------------------------------------------------------------------------------
modifier_windrunner_windrun = class({})

function modifier_windrunner_windrun:IsHidden() return false end
function modifier_windrunner_windrun:IsBuff() return true end
function modifier_windrunner_windrun:IsDebuff() return false end
function modifier_windrunner_windrun:RemoveOnDeath() return true end
function modifier_windrunner_windrun:GetTexture() return "windrunner_windrun" end

-- special_bonus_unique_windranger_windrun_undispellable даёт cannot_be_dispelled = 1
function modifier_windrunner_windrun:IsPurgable()
	return self:GetAbility():GetSpecialValueFor("cannot_be_dispelled") ~= 1
end

function modifier_windrunner_windrun:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_EVASION_CONSTANT,
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	}
end

function modifier_windrunner_windrun:GetModifierEvasion_Constant()
	return self:GetAbility():GetSpecialValueFor("evasion_pct_tooltip")
end

function modifier_windrunner_windrun:GetModifierMoveSpeedBonus_Percentage()
	return self:GetAbility():GetSpecialValueFor("movespeed_bonus_pct")
end

--------------------------------------------------------------------------------
modifier_windrunner_windrun_passive = class({})

function modifier_windrunner_windrun_passive:IsHidden() return false end
function modifier_windrunner_windrun_passive:IsBuff() return true end
function modifier_windrunner_windrun_passive:IsDebuff() return false end
function modifier_windrunner_windrun_passive:IsPurgable() return false end
function modifier_windrunner_windrun_passive:RemoveOnDeath() return false end
function modifier_windrunner_windrun_passive:GetTexture() return "windrunner_windrun" end

function modifier_windrunner_windrun_passive:DeclareFunctions()
	return { MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE }
end

-- Универсальное уклонение: шанс universal_evasion полностью проигнорировать любой урон
function modifier_windrunner_windrun_passive:GetModifierIncomingDamage_Percentage()
	local parent = self:GetParent()

	if RollPercentage(self:GetAbility():GetSpecialValueFor("universal_evasion")) then
		SendOverheadEventMessage(nil, OVERHEAD_ALERT_EVADE, parent, 0, nil)
		return -100
	end
end
