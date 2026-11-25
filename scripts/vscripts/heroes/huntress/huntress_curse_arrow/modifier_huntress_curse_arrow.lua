modifier_huntress_curse_arrow = modifier_huntress_curse_arrow or class({})
local mod = modifier_huntress_curse_arrow

function mod:IsHidden() return false end
function mod:IsDebuff() return true end
function mod:IsPurgable() return false end
function mod:IsPurgeException() return false end

function mod:GetStatusEffectName()
	return "particles/huntress/huntress_hunting_spirit/huntress_hunting_spirit.vpcf"
end

function mod:OnCreated()
	self.break_passives = self:GetAbility() and self:GetAbility():GetSpecialValueFor("scepter_break") > 0
	if not IsServer() then return end
	self:OnIntervalThink()
	self:StartIntervalThink(0.1)
end
mod.OnRefresh = mod.OnCreated

-- как Nullifier: снимает положительные эффекты всё время действия
function mod:OnIntervalThink()
	if not IsServer() then return end
	self:GetParent():Purge(true, false, false, false, true)
end

-- аганим: ещё и Break
function mod:CheckState()
	if self.break_passives then
		return { [MODIFIER_STATE_PASSIVES_DISABLED] = true }
	end
	return {}
end
