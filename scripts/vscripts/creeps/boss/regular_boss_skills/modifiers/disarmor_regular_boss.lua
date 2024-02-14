modifier_disarmor_regular_boss = modifier_disarmor_regular_boss or class({})
local mod = modifier_disarmor_regular_boss



function mod:IsDebuff() 		return false end
function mod:IsHidden() 		return true end
function mod:IsPurgable() 		return false end
function mod:DestroyOnExpire() 	return true end
function mod:IsPurgeException() return false end

function mod:OnCreated(kv)
	local ability = self:GetAbility()

	if not ability then return end

	self.debuffDuration = ability:GetSpecialValueFor("disarmor_duration")
end

mod.OnRefresh = mod.OnCreated

function mod:DeclareFunctions() return 
{
	MODIFIER_EVENT_ON_ATTACK_LANDED,
}
end


function mod:OnAttackLanded( params )
	if not IsServer() then return end

	if not self then return end

	local ability = self:GetAbility()
	local parent = self:GetParent()
	local target = params.target

	if not ability or parent ~= params.attacker then return end

	if not parent:IsAlive() or not target:IsAlive() then return end

	local duration = self.debuffDuration

	if not duration then return end

	local mod = target:AddNewModifier(parent, ability, "modifier_possessed_rebel_debuff", { duration = duration })

	if mod then
		mod:IncrementStackCount()
	end
end
