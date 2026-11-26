-- Gun Joe: Frag Grenade. Граната по дуге в точку: урон по площади (база + % ловкости) и замедление.

gun_joe_frag_grenade = class({})

local GRENADE_PFX = "particles/units/heroes/hero_sniper/sniper_shard_concussive_grenade_model.vpcf"

LinkLuaModifier("modifier_gun_joe_frag_grenade_slow", "heroes/gun_joe/gun_joe_frag_grenade", LUA_MODIFIER_MOTION_NONE)

function gun_joe_frag_grenade:Precache(context)
	PrecacheResource("particle", "particles/econ/items/gyrocopter/hero_gyrocopter_gyrotechnics/gyro_guided_missile_explosion.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_sniper/sniper_shard_concussive_grenade_model.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_sniper.vsndevts", context)
end

function gun_joe_frag_grenade:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function gun_joe_frag_grenade:OnSpellStart()
	local caster = self:GetCaster()
	local point = self:GetCursorPosition()

	caster:EmitSound("Hero_Sniper.ConcussiveGrenade.Cast")

	-- Ванильный партикл гранаты снайпера дугу строит к CP5 (точке падения). Снаряд
	-- ProjectileManager его не задаёт - CP5 оставался в (0,0,0) и модель улетала в
	-- центр карты. Поэтому полёт ведём сами: CP0 - текущая точка, CP1/CP5 - цель.
	local start = caster:GetAttachmentOrigin(caster:ScriptLookupAttachment("attach_attack1"))
	if not start or start == Vector(0, 0, 0) then start = caster:GetAbsOrigin() end

	point = GetGroundPosition(point, nil)

	local speed = math.max(100, self:GetSpecialValueFor("speed"))
	local flight = math.max(0.1, (point - start):Length2D() / speed)
	local pfx = ParticleManager:CreateParticle(GRENADE_PFX, PATTACH_CUSTOMORIGIN, nil)

	ParticleManager:SetParticleControl(pfx, 0, start)
	ParticleManager:SetParticleControl(pfx, 1, point)
	ParticleManager:SetParticleControl(pfx, 5, point)

	local t0 = GameRules:GetGameTime()

	Timers:CreateTimer(FrameTime(), function()
		local k = (GameRules:GetGameTime() - t0) / flight

		if k >= 1 or self:IsNull() then
			ParticleManager:DestroyParticle(pfx, false)
			ParticleManager:ReleaseParticleIndex(pfx)
			if not self:IsNull() then self:Explode(point) end
			return nil
		end

		ParticleManager:SetParticleControl(pfx, 0, start + (point - start) * k)

		return FrameTime()
	end)
end

function gun_joe_frag_grenade:Explode(point)
	local caster = self:GetCaster()
	local radius = self:GetSpecialValueFor("radius")
	local damage = self:GetSpecialValueFor("damage") + caster:GetAgility() * self:GetSpecialValueFor("damage_pct") / 100

	local pfx = ParticleManager:CreateParticle("particles/econ/items/gyrocopter/hero_gyrocopter_gyrotechnics/gyro_guided_missile_explosion.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(pfx, 0, point)
	ParticleManager:SetParticleControl(pfx, 1, Vector(radius, radius, radius))
	ParticleManager:ReleaseParticleIndex(pfx)
	EmitSoundOnLocationWithCaster(point, "Hero_Sniper.ConcussiveGrenade.Impact", caster)

	local enemies = FindUnitsInRadius(caster:GetTeamNumber(), point, nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

	for _, enemy in pairs(enemies) do
		ApplyDamage({ victim = enemy, attacker = caster, damage = damage, damage_type = self:GetAbilityDamageType(), ability = self })
		enemy:AddNewModifier(caster, self, "modifier_gun_joe_frag_grenade_slow", { duration = self:GetSpecialValueFor("slow_duration") })
	end

	GridNav:DestroyTreesAroundPoint(point, radius, false)
end

--------------------------------------------------------------------------------

modifier_gun_joe_frag_grenade_slow = class({})

function modifier_gun_joe_frag_grenade_slow:IsHidden() return false end
function modifier_gun_joe_frag_grenade_slow:IsDebuff() return true end
function modifier_gun_joe_frag_grenade_slow:IsPurgable() return true end

function modifier_gun_joe_frag_grenade_slow:OnCreated()
	local ability = self:GetAbility()
	self.slow = ability and -ability:GetSpecialValueFor("slow") or 0
end

modifier_gun_joe_frag_grenade_slow.OnRefresh = modifier_gun_joe_frag_grenade_slow.OnCreated

function modifier_gun_joe_frag_grenade_slow:DeclareFunctions()
	return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end

function modifier_gun_joe_frag_grenade_slow:GetModifierMoveSpeedBonus_Percentage()
	return self.slow
end
