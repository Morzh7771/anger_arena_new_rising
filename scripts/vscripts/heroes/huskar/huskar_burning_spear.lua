-- Huskar: Burning Spear на Lua (2026-11-22). Нужен перенос стаков копий на соседа.
-- Как в доте: автокаст или ручное применение, копьё стоит health_cost% текущего
-- + max_health_cost% макс. здоровья (не убивает), стак жжёт burn_damage +
-- burn_damage_max_pct% макс. здоровья цели в секунду, каждое попадание вешает стак горения на duration сек (у каждого стака
-- своя длительность), стак жжёт burn_damage магического урона в секунду.
-- Против крипов: если крип умирает под копьями, все его стаки с оставшейся
-- длительностью переходят на ближайшего крипа в creep_spread_radius.

huskar_burning_spear = class({})

LinkLuaModifier("modifier_huskar_burning_spear_aa", "heroes/huskar/huskar_burning_spear", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_huskar_burning_spear_aa_debuff", "heroes/huskar/huskar_burning_spear", LUA_MODIFIER_MOTION_NONE)

local PROJECTILE = "particles/units/heroes/hero_huskar/huskar_burning_spear.vpcf"
local DEBUFF_FX = "particles/units/heroes/hero_huskar/huskar_burning_spear_debuff.vpcf"
local TICK = 0.5

function huskar_burning_spear:Precache(context)
	PrecacheResource("particle", PROJECTILE, context)
	PrecacheResource("particle", DEBUFF_FX, context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_huskar.vsndevts", context)
end

function huskar_burning_spear:GetIntrinsicModifierName()
	return "modifier_huskar_burning_spear_aa"
end

function huskar_burning_spear:GetCastRange(location, target)
	return self:GetCaster():Script_GetAttackRange()
end

function huskar_burning_spear:OnSpellStart()
	self.manual = true
	self:GetCaster():MoveToTargetToAttack(self:GetCursorTarget())
end

-- повесить на цель стаки с заданными длительностями
function huskar_burning_spear:AddStacks(target, durations)
	local caster = self:GetCaster()
	local mod = target:FindModifierByNameAndCaster("modifier_huskar_burning_spear_aa_debuff", caster)
	if not mod then
		mod = target:AddNewModifier(caster, self, "modifier_huskar_burning_spear_aa_debuff", {})
	end
	if not mod then return end
	local now = GameRules:GetGameTime()
	for _, d in ipairs(durations) do table.insert(mod.expires, now + d) end
	mod:Sync()
end

--------------------------------------------------------------------------------
-- Орб копий на Хускаре

modifier_huskar_burning_spear_aa = class({})

function modifier_huskar_burning_spear_aa:IsHidden() return true end
function modifier_huskar_burning_spear_aa:IsPurgable() return false end

function modifier_huskar_burning_spear_aa:OnCreated()
	self.records = {}
end

function modifier_huskar_burning_spear_aa:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ATTACK_RECORD,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
		MODIFIER_EVENT_ON_ATTACK_RECORD_DESTROY,
		MODIFIER_PROPERTY_PROJECTILE_NAME,
	}
end

function modifier_huskar_burning_spear_aa:WillFire()
	local ab = self:GetAbility()
	if not ab or ab:GetLevel() <= 0 or self:GetParent():IsSilenced() then return false end
	return ab.manual or ab:GetAutoCastState()
end

function modifier_huskar_burning_spear_aa:GetModifierProjectileName()
	if self:WillFire() then return PROJECTILE end
end

function modifier_huskar_burning_spear_aa:OnAttackRecord(params)
	if not IsServer() or params.attacker ~= self:GetParent() or self:GetParent():IsIllusion() then return end
	if not params.target or params.target:IsBuilding() or not self:WillFire() then return end
	local ab = self:GetAbility()
	ab.manual = nil
	local parent = self:GetParent()
	local cost = parent:GetHealth() * ab:GetSpecialValueFor("health_cost") / 100
		+ parent:GetMaxHealth() * ab:GetSpecialValueFor("max_health_cost") / 100
	parent:ModifyHealth(math.max(1, parent:GetHealth() - cost), ab, false, 0)
	self.records[params.record] = true
	parent:EmitSound("Hero_Huskar.Burning_Spear.Cast")
end

function modifier_huskar_burning_spear_aa:OnAttackLanded(params)
	if not IsServer() or params.attacker ~= self:GetParent() or not self.records[params.record] then return end
	local ab = self:GetAbility()
	ab:AddStacks(params.target, { ab:GetSpecialValueFor("duration") })
	params.target:EmitSound("Hero_Huskar.Burning_Spear")
end

function modifier_huskar_burning_spear_aa:OnAttackRecordDestroy(params)
	if self.records then self.records[params.record] = nil end
end

--------------------------------------------------------------------------------
-- Горение на цели: список стаков со своими сроками

modifier_huskar_burning_spear_aa_debuff = class({})

function modifier_huskar_burning_spear_aa_debuff:IsDebuff() return true end
function modifier_huskar_burning_spear_aa_debuff:IsPurgable() return false end
function modifier_huskar_burning_spear_aa_debuff:GetTexture() return "huskar_burning_spear" end
function modifier_huskar_burning_spear_aa_debuff:GetEffectName() return DEBUFF_FX end
function modifier_huskar_burning_spear_aa_debuff:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_huskar_burning_spear_aa_debuff:DeclareFunctions()
	return { MODIFIER_EVENT_ON_DEATH, MODIFIER_PROPERTY_TOOLTIP }
end

function modifier_huskar_burning_spear_aa_debuff:OnTooltip()
	local ab = self:GetAbility()
	return ab and ab:GetSpecialValueFor("burn_damage") * self:GetStackCount() or 0
end

function modifier_huskar_burning_spear_aa_debuff:OnCreated()
	if not IsServer() then return end
	self.expires = {}
	self:StartIntervalThink(TICK)
end

-- выкинуть истёкшие стаки, обновить счётчик и длительность
function modifier_huskar_burning_spear_aa_debuff:Sync()
	local now = GameRules:GetGameTime()
	local keep, last = {}, now
	for _, t in ipairs(self.expires) do
		if t > now then table.insert(keep, t) last = math.max(last, t) end
	end
	self.expires = keep
	if #keep == 0 then self:Destroy() return end
	self:SetStackCount(#keep)
	self:SetDuration(last - now, true)
end

function modifier_huskar_burning_spear_aa_debuff:OnIntervalThink()
	local caster, ab = self:GetCaster(), self:GetAbility()
	if not caster or caster:IsNull() or not ab then self:Destroy() return end
	self:Sync()
	if self:IsNull() then return end
	ApplyDamage({ victim = self:GetParent(), attacker = caster,
		damage = (ab:GetSpecialValueFor("burn_damage")
			+ self:GetParent():GetMaxHealth() * ab:GetSpecialValueFor("burn_damage_max_pct") / 100) * self:GetStackCount() * TICK,
		damage_type = DAMAGE_TYPE_MAGICAL, ability = ab })
end

function modifier_huskar_burning_spear_aa_debuff:OnDeath(params)
	if not IsServer() or params.unit ~= self:GetParent() then return end
	local parent, ab = self:GetParent(), self:GetAbility()
	if not ab or parent:GetTeamNumber() ~= DOTA_TEAM_NEUTRALS or parent:IsHero() or parent.IsAngelArenaBoss then return end

	local now = GameRules:GetGameTime()
	local left = {}
	for _, t in ipairs(self.expires or {}) do
		if t > now then table.insert(left, t - now) end
	end
	if #left == 0 then return end

	local units = FindUnitsInRadius(self:GetCaster():GetTeamNumber(), parent:GetAbsOrigin(), nil,
		ab:GetSpecialValueFor("creep_spread_radius"), DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_CLOSEST, false)
	for _, u in ipairs(units) do
		if u ~= parent and u:IsAlive() and u:GetTeamNumber() == DOTA_TEAM_NEUTRALS and not u.IsAngelArenaBoss then
			ab:AddStacks(u, left)
			local fx = ParticleManager:CreateParticle("particles/units/heroes/hero_huskar/huskar_burning_spear_launch.vpcf", PATTACH_CUSTOMORIGIN, nil)
			ParticleManager:SetParticleControl(fx, 0, parent:GetAbsOrigin())
			ParticleManager:SetParticleControlEnt(fx, 1, u, PATTACH_POINT_FOLLOW, "attach_hitloc", u:GetAbsOrigin(), true)
			ParticleManager:ReleaseParticleIndex(fx)
			return
		end
	end
end
