-- "!" над боссом на каждом замахе и канале способности: игрок видит, что
-- сейчас прилетит, ещё до круга или линии. Вешает BossSpawner:SpawnBoss
-- (и тест aa_boss). Каст не задерживает, только показывает.

modifier_boss_cast_alert = modifier_boss_cast_alert or class({})
local mod = modifier_boss_cast_alert

local FX_MARK = "particles/msg_fx/msg_aggro.vpcf"
local MIN_SHOW = 0.5

function mod:IsHidden()        return true  end
function mod:IsPurgable()      return false end
function mod:RemoveOnDeath()   return false end

function mod:DeclareFunctions() return { MODIFIER_EVENT_ON_ABILITY_START } end

function mod:OnAbilityStart(params)
	if not IsServer() then return end
	local p = self:GetParent()
	if params.unit ~= p then return end
	local ab = params.ability
	if not ab or ab:IsNull() or ab:IsItem() then return end

	local show = ab:GetCastPoint()
	if bit.band(ab:GetBehaviorInt(), DOTA_ABILITY_BEHAVIOR_CHANNELLED) ~= 0 then
		show = show + (ab:GetChannelTime() or 0)
	end
	show = math.max(show, MIN_SHOW)

	if self.fx then
		ParticleManager:DestroyParticle(self.fx, true)
		ParticleManager:ReleaseParticleIndex(self.fx)
	end

	local fx = ParticleManager:CreateParticle(FX_MARK, PATTACH_OVERHEAD_FOLLOW, p)
	self.fx = fx

	Timers:CreateTimer(show, function()
		if self.fx ~= fx then return end
		self.fx = nil
		ParticleManager:DestroyParticle(fx, false)
		ParticleManager:ReleaseParticleIndex(fx)
	end)
end
