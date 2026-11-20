require("lib/attack_potency")
-- Vile Phial (нейтральный, 5 разряд). Полностью на Lua, вместо движкового item_vile_phial.
--
-- Как в доте:
--   - пассивно: атаки владельца по врагу копят счётчик на цели; счётчик живёт counter_duration
--     и обновляется каждым ударом;
--   - на required_hits-м ударе цель отравлена на poison_duration секунд, счётчик сбрасывается;
--   - яд раз в секунду наносит магический урон и режет входящее лечение на heal_reduce %.
--
-- Урон яда (новый): damage_per_second плоских + poison_max_hp_pct % макс. HP цели в секунду.
-- Боссы (BossSpawner:IsBoss): процентная часть = 25% от обычной.

LinkLuaModifier("modifier_item_vile_phial_passive", "items/item_vile_phial", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_vile_phial_counter", "items/item_vile_phial", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_vile_phial_poison", "items/item_vile_phial", LUA_MODIFIER_MOTION_NONE)

item_vile_phial = class({})

local FX_POISON = "particles/units/heroes/hero_venomancer/venomancer_gale_poison_debuff.vpcf"

function item_vile_phial:Precache(context)
	PrecacheResource("particle", FX_POISON, context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_venomancer.vsndevts", context)
end

local BOSS_PCT_MULT = 0.25
local POISON_TICK = 1

function item_vile_phial:GetIntrinsicModifierName()
	return "modifier_item_vile_phial_passive"
end

---------------------------------------------------------------------------------------------------

modifier_item_vile_phial_passive = class({})

function modifier_item_vile_phial_passive:IsHidden() return true end
function modifier_item_vile_phial_passive:IsPurgable() return false end
function modifier_item_vile_phial_passive:RemoveOnDeath() return false end

function modifier_item_vile_phial_passive:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end

function modifier_item_vile_phial_passive:OnAttackLanded(kv)
	if not IsServer() then return end

	local parent = self:GetParent()
	local ability = self:GetAbility()
	if kv.attacker ~= parent or parent:IsIllusion() then return end
	if not ability or ability:IsNull() then return end

	local target = kv.target
	if not target or target:IsNull() or target:IsBuilding() or not target:IsAlive() then return end
	if target:GetTeamNumber() == parent:GetTeamNumber() then return end

	local required = ability:GetSpecialValueFor("required_hits")
	local counter = target:FindModifierByNameAndCaster("modifier_item_vile_phial_counter", parent)
	local hits = (counter and counter:GetStackCount() or 0) + 1

	if hits >= required then
		if counter then counter:Destroy() end
		target:AddNewModifier(parent, ability, "modifier_item_vile_phial_poison", AttackPotency:Kv(AttackPotency:Get(parent, kv), { duration = ability:GetSpecialValueFor("poison_duration") }))
		return
	end

	if not counter then
		counter = target:AddNewModifier(parent, ability, "modifier_item_vile_phial_counter", { duration = ability:GetSpecialValueFor("counter_duration") })
	end

	if counter then
		counter:SetStackCount(hits)
		counter:ForceRefresh()
	end
end

---------------------------------------------------------------------------------------------------

-- счётчик ударов на цели (видим владельцу, для тултипа и стаков)
modifier_item_vile_phial_counter = class({})

function modifier_item_vile_phial_counter:IsHidden() return false end
function modifier_item_vile_phial_counter:IsDebuff() return true end
function modifier_item_vile_phial_counter:IsPurgable() return false end
function modifier_item_vile_phial_counter:GetTexture() return "item_vile_phial" end

---------------------------------------------------------------------------------------------------

modifier_item_vile_phial_poison = class({})

function modifier_item_vile_phial_poison:IsHidden() return false end
function modifier_item_vile_phial_poison:IsDebuff() return true end
function modifier_item_vile_phial_poison:IsPurgable()
	local p = self:GetParent()
	return not (p.IsBoss and p:IsBoss())
end
function modifier_item_vile_phial_poison:GetTexture() return "item_vile_phial" end
function modifier_item_vile_phial_poison:GetEffectName() return FX_POISON end
function modifier_item_vile_phial_poison:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

AttackPotency:Transmitter(modifier_item_vile_phial_poison)

function modifier_item_vile_phial_poison:OnRefresh(kv)
	AttackPotency:Attach(self, kv)
end

function modifier_item_vile_phial_poison:OnCreated(kv)
	AttackPotency:Attach(self, kv)
	local ability = self:GetAbility()
	if ability and not ability:IsNull() then
		self.heal_reduce = ability:GetSpecialValueFor("heal_reduce")
	end
	if not IsServer() then return end

	self.dps = ability:GetSpecialValueFor("damage_per_second")
	self.pct = ability:GetSpecialValueFor("poison_max_hp_pct")
	self.heal_reduce = ability:GetSpecialValueFor("heal_reduce")

	self:GetParent():EmitSound("Hero_Venomancer.VenomousGaleImpact")
	self:OnIntervalThink()
	self:StartIntervalThink(POISON_TICK)
end

function modifier_item_vile_phial_poison:OnIntervalThink()
	if not IsServer() then return end

	local ability = self:GetAbility()
	local parent = self:GetParent()
	if not ability or ability:IsNull() or not parent or parent:IsNull() or not parent:IsAlive() then return end

	local mult = (BossSpawner and BossSpawner:IsBoss(parent)) and BOSS_PCT_MULT or 1
	local damage = (self.dps + parent:GetMaxHealth() * self.pct / 100 * mult) * POISON_TICK

	ApplyDamage({
		victim = parent,
		attacker = self:GetCaster(),
		damage = damage,
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = ability,
	})
end

function modifier_item_vile_phial_poison:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_HEAL_AMPLIFY_PERCENTAGE_TARGET,
	}
end

function modifier_item_vile_phial_poison:GetModifierHealAmplify_PercentageTarget()
	-- heal_reduce с действенностью атаки (apply_effectiveness)
	return -(self.heal_reduce or 0) * self:Potency()
end
