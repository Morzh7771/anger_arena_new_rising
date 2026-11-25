-- Ликан (npc_aa_lycan_boss). Как в доте: волки, вой, превращение.
-- Подход: до 50% HP вложить урон - превращение снимает минус броню.

require("creeps/boss/boss_kit")

LinkLuaModifier("modifier_lycan_boss_wolf",       "creeps/boss/lycan/lycan_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_lycan_boss_howl",       "creeps/boss/lycan/lycan_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_lycan_boss_shape_watch","creeps/boss/lycan/lycan_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_lycan_boss_shapeshift", "creeps/boss/lycan/lycan_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_lycan_boss_bleed",      "creeps/boss/lycan/lycan_abilities", LUA_MODIFIER_MOTION_NONE)

local WOLF_UNIT = "npc_aa_lycan_boss_wolf"

local function LiveWolves(boss)
	local n = 0
	for _, w in pairs(boss.aa_wolves or {}) do
		if w and not w:IsNull() and w:IsAlive() then n = n + 1 end
	end
	return n
end

--------------------------------------------------------------------------------
-- Волки: двое рядом. HP и урон - доля от босса.
--------------------------------------------------------------------------------
lycan_boss_wolves = lycan_boss_wolves or class({})
local wolves = lycan_boss_wolves

function wolves:Precache(ctx)
	PrecacheResource("model", "models/heroes/lycan/summon_wolves.vmdl", ctx)
	PrecacheUnitByNameSync(WOLF_UNIT, ctx)
end

function wolves:OnSpellStart()
	local caster = self:GetCaster()
	caster.aa_wolves = caster.aa_wolves or {}

	local count = self:GetSpecialValueFor("count")
	local hp    = caster:GetMaxHealth() * self:GetSpecialValueFor("hp_pct") / 100
	local dmg   = caster:GetBaseDamageMax() * self:GetSpecialValueFor("damage_pct") / 100

	for _, w in pairs(caster.aa_wolves) do
		if w and not w:IsNull() and w:IsAlive() then w:ForceKill(false) end
	end
	caster.aa_wolves = {}

	for i = 1, count do
		local pos = caster:GetAbsOrigin() + RandomVector(150)
		local w = CreateUnitByName(WOLF_UNIT, pos, true, nil, nil, caster:GetTeamNumber())
		if w then
			w:SetBaseMaxHealth(hp)
			w:SetMaxHealth(hp)
			w:SetHealth(hp)
			w:SetBaseDamageMin(dmg)
			w:SetBaseDamageMax(dmg)
			w:AddNewModifier(caster, self, "modifier_lycan_boss_wolf", {})
			table.insert(caster.aa_wolves, w)
		end
	end

	caster:EmitSound("Hero_Lycan.SummonWolves")
end

-- волк держится у Ликана и бьёт ближайшего героя
modifier_lycan_boss_wolf = modifier_lycan_boss_wolf or class({})
local wm = modifier_lycan_boss_wolf

function wm:IsHidden()   return true end
function wm:IsPurgable() return false end

function wm:OnCreated()
	if not IsServer() then return end
	self:StartIntervalThink(0.5)
end

function wm:OnIntervalThink()
	local w = self:GetParent()
	local boss = self:GetCaster()

	if not boss or boss:IsNull() or not boss:IsAlive() then
		w:ForceKill(false)
		return
	end

	local home = boss:GetAbsOrigin()

	if (w:GetAbsOrigin() - home):Length2D() > 900 then
		w:MoveToPosition(home)
		return
	end

	local heroes = BossKit:EnemyHeroes(boss, home, 700)
	if #heroes > 0 then
		if w:GetAttackTarget() == nil then w:MoveToTargetToAttack(heroes[1]) end
	elseif (w:GetAbsOrigin() - home):Length2D() > 250 then
		w:MoveToPosition(home + RandomVector(150))
	end
end

--------------------------------------------------------------------------------
-- Вой: минус броня героям вокруг, с каждым живым волком сильнее.
--------------------------------------------------------------------------------
lycan_boss_howl = lycan_boss_howl or class({})
local howl = lycan_boss_howl

function howl:OnSpellStart()
	local caster = self:GetCaster()
	local armor = self:GetSpecialValueFor("armor") + self:GetSpecialValueFor("armor_per_wolf") * LiveWolves(caster)

	for _, h in pairs(BossKit:Enemies(caster, caster:GetAbsOrigin(), self:GetSpecialValueFor("radius"))) do
		h:AddNewModifier(caster, self, "modifier_lycan_boss_howl", { duration = self:GetSpecialValueFor("duration"), armor = armor })
	end

	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_lycan/lycan_howl_cast.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:ReleaseParticleIndex(fx)
	caster:EmitSound("Hero_Lycan.Howl")
end

modifier_lycan_boss_howl = modifier_lycan_boss_howl or class({})
local hm = modifier_lycan_boss_howl

function hm:IsDebuff() return true end
function hm:GetTexture() return "lycan_howl" end
function hm:GetEffectName() return "particles/units/heroes/hero_lycan/lycan_howl_buff.vpcf" end
function hm:GetEffectAttachType() return PATTACH_OVERHEAD_FOLLOW end

function hm:OnCreated(kv)
	if IsServer() then self:SetStackCount(kv.armor or 0) end
end
function hm:OnRefresh(kv)
	if IsServer() then self:SetStackCount(kv.armor or 0) end
end

function hm:DeclareFunctions() return { MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS } end
function hm:GetModifierPhysicalArmorBonus() return -self:GetStackCount() end

--------------------------------------------------------------------------------
-- Превращение: на 50% HP волк. Снимает дебафы, быстрее, крит.
--------------------------------------------------------------------------------
lycan_boss_shapeshift = lycan_boss_shapeshift or class({})
function lycan_boss_shapeshift:Precache(ctx)
	PrecacheResource("model", "models/heroes/lycan/lycan_wolf.vmdl", ctx)
end

function lycan_boss_shapeshift:GetIntrinsicModifierName() return "modifier_lycan_boss_shape_watch" end

modifier_lycan_boss_shape_watch = modifier_lycan_boss_shape_watch or class({})
local sw = modifier_lycan_boss_shape_watch

function sw:IsHidden()   return true end
function sw:IsPurgable() return false end
function sw:DeclareFunctions() return { MODIFIER_EVENT_ON_TAKEDAMAGE } end

function sw:OnTakeDamage(params)
	if not IsServer() then return end
	local p = self:GetParent()
	if params.unit ~= p or self.done then return end
	if p:GetHealthPercent() > self:GetAbility():GetSpecialValueFor("hp_pct") then return end

	self.done = true
	BossKit:Dispel(p)
	p:AddNewModifier(p, self:GetAbility(), "modifier_lycan_boss_shapeshift", {})

	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_lycan/lycan_shapeshift_cast.vpcf", PATTACH_ABSORIGIN_FOLLOW, p)
	ParticleManager:ReleaseParticleIndex(fx)
	p:EmitSound("Hero_Lycan.Shapeshift.Cast")
end

modifier_lycan_boss_shapeshift = modifier_lycan_boss_shapeshift or class({})
local ss = modifier_lycan_boss_shapeshift

function ss:IsHidden()   return false end
function ss:IsPurgable() return false end
function ss:GetTexture() return "lycan_shapeshift" end
function ss:GetEffectName() return "particles/units/heroes/hero_lycan/lycan_shapeshift_buff.vpcf" end
function ss:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function ss:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MODEL_CHANGE,
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
		MODIFIER_EVENT_ON_ATTACK_FAIL,
	}
end

function ss:OnAttackFail(params)
	if IsServer() and params.attacker == self:GetParent() then self.crit = false end
end

-- крит пробивает броню: сверху % от макс. HP цели
function ss:OnAttackLanded(params)
	if not IsServer() or not self.crit then return end
	local p = self:GetParent()
	if params.attacker ~= p then return end
	self.crit = false
	local t = params.target
	if not t or t:IsNull() or t:IsBuilding() then return end
	BossKit:PctDamage(p, self:GetAbility(), t, self:GetAbility():GetSpecialValueFor("crit_pct_hp"))
end

function ss:GetModifierModelChange() return "models/heroes/lycan/lycan_wolf.vmdl" end

-- шмотки человеческой модели (AttachWearables) на волке висели бы в воздухе
function ss:OnCreated()
	if not IsServer() then return end
	for _, child in pairs(self:GetParent():GetChildren()) do
		if child and not child:IsNull() and child:GetClassname() == "dota_item_wearable" then
			child:AddEffects(EF_NODRAW)
		end
	end
end
function ss:GetModifierMoveSpeedBonus_Percentage() return self:GetAbility():GetSpecialValueFor("move_speed") end

function ss:GetModifierPreAttack_CriticalStrike()
	if not IsServer() then return end
	local ab = self:GetAbility()
	if RollPercentage(ab:GetSpecialValueFor("crit_chance")) then
		self.crit = true
		return ab:GetSpecialValueFor("crit_damage")
	end
	self.crit = false
end

--------------------------------------------------------------------------------
-- Прыжок волка (только в форме волка): прыгает в героя, кровотечение.
--------------------------------------------------------------------------------
lycan_boss_pounce = lycan_boss_pounce or class({})
local pounce = lycan_boss_pounce

function pounce:OnAbilityPhaseStart()
	if not IsServer() then return true end
	local t = self:GetCursorTarget()
	if t then BossKit:TelegraphLineTo(self:GetCaster(), t, 150, self:GetCastPoint()) end
	return true
end

function pounce:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	if not target then return end

	local dir = target:GetAbsOrigin() - caster:GetAbsOrigin()
	dir.z = 0
	local land = target:GetAbsOrigin() - dir:Normalized() * 100

	local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_lycan/lycan_shapeshift_cast_transition.vpcf", PATTACH_ABSORIGIN, caster)
	ParticleManager:ReleaseParticleIndex(fx)

	FindClearSpaceForUnit(caster, land, true)
	caster:FaceTowards(target:GetAbsOrigin())
	caster:EmitSound("Hero_Lycan.Wolf.Hamstring")

	BossKit:PctDamage(caster, self, target, self:GetSpecialValueFor("damage_pct"))
	target:AddNewModifier(caster, self, "modifier_lycan_boss_bleed", { duration = self:GetSpecialValueFor("bleed_duration") })
	caster:MoveToTargetToAttack(target)
end

modifier_lycan_boss_bleed = modifier_lycan_boss_bleed or class({})
local bl = modifier_lycan_boss_bleed

function bl:IsDebuff() return true end
function bl:GetTexture() return "lycan_feral_impulse" end
function bl:GetEffectName() return "particles/units/heroes/hero_lycan/lycan_wolfbite_ambient.vpcf" end

function bl:OnCreated()
	if not IsServer() then return end
	self:StartIntervalThink(1)
end

function bl:OnIntervalThink()
	local ab = self:GetAbility()
	if not ab or ab:IsNull() then return end
	BossKit:PctDamage(self:GetCaster(), ab, self:GetParent(), ab:GetSpecialValueFor("bleed_pct"))
end

function bl:DeclareFunctions() return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE } end
function bl:GetModifierMoveSpeedBonus_Percentage()
	local a = self:GetAbility()
	return a and -a:GetSpecialValueFor("bleed_slow") or 0
end
