-- Rattlecage (нейтральный, 4 разряд). Полностью на Lua, вместо движкового item_rattlecage.
--
-- Как в доте (Reverberate):
--   - пассивно: владелец получил damage_threshold урона от любого источника за окно
--     damage_reset_interval - выпускает снаряды в target_count случайных врагов в радиусе radius
--     (сначала герои);
--   - снаряд замедляет цель на slow (движение и атака) на slow_duration секунд.
--
-- Урон снаряда (новый): projectile_attack_pct % от урона атаки владельца
--   + projectile_max_hp_pct % макс. HP цели.
-- Боссы (BossSpawner:IsBoss): процентная часть = 25% от обычной.

LinkLuaModifier("modifier_item_rattlecage_passive", "items/item_rattlecage", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_rattlecage_slow", "items/item_rattlecage", LUA_MODIFIER_MOTION_NONE)

item_rattlecage = class({})

local BOSS_PCT_MULT = 0.25
local PROJECTILE_EFFECT = "particles/items2_fx/rattlecage_projectile.vpcf"

function item_rattlecage:Precache(context)
	PrecacheResource("particle", PROJECTILE_EFFECT, context)
end

function item_rattlecage:GetIntrinsicModifierName()
	return "modifier_item_rattlecage_passive"
end

-- снаряд: урон считается в момент попадания, от текущего урона атаки владельца
function item_rattlecage:OnProjectileHit(target, location)
	if not target or target:IsNull() or not target:IsAlive() then return end
	if target:TriggerSpellAbsorb(self) then return end

	local caster = self:GetCaster()
	if not caster or caster:IsNull() then return end

	local attack_pct = self:GetSpecialValueFor("projectile_attack_pct")
	local hp_pct = self:GetSpecialValueFor("projectile_max_hp_pct")
	local mult = (BossSpawner and BossSpawner:IsBoss(target)) and BOSS_PCT_MULT or 1

	local attack_damage = caster:GetAverageTrueAttackDamage(target)
	local damage = attack_damage * attack_pct / 100 + target:GetMaxHealth() * hp_pct / 100 * mult

	ApplyDamage({
		victim = target,
		attacker = caster,
		damage = damage,
		damage_type = DAMAGE_TYPE_PHYSICAL,
		ability = self,
	})

	target:AddNewModifier(caster, self, "modifier_item_rattlecage_slow", { duration = self:GetSpecialValueFor("slow_duration") })
end

---------------------------------------------------------------------------------------------------

modifier_item_rattlecage_passive = class({})

function modifier_item_rattlecage_passive:IsHidden() return true end
function modifier_item_rattlecage_passive:IsPurgable() return false end
function modifier_item_rattlecage_passive:RemoveOnDeath() return false end

function modifier_item_rattlecage_passive:OnCreated()
	self.accumulated = 0
	self.last_hit_time = 0
end

function modifier_item_rattlecage_passive:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
	}
end

function modifier_item_rattlecage_passive:GetModifierPhysicalArmorBonus()
	return self:GetAbility() and self:GetAbility():GetSpecialValueFor("bonus_armor") or 0
end

function modifier_item_rattlecage_passive:OnTakeDamage(kv)
	if not IsServer() then return end

	local parent = self:GetParent()
	if kv.unit ~= parent or not kv.damage or kv.damage <= 0 then return end

	local ability = self:GetAbility()
	if not ability or ability:IsNull() then return end

	local now = GameRules:GetGameTime()
	if now - self.last_hit_time > ability:GetSpecialValueFor("damage_reset_interval") then
		self.accumulated = 0
	end
	self.last_hit_time = now
	self.accumulated = self.accumulated + kv.damage

	if self.accumulated < ability:GetSpecialValueFor("damage_threshold") then return end
	self.accumulated = 0

	self:Reverberate()
end

function modifier_item_rattlecage_passive:Reverberate()
	local parent = self:GetParent()
	local ability = self:GetAbility()
	local radius = ability:GetSpecialValueFor("radius")
	local count = ability:GetSpecialValueFor("target_count")
	local speed = ability:GetSpecialValueFor("projectile_speed")

	local enemies = FindUnitsInRadius(
		parent:GetTeamNumber(),
		parent:GetAbsOrigin(),
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		bit.bor(DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_BASIC),
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	local heroes, others = {}, {}
	for _, enemy in pairs(enemies) do
		if enemy and not enemy:IsNull() and enemy:IsAlive() then
			if enemy:IsRealHero() then
				table.insert(heroes, enemy)
			else
				table.insert(others, enemy)
			end
		end
	end

	-- случайный порядок внутри групп: героев бьём первыми
	local function shuffle(t)
		for i = #t, 2, -1 do
			local j = RandomInt(1, i)
			t[i], t[j] = t[j], t[i]
		end
	end
	shuffle(heroes)
	shuffle(others)

	local targets = {}
	for _, unit in ipairs(heroes) do
		if #targets >= count then break end
		table.insert(targets, unit)
	end
	for _, unit in ipairs(others) do
		if #targets >= count then break end
		table.insert(targets, unit)
	end

	for _, target in ipairs(targets) do
		ProjectileManager:CreateTrackingProjectile({
			EffectName = PROJECTILE_EFFECT,
			Ability = ability,
			Source = parent,
			Target = target,
			iMoveSpeed = speed,
			bDodgeable = false,
			bProvidesVision = false,
			iVisionTeamNumber = parent:GetTeamNumber(),
		})
	end

	parent:EmitSound("DOTA_Item.Rattlecage.Activate")
end

---------------------------------------------------------------------------------------------------

modifier_item_rattlecage_slow = class({})

function modifier_item_rattlecage_slow:IsHidden() return false end
function modifier_item_rattlecage_slow:IsDebuff() return true end
function modifier_item_rattlecage_slow:IsPurgable() return true end
function modifier_item_rattlecage_slow:GetTexture() return "item_rattlecage" end
function modifier_item_rattlecage_slow:GetEffectName() return "particles/items2_fx/sange_maim.vpcf" end
function modifier_item_rattlecage_slow:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_item_rattlecage_slow:OnCreated()
	self.slow = self:GetAbility() and self:GetAbility():GetSpecialValueFor("slow") or 0
end

function modifier_item_rattlecage_slow:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
	}
end

function modifier_item_rattlecage_slow:GetModifierMoveSpeedBonus_Constant()
	return 0 - (self.slow or 0)
end

function modifier_item_rattlecage_slow:GetModifierAttackSpeedBonus_Constant()
	return 0 - (self.slow or 0)
end
