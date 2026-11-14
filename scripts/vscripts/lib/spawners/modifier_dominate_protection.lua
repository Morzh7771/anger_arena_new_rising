modifier_dominate_protection = modifier_dominate_protection or class({})
local mod = modifier_dominate_protection

function mod:IsHidden()         return true  end
function mod:IsPurgable()       return false end
function mod:DestroyOnExpire()  return true end
function mod:IsPurgable()       return false end
function mod:IsPurgeException() return false end

-- смерть крипа считается в CreepSpawner через ListenToGameEvent("entity_killed"),
-- поэтому MODIFIER_EVENT_ON_DEATH тут больше не нужен: он звал давно удалённый
-- CreepSpawner:_OnDied и валился с attempt to call a nil value на каждой смерти
function mod:DeclareFunctions() return
{
	MODIFIER_EVENT_ON_DOMINATED,
}
end

function mod:OnDominated(params)
	if not IsServer() then return end

	local unit = params.unit
	local parent = self:GetParent()

	if unit ~= parent then return end

	CreepSpawner:_OnDominated( unit )

	-- приручённый крип становится суммоном героя: бафф от его статов
	if SummonPower then SummonPower:ApplyWhenReady( unit ) end

	self:Destroy()
end