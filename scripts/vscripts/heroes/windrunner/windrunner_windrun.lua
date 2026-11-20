-- Windrun (Windranger) на Lua.
-- Значения - scripts/npc/heroes/windrunner/ability_data.txt (windrunner_windrun).
--   modifier_windrunner_windrun_aa - на время баффа (своё имя: с ванильным
--     "modifier_windrunner_windrun" работал встроенный модификатор движка, и наше
--     универсальное уклонение не срабатывало, 2026-11-17): 100% уклонение от атак, бонус скорости
--     (movespeed_bonus_pct) и универсальное уклонение universal_evasion (20%: шанс полностью
--     проигнорировать любой урон, как у Бабочки). Пассивки нет - только пока Windrun активен.

LinkLuaModifier("modifier_windrunner_windrun_aa", "heroes/windrunner/windrunner_windrun", LUA_MODIFIER_MOTION_NONE)

windrunner_windrun = class({})

function windrunner_windrun:Precache(context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_windrunner.vsndevts", context)
end

function windrunner_windrun:OnSpellStart()
	local caster = self:GetCaster()

	-- GetDuration учитывает AbilityDuration с талантом special_bonus_unique_windranger_4
	caster:AddNewModifier(caster, self, "modifier_windrunner_windrun_aa", { duration = self:GetDuration() })
	caster:EmitSound("Ability.Windrun")
end

--------------------------------------------------------------------------------
modifier_windrunner_windrun_aa = class({})

function modifier_windrunner_windrun_aa:IsHidden() return false end
function modifier_windrunner_windrun_aa:IsBuff() return true end
function modifier_windrunner_windrun_aa:IsDebuff() return false end
function modifier_windrunner_windrun_aa:RemoveOnDeath() return true end
function modifier_windrunner_windrun_aa:GetTexture() return "windrunner_windrun" end

-- special_bonus_unique_windranger_windrun_undispellable даёт cannot_be_dispelled = 1
function modifier_windrunner_windrun_aa:IsPurgable()
	return self:GetAbility():GetSpecialValueFor("cannot_be_dispelled") ~= 1
end

function modifier_windrunner_windrun_aa:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_EVASION_CONSTANT,
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
	}
end

function modifier_windrunner_windrun_aa:GetModifierEvasion_Constant()
	return self:GetAbility():GetSpecialValueFor("evasion_pct_tooltip")
end

function modifier_windrunner_windrun_aa:GetModifierMoveSpeedBonus_Percentage()
	return self:GetAbility():GetSpecialValueFor("movespeed_bonus_pct")
end

-- Универсальное уклонение (только пока Windrun активен): шанс universal_evasion полностью проигнорировать любой урон
function modifier_windrunner_windrun_aa:GetModifierIncomingDamage_Percentage()
	if not IsServer() then return 0 end

	local parent = self:GetParent()

	if RollPercentage(self:GetAbility():GetSpecialValueFor("universal_evasion")) then
		-- тот же отклик, что у Бабочки (Absolute Evasion): вспышка отката и "Уклонение" над головой
		local fx = ParticleManager:CreateParticle("particles/econ/items/faceless_void/faceless_void_bracers_of_aeons/fv_bracers_of_aeons_backtrack.vpcf", PATTACH_ABSORIGIN, parent)
		ParticleManager:SetParticleControl(fx, 0, parent:GetAbsOrigin())
		ParticleManager:ReleaseParticleIndex(fx)
		SendOverheadEventMessage(nil, OVERHEAD_ALERT_EVADE, parent, 0, nil)
		return -100
	end
end
