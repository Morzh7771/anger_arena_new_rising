modifier_talant_bash = class({
    IsHidden = function (self) return false end,
    IsPurgeException = function (self) return true end,
    IsStunDebuff = function (self) return true end,
    CheckState = function (self) return {
		[MODIFIER_STATE_STUNNED] = true
	} end,
    GetEffectName = function (self) return "particles/generic_gameplay/generic_stunned.vpcf" end,
    GetEffectAttachType = function (self) return PATTACH_OVERHEAD_FOLLOW end,
    DeclareFunctions = function (self) return {
		MODIFIER_PROPERTY_OVERRIDE_ANIMATION
	} end,
    GetOverrideAnimation = function (self) return ACT_DOTA_DISABLED end,
})
modifier_talant_bash_cd = class({
    IsHidden = function (self) return false end,
})
