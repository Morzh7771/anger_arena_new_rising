-- Clinkz: Searing Arrows на Lua (2026-11-22). Ванильный орб не давал повесить
-- сплэш по крипам. Поведение как в доте 7.42:
--  * автокаст или ручное применение на цель, стрела тратит ману и добавляет
--    damage_bonus к физическому урону атаки;
--  * атаки без кулдауна (Burning Barrage и т.п.) получают огненную стрелу бесплатно,
--    если включён автокаст;
--  * скелеты-лучники Клинкза стреляют такими же стрелами по цели героя
--    с skeleton_damage_pct% урона способности;
--  * талант has_multishot (special_bonus_unique_clinkz_3): огненная атака героя
--    выпускает вторую стрелу в случайного врага в радиусе атаки.
-- Против крипов: тот же бонус получают все крипы в creep_splash_radius вокруг цели.

clinkz_searing_arrows = class({})

LinkLuaModifier("modifier_clinkz_searing_arrows_aa", "heroes/clinkz/clinkz_searing_arrows", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_clinkz_searing_arrows_aa_skeleton", "heroes/clinkz/clinkz_searing_arrows", LUA_MODIFIER_MOTION_NONE)

local PROJECTILE = "particles/units/heroes/hero_clinkz/clinkz_searing_arrow.vpcf"
local IMPACT = "particles/units/heroes/hero_clinkz/clinkz_infernal_shred_arrow_impact.vpcf"
local SKELETON = "npc_dota_clinkz_skeleton_archer"

function clinkz_searing_arrows:Precache(context)
	PrecacheResource("particle", PROJECTILE, context)
	PrecacheResource("particle", IMPACT, context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_clinkz.vsndevts", context)
end

function clinkz_searing_arrows:GetIntrinsicModifierName()
	return "modifier_clinkz_searing_arrows_aa"
end

function clinkz_searing_arrows:GetCastRange(location, target)
	return self:GetCaster():Script_GetAttackRange()
end

-- ручное применение: следующая атака по цели - огненная (мана уже потрачена кастом)
function clinkz_searing_arrows:OnSpellStart()
	self.manual = true
	self:GetCaster():MoveToTargetToAttack(self:GetCursorTarget())
end

-- бонус огненной стрелы по цели и сплэш по крипам вокруг (attacker - герой или скелет)
function clinkz_searing_arrows:Impact(attacker, target, damage)
	target:EmitSound("Hero_Clinkz.SearingArrows.Impact")
	if target:GetTeamNumber() ~= DOTA_TEAM_NEUTRALS or target:IsHero() or target.IsAngelArenaBoss then return end
	local units = FindUnitsInRadius(attacker:GetTeamNumber(), target:GetAbsOrigin(), nil, self:GetSpecialValueFor("creep_splash_radius"),
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	for _, u in ipairs(units) do
		if u ~= target and u:GetTeamNumber() == DOTA_TEAM_NEUTRALS and not u.IsAngelArenaBoss then
			ApplyDamage({ victim = u, attacker = attacker, damage = damage, damage_type = DAMAGE_TYPE_PHYSICAL, ability = self })
		end
	end
	local fx = ParticleManager:CreateParticle(IMPACT, PATTACH_ABSORIGIN, target)
	ParticleManager:SetParticleControl(fx, 0, target:GetAbsOrigin())
	ParticleManager:ReleaseParticleIndex(fx)
end

--------------------------------------------------------------------------------
-- Орб на Клинкзе

modifier_clinkz_searing_arrows_aa = class({})

function modifier_clinkz_searing_arrows_aa:IsHidden() return true end
function modifier_clinkz_searing_arrows_aa:IsPurgable() return false end

function modifier_clinkz_searing_arrows_aa:OnCreated()
	self.records = {}
	if not IsServer() then return end
	-- скелеты-лучники получают свою копию орба
	self:StartIntervalThink(0.5)
end

function modifier_clinkz_searing_arrows_aa:OnIntervalThink()
	local parent = self:GetParent()
	if parent:IsIllusion() then self:StartIntervalThink(-1) return end
	local units = FindUnitsInRadius(parent:GetTeamNumber(), parent:GetAbsOrigin(), nil, FIND_UNITS_EVERYWHERE,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_INVULNERABLE, FIND_ANY_ORDER, false)
	for _, u in ipairs(units) do
		if u:GetUnitName() == SKELETON and u:GetPlayerOwnerID() == parent:GetPlayerOwnerID()
			and not u:HasModifier("modifier_clinkz_searing_arrows_aa_skeleton") then
			u:AddNewModifier(parent, self:GetAbility(), "modifier_clinkz_searing_arrows_aa_skeleton", {})
		end
	end
end

function modifier_clinkz_searing_arrows_aa:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ATTACK_RECORD,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
		MODIFIER_EVENT_ON_ATTACK_RECORD_DESTROY,
		MODIFIER_PROPERTY_PROCATTACK_BONUS_DAMAGE_PHYSICAL,
		MODIFIER_PROPERTY_PROJECTILE_NAME,
	}
end

-- будет ли следующая обычная атака огненной
function modifier_clinkz_searing_arrows_aa:WillFire()
	local ab = self:GetAbility()
	local parent = self:GetParent()
	if not ab or ab:GetLevel() <= 0 or parent:IsSilenced() then return false end
	if ab.manual or ab.free_next then return true end
	return ab:GetAutoCastState() and parent:GetMana() >= ab:GetManaCost(-1)
end

function modifier_clinkz_searing_arrows_aa:GetModifierProjectileName()
	if self:WillFire() then return PROJECTILE end
end

function modifier_clinkz_searing_arrows_aa:OnAttackRecord(params)
	if not IsServer() or params.attacker ~= self:GetParent() then return end
	local parent = self:GetParent()
	local ab = self:GetAbility()
	if not ab or ab:GetLevel() <= 0 then return end

	local free = ab.free_next
	ab.free_next = nil
	if free then
		-- вторая стрела таланта
	elseif params.no_attack_cooldown then
		-- Burning Barrage и прочие доп. атаки: бесплатно при включённом автокасте
		if not ab:GetAutoCastState() then return end
	else
		if parent:IsIllusion() or not self:WillFire() then return end
		if ab.manual then
			ab.manual = nil
		else
			ab:UseResources(true, false, false, false)
		end
	end

	self.records[params.record] = true
	parent:EmitSound("Hero_Clinkz.SearingArrows")

	-- талант: вторая огненная стрела в случайного врага в радиусе атаки
	if not free and not params.no_attack_cooldown and ab:GetSpecialValueFor("has_multishot") > 0 then
		local units = FindUnitsInRadius(parent:GetTeamNumber(), parent:GetAbsOrigin(), nil, parent:Script_GetAttackRange() + parent:GetHullRadius(),
			DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			DOTA_UNIT_TARGET_FLAG_NO_INVIS + DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NOT_ATTACK_IMMUNE, FIND_ANY_ORDER, false)
		local pool = {}
		for _, u in ipairs(units) do if u ~= params.target then table.insert(pool, u) end end
		if #pool > 0 then
			local second = pool[RandomInt(1, #pool)]
			Timers:CreateTimer(FrameTime(), function()
				if parent:IsNull() or not parent:IsAlive() or second:IsNull() or not second:IsAlive() then return end
				ab.free_next = true
				parent:PerformAttack(second, true, true, true, false, true, false, false)
				ab.free_next = nil
			end)
		end
	end
end

function modifier_clinkz_searing_arrows_aa:GetModifierProcAttack_BonusDamage_Physical(params)
	if not IsServer() or not self.records[params.record] then return 0 end
	return self:GetAbility():GetSpecialValueFor("damage_bonus")
end

function modifier_clinkz_searing_arrows_aa:OnAttackLanded(params)
	if not IsServer() or params.attacker ~= self:GetParent() or not self.records[params.record] then return end
	local ab = self:GetAbility()
	ab:Impact(self:GetParent(), params.target, ab:GetSpecialValueFor("damage_bonus"))
end

function modifier_clinkz_searing_arrows_aa:OnAttackRecordDestroy(params)
	if self.records then self.records[params.record] = nil end
end

--------------------------------------------------------------------------------
-- Скелет-лучник: огненные стрелы по цели героя

modifier_clinkz_searing_arrows_aa_skeleton = class({})

function modifier_clinkz_searing_arrows_aa_skeleton:IsHidden() return true end
function modifier_clinkz_searing_arrows_aa_skeleton:IsPurgable() return false end

function modifier_clinkz_searing_arrows_aa_skeleton:OnCreated()
	self.records = {}
end

function modifier_clinkz_searing_arrows_aa_skeleton:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ATTACK_RECORD,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
		MODIFIER_EVENT_ON_ATTACK_RECORD_DESTROY,
		MODIFIER_PROPERTY_PROCATTACK_BONUS_DAMAGE_PHYSICAL,
		MODIFIER_PROPERTY_PROJECTILE_NAME,
	}
end

-- стреляет огнём, если герой с включённой способностью бьёт ту же цель
function modifier_clinkz_searing_arrows_aa_skeleton:Active(target)
	local ab, hero = self:GetAbility(), self:GetCaster()
	if not ab or ab:IsNull() or ab:GetLevel() <= 0 or not hero or hero:IsNull() or not hero:IsAlive() then return false end
	if not ab:GetAutoCastState() then return false end
	if target and hero:GetAttackTarget() ~= target then return false end
	return true
end

function modifier_clinkz_searing_arrows_aa_skeleton:Damage()
	local ab = self:GetAbility()
	return ab:GetSpecialValueFor("damage_bonus") * ab:GetSpecialValueFor("skeleton_damage_pct") / 100
end

function modifier_clinkz_searing_arrows_aa_skeleton:GetModifierProjectileName()
	if self:Active() then return PROJECTILE end
end

function modifier_clinkz_searing_arrows_aa_skeleton:OnAttackRecord(params)
	if not IsServer() or params.attacker ~= self:GetParent() then return end
	if self:Active(params.target) then self.records[params.record] = true end
end

function modifier_clinkz_searing_arrows_aa_skeleton:GetModifierProcAttack_BonusDamage_Physical(params)
	if not IsServer() or not self.records[params.record] then return 0 end
	return self:Damage()
end

function modifier_clinkz_searing_arrows_aa_skeleton:OnAttackLanded(params)
	if not IsServer() or params.attacker ~= self:GetParent() or not self.records[params.record] then return end
	self:GetAbility():Impact(self:GetParent(), params.target, self:Damage())
end

function modifier_clinkz_searing_arrows_aa_skeleton:OnAttackRecordDestroy(params)
	if self.records then self.records[params.record] = nil end
end
