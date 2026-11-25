-- Riki: Tricks of the Trade на Lua (2026-11-22). Ванильный бил по 2 случайным
-- целям за удар, и это нельзя было поменять для крипов.
-- Как в доте: канал AbilityChannelTime, Рики пропадает из мира, attack_count раз за
-- канал атакует в спину врагов в radius (урон атаки фиксированный: attack_damage +
-- base_attack_damage_pct% базового урона + agility_pct% ловкости), Backstab проходит
-- по всем целям. Героев - до interval_targets за удар, как в доте.
-- Против крипов: каждый удар бьёт ВСЕХ крипов в зоне.
-- Аганим: можно спрятаться в союзника (зона едет с ним, +scepter_bonus_duration сек,
-- +scepter_bonus_attacks ударов, союзнику +scepter_movespeed% скорости).

riki_tricks_of_the_trade = class({})

LinkLuaModifier("modifier_riki_tricks_of_the_trade_aa", "heroes/riki/riki_tricks_of_the_trade", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_riki_tricks_of_the_trade_aa_ally", "heroes/riki/riki_tricks_of_the_trade", LUA_MODIFIER_MOTION_NONE)

local FX_AREA = "particles/units/heroes/hero_riki/riki_tricks.vpcf"
local FX_CAST = "particles/units/heroes/hero_riki/riki_tricks_cast.vpcf"
local FX_END = "particles/units/heroes/hero_riki/riki_tricks_end.vpcf"

function riki_tricks_of_the_trade:Precache(context)
	PrecacheResource("particle", FX_AREA, context)
	PrecacheResource("particle", FX_CAST, context)
	PrecacheResource("particle", FX_END, context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_riki.vsndevts", context)
end

function riki_tricks_of_the_trade:GetBehavior()
	local b = DOTA_ABILITY_BEHAVIOR_POINT + DOTA_ABILITY_BEHAVIOR_AOE + DOTA_ABILITY_BEHAVIOR_CHANNELLED
	if self:GetCaster():HasScepter() then b = b + DOTA_ABILITY_BEHAVIOR_UNIT_TARGET end
	return b
end

function riki_tricks_of_the_trade:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function riki_tricks_of_the_trade:CastFilterResultTarget(target)
	if target == self:GetCaster() or not target:IsHero() then return UF_FAIL_CUSTOM end
	return UnitFilter(target, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_NOT_CREEP_HERO, self:GetCaster():GetTeamNumber())
end

function riki_tricks_of_the_trade:GetCustomCastErrorTarget(target)
	return "#dota_hud_error_cant_cast_on_self"
end

function riki_tricks_of_the_trade:GetChannelTime()
	local t = self:GetSpecialValueFor("AbilityChannelTime")
	if self.ally then t = t + self:GetSpecialValueFor("scepter_bonus_duration") end
	return t
end

function riki_tricks_of_the_trade:OnAbilityPhaseStart()
	local target = self:GetCursorTarget()
	self.ally = (target and target ~= self:GetCaster() and self:GetCaster():HasScepter()) and target or nil
	return true
end

function riki_tricks_of_the_trade:OnSpellStart()
	local caster = self:GetCaster()
	local point = self.ally and self.ally:GetAbsOrigin() or self:GetCursorPosition()

	if self:GetSpecialValueFor("dispel") > 0 then caster:Purge(false, true, false, false, false) end

	local attacks = self:GetSpecialValueFor("attack_count")
	if self.ally then
		attacks = attacks + self:GetSpecialValueFor("scepter_bonus_attacks")
		self.ally:AddNewModifier(caster, self, "modifier_riki_tricks_of_the_trade_aa_ally", { duration = self:GetChannelTime() })
	end

	caster:AddNewModifier(caster, self, "modifier_riki_tricks_of_the_trade_aa", {
		duration = self:GetChannelTime(),
		x = point.x, y = point.y, z = point.z,
		interval = self:GetChannelTime() / math.max(1, attacks),
	})

	local fx = ParticleManager:CreateParticle(FX_CAST, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, caster:GetAbsOrigin())
	ParticleManager:ReleaseParticleIndex(fx)
	caster:EmitSound("Hero_Riki.TricksOfTheTrade.Cast")
end

function riki_tricks_of_the_trade:OnChannelFinish(interrupted)
	self:GetCaster():RemoveModifierByName("modifier_riki_tricks_of_the_trade_aa")
	if self.ally and not self.ally:IsNull() then
		self.ally:RemoveModifierByName("modifier_riki_tricks_of_the_trade_aa_ally")
	end
	self.ally = nil
end

--------------------------------------------------------------------------------
-- Рики вне мира, бьёт из зоны

modifier_riki_tricks_of_the_trade_aa = class({})

function modifier_riki_tricks_of_the_trade_aa:IsHidden() return false end
function modifier_riki_tricks_of_the_trade_aa:IsPurgable() return false end

function modifier_riki_tricks_of_the_trade_aa:CheckState()
	return {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_UNTARGETABLE] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_UNSELECTABLE] = true,
	}
end

function modifier_riki_tricks_of_the_trade_aa:DeclareFunctions()
	return { MODIFIER_PROPERTY_OVERRIDE_ATTACK_DAMAGE }
end

-- урон атаки во время Tricks фиксированный
function modifier_riki_tricks_of_the_trade_aa:GetModifierOverrideAttackDamage()
	local ab, parent = self:GetAbility(), self:GetParent()
	if not ab then return end
	local base = (parent:GetBaseDamageMin() + parent:GetBaseDamageMax()) / 2
	local agi = parent.GetAgility and parent:GetAgility() or 0
	return ab:GetSpecialValueFor("attack_damage")
		+ base * ab:GetSpecialValueFor("base_attack_damage_pct") / 100
		+ agi * ab:GetSpecialValueFor("agility_pct") / 100
end

function modifier_riki_tricks_of_the_trade_aa:OnCreated(kv)
	if not IsServer() then return end
	local parent = self:GetParent()
	self.center = Vector(kv.x, kv.y, kv.z)
	self.start = parent:GetAbsOrigin()
	self.radius = self:GetAbility():GetSpecialValueFor("radius")
	parent:AddNoDraw()

	self.fx = ParticleManager:CreateParticle(FX_AREA, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(self.fx, 0, self.center)
	ParticleManager:SetParticleControl(self.fx, 1, Vector(self.radius, self.radius, self.radius))
	ParticleManager:SetParticleControl(self.fx, 2, Vector(self:GetDuration(), 0, 0))
	parent:EmitSound("Hero_Riki.TricksOfTheTrade")

	self:StartIntervalThink(kv.interval)
	self:OnIntervalThink()
end

function modifier_riki_tricks_of_the_trade_aa:OnIntervalThink()
	local parent, ab = self:GetParent(), self:GetAbility()
	if not ab then self:Destroy() return end

	-- в аганиме зона едет с союзником
	if ab.ally and not ab.ally:IsNull() and ab.ally:IsAlive() then
		self.center = ab.ally:GetAbsOrigin()
		ParticleManager:SetParticleControl(self.fx, 0, self.center)
	end

	local units = FindUnitsInRadius(parent:GetTeamNumber(), self.center, nil, self.radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NO_INVIS + DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NOT_ATTACK_IMMUNE,
		FIND_ANY_ORDER, false)

	local heroes, creeps = {}, {}
	for _, u in ipairs(units) do
		if u:GetTeamNumber() == DOTA_TEAM_NEUTRALS and not u:IsHero() and not u.IsAngelArenaBoss then
			table.insert(creeps, u)
		else
			table.insert(heroes, u)
		end
	end

	-- герои и прочие (не нейтральные крипы) - до interval_targets случайных, крипы - все
	local targets = {}
	local limit = ab:GetSpecialValueFor("interval_targets")
	while #heroes > 0 and #targets < limit do
		table.insert(targets, table.remove(heroes, RandomInt(1, #heroes)))
	end
	for _, c in ipairs(creeps) do table.insert(targets, c) end

	for _, target in ipairs(targets) do
		-- встаём невидимым за спину цели: Backstab срабатывает сам
		local behind = target:GetAbsOrigin() - target:GetForwardVector() * 50
		parent:SetAbsOrigin(behind)
		parent:SetForwardVector((target:GetAbsOrigin() - behind):Normalized())
		parent:PerformAttack(target, true, true, true, true, false, false, true)
	end
	parent:SetAbsOrigin(self.center)
end

function modifier_riki_tricks_of_the_trade_aa:OnDestroy()
	if not IsServer() then return end
	local parent = self:GetParent()
	parent:RemoveNoDraw()
	parent:StopSound("Hero_Riki.TricksOfTheTrade")
	if self.fx then
		ParticleManager:DestroyParticle(self.fx, false)
		ParticleManager:ReleaseParticleIndex(self.fx)
	end
	FindClearSpaceForUnit(parent, self.center or parent:GetAbsOrigin(), true)
	local fx = ParticleManager:CreateParticle(FX_END, PATTACH_ABSORIGIN, parent)
	ParticleManager:ReleaseParticleIndex(fx)
	local ab = self:GetAbility()
	if ab and ab:IsChanneling() then parent:InterruptChannel() end
end

--------------------------------------------------------------------------------
-- Аганим: Рики спрятался в союзника

modifier_riki_tricks_of_the_trade_aa_ally = class({})

function modifier_riki_tricks_of_the_trade_aa_ally:IsPurgable() return false end
function modifier_riki_tricks_of_the_trade_aa_ally:GetTexture() return "riki_tricks_of_the_trade" end

function modifier_riki_tricks_of_the_trade_aa_ally:DeclareFunctions()
	return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end

function modifier_riki_tricks_of_the_trade_aa_ally:GetModifierMoveSpeedBonus_Percentage()
	local ab = self:GetAbility()
	return ab and ab:GetSpecialValueFor("scepter_movespeed") or 0
end
