-- Gun Joe: Explosive Bullets. Порт из Angel Arena Global.
-- Заряды на следующие атаки: каждая атака взрывается магическим уроном по площади.
-- Таланты: больше зарядов, больше радиус, меньше перезарядка.

gun_joe_explosive = class({})

LinkLuaModifier("modifier_gun_joe_explosive", "heroes/gun_joe/gun_joe_explosive", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_gun_joe_explosive_slow", "heroes/gun_joe/gun_joe_explosive", LUA_MODIFIER_MOTION_NONE)

function gun_joe_explosive:Precache(context)
	PrecacheResource("particle", "particles/econ/items/gyrocopter/hero_gyrocopter_gyrotechnics/gyro_guided_missile_explosion.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_techies.vsndevts", context)
end

function gun_joe_explosive:OnSpellStart()
	local caster = self:GetCaster()
	local mod = caster:AddNewModifier(caster, self, "modifier_gun_joe_explosive", { duration = self:GetSpecialValueFor("duration") })
	if mod then
		mod:SetStackCount(self:GetSpecialValueFor("stack_count"))
	end
end

--------------------------------------------------------------------------------

modifier_gun_joe_explosive = class({})

function modifier_gun_joe_explosive:IsHidden() return false end
function modifier_gun_joe_explosive:IsPurgable() return false end

function modifier_gun_joe_explosive:DeclareFunctions()
	return { MODIFIER_EVENT_ON_ATTACK_LANDED }
end

function modifier_gun_joe_explosive:OnAttackLanded(params)
	if not IsServer() then return end

	local parent = self:GetParent()
	local ability = self:GetAbility()
	local target = params.target
	if params.attacker ~= parent or not ability or not target or target:IsNull() then return end
	if target:GetTeamNumber() == parent:GetTeamNumber() then return end

	local pfx = ParticleManager:CreateParticle("particles/econ/items/gyrocopter/hero_gyrocopter_gyrotechnics/gyro_guided_missile_explosion.vpcf", PATTACH_ABSORIGIN_FOLLOW, target)
	ParticleManager:SetParticleControlEnt(pfx, 2, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)
	ParticleManager:ReleaseParticleIndex(pfx)
	target:EmitSound("Hero_Techies.Pick")

	local enemies = FindUnitsInRadius(parent:GetTeamNumber(), target:GetAbsOrigin(), nil, ability:GetSpecialValueFor("radius"),
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

	local damage = ability:GetSpecialValueFor("bonus_damage") + parent:GetAgility() * ability:GetSpecialValueFor("damage_pct") / 100
	-- шард: взрывы замедляют
	local slow = ability:GetSpecialValueFor("shard_slow")
	local slow_duration = ability:GetSpecialValueFor("shard_slow_duration")
	for _, enemy in pairs(enemies) do
		if not enemy:IsMagicImmune() then
			ApplyDamage({
				victim		= enemy,
				attacker	= parent,
				damage		= damage,
				damage_type	= DAMAGE_TYPE_MAGICAL,
				ability		= ability,
			})

			if slow > 0 then
				enemy:AddNewModifier(parent, ability, "modifier_gun_joe_explosive_slow", { duration = slow_duration })
			end
		end
	end

	self:DecrementStackCount()
	if self:GetStackCount() <= 0 then
		self:Destroy()
	end
end

--------------------------------------------------------------------------------
-- Шард: замедление от взрыва

modifier_gun_joe_explosive_slow = class({})

function modifier_gun_joe_explosive_slow:IsHidden() return false end
function modifier_gun_joe_explosive_slow:IsDebuff() return true end
function modifier_gun_joe_explosive_slow:IsPurgable() return true end

function modifier_gun_joe_explosive_slow:OnCreated()
	local ability = self:GetAbility()
	self.slow = ability and -ability:GetSpecialValueFor("shard_slow") or 0
end

modifier_gun_joe_explosive_slow.OnRefresh = modifier_gun_joe_explosive_slow.OnCreated

function modifier_gun_joe_explosive_slow:DeclareFunctions()
	return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end

function modifier_gun_joe_explosive_slow:GetModifierMoveSpeedBonus_Percentage()
	return self.slow
end
