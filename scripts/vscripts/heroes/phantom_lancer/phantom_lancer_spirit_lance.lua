-- Phantom Lancer: Spirit Lance на Lua (2026-11-22). Ванильному копью нельзя было
-- добавить отскоки по крипам.
-- Как в доте: копьё наносит lance_damage магического урона, замедляет на duration и
-- создаёт рядом с целью иллюзию на illusion_duration (урон -80%, получает 300%).
-- Талант illusion_lance_damage_pct: иллюзии в fake_lance_distance тоже бросают копья.
-- Против крипов: от крипа отскакивает ещё в creep_bounce_count крипов в creep_bounce_radius.
-- Урон от атрибута (damage_pct) добавляет общий фильтр урона по имени способности.

phantom_lancer_spirit_lance = class({})

LinkLuaModifier("modifier_phantom_lancer_spirit_lance_aa", "heroes/phantom_lancer/phantom_lancer_spirit_lance", LUA_MODIFIER_MOTION_NONE)

local PROJECTILE = "particles/units/heroes/hero_phantom_lancer/phantomlancer_spiritlance_projectile.vpcf"

function phantom_lancer_spirit_lance:Precache(context)
	PrecacheResource("particle", PROJECTILE, context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_phantom_lancer.vsndevts", context)
end

function phantom_lancer_spirit_lance:Throw(source, target, data)
	ProjectileManager:CreateTrackingProjectile({
		Target = target,
		Source = source,
		Ability = self,
		EffectName = PROJECTILE,
		iMoveSpeed = self:GetSpecialValueFor("lance_speed"),
		bDodgeable = true,
		bProvidesVision = false,
		iSourceAttachment = DOTA_PROJECTILE_ATTACHMENT_ATTACK_1,
		ExtraData = data,
	})
end

function phantom_lancer_spirit_lance:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	self.cast_id = (self.cast_id or 0) + 1
	self.chains = self.chains or {}
	self.chains[self.cast_id] = {
		hit = {},
		creep_left = self:GetSpecialValueFor("creep_bounce_count"),
	}
	self:Throw(caster, target, { id = self.cast_id, first = 1 })
	caster:EmitSound("Hero_PhantomLancer.SpiritLance.Throw")

	-- талант: иллюзии рядом тоже бросают копья
	local pct = self:GetSpecialValueFor("illusion_lance_damage_pct")
	if pct > 0 then
		local allies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, self:GetSpecialValueFor("fake_lance_distance"),
			DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
		for _, u in ipairs(allies) do
			if u:IsIllusion() and u:GetPlayerOwnerID() == caster:GetPlayerOwnerID() then
				u:StartGesture(ACT_DOTA_CAST_ABILITY_1)
				self:Throw(u, target, { fake = 1 })
			end
		end
	end
end

local function IsFarmCreep(u)
	return u:GetTeamNumber() == DOTA_TEAM_NEUTRALS and not u:IsHero() and not u.IsAngelArenaBoss
end

function phantom_lancer_spirit_lance:OnProjectileHit_ExtraData(target, location, data)
	if not target or not target:IsAlive() then return true end
	local caster = self:GetCaster()
	local fake = data.fake == 1

	if data.first == 1 and target:TriggerSpellAbsorb(self) then return true end

	local damage = self:GetSpecialValueFor("lance_damage")
	if fake then damage = damage * self:GetSpecialValueFor("illusion_lance_damage_pct") / 100 end
	ApplyDamage({ victim = target, attacker = caster, damage = damage, damage_type = self:GetAbilityDamageType(), ability = self })
	target:AddNewModifier(caster, self, "modifier_phantom_lancer_spirit_lance_aa", { duration = self:GetSpecialValueFor("duration") * (1 - target:GetStatusResistance()) })
	target:EmitSound("Hero_PhantomLancer.SpiritLance.Impact")
	if fake then return true end

	-- иллюзия у цели
	local out = self:GetSpecialValueFor("illusion_damage_out_pct")
	local illusions = CreateIllusions(caster, caster, {
		outgoing_damage = out,
		incoming_damage = self:GetSpecialValueFor("illusion_damage_in_pct"),
		duration = self:GetSpecialValueFor("illusion_duration"),
	}, 1, 72, false, true)
	for _, ill in pairs(illusions or {}) do
		FindClearSpaceForUnit(ill, target:GetAbsOrigin() + RandomVector(72), true)
		ill:MoveToTargetToAttack(target)
	end

	-- отскоки по крипам
	local chain = self.chains and self.chains[data.id]
	if not chain then return true end
	chain.hit[target:entindex()] = true

	if not IsFarmCreep(target) or chain.creep_left <= 0 then self.chains[data.id] = nil return true end
	chain.creep_left = chain.creep_left - 1
	local radius = self:GetSpecialValueFor("creep_bounce_radius")

	local units = FindUnitsInRadius(caster:GetTeamNumber(), target:GetAbsOrigin(), nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS, FIND_CLOSEST, false)
	for _, u in ipairs(units) do
		if not chain.hit[u:entindex()] and IsFarmCreep(u) then
			self:Throw(target, u, { id = data.id })
			return true
		end
	end
	self.chains[data.id] = nil
	return true
end

--------------------------------------------------------------------------------

modifier_phantom_lancer_spirit_lance_aa = class({})

function modifier_phantom_lancer_spirit_lance_aa:IsDebuff() return true end
function modifier_phantom_lancer_spirit_lance_aa:IsPurgable() return true end
function modifier_phantom_lancer_spirit_lance_aa:GetTexture() return "phantom_lancer_spirit_lance" end
function modifier_phantom_lancer_spirit_lance_aa:GetEffectName() return "particles/units/heroes/hero_phantom_lancer/phantomlancer_spiritlance_target.vpcf" end
function modifier_phantom_lancer_spirit_lance_aa:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_phantom_lancer_spirit_lance_aa:DeclareFunctions()
	return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end

function modifier_phantom_lancer_spirit_lance_aa:GetModifierMoveSpeedBonus_Percentage()
	local ab = self:GetAbility()
	return ab and ab:GetSpecialValueFor("movement_speed_pct") or 0
end
