modifier_huntress_curse_arrow_scepter_mute = modifier_huntress_curse_arrow_scepter_mute or class({})
local mod = modifier_huntress_curse_arrow_scepter_mute

function mod:IsHidden() return false end
function mod:IsDebuff() return true end
function mod:IsPurgable() return true end

function mod:GetEffectName()
	return "particles/generic_gameplay/generic_silenced.vpcf"
end

function mod:GetStatusEffectName()
	return "particles/status_fx/status_effect_silencer.vpcf"
end

function mod:DeclareFunctions()
	return {
		MODIFIER_STATE_SILENCED,
	}
end

function mod:CheckState()
	return {
		[MODIFIER_STATE_SILENCED] = true,
	}
end
