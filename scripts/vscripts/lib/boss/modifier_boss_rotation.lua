-- Канал телепорта босса при ротации (lib/boss/boss_spawner.lua). Босс стоит
-- с поднятой рукой, вокруг аура телепорта и круг с обратным отсчётом, на
-- точке прибытия - такой же свет. Урон по боссу сбивает канал (это делает
-- спавнер), иначе в конце канала босс переносится.

modifier_boss_rotation = modifier_boss_rotation or class({})
local mod = modifier_boss_rotation

local FX_START = "particles/items2_fx/teleport_start.vpcf"
local FX_END   = "particles/items2_fx/teleport_end.vpcf"
local FX_RING  = "particles/units/heroes/hero_snapfire/hero_snapfire_ultimate_calldown.vpcf"
local COLOR    = Vector(255, 60, 40)

function mod:IsHidden()      return false end
function mod:IsPurgable()    return false end
function mod:IsDebuff()      return false end
function mod:GetTexture()    return "item_tpscroll" end

function mod:CheckState()
	return {
		[MODIFIER_STATE_ROOTED]   = true,
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_SILENCED] = true,
	}
end

function mod:DeclareFunctions() return { MODIFIER_PROPERTY_OVERRIDE_ANIMATION } end
function mod:GetOverrideAnimation() return ACT_DOTA_TELEPORT end

function mod:OnCreated(kv)
	if not IsServer() then return end
	local p = self:GetParent()
	local origin = p:GetAbsOrigin()
	local dest = Vector(kv.x or 0, kv.y or 0, kv.z or 0)
	local dur = self:GetDuration()

	p:Stop()

	local s = ParticleManager:CreateParticle(FX_START, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(s, 0, origin)
	ParticleManager:SetParticleControl(s, 2, COLOR)
	self:AddParticle(s, false, false, -1, false, false)

	local e = ParticleManager:CreateParticle(FX_END, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(e, 0, dest)
	ParticleManager:SetParticleControl(e, 1, dest)
	ParticleManager:SetParticleControl(e, 2, COLOR)
	self:AddParticle(e, false, false, -1, false, false)

	local r = ParticleManager:CreateParticle(FX_RING, PATTACH_ABSORIGIN_FOLLOW, p)
	ParticleManager:SetParticleControl(r, 1, Vector(250, 0, -250))
	ParticleManager:SetParticleControl(r, 2, Vector(dur, 0, 0))
	self:AddParticle(r, false, false, -1, false, false)

	local mark = ParticleManager:CreateParticle("particles/msg_fx/msg_aggro.vpcf", PATTACH_OVERHEAD_FOLLOW, p)
	self:AddParticle(mark, false, false, -1, false, true)

	p:EmitSound("Portal.Loop_Disappear")
end

function mod:OnDestroy()
	if not IsServer() then return end
	local p = self:GetParent()
	p:StopSound("Portal.Loop_Disappear")
end
