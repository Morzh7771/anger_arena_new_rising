-- Fallen Sky (нейтральный, 5 разряд). Полностью на Lua, вместо движкового item_fallen_sky.
--
-- Как в доте: владелец превращается в метеор - исчезает с карты (неуязвим, скрыт, вне игры),
-- через land_time сек. метеор падает в точку (до AbilityCastRange), и владелец появляется на
-- месте падения. Никакого прыжка по дуге и запрета команд: во время полёта героя просто нет.
--   - при падении в радиусе impact_radius: стан врагов на stun_duration (с учётом статус-резиста),
--     урон юнитам и зданиям, горение на burn_duration (тик burn_interval);
--   - получив урон от вражеского героя, предмет уходит на перезарядку blink_damage_cooldown (как блинк).
--
-- Процентная часть (наша):
--   - падение по юнитам: impact_max_hp_pct % макс. HP цели (сверху к плоскому impact_damage_units);
--   - горение по юнитам: burn_max_hp_pct % макс. HP цели в секунду (сверху к плоскому burn_dps_units);
--   - боссы (BossSpawner:IsBoss): процентная часть = 25% от обычной; здания - только плоский урон.
--
-- Визуал: ванильный particles/items5_fx/fallen_sky.vpcf (метеор из точки взлёта в точку падения,
-- CP0 - старт, CP1 - точка падения, CP2.x - время полёта), звуки метеорхаммера, как у ванили.

LinkLuaModifier("modifier_item_fallen_sky_passive", "items/item_fallen_sky", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_fallen_sky_land", "items/item_fallen_sky", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_fallen_sky_stun", "items/item_fallen_sky", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_fallen_sky_burn", "items/item_fallen_sky", LUA_MODIFIER_MOTION_NONE)

item_fallen_sky = class({})

local BOSS_PCT_MULT = 0.25
local FX_METEOR = "particles/items4_fx/meteor_hammer_spell.vpcf" -- CP0 небо, CP1 земля, CP2 время падения
local FX_BURN = "particles/items4_fx/meteor_hammer_spell_debuff.vpcf"

-- процент макс. HP цели с учётом боссов
local function MaxHpPart(target, pct)
	if not target or target:IsNull() or pct == 0 then return 0 end
	local mult = (BossSpawner and BossSpawner.IsBoss and BossSpawner:IsBoss(target)) and BOSS_PCT_MULT or 1
	return target:GetMaxHealth() * pct / 100 * mult
end

function item_fallen_sky:Precache(context)
	PrecacheResource("particle", FX_METEOR, context)
	PrecacheResource("particle", FX_BURN, context)
	PrecacheResource("particle", "particles/generic_gameplay/generic_stunned.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_items.vsndevts", context)
end

function item_fallen_sky:GetIntrinsicModifierName()
	return "modifier_item_fallen_sky_passive"
end

function item_fallen_sky:GetAOERadius()
	return self:GetSpecialValueFor("impact_radius")
end

function item_fallen_sky:OnSpellStart()
	local caster = self:GetCaster()
	local start_pos = caster:GetAbsOrigin()
	local point = self:GetCursorPosition()

	local dir = point - start_pos
	dir.z = 0
	local dist = math.min(dir:Length2D(), self:GetCastRange(point, nil) + caster:GetCastRangeBonus())
	local landing = dist > 0 and (start_pos + dir:Normalized() * dist) or start_pos
	landing = GetGroundPosition(landing, caster)

	local land_time = self:GetSpecialValueFor("land_time")

	caster:EmitSound("DOTA_Item.MeteorHammer.Cast")
	EmitSoundOnLocationWithCaster(landing, "DOTA_Item.MeteorHammer.Channel", caster)

	local fx = ParticleManager:CreateParticle(FX_METEOR, PATTACH_WORLDORIGIN, nil)
	-- метеор (герой) падает с неба в точку приземления; в точке взлёта эффектов нет
	ParticleManager:SetParticleControl(fx, 0, landing + Vector(0, 0, 1000))
	ParticleManager:SetParticleControl(fx, 1, landing)
	ParticleManager:SetParticleControl(fx, 2, Vector(land_time, 0, 0))
	ParticleManager:ReleaseParticleIndex(fx)

	caster:AddNewModifier(caster, self, "modifier_item_fallen_sky_land", {
		duration = land_time,
		x = landing.x, y = landing.y, z = landing.z,
	})
	-- герой уже скрыт модификатором: переносим сразу, при приземлении он только проявляется
	caster:SetAbsOrigin(landing)
	self.fallen_landing = landing
end

function item_fallen_sky:Land(point)
	local caster = self:GetCaster()
	local radius = self:GetSpecialValueFor("impact_radius")
	local stun_duration = self:GetSpecialValueFor("stun_duration")
	local burn_duration = self:GetSpecialValueFor("burn_duration")
	local impact_flat_units = self:GetSpecialValueFor("impact_damage_units")
	local impact_flat_buildings = self:GetSpecialValueFor("impact_damage_buildings")
	local impact_pct = self:GetSpecialValueFor("impact_max_hp_pct")

	caster:StopSound("DOTA_Item.MeteorHammer.Channel")
	EmitSoundOnLocationWithCaster(point, "DOTA_Item.MeteorHammer.Impact", caster)
	GridNav:DestroyTreesAroundPoint(point, radius, true)

	local units = FindUnitsInRadius(caster:GetTeamNumber(), point, nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, bit.bor(DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_BASIC),
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

	for _, enemy in pairs(units) do
		if enemy and not enemy:IsNull() then
			enemy:AddNewModifier(caster, self, "modifier_item_fallen_sky_burn", { duration = burn_duration })

			local stun = stun_duration * (1 - enemy:GetStatusResistance())
			enemy:AddNewModifier(caster, self, "modifier_item_fallen_sky_stun", { duration = stun })

			if enemy:IsAlive() then
				ApplyDamage({
					victim = enemy,
					attacker = caster,
					damage = impact_flat_units + MaxHpPart(enemy, impact_pct),
					damage_type = DAMAGE_TYPE_MAGICAL,
					ability = self,
				})
			end
		end
	end

	local buildings = FindUnitsInRadius(caster:GetTeamNumber(), point, nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_BUILDING,
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

	for _, building in pairs(buildings) do
		if building and not building:IsNull() then
			building:AddNewModifier(caster, self, "modifier_item_fallen_sky_burn", { duration = burn_duration })

			if building:IsAlive() then
				ApplyDamage({
					victim = building,
					attacker = caster,
					damage = impact_flat_buildings,
					damage_type = DAMAGE_TYPE_MAGICAL,
					ability = self,
				})
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Пассивка: статы из KV + перезарядка после урона от вражеского героя (как у ванили).

modifier_item_fallen_sky_passive = class({})

function modifier_item_fallen_sky_passive:IsHidden() return true end
function modifier_item_fallen_sky_passive:IsPurgable() return false end
function modifier_item_fallen_sky_passive:RemoveOnDeath() return false end
function modifier_item_fallen_sky_passive:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end

function modifier_item_fallen_sky_passive:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
		MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
		MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
	}
end

function modifier_item_fallen_sky_passive:GetModifierBonusStats_Strength()
	return self:GetAbility() and self:GetAbility():GetSpecialValueFor("bonus_strength") or 0
end

function modifier_item_fallen_sky_passive:GetModifierBonusStats_Intellect()
	return self:GetAbility() and self:GetAbility():GetSpecialValueFor("bonus_intellect") or 0
end

function modifier_item_fallen_sky_passive:GetModifierConstantHealthRegen()
	return self:GetAbility() and self:GetAbility():GetSpecialValueFor("bonus_health_regen") or 0
end

function modifier_item_fallen_sky_passive:GetModifierConstantManaRegen()
	return self:GetAbility() and self:GetAbility():GetSpecialValueFor("bonus_mana_regen") or 0
end

function modifier_item_fallen_sky_passive:OnTakeDamage(params)
	if not IsServer() then return end
	local parent = self:GetParent()
	local ability = self:GetAbility()
	if params.unit ~= parent or not ability or ability:IsNull() then return end
	local attacker = params.attacker
	if not attacker or attacker:IsNull() or attacker:GetTeamNumber() == parent:GetTeamNumber() then return end
	if not attacker:IsRealHero() and not attacker:IsConsideredHero() then return end
	if params.damage <= 0 then return end

	local cd = ability:GetSpecialValueFor("blink_damage_cooldown")
	if cd > 0 and ability:GetCooldownTimeRemaining() < cd then
		ability:EndCooldown()
		ability:StartCooldown(cd)
	end
end

---------------------------------------------------------------------------------------------------
-- Полёт метеором: героя нет на карте, он неуязвим и недоступен, по окончании - падение.

modifier_item_fallen_sky_land = class({})

function modifier_item_fallen_sky_land:IsHidden() return false end
function modifier_item_fallen_sky_land:IsPurgable() return false end
function modifier_item_fallen_sky_land:GetTexture() return "item_fallen_sky" end

function modifier_item_fallen_sky_land:OnCreated(kv)
	if not IsServer() then return end
	self.landing = Vector(kv.x or 0, kv.y or 0, kv.z or 0)
	local parent = self:GetParent()
	parent:Stop()
	ProjectileManager:ProjectileDodge(parent)
	parent:AddNoDraw()
end

function modifier_item_fallen_sky_land:OnDestroy()
	if not IsServer() then return end
	local parent = self:GetParent()
	if not parent or parent:IsNull() then return end
	parent:RemoveNoDraw()
	if not parent:IsAlive() then return end

	local ability = self:GetAbility()
	local landing = self.landing
	if (not landing or landing:Length2D() == 0) and ability and not ability:IsNull() and ability.fallen_landing then
		landing = ability.fallen_landing
	end
	FindClearSpaceForUnit(parent, landing, true)
	parent:Stop()

	if ability and not ability:IsNull() then
		ability:Land(landing)
	end
end

function modifier_item_fallen_sky_land:CheckState()
	return {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_OUT_OF_GAME] = true,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_UNTARGETABLE] = true,
		[MODIFIER_STATE_NOT_ON_MINIMAP_FOR_ENEMIES] = true,
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_SILENCED] = true,
		[MODIFIER_STATE_MUTED] = true,
	}
end

---------------------------------------------------------------------------------------------------

modifier_item_fallen_sky_stun = class({})

function modifier_item_fallen_sky_stun:IsDebuff() return true end
function modifier_item_fallen_sky_stun:IsStunDebuff() return true end
function modifier_item_fallen_sky_stun:IsPurgable() return true end
function modifier_item_fallen_sky_stun:GetTexture() return "item_fallen_sky" end
function modifier_item_fallen_sky_stun:GetEffectName() return "particles/generic_gameplay/generic_stunned.vpcf" end
function modifier_item_fallen_sky_stun:GetEffectAttachType() return PATTACH_OVERHEAD_FOLLOW end

function modifier_item_fallen_sky_stun:DeclareFunctions()
	return { MODIFIER_PROPERTY_OVERRIDE_ANIMATION }
end

function modifier_item_fallen_sky_stun:GetOverrideAnimation() return ACT_DOTA_DISABLED end

function modifier_item_fallen_sky_stun:CheckState()
	return {
		[MODIFIER_STATE_STUNNED] = true,
	}
end

---------------------------------------------------------------------------------------------------

modifier_item_fallen_sky_burn = class({})

function modifier_item_fallen_sky_burn:IsDebuff() return true end
function modifier_item_fallen_sky_burn:IsPurgable()
	local p = self:GetParent()
	return not (p.IsBoss and p:IsBoss())
end
function modifier_item_fallen_sky_burn:GetTexture() return "item_fallen_sky" end
function modifier_item_fallen_sky_burn:GetEffectName() return FX_BURN end
function modifier_item_fallen_sky_burn:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_item_fallen_sky_burn:OnCreated()
	if not IsServer() then return end

	local ability = self:GetAbility()
	self.interval = ability:GetSpecialValueFor("burn_interval")

	if self:GetParent():IsBuilding() then
		self.dps = ability:GetSpecialValueFor("burn_dps_buildings")
		self.pct = 0
	else
		self.dps = ability:GetSpecialValueFor("burn_dps_units")
		self.pct = ability:GetSpecialValueFor("burn_max_hp_pct")
	end

	self:OnIntervalThink()
	self:StartIntervalThink(self.interval)
end

function modifier_item_fallen_sky_burn:OnIntervalThink()
	if not IsServer() then return end

	local ability = self:GetAbility()
	local parent = self:GetParent()
	if not ability or ability:IsNull() or not parent or parent:IsNull() or not parent:IsAlive() then return end

	local damage = self.dps * self.interval + MaxHpPart(parent, self.pct) * self.interval

	ApplyDamage({
		victim = parent,
		attacker = self:GetCaster(),
		damage = damage,
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = ability,
	})
end
