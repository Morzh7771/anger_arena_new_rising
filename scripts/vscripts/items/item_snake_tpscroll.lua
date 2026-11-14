--[[
	Свиток Snake Boots (выдаёт lib/tpscroll_free.lua вместо обычного свитка).
	Цель - союзный юнит или строение, по которому кликнули; телепорт ровно на
	него (на свободное место рядом). Порталы и аванпосты - нельзя.
	Откат берётся у Snake Boots (tp_cooldown).
]]

item_snake_tpscroll = class({})

-- на них телепорт запрещён
local FORBIDDEN = {
	npc_teleport = "#aa_tp_no_portal",
	npc_dota_watch_tower = "#aa_tp_no_outpost",
}

local function IsPhantom(unit)
	if unit:GetClassname() == "npc_dota_thinker" then return true end
	if unit:HasModifier("modifier_hidden_from_map") then return true end

	return false
end

function item_snake_tpscroll:Precache(context)
	PrecacheResource("particle", "particles/items2_fx/teleport_start.vpcf", context)
	PrecacheResource("particle", "particles/items2_fx/teleport_end.vpcf", context)
end

function item_snake_tpscroll:CastFilterResultTarget(target)
	local caster = self:GetCaster()

	if target == caster then
		return UF_FAIL_CUSTOM
	end

	if FORBIDDEN[target:GetUnitName()] then
		return UF_FAIL_CUSTOM
	end

	if IsServer() and IsPhantom(target) then
		return UF_FAIL_CUSTOM
	end

	return UnitFilter(target, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_ALL,
		DOTA_UNIT_TARGET_FLAG_INVULNERABLE, caster:GetTeamNumber())
end

function item_snake_tpscroll:GetCustomCastErrorTarget(target)
	if target == self:GetCaster() then return "#dota_hud_error_cant_cast_on_self" end

	return FORBIDDEN[target:GetUnitName()] or "#aa_tp_no_target"
end

function item_snake_tpscroll:GetCooldown(level)
	local caster = self:GetCaster()

	if caster and caster.GetItemInSlot then
		for slot = 0, 5 do
			local item = caster:GetItemInSlot(slot)

			if item and item:GetAbilityName() == "item_snake_boots" then
				return item:GetSpecialValueFor("tp_cooldown")
			end
		end
	end

	return self.BaseClass.GetCooldown(self, level)
end

function item_snake_tpscroll:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	self.target = target

	-- выбранный игроком телепорт косметики (lib/cosmetics/effects.lua); без выбора - ванильные пути
	local start_path, end_path = "particles/items2_fx/teleport_start.vpcf", "particles/items2_fx/teleport_end.vpcf"

	if CosmeticsEffects and CosmeticsEffects.TpPaths then
		local s, e = CosmeticsEffects.TpPaths(caster)

		start_path = s or start_path
		end_path = e or end_path
	end

	self.fx_start = ParticleManager:CreateParticle(start_path, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(self.fx_start, 0, caster:GetAbsOrigin())
	ParticleManager:SetParticleControl(self.fx_start, 2, Vector(255, 255, 255))

	self.fx_end = ParticleManager:CreateParticle(end_path, PATTACH_ABSORIGIN_FOLLOW, target)
	ParticleManager:SetParticleControl(self.fx_end, 0, target:GetAbsOrigin())
	ParticleManager:SetParticleControl(self.fx_end, 1, target:GetAbsOrigin())
	ParticleManager:SetParticleControl(self.fx_end, 2, Vector(255, 255, 255))

	caster:EmitSound("Portal.Loop_Disappear")
	target:EmitSound("Portal.Loop_Appear")
	caster:StartGesture(ACT_DOTA_TELEPORT)
end

function item_snake_tpscroll:OnChannelFinish(interrupted)
	local caster = self:GetCaster()
	local target = self.target

	self.target = nil

	for _, fx in ipairs({ self.fx_start, self.fx_end }) do
		if fx then
			ParticleManager:DestroyParticle(fx, false)
			ParticleManager:ReleaseParticleIndex(fx)
		end
	end

	self.fx_start = nil
	self.fx_end = nil

	caster:StopSound("Portal.Loop_Disappear")
	caster:FadeGesture(ACT_DOTA_TELEPORT)

	if target and not target:IsNull() then
		target:StopSound("Portal.Loop_Appear")
	end

	if interrupted then return end
	if not target or target:IsNull() or not target:IsAlive() then return end

	EmitSoundOnLocationWithCaster(caster:GetAbsOrigin(), "Portal.Hero_Disappear", caster)

	ProjectileManager:ProjectileDodge(caster)
	FindClearSpaceForUnit(caster, target:GetAbsOrigin(), true)
	caster:Stop()

	caster:EmitSound("Portal.Hero_Appear")
end
