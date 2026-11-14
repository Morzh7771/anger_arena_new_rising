-- Лечащая лужа захваченной вышки.
--
-- Отдельная способность башни (Ability3 у npc_dota_custom_tower, KV -
-- "tower_capture_pool" в npc_abilities_custom.txt). Сама ничего не делает,
-- пока её не включит захват вышки: tower_base.lua зовёт Activate() в момент,
-- когда башня сменила команду.
--
-- Пока лужа жива, союзным героям в радиусе капает лечение: процент от их
-- максимального здоровья плюс плоская добавка, раз в interval секунд.

LinkLuaModifier("tower_capture_pool_aura", "lib/tower/tower_capture_pool", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("tower_capture_pool_heal", "lib/tower/tower_capture_pool", LUA_MODIFIER_MOTION_NONE)

-- Эффекты торментора: светящийся круг на земле от его приземления и искры
-- его ямы. Круг задаёт размер лужи, искры добавляют жизни.
local POOL_PARTICLES = {
	"particles/neutral_fx/miniboss_spawner_effect_ground_decal.vpcf",
	"particles/neutral_fx/miniboss_pit_sparkle.vpcf",
}

-- лечение на самом герое, чтобы было видно, кого лужа лечит
local HEAL_PARTICLE = "particles/items2_fx/tranquil_boots_heal.vpcf"

tower_capture_pool = class{}

function tower_capture_pool:GetIntrinsicModifierName()
	return nil
end

function tower_capture_pool:Precache(context)
	for _, path in ipairs(POOL_PARTICLES) do
		PrecacheResource("particle", path, context)
	end

	PrecacheResource("particle", HEAL_PARTICLE, context)
end

-- Зовёт tower_base.lua при захвате вышки (Activate занят движком)
function tower_capture_pool:ActivatePool()
	if not IsServer() then return end

	local caster = self:GetCaster()

	if not caster or caster:IsNull() then return end

	-- у вышек в KV нет уровня, а на нулевом GetSpecialValueFor отдаёт 0
	if self:GetLevel() < 1 then self:SetLevel(1) end

	caster:AddNewModifier(caster, self, "tower_capture_pool_aura", {
		duration = self:GetSpecialValueFor("duration"),
	})
end

--------------------------------------------------------------------------------
-- аура лужи: висит на самой вышке, раздаёт лечащий баф союзным героям
--------------------------------------------------------------------------------

tower_capture_pool_aura = class{
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return false end,
	IsAura = function(self) return true end,
	GetModifierAura = function(self) return "tower_capture_pool_heal" end,
	GetAuraSearchTeam = function(self) return DOTA_UNIT_TARGET_TEAM_FRIENDLY end,
	GetAuraSearchType = function(self) return DOTA_UNIT_TARGET_HERO end,
	GetAuraRadius = function(self) return self.radius or 600 end,
	GetEffectAttachType = function(self) return PATTACH_ABSORIGIN_FOLLOW end,
}

function tower_capture_pool_aura:OnCreated()
	local ability = self:GetAbility()

	self.radius = ability and ability:GetSpecialValueFor("radius") or 600

	if self.radius <= 0 then self.radius = 600 end

	if not IsServer() then return end

	local parent = self:GetParent()
	local origin = parent:GetAbsOrigin()

	self.fx = {}

	for _, path in ipairs(POOL_PARTICLES) do
		local fx = ParticleManager:CreateParticle(path, PATTACH_CUSTOMORIGIN, parent)

		ParticleManager:SetParticleControl(fx, 0, origin)
		-- у эффектов торментора размер круга задаётся радиусом в CP1 и CP3
		ParticleManager:SetParticleControl(fx, 1, Vector(self.radius, self.radius, self.radius))
		ParticleManager:SetParticleControl(fx, 3, Vector(self.radius, self.radius, self.radius))

		table.insert(self.fx, fx)
	end
end

function tower_capture_pool_aura:OnDestroy()
	if not IsServer() or not self.fx then return end

	for _, fx in ipairs(self.fx) do
		ParticleManager:DestroyParticle(fx, false)
		ParticleManager:ReleaseParticleIndex(fx)
	end
end

--------------------------------------------------------------------------------
-- лечащий баф на герое в радиусе
--------------------------------------------------------------------------------

tower_capture_pool_heal = class{
	IsPurgable = function(self) return false end,
}

function tower_capture_pool_heal:OnCreated()
	if not IsServer() then return end

	local ability = self:GetAbility()

	self.pct = ability and ability:GetSpecialValueFor("heal_pct") or 1
	self.flat = ability and ability:GetSpecialValueFor("heal_flat") or 10

	local interval = ability and ability:GetSpecialValueFor("interval") or 1

	if interval <= 0 then interval = 1 end

	self:StartIntervalThink(interval)
	self:OnIntervalThink()
end

function tower_capture_pool_heal:OnIntervalThink()
	local parent = self:GetParent()

	if not parent or parent:IsNull() or not parent:IsAlive() then return end

	parent:Heal(parent:GetMaxHealth() * self.pct / 100 + self.flat, self:GetAbility())

	local fx = ParticleManager:CreateParticle(HEAL_PARTICLE, PATTACH_ABSORIGIN_FOLLOW, parent)

	ParticleManager:ReleaseParticleIndex(fx)
end
