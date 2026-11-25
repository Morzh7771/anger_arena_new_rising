-- Фарм героев (2026-11-22, doc/farm_rework_brief_2026-11-22.md).
-- Скрытый модификатор на героя (и медведя Лон Друида): добавляет ванильным
-- способностям эффекты "против крипов" - сплэши, отскоки, урон. Ванильные
-- способности не переписываем: ловим их урон/атаки/касты, числа берём из их
-- AbilityValues (свои ключи creep_* дописаны в KV героя).
-- Вешает lib/hero_farm.lua. Работает только по нейтральным крипам (не боссам).

modifier_aa_hero_farm = class({})

LinkLuaModifier("modifier_aa_farm_burn", "modifiers/modifier_aa_hero_farm", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_aa_farm_jingu", "modifiers/modifier_aa_hero_farm", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_aa_farm_flux", "modifiers/modifier_aa_hero_farm", LUA_MODIFIER_MOTION_NONE)

function modifier_aa_hero_farm:IsHidden() return true end
function modifier_aa_hero_farm:IsPurgable() return false end
function modifier_aa_hero_farm:RemoveOnDeath() return false end
function modifier_aa_hero_farm:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT end

--------------------------------------------------------------------------------
-- Общие хелперы

local function IsFarmCreep(unit)
	return unit and not unit:IsNull() and unit:IsAlive()
		and unit:GetTeamNumber() == DOTA_TEAM_NEUTRALS
		and not unit:IsHero() and not unit:IsConsideredHero()
		and not unit.IsAngelArenaBoss
end

local function Creeps(team, pos, radius, exclude, order)
	local res = {}
	local units = FindUnitsInRadius(team, pos, nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, order or FIND_ANY_ORDER, false)
	for _, u in ipairs(units) do
		if u ~= exclude and IsFarmCreep(u) then table.insert(res, u) end
	end
	return res
end

local function Ability(unit, name)
	local ab = unit:FindAbilityByName(name)
	if ab and ab:GetLevel() > 0 then return ab end
end

-- урон с защитой от рекурсии: наш же урон этим модификатором не обрабатывается
function modifier_aa_hero_farm:Hit(victim, damage, dtype, ability, flags)
	if damage <= 0 or not IsFarmCreep(victim) then return end
	self.busy = true
	ApplyDamage({
		victim = victim, attacker = self:GetParent(), damage = damage,
		damage_type = dtype or DAMAGE_TYPE_PHYSICAL, ability = ability,
		damage_flags = flags or DOTA_DAMAGE_FLAG_NONE,
	})
	self.busy = false
end

-- снаряд-отскок от одной цели к другой (только визуал), по прилёту cb()
function modifier_aa_hero_farm:Fly(from, to, effect, speed, cb)
	local fx = ParticleManager:CreateParticle(effect, PATTACH_CUSTOMORIGIN, nil)
	ParticleManager:SetParticleControlEnt(fx, 0, from, PATTACH_POINT_FOLLOW, "attach_hitloc", from:GetAbsOrigin(), true)
	ParticleManager:SetParticleControlEnt(fx, 1, to, PATTACH_POINT_FOLLOW, "attach_hitloc", to:GetAbsOrigin(), true)
	ParticleManager:SetParticleControl(fx, 2, Vector(speed, 0, 0))
	local delay = (to:GetAbsOrigin() - from:GetAbsOrigin()):Length2D() / speed
	Timers:CreateTimer(delay, function()
		ParticleManager:DestroyParticle(fx, false)
		ParticleManager:ReleaseParticleIndex(fx)
		if not self:IsNull() and IsFarmCreep(to) then cb() end
	end)
end

-- отскоки в count соседних крипов
function modifier_aa_hero_farm:Bounce(target, count, radius, effect, speed, cb)
	local team = self:GetParent():GetTeamNumber()
	local list = Creeps(team, target:GetAbsOrigin(), radius, target, FIND_CLOSEST)
	for i = 1, math.min(count, #list) do
		local next_unit = list[i]
		self:Fly(target, next_unit, effect, speed, function() cb(next_unit) end)
	end
end

-- урон по площади вокруг цели (без самой цели)
function modifier_aa_hero_farm:Splash(target, radius, damage, dtype, ability, effect)
	local team = self:GetParent():GetTeamNumber()
	for _, u in ipairs(Creeps(team, target:GetAbsOrigin(), radius, target)) do
		self:Hit(u, damage, dtype, ability)
	end
	if effect then
		local fx = ParticleManager:CreateParticle(effect, PATTACH_ABSORIGIN, target)
		ParticleManager:SetParticleControl(fx, 0, target:GetAbsOrigin())
		ParticleManager:SetParticleControl(fx, 1, Vector(radius, radius, radius))
		ParticleManager:ReleaseParticleIndex(fx)
	end
end

local function Stun(unit, caster, ability, duration)
	if duration and duration > 0 and IsFarmCreep(unit) then
		unit:AddNewModifier(caster, ability, "modifier_stunned", { duration = duration })
	end
end

-- "первое попадание после каста": чтобы отскок срабатывал один раз за каст,
-- а не на каждом тике/отскоке самого ванильного скилла
function modifier_aa_hero_farm:MarkCast(name) self.cast_marks[name] = GameRules:GetGameTime() end
function modifier_aa_hero_farm:TakeCast(name, window)
	local t = self.cast_marks[name]
	if t and GameRules:GetGameTime() - t <= (window or 5) then
		self.cast_marks[name] = nil
		return true
	end
end

--------------------------------------------------------------------------------
-- Конфиг по героям

local H = {}

-- Phantom Assassin: кинжал отскакивает от крипа
H.npc_dota_hero_phantom_assassin = {
	attack = function(self, p)
		local parent = self:GetParent()
		if not parent:HasModifier("modifier_phantom_assassin_stiflingdagger_caster") then return end
		local ab = Ability(parent, "phantom_assassin_stifling_dagger")
		if not ab then return end
		local damage = p.damage * ab:GetSpecialValueFor("creep_bounce_damage_pct") / 100
		self:Bounce(p.target, ab:GetSpecialValueFor("creep_bounce_count"), ab:GetSpecialValueFor("creep_bounce_radius"),
			"particles/units/heroes/hero_phantom_assassin/phantom_assassin_stifling_dagger.vpcf", 1200,
			function(u) self:Hit(u, damage, DAMAGE_TYPE_PHYSICAL, ab) end)
	end,
}

-- Wraith King: Hellfire Blast взрывается на крипе
H.npc_dota_hero_skeleton_king = {
	cast = { skeleton_king_hellfire_blast = true },
	damage = function(self, p, name)
		if name ~= "skeleton_king_hellfire_blast" or not self:TakeCast(name) then return end
		local ab = p.inflictor
		local radius = ab:GetSpecialValueFor("creep_splash_radius")
		local stun = ab:GetSpecialValueFor("blast_stun_duration")
		local team = self:GetParent():GetTeamNumber()
		for _, u in ipairs(Creeps(team, p.unit:GetAbsOrigin(), radius, p.unit)) do
			self:Hit(u, p.original_damage, p.damage_type, ab)
			Stun(u, self:GetParent(), ab, stun)
		end
		local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_skeletonking/skeletonking_hellfireblast_explosion.vpcf", PATTACH_ABSORIGIN, p.unit)
		ParticleManager:ReleaseParticleIndex(fx)
	end,
}

-- Anti-Mage: Mana Break бьёт соседей сожжённой маной
H.npc_dota_hero_antimage = {
	attack = function(self, p)
		local parent = self:GetParent()
		if parent:PassivesDisabled() then return end
		local ab = Ability(parent, "antimage_mana_break")
		local target = p.target
		if not ab or target:GetMaxMana() <= 0 then return end
		local burn = ab:GetSpecialValueFor("mana_per_hit") + target:GetMaxMana() * ab:GetSpecialValueFor("mana_per_hit_pct") / 100
		-- мана уже снята атакой: сожгли не больше, чем было
		burn = math.min(burn, target:GetMana() + burn)
		local damage = burn * ab:GetSpecialValueFor("percent_damage_per_burn") / 100
		self:Splash(target, ab:GetSpecialValueFor("creep_splash_radius"), damage, DAMAGE_TYPE_PHYSICAL, ab,
			"particles/generic_gameplay/generic_manaburn.vpcf")
	end,
}

-- Spirit Breaker: баш по крипу бьёт по площади
H.npc_dota_hero_spirit_breaker = {
	damage = function(self, p, name)
		if name ~= "spirit_breaker_greater_bash" then return end
		local ab = p.inflictor
		local team = self:GetParent():GetTeamNumber()
		local stun = ab:GetSpecialValueFor("creep_splash_stun")
		for _, u in ipairs(Creeps(team, p.unit:GetAbsOrigin(), ab:GetSpecialValueFor("creep_splash_radius"), p.unit)) do
			self:Hit(u, p.original_damage, p.damage_type, ab)
			Stun(u, self:GetParent(), ab, stun)
		end
	end,
}

-- Lifestealer: Feast даёт сплэш по крипам
H.npc_dota_hero_life_stealer = {
	attack = function(self, p)
		local parent = self:GetParent()
		if parent:PassivesDisabled() then return end
		local ab = Ability(parent, "life_stealer_feast_aa")
		if not ab then return end
		local damage = p.target:GetMaxHealth() * ab:GetSpecialValueFor("hp_damage_percent") / 100
			* ab:GetSpecialValueFor("creep_splash_pct") / 100
		self:Splash(p.target, ab:GetSpecialValueFor("creep_splash_radius"), damage, DAMAGE_TYPE_PHYSICAL, ab)
	end,
}

-- Lone Druid: Savage Roar наносит урон крипам
H.npc_dota_hero_lone_druid = {
	cast_fn = {
		lone_druid_savage_roar = function(self, ab)
			local parent = self:GetParent()
			local damage = ab:GetSpecialValueFor("creep_damage")
			for _, u in ipairs(Creeps(parent:GetTeamNumber(), parent:GetAbsOrigin(), ab:GetSpecialValueFor("radius"))) do
				self:Hit(u, damage, DAMAGE_TYPE_MAGICAL, ab)
			end
		end,
	},
}

-- медведь Лон Друида: клив по крипам от уровня Spirit Bear
local BEAR = {
	attack = function(self, p)
		local bear = self:GetParent()
		local owner = bear:GetOwner()
		if not owner or owner:IsNull() or not owner.FindAbilityByName then return end
		local ab = Ability(owner, "lone_druid_spirit_bear")
		if not ab then return end
		local pct = ab:GetSpecialValueFor("creep_cleave_pct")
		if pct <= 0 then return end
		self.busy = true
		DoCleaveAttack(bear, p.target, ab, p.damage * pct / 100, 150, 360, 650,
			"particles/items_fx/battlefury_cleave.vpcf")
		self.busy = false
	end,
}

-- Faceless Void: сплэш атак по крипам, прок Time Lock бьёт по площади
H.npc_dota_hero_faceless_void = {
	attack = function(self, p)
		local parent = self:GetParent()
		if parent:PassivesDisabled() then return end
		local ab = Ability(parent, "faceless_void_time_lock")
		if not ab then return end
		local pct = ab:GetSpecialValueFor("creep_cleave_pct")
		self.busy = true
		DoCleaveAttack(parent, p.target, ab, p.damage * pct / 100, 150, 360, 650,
			"particles/units/heroes/hero_faceless_void/faceless_void_time_lock_bash.vpcf")
		self.busy = false
	end,
	damage = function(self, p, name)
		if name ~= "faceless_void_time_lock" then return end
		self:Splash(p.unit, p.inflictor:GetSpecialValueFor("creep_splash_radius"), p.original_damage, p.damage_type, p.inflictor)
	end,
}

-- Bounty Hunter: сюрикен отскакивает от крипа
H.npc_dota_hero_bounty_hunter = {
	cast = { bounty_hunter_shuriken_toss = true },
	damage = function(self, p, name)
		if name ~= "bounty_hunter_shuriken_toss" or not self:TakeCast(name) then return end
		local ab, damage = p.inflictor, p.original_damage
		self:Bounce(p.unit, ab:GetSpecialValueFor("creep_bounce_count"), ab:GetSpecialValueFor("creep_bounce_radius"),
			"particles/units/heroes/hero_bounty_hunter/bounty_hunter_suriken_toss.vpcf", 1000,
			function(u) self:Hit(u, damage, p.damage_type, ab) end)
	end,
}

-- Monkey King: облегчённый Jingu по крипам
H.npc_dota_hero_monkey_king = {
	attack = function(self, p)
		local parent = self:GetParent()
		if parent:PassivesDisabled() or parent:HasModifier("modifier_aa_farm_jingu") then return end
		if parent:HasModifier("modifier_monkey_king_quadruple_tap_bonuses") then return end
		local ab = Ability(parent, "monkey_king_jingu_mastery")
		if not ab then return end
		self.mk_hits = (self.mk_hits or 0) + 1
		if self.mk_hits < ab:GetSpecialValueFor("creep_required_hits") then return end
		self.mk_hits = 0
		local mod = parent:AddNewModifier(parent, ab, "modifier_aa_farm_jingu", { duration = ab:GetSpecialValueFor("creep_buff_duration") })
		if mod then mod:SetStackCount(ab:GetSpecialValueFor("creep_charges")) end
	end,
}

-- Outworld Destroyer: шард - Astral бьёт ещё % текущей маны OD
H.npc_dota_hero_obsidian_destroyer = {
	damage = function(self, p, name)
		if name ~= "obsidian_destroyer_astral_imprisonment" then return end
		local pct = p.inflictor:GetSpecialValueFor("shard_mana_damage_pct")
		if pct <= 0 then return end
		local parent = self:GetParent()
		-- и по героям: это шард, не фарм
		self.busy = true
		ApplyDamage({ victim = p.unit, attacker = parent, damage = parent:GetMana() * pct / 100,
			damage_type = p.damage_type, ability = p.inflictor })
		self.busy = false
	end,
}

-- Arc Warden (как у Ксена): Flux на крипе цепляет ещё крипов рядом,
-- и по крипам урон не блокируется соседями
H.npc_dota_hero_arc_warden = {
	cast_fn = {
		arc_warden_flux = function(self, ab)
			local target = ab:GetCursorTarget()
			if not IsFarmCreep(target) then return end
			local parent = self:GetParent()
			local duration = ab:GetSpecialValueFor("duration")
			target:AddNewModifier(parent, ab, "modifier_aa_farm_flux", { duration = duration, main = 1 })
			local list = Creeps(parent:GetTeamNumber(), target:GetAbsOrigin(), ab:GetSpecialValueFor("creep_aoe_radius"), target, FIND_CLOSEST)
			for i = 1, math.min(ab:GetSpecialValueFor("creep_aoe_count"), #list) do
				list[i]:AddNewModifier(parent, ab, "modifier_aa_farm_flux", { duration = duration, main = 0 })
			end
		end,
	},
}

--------------------------------------------------------------------------------

function modifier_aa_hero_farm:OnCreated(kv)
	if not IsServer() then return end
	self.cast_marks = {}
	local parent = self:GetParent()
	if string.find(parent:GetUnitName(), "npc_dota_lone_druid_bear", 1, true) then
		self.cfg = BEAR
	else
		self.cfg = H[parent:GetUnitName()]
	end
	if not self.cfg then self:Destroy() end
end

function modifier_aa_hero_farm:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ATTACK_LANDED,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
		MODIFIER_EVENT_ON_ABILITY_FULLY_CAST,
		MODIFIER_EVENT_ON_DEATH,
	}
end

function modifier_aa_hero_farm:OnAttackLanded(p)
	if not IsServer() or self.busy or not self.cfg or not self.cfg.attack then return end
	if p.attacker ~= self:GetParent() or not IsFarmCreep(p.target) then return end
	if self:GetParent():IsIllusion() then return end
	self.cfg.attack(self, p)
end

function modifier_aa_hero_farm:OnTakeDamage(p)
	if not IsServer() or self.busy or not self.cfg or not self.cfg.damage then return end
	if p.attacker ~= self:GetParent() or not p.inflictor or p.inflictor:IsNull() then return end
	if not IsFarmCreep(p.unit) and not self.cfg.damage_any then
		-- OD шард бьёт и героев
		if self:GetParent():GetUnitName() ~= "npc_dota_hero_obsidian_destroyer" then return end
	end
	self.cfg.damage(self, p, p.inflictor:GetAbilityName())
end

function modifier_aa_hero_farm:OnAbilityFullyCast(p)
	if not IsServer() or not self.cfg or p.unit ~= self:GetParent() or not p.ability then return end
	local name = p.ability:GetAbilityName()
	if self.cfg.cast and self.cfg.cast[name] then self:MarkCast(name) end
	local fn = self.cfg.cast_fn and self.cfg.cast_fn[name]
	if fn then fn(self, p.ability) end
end

function modifier_aa_hero_farm:OnDeath(p)
	if not IsServer() or not self.cfg or not self.cfg.death then return end
	if not p.unit or p.unit:GetTeamNumber() ~= DOTA_TEAM_NEUTRALS or p.unit.IsAngelArenaBoss then return end
	self.cfg.death(self, p.unit)
end

--------------------------------------------------------------------------------
-- Горение копий Хускара, перешедшее с умершего крипа

modifier_aa_farm_burn = class({})

function modifier_aa_farm_burn:IsDebuff() return true end
function modifier_aa_farm_burn:IsPurgable() return true end
function modifier_aa_farm_burn:GetTexture() return "huskar_burning_spear" end
function modifier_aa_farm_burn:GetEffectName() return "particles/units/heroes/hero_huskar/huskar_burning_spear_debuff.vpcf" end
function modifier_aa_farm_burn:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_aa_farm_burn:OnCreated(kv)
	if not IsServer() then return end
	self.dps = kv.dps or 0
	self:StartIntervalThink(1)
end

function modifier_aa_farm_burn:OnRefresh(kv)
	if not IsServer() then return end
	self.dps = math.max(self.dps or 0, kv.dps or 0)
end

function modifier_aa_farm_burn:OnIntervalThink()
	local caster = self:GetCaster()
	if not caster or caster:IsNull() then self:Destroy() return end
	ApplyDamage({ victim = self:GetParent(), attacker = caster, damage = self.dps,
		damage_type = DAMAGE_TYPE_MAGICAL, ability = self:GetAbility() })
end

--------------------------------------------------------------------------------
-- Облегчённый Jingu Мастера по крипам: заряды бонусного урона

modifier_aa_farm_jingu = class({})

function modifier_aa_farm_jingu:IsPurgable() return false end
function modifier_aa_farm_jingu:GetTexture() return "monkey_king_jingu_mastery" end
function modifier_aa_farm_jingu:GetEffectName() return "particles/units/heroes/hero_monkey_king/monkey_king_quad_tap_overhead.vpcf" end
function modifier_aa_farm_jingu:GetEffectAttachType() return PATTACH_OVERHEAD_FOLLOW end

function modifier_aa_farm_jingu:DeclareFunctions()
	return { MODIFIER_PROPERTY_PROCATTACK_BONUS_DAMAGE_PHYSICAL, MODIFIER_PROPERTY_TOOLTIP, MODIFIER_EVENT_ON_TAKEDAMAGE }
end

-- вампиризм Jingu остаётся полным (как у Ксена), заряд тратится на попадании
function modifier_aa_farm_jingu:OnTakeDamage(p)
	if not IsServer() or p.attacker ~= self:GetParent() or p.inflictor or not IsFarmCreep(p.unit) then return end
	local ab = self:GetAbility()
	if ab then
		local heal = p.damage * ab:GetSpecialValueFor("lifesteal") / 100
		if heal > 0 then
			self:GetParent():HealWithParams(heal, ab, true, true, self:GetParent(), false)
			local fx = ParticleManager:CreateParticle("particles/generic_gameplay/generic_lifesteal.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
			ParticleManager:ReleaseParticleIndex(fx)
		end
	end
	self:DecrementStackCount()
	if self:GetStackCount() <= 0 then self:Destroy() end
end

function modifier_aa_farm_jingu:Bonus()
	local ab = self:GetAbility()
	if not ab then return 0 end
	return ab:GetSpecialValueFor("bonus_damage") * ab:GetSpecialValueFor("creep_bonus_pct") / 100
end

function modifier_aa_farm_jingu:OnTooltip() return self:Bonus() end

function modifier_aa_farm_jingu:GetModifierProcAttack_BonusDamage_Physical(p)
	if not IsServer() or not IsFarmCreep(p.target) then return 0 end
	return self:Bonus()
end

--------------------------------------------------------------------------------
-- Flux Арк Вардена на крипах. На основной цели бьёт только когда ванильный
-- Flux заблокирован (рядом есть другие враги), на соседних - всегда.

modifier_aa_farm_flux = class({})

function modifier_aa_farm_flux:IsDebuff() return true end
function modifier_aa_farm_flux:IsPurgable() return true end
function modifier_aa_farm_flux:IsHidden() return self:GetStackCount() == 1 end
function modifier_aa_farm_flux:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end
function modifier_aa_farm_flux:GetTexture() return "arc_warden_flux" end
function modifier_aa_farm_flux:GetEffectName() return "particles/units/heroes/hero_arc_warden/arc_warden_flux_tgt.vpcf" end
function modifier_aa_farm_flux:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_aa_farm_flux:OnCreated(kv)
	if not IsServer() then return end
	self.main = kv.main == 1
	if self.main then self:SetStackCount(1) end
	self.interval = 0.5
	self:StartIntervalThink(self.interval)
end

function modifier_aa_farm_flux:OnIntervalThink()
	local parent, caster, ab = self:GetParent(), self:GetCaster(), self:GetAbility()
	if not caster or caster:IsNull() or not ab then self:Destroy() return end
	if self.main then
		local near = FindUnitsInRadius(caster:GetTeamNumber(), parent:GetAbsOrigin(), nil, ab:GetSpecialValueFor("search_radius"),
			DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
		if #near <= 1 then return end -- одна - ванильный Flux бьёт сам
	end
	local key = caster:IsTempestDouble() and "tempest_damage_per_second" or "damage_per_second"
	ApplyDamage({ victim = parent, attacker = caster, damage = ab:GetSpecialValueFor(key) * self.interval,
		damage_type = DAMAGE_TYPE_MAGICAL, ability = ab })
end
