-- Terrorblade: Reflection на Lua (2026-11-22).
-- Как в доте: враги-герои в range от точки получают своё отражение на
-- illusion_duration (урон illusion_outgoing_damage%), неуязвимое, бьёт только
-- свой оригинал; оригинал замедлен на move_slow / attack_slow.
-- Против крипов (как у Ксена): вместо отражения крипа (у иллюзий крипов нет
-- анимации атаки) на каждого из creep_max_illusions ближайших крипов выходит
-- отражение самого Террорблейда с тем же уроном.

terrorblade_reflection = class({})

LinkLuaModifier("modifier_terrorblade_reflection_aa_unit", "heroes/terrorblade/terrorblade_reflection", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_terrorblade_reflection_aa_slow", "heroes/terrorblade/terrorblade_reflection", LUA_MODIFIER_MOTION_NONE)

function terrorblade_reflection:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_terrorblade/terrorblade_reflection_cast.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_terrorblade/terrorblade_reflection_slow.vpcf", context)
	PrecacheResource("particle", "particles/status_fx/status_effect_terrorblade_reflection.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_terrorblade.vsndevts", context)
end

function terrorblade_reflection:GetAOERadius()
	return self:GetSpecialValueFor("range")
end

local function IsFarmCreep(u)
	return u:GetTeamNumber() == DOTA_TEAM_NEUTRALS and not u:IsHero() and not u.IsAngelArenaBoss
end

function terrorblade_reflection:OnSpellStart()
	local caster = self:GetCaster()
	local point = self:GetCursorPosition()

	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_terrorblade/terrorblade_reflection_cast.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, point)
	ParticleManager:SetParticleControl(fx, 1, Vector(self:GetSpecialValueFor("range"), 0, 0))
	ParticleManager:ReleaseParticleIndex(fx)
	EmitSoundOnLocationWithCaster(point, "Hero_Terrorblade.Reflection", caster)

	local units = FindUnitsInRadius(caster:GetTeamNumber(), point, nil, self:GetSpecialValueFor("range"),
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS + DOTA_UNIT_TARGET_FLAG_NO_INVIS, FIND_CLOSEST, false)

	local creeps_left = self:GetSpecialValueFor("creep_max_illusions")
	for _, enemy in ipairs(units) do
		if enemy:IsRealHero() then
			self:Reflect(enemy, enemy)
		elseif IsFarmCreep(enemy) and creeps_left > 0 then
			creeps_left = creeps_left - 1
			self:Reflect(enemy, caster)
		end
	end
end

-- отражение copy_unit, которое бьёт enemy
function terrorblade_reflection:Reflect(enemy, copy_unit)
	local caster = self:GetCaster()
	local duration = self:GetSpecialValueFor("illusion_duration") * (1 - enemy:GetStatusResistance())

	enemy:AddNewModifier(caster, self, "modifier_terrorblade_reflection_aa_slow", { duration = duration })

	local illusions = CreateIllusions(caster, copy_unit, {
		outgoing_damage = self:GetSpecialValueFor("illusion_outgoing_damage"),
		incoming_damage = 0,
		bounty_base = 0,
		duration = duration,
	}, 1, 108, false, true)

	for _, ill in pairs(illusions or {}) do
		FindClearSpaceForUnit(ill, enemy:GetAbsOrigin() + RandomVector(108), true)
		ill:AddNewModifier(caster, self, "modifier_terrorblade_reflection_aa_unit", { duration = duration, target = enemy:entindex() })
	end
end

--------------------------------------------------------------------------------
-- Отражение: неуязвимо, бьёт только свою цель

modifier_terrorblade_reflection_aa_unit = class({})

function modifier_terrorblade_reflection_aa_unit:IsHidden() return true end
function modifier_terrorblade_reflection_aa_unit:IsPurgable() return false end
function modifier_terrorblade_reflection_aa_unit:GetStatusEffectName() return "particles/status_fx/status_effect_terrorblade_reflection.vpcf" end
function modifier_terrorblade_reflection_aa_unit:StatusEffectPriority() return 20 end

function modifier_terrorblade_reflection_aa_unit:CheckState()
	return {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_UNSELECTABLE] = true,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_COMMAND_RESTRICTED] = true,
	}
end

function modifier_terrorblade_reflection_aa_unit:OnCreated(kv)
	if not IsServer() then return end
	self.target = EntIndexToHScript(kv.target)
	self:StartIntervalThink(0.2)
	self:OnIntervalThink()
end

function modifier_terrorblade_reflection_aa_unit:OnIntervalThink()
	local parent = self:GetParent()
	if not self.target or self.target:IsNull() or not self.target:IsAlive() then
		parent:ForceKill(false)
		return
	end
	parent:SetForceAttackTarget(self.target)
	if not parent:IsAttacking() then parent:MoveToTargetToAttack(self.target) end
end

function modifier_terrorblade_reflection_aa_unit:OnDestroy()
	if not IsServer() then return end
	local parent = self:GetParent()
	if parent and not parent:IsNull() and parent:IsAlive() then
		parent:SetForceAttackTarget(nil)
		parent:ForceKill(false)
	end
end

--------------------------------------------------------------------------------
-- Замедление оригинала

modifier_terrorblade_reflection_aa_slow = class({})

function modifier_terrorblade_reflection_aa_slow:IsDebuff() return true end
function modifier_terrorblade_reflection_aa_slow:IsPurgable() return true end
function modifier_terrorblade_reflection_aa_slow:GetTexture() return "terrorblade_reflection" end
function modifier_terrorblade_reflection_aa_slow:GetEffectName() return "particles/units/heroes/hero_terrorblade/terrorblade_reflection_slow.vpcf" end
function modifier_terrorblade_reflection_aa_slow:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_terrorblade_reflection_aa_slow:DeclareFunctions()
	return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE, MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT }
end

function modifier_terrorblade_reflection_aa_slow:GetModifierMoveSpeedBonus_Percentage()
	local ab = self:GetAbility()
	return ab and -ab:GetSpecialValueFor("move_slow") or 0
end

function modifier_terrorblade_reflection_aa_slow:GetModifierAttackSpeedBonus_Constant()
	local ab = self:GetAbility()
	return ab and -ab:GetSpecialValueFor("attack_slow") or 0
end
