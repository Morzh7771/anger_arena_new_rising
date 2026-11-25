--[[
	Supernova Феникса на Lua. Имя способности ванильное: иконка, тексты, таланты
	и % урона от макс. здоровья (lib/percent_damage.lua) остаются дотовские.

	Отличия от доты:
	  - сегментов у яйца: max_hero_attacks + 1 за каждые hp_per_extra_attack
	    макс. здоровья Феникса; удары видны делениями полоски здоровья;
	  - без аганима сломанное яйцо убивает Феникса (как в доте);
	  - с аганимом (можно взять союзника) сломанное яйцо выплёвывает всех, кто внутри:
	    здоровье какое успело набраться, ничего не обновляется, spit_invuln_duration
	    неуязвимости;
	  - с аганим-шардом из яйца работают Sun Ray и его переключатели (луч идёт из яйца).
]]

LinkLuaModifier("modifier_phoenix_supernova_aa_hidden", "heroes/phoenix/phoenix_supernova_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_phoenix_supernova_aa_egg", "heroes/phoenix/phoenix_supernova_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_phoenix_supernova_aa_burn", "heroes/phoenix/phoenix_supernova_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_phoenix_supernova_aa_spit", "heroes/phoenix/phoenix_supernova_aa", LUA_MODIFIER_MOTION_NONE)

-- способности, которые остаются рабочими в яйце при шарде
local HIT_HP = 4

local SUN_RAY_ABILITIES = {
	phoenix_sun_ray = true,
	phoenix_sun_ray_stop = true,
	phoenix_sun_ray_toggle_move = true,
}

phoenix_supernova = phoenix_supernova or class({})

function phoenix_supernova:GetBehavior()
	if self:GetCaster():HasScepter() then
		return DOTA_ABILITY_BEHAVIOR_UNIT_TARGET + DOTA_ABILITY_BEHAVIOR_DONT_RESUME_ATTACK
	end
	return DOTA_ABILITY_BEHAVIOR_NO_TARGET + DOTA_ABILITY_BEHAVIOR_DONT_RESUME_ATTACK
end

function phoenix_supernova:GetCastRange(location, target)
	if self:GetCaster():HasScepter() then
		return self.BaseClass.GetCastRange(self, location, target)
	end
	return 0
end

function phoenix_supernova:GetAOERadius()
	return self:GetSpecialValueFor("aura_radius")
end

function phoenix_supernova:CastFilterResultTarget(target)
	local caster = self:GetCaster()
	if target == caster then return UF_SUCCESS end
	return UnitFilter(target, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_NOT_CREEP_HERO + DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS, caster:GetTeamNumber())
end

function phoenix_supernova:GetHitCount()
	local caster = self:GetCaster()
	local hits = self:GetSpecialValueFor("max_hero_attacks") -- аганим добавляет через special_bonus_scepter
	local per_hp = self:GetSpecialValueFor("hp_per_extra_attack")
	if per_hp > 0 then
		hits = hits + math.floor(caster:GetMaxHealth() / per_hp)
	end
	return math.max(1, hits)
end

function phoenix_supernova:OnSpellStart()
	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()
	local duration = self:GetSpecialValueFor("egg_duration")
	if duration <= 0 then duration = self:GetDuration() end

	-- кто садится в яйцо
	local inside = { caster }
	local target = self:GetCursorTarget()
	if caster:HasScepter() and target and target ~= caster and target:IsAlive() then
		table.insert(inside, target)
	end

	local egg = CreateUnitByName("npc_dota_phoenix_sun", origin, false, caster, caster, caster:GetTeamNumber())
	if not egg then return end

	-- бафф от статов хозяина ломает счёт ударов
	egg:RemoveModifierByName("modifier_summon_power")
	if egg:HasAbility("summon_power_passive") then egg:RemoveAbility("summon_power_passive") end
	egg:SetOwner(caster)

	local egg_mod = egg:AddNewModifier(caster, self, "modifier_phoenix_supernova_aa_egg", {
		duration = duration,
		hits = self:GetHitCount(),
		scepter = caster:HasScepter() and 1 or 0,
	})
	if not egg_mod then
		UTIL_Remove(egg)
		return
	end

	local shard = caster:HasModifier("modifier_item_aghanims_shard")
	for _, unit in ipairs(inside) do
		egg_mod:AddInside(unit, unit == caster and shard)
	end
end

--------------------------------------------------------------------------------
-- Яйцо
--------------------------------------------------------------------------------
modifier_phoenix_supernova_aa_egg = class({})

function modifier_phoenix_supernova_aa_egg:IsHidden() return true end
function modifier_phoenix_supernova_aa_egg:IsPurgable() return false end

function modifier_phoenix_supernova_aa_egg:IsAura() return true end
function modifier_phoenix_supernova_aa_egg:GetAuraSearchTeam() return DOTA_UNIT_TARGET_TEAM_ENEMY end
function modifier_phoenix_supernova_aa_egg:GetAuraSearchType() return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end
function modifier_phoenix_supernova_aa_egg:GetAuraRadius() return self.radius end
function modifier_phoenix_supernova_aa_egg:GetModifierAura() return "modifier_phoenix_supernova_aa_burn" end

function modifier_phoenix_supernova_aa_egg:OnCreated(kv)
	local ability = self:GetAbility()
	self.radius = ability and ability:GetSpecialValueFor("aura_radius") or 0
	if not IsServer() then return end

	self.dps = ability:GetSpecialValueFor("damage_per_sec")
	self.hp_pct = ability:GetSpecialValueFor("max_health_damage_pct") -- % макс. здоровья Феникса в секунду
	self.interval = math.max(0.1, ability:GetSpecialValueFor("tick_interval"))
	self.stun = ability:GetSpecialValueFor("stun_duration")
	self.spit_invuln = ability:GetSpecialValueFor("spit_invuln_duration")
	self.scepter = (kv.scepter or 0) == 1
	self.inside = {}

	local egg = self:GetParent()
	local hits = math.max(1, kv.hits or 1)
	self:SetStackCount(hits)
	-- сегмент = HIT_HP здоровья: удар героя снимает сегмент, крипа и иллюзии - четверть (как в доте)
	egg:SetBaseMaxHealth(hits * HIT_HP)
	egg:SetMaxHealth(hits * HIT_HP)
	egg:SetHealth(hits * HIT_HP)

	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_phoenix/phoenix_supernova_egg.vpcf", PATTACH_ABSORIGIN_FOLLOW, egg)
	ParticleManager:SetParticleControlEnt(pfx, 1, egg, PATTACH_POINT_FOLLOW, "attach_hitloc", egg:GetAbsOrigin(), true)
	self:AddParticle(pfx, false, false, -1, false, false)

	egg:EmitSound("Hero_Phoenix.SuperNova.Begin")
	egg:EmitSound("Hero_Phoenix.SuperNova.Cast")
	GridNav:DestroyTreesAroundPoint(egg:GetAbsOrigin(), 500, false)
	AddFOWViewer(egg:GetTeamNumber(), egg:GetAbsOrigin(), self.radius, self:GetRemainingTime() + 0.5, false)

	self:StartIntervalThink(self.interval)
end

-- посадить героя в яйцо; allow_sun_ray - Феникс с шардом
function modifier_phoenix_supernova_aa_egg:AddInside(unit, allow_sun_ray)
	local egg = self:GetParent()

	-- прерываем то, что тащит героя прочь от яйца
	unit:RemoveModifierByName("modifier_phoenix_icarus_dive_aa")
	if not allow_sun_ray then
		unit:RemoveModifierByName("modifier_phoenix_sun_ray_aa")
	end
	unit:Stop()
	unit:Purge(false, true, false, true, true) -- сильное развеивание, как в доте
	FindClearSpaceForUnit(unit, egg:GetAbsOrigin(), false)
	unit:SetAbsOrigin(egg:GetAbsOrigin())

	local mod = unit:AddNewModifier(self:GetCaster(), self:GetAbility(), "modifier_phoenix_supernova_aa_hidden", {
		duration = self:GetRemainingTime() + 1,
		sun_ray = allow_sun_ray and 1 or 0,
	})
	if mod then
		mod.egg = egg
		table.insert(self.inside, unit)
	end
end

function modifier_phoenix_supernova_aa_egg:OnIntervalThink()
	local egg = self:GetParent()
	local caster = self:GetCaster()
	local ability = self:GetAbility()
	if not caster or caster:IsNull() then return end

	for _, enemy in pairs(FindUnitsInRadius(caster:GetTeamNumber(), egg:GetAbsOrigin(), nil, self.radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)) do
		ApplyDamage({
			victim = enemy,
			attacker = caster,
			damage = (self.dps + caster:GetMaxHealth() * self.hp_pct / 100) * self.interval,
			damage_type = DAMAGE_TYPE_MAGICAL,
			ability = ability,
		})
	end
end

function modifier_phoenix_supernova_aa_egg:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL,
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL,
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE,
		MODIFIER_PROPERTY_HEALTHBAR_PIPS,
		MODIFIER_PROPERTY_DISABLE_HEALING,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end

function modifier_phoenix_supernova_aa_egg:GetAbsoluteNoDamagePhysical() return 1 end
function modifier_phoenix_supernova_aa_egg:GetAbsoluteNoDamageMagical() return 1 end
function modifier_phoenix_supernova_aa_egg:GetAbsoluteNoDamagePure() return 1 end
function modifier_phoenix_supernova_aa_egg:GetDisableHealing() return 1 end

-- деления = максимум ударов (здоровье яйца равно числу ударов)
function modifier_phoenix_supernova_aa_egg:GetModifierHealthBarPips()
	return self:GetStackCount()
end

function modifier_phoenix_supernova_aa_egg:CheckState()
	return {
		[MODIFIER_STATE_MAGIC_IMMUNE] = true,
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_ROOTED] = true,
	}
end

function modifier_phoenix_supernova_aa_egg:OnAttackLanded(params)
	if not IsServer() then return end
	local egg = self:GetParent()
	if params.target ~= egg or self.finished then return end

	local attacker = params.attacker
	if not attacker or attacker:IsNull() then return end
	local dmg = (attacker:IsRealHero() and not attacker:IsIllusion()) and HIT_HP or 1

	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_phoenix/phoenix_supernova_hit.vpcf", PATTACH_POINT_FOLLOW, egg)
	ParticleManager:SetParticleControlEnt(pfx, 0, egg, PATTACH_POINT_FOLLOW, "attach_hitloc", egg:GetAbsOrigin(), true)
	ParticleManager:SetParticleControlEnt(pfx, 1, egg, PATTACH_POINT_FOLLOW, "attach_hitloc", egg:GetAbsOrigin(), true)
	ParticleManager:ReleaseParticleIndex(pfx)

	local hp = egg:GetHealth() - dmg
	if hp > 0 then
		egg:SetHealth(hp)
	else
		self:Break(attacker)
	end
end

-- выпустить всех из яйца (снять скрытие)
function modifier_phoenix_supernova_aa_egg:ReleaseAll()
	for _, unit in ipairs(self.inside) do
		if unit and not unit:IsNull() then
			unit:RemoveModifierByName("modifier_phoenix_supernova_aa_hidden")
		end
	end
end

-- яйцо сломали
function modifier_phoenix_supernova_aa_egg:Break(killer)
	self.finished = true
	local egg = self:GetParent()
	local pos = egg:GetAbsOrigin()

	egg:StopSound("Hero_Phoenix.SuperNova.Begin")
	egg:StopSound("Hero_Phoenix.SuperNova.Cast")
	EmitSoundOnLocationWithCaster(pos, "Hero_Phoenix.SuperNova.Death", egg)

	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_phoenix/phoenix_supernova_death.vpcf", PATTACH_WORLDORIGIN, nil)
	local hit = pos + Vector(0, 0, 128)
	ParticleManager:SetParticleControl(pfx, 0, hit)
	ParticleManager:SetParticleControl(pfx, 1, hit)
	ParticleManager:SetParticleControl(pfx, 3, hit)
	ParticleManager:ReleaseParticleIndex(pfx)

	self:ReleaseAll()

	for _, unit in ipairs(self.inside) do
		if unit and not unit:IsNull() and unit:IsAlive() then
			if self.scepter then
				-- выплёвываем: здоровье как есть, ничего не обновляем
				FindClearSpaceForUnit(unit, pos, true)
				unit:AddNewModifier(self:GetCaster(), self:GetAbility(), "modifier_phoenix_supernova_aa_spit", { duration = self.spit_invuln })
			else
				unit:Kill(self:GetAbility(), killer)
			end
		end
	end

	egg:AddNoDraw()
	self:Destroy()
end

-- яйцо дожило до конца
function modifier_phoenix_supernova_aa_egg:Reborn()
	self.finished = true
	local egg = self:GetParent()
	local caster = self:GetCaster()
	local ability = self:GetAbility()
	local pos = egg:GetAbsOrigin()

	EmitSoundOnLocationWithCaster(pos, "Hero_Phoenix.SuperNova.Explode", egg)
	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_phoenix/phoenix_supernova_reborn.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(pfx, 0, pos)
	ParticleManager:SetParticleControl(pfx, 1, Vector(1.5, 1.5, 1.5))
	ParticleManager:SetParticleControl(pfx, 3, pos)
	ParticleManager:ReleaseParticleIndex(pfx)

	self:ReleaseAll()

	for _, unit in ipairs(self.inside) do
		if unit and not unit:IsNull() and unit:IsAlive() then
			FindClearSpaceForUnit(unit, pos, true)
			unit:SetHealth(unit:GetMaxHealth())
			unit:SetMana(unit:GetMaxMana())
			-- обновляем способности, кроме самой ульты Феникса
			for i = 0, unit:GetAbilityCount() - 1 do
				local a = unit:GetAbilityByIndex(i)
				if a and a ~= ability then
					a:EndCooldown()
				end
			end
		end
	end

	if caster and not caster:IsNull() then
		for _, enemy in pairs(FindUnitsInRadius(caster:GetTeamNumber(), pos, nil, self.radius,
			DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, FIND_ANY_ORDER, false)) do
			enemy:AddNewModifier(caster, ability, "modifier_stunned", { duration = self.stun * (1 - enemy:GetStatusResistance()) })
		end
	end
end

function modifier_phoenix_supernova_aa_egg:OnDestroy()
	if not IsServer() then return end
	if not self.finished then
		if self:GetRemainingTime() <= 0.05 then
			self:Reborn()
		else
			-- яйцо убрали чем-то посторонним: просто выпускаем
			self.finished = true
			self:ReleaseAll()
		end
	end
	local egg = self:GetParent()
	egg:StopSound("Hero_Phoenix.SuperNova.Begin")
	egg:StopSound("Hero_Phoenix.SuperNova.Cast")
	-- юнит удаляем на следующем кадре: мы ещё внутри его модификатора
	Timers:CreateTimer(FrameTime(), function()
		if egg and not egg:IsNull() then UTIL_Remove(egg) end
	end)
end

--------------------------------------------------------------------------------
-- Герой внутри яйца
--------------------------------------------------------------------------------
modifier_phoenix_supernova_aa_hidden = class({})

function modifier_phoenix_supernova_aa_hidden:IsHidden() return false end
function modifier_phoenix_supernova_aa_hidden:IsPurgable() return false end
function modifier_phoenix_supernova_aa_hidden:RemoveOnDeath() return true end
function modifier_phoenix_supernova_aa_hidden:GetTexture() return "phoenix_supernova" end

function modifier_phoenix_supernova_aa_hidden:OnCreated(kv)
	self.sun_ray = (kv and kv.sun_ray or 0) == 1
	if not IsServer() then return end
	self:SetStackCount(self.sun_ray and 1 or 0)

	local parent = self:GetParent()
	parent:AddNoDraw()

	-- с шардом оставляем только Sun Ray, остальное гасим
	self.disabled = {}
	if self.sun_ray then
		for i = 0, parent:GetAbilityCount() - 1 do
			local a = parent:GetAbilityByIndex(i)
			if a and not SUN_RAY_ABILITIES[a:GetAbilityName()] and a:IsActivated() then
				a:SetActivated(false)
				table.insert(self.disabled, a)
			end
		end
	end
end

function modifier_phoenix_supernova_aa_hidden:OnDestroy()
	if not IsServer() then return end
	local parent = self:GetParent()
	parent:RemoveNoDraw()
	for _, a in ipairs(self.disabled or {}) do
		if a and not a:IsNull() then a:SetActivated(true) end
	end
	if not self.sun_ray or not parent:HasModifier("modifier_phoenix_sun_ray_aa") then
		parent:StartGesture(ACT_DOTA_INTRO)
	end
end

function modifier_phoenix_supernova_aa_hidden:CheckState()
	local sun_ray = self:GetStackCount() == 1
	return {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_UNTARGETABLE] = true,
		[MODIFIER_STATE_UNSELECTABLE] = not sun_ray,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_NOT_ON_MINIMAP] = true,
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_MUTED] = true,
		[MODIFIER_STATE_SILENCED] = not sun_ray,
	}
end

function modifier_phoenix_supernova_aa_hidden:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL,
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL,
		MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE,
	}
end

function modifier_phoenix_supernova_aa_hidden:GetAbsoluteNoDamagePhysical() return 1 end
function modifier_phoenix_supernova_aa_hidden:GetAbsoluteNoDamageMagical() return 1 end
function modifier_phoenix_supernova_aa_hidden:GetAbsoluteNoDamagePure() return 1 end

--------------------------------------------------------------------------------
-- Неуязвимость после того, как яйцо выплюнуло
--------------------------------------------------------------------------------
modifier_phoenix_supernova_aa_spit = class({})

function modifier_phoenix_supernova_aa_spit:IsHidden() return false end
function modifier_phoenix_supernova_aa_spit:IsPurgable() return false end
function modifier_phoenix_supernova_aa_spit:GetTexture() return "phoenix_supernova" end

function modifier_phoenix_supernova_aa_spit:CheckState()
	return { [MODIFIER_STATE_INVULNERABLE] = true }
end

--------------------------------------------------------------------------------
-- Подсветка врагов в радиусе яйца
--------------------------------------------------------------------------------
modifier_phoenix_supernova_aa_burn = class({})

function modifier_phoenix_supernova_aa_burn:IsHidden() return false end
function modifier_phoenix_supernova_aa_burn:IsDebuff() return true end
function modifier_phoenix_supernova_aa_burn:IsPurgable() return false end
function modifier_phoenix_supernova_aa_burn:GetTexture() return "phoenix_supernova" end
function modifier_phoenix_supernova_aa_burn:GetEffectName() return "particles/units/heroes/hero_phoenix/phoenix_supernova_radiance.vpcf" end
function modifier_phoenix_supernova_aa_burn:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end
