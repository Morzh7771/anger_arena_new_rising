-- Состояние пета-косметики (юнит npc_dota_aa_cosmetic_pet, см. lib/cosmetics/core.lua).
--
-- Сделано один в один как modifier_donate_pet в 1x6:
--  * юнит - npc_dota_creature с настоящей моделью курьера в KV, поэтому стойку и бег
--    проигрывает движок сам. Никаких StartGesture/FadeGesture: прежний перезапуск жеста
--    каждые 0.2 с и давал "застывшую едущую" модель;
--  * движение только через MoveToPosition раз в 0.4 с;
--  * дальше 900 от героя - телепорт рядом (с эффектом), дальше 150 - идёт в точку сбоку
--    от героя, ближе 90 - отходит;
--  * скорость = скорость владельца;
--  * владелец невидим - пет тоже (modifier_invisible), владелец мёртв - пет прячется.
-- Летающий пет (params.flying == 1): MODIFIER_STATE_FLYING.

modifier_aa_cosmetic_pet = class({})

local THINK_INTERVAL = 0.4
local TELEPORT_DIST = 900
local FAR_DIST = 150
local NEAR_DIST = 90

function modifier_aa_cosmetic_pet:IsHidden() return true end
function modifier_aa_cosmetic_pet:IsDebuff() return false end
function modifier_aa_cosmetic_pet:IsPurgable() return false end
function modifier_aa_cosmetic_pet:IsPermanent() return true end
function modifier_aa_cosmetic_pet:RemoveOnDeath() return false end

function modifier_aa_cosmetic_pet:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE,
	}
end

function modifier_aa_cosmetic_pet:GetModifierMoveSpeed_Absolute()
	local owner = self:GetCaster()

	if not owner or owner:IsNull() then return 350 end

	local ms = owner:GetMoveSpeedModifier(owner:GetBaseMoveSpeed(), true)

	if ms < 100 then ms = 350 end

	return ms
end

-- как у 1x6, но без IGNORING_MOVE_AND_ATTACK_ORDERS/COMMAND_RESTRICTED: наши MoveToPosition
-- идут приказом, а с COMMAND_RESTRICTED пет вообще не ходил
function modifier_aa_cosmetic_pet:CheckState()
	local state = {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_UNSELECTABLE] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_NOT_ON_MINIMAP] = true,
		[MODIFIER_STATE_OUT_OF_GAME] = true,
		[MODIFIER_STATE_UNTARGETABLE] = true,
		[MODIFIER_STATE_DISARMED] = true,
	}

	if self.flying then
		state[MODIFIER_STATE_FLYING] = true
	end

	return state
end

function modifier_aa_cosmetic_pet:OnCreated(params)
	self.flying = params ~= nil and tonumber(params.flying) == 1

	if not IsServer() then return end

	self.owner_alive = true
	self:StartIntervalThink(THINK_INTERVAL)
end

function modifier_aa_cosmetic_pet:BlinkFx(pos, follow)
	local pet = self:GetParent()
	local name = follow and "particles/units/heroes/hero_lone_druid/lone_druid_bear_blink_end.vpcf"
		or "particles/units/heroes/hero_lone_druid/lone_druid_bear_blink_start.vpcf"
	local p = ParticleManager:CreateParticle(name, follow and PATTACH_ABSORIGIN_FOLLOW or PATTACH_WORLDORIGIN, follow and pet or nil)

	ParticleManager:SetParticleControl(p, 0, pos)
	ParticleManager:ReleaseParticleIndex(p)
end

function modifier_aa_cosmetic_pet:OnIntervalThink()
	local pet = self:GetParent()
	local owner = self:GetCaster()

	if not pet or pet:IsNull() then return end

	if not owner or owner:IsNull() or not (owner:IsAlive() or owner:IsReincarnating()) then
		if self.owner_alive then
			self.owner_alive = false
			self:BlinkFx(pet:GetAbsOrigin(), false)
		end

		pet:AddNoDraw()

		return
	end

	pet:RemoveNoDraw()

	local owner_pos = owner:GetAbsOrigin()
	local pet_pos = pet:GetAbsOrigin()
	local dist = (owner_pos - pet_pos):Length2D()
	local owner_dir = owner:GetForwardVector()
	local dir = owner_dir * RandomInt(110, 140)

	-- после смерти владельца пет появляется рядом с ним заново
	if not self.owner_alive then
		self.owner_alive = true
		dist = TELEPORT_DIST + 1
	end

	if dist > TELEPORT_DIST then
		local a = RandomInt(60, 120)

		if RandomInt(1, 2) == 1 then a = -a end

		local r = RotatePosition(Vector(0, 0, 0), QAngle(0, a, 0), dir)

		self:BlinkFx(pet_pos, false)
		pet:SetAbsOrigin(owner_pos + r)
		pet:SetForwardVector(owner_dir)
		FindClearSpaceForUnit(pet, owner_pos + r, true)
		self:BlinkFx(pet:GetAbsOrigin(), true)
	elseif dist > FAR_DIST then
		local right = RotatePosition(Vector(0, 0, 0), QAngle(0, -RandomInt(70, 110), 0), dir) + owner_pos
		local left = RotatePosition(Vector(0, 0, 0), QAngle(0, RandomInt(70, 110), 0), dir) + owner_pos

		if (pet_pos - right):Length2D() > (pet_pos - left):Length2D() then
			pet:MoveToPosition(left)
		else
			pet:MoveToPosition(right)
		end
	elseif dist < NEAR_DIST then
		pet:MoveToPosition(owner_pos + (pet_pos - owner_pos):Normalized() * RandomInt(110, 140))
	end

	if owner:IsInvisible() then
		if not pet:HasModifier("modifier_invisible") then
			pet:AddNewModifier(pet, nil, "modifier_invisible", {})
		end
	elseif pet:HasModifier("modifier_invisible") then
		pet:RemoveModifierByName("modifier_invisible")
	end
end
