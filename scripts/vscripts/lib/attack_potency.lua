-- Действенность атаки (Item Potency) для наших Lua-проков.
--
-- Движок считает потенцию на каждую атаку и применяет её к ключам нативных
-- предметов с "apply_effectiveness" "1", но Lua её не отдаёт: в api.json есть
-- только MODIFIER_PROPERTY_ATTACK_POTENCY / GetModifierPropertyAttackPotency
-- (задать), геттера и поля в событии атаки нет. Поэтому считаем сами:
--
--   потенция % = база (100, у иллюзии - её illusion_effectiveness)
--              x множители способностей, которые режут атаку (Focus Fire, Flak,
--                Sleight of Fist, Swashbuckle, Scorpion Strike, отскок Moon Glaive)
--              + бонусы способностей, которые её поднимают (Backstab, Geminate,
--                Assassinate, Astral Step, Celestial Quiver, чара Evolved)
--
-- Значения читаются из KV самих способностей у атакующего (уровни, таланты,
-- наши правки), таблицы ниже - только запасные цифры 7.42.
--
-- Использование (сервер, в OnAttackLanded / ProcAttack_Feedback):
--   local p = AttackPotency:Get(attacker, params)        -- 1.0 = 100%
--   if RollPseudoRandomPercentage(AttackPotency:Chance(chance, p), ...) then
--   target:AddNewModifier(attacker, ability, "mod", AttackPotency:Kv(p, {duration = d}))
-- В дебафе: AttackPotency:Attach(self, kv) в OnCreated/OnRefresh и
-- AttackPotency:Transmitter(класс) один раз - потенция доедет до клиента
-- (числа в тултипе бафа совпадут с сервером); значение - self:Potency().

AttackPotency = AttackPotency or {}

-- иллюзии: модификатор на иллюзии -> {способность-источник, ключ, запасное %}
local ILLUSION_SOURCES = {
	{ mod = "modifier_chaos_knight_phantasm_illusion_shard", ability = "chaos_knight_chaos_bolt", key = "illusion_effectiveness", default = 25 },
	{ mod = "modifier_chaos_knight_phantasm_illusion", ability = "chaos_knight_phantasm", key = "illusion_effectiveness", default = 100 },
	{ mod = "modifier_darkseer_wallofreplica_illusion", ability = "dark_seer_wall_of_replica", key = "replica_effectiveness", default = 60 },
	{ mod = "modifier_darkseer_normal_punch_illusion", ability = "dark_seer_normal_punch", key = "replica_effectiveness", default = 60 },
	{ mod = "modifier_spectre_shadow_step_illusion", ability = "spectre_shadow_step", key = "illusion_effectiveness", default = 25 },
	{ mod = "modifier_spectre_haunt", ability = "spectre_haunt", key = "illusion_effectiveness", default = 40 },
	{ mod = "modifier_item_riftshadow_prism_illusion", ability = "item_riftshadow_prism", key = "illusion_effectiveness", default = 100 },
	{ mod = "modifier_rune_illusion", default = 40 },
	{ mod = "modifier_terrorblade_conjureimage", ability = "terrorblade_conjure_image", key = "illusion_effectiveness", default = 35 },
}
-- источник не опознан: как у Manta / рядовой иллюзии
local ILLUSION_DEFAULT = 35

-- способности, которые ставят потенцию атаки в X% (множитель)
local MULT_SOURCES = {
	{ mod = "modifier_windrunner_focusfire", ability = "windrunner_focusfire", key = "focusfire_attack_effectiveness", default = 75 },
	{ mod = "modifier_ember_spirit_sleight_of_fist_caster", ability = "ember_spirit_sleight_of_fist", key = "attack_effectiveness", default = 80 },
	{ mod = "modifier_pangolier_swashbuckle_attack", ability = "pangolier_swashbuckle", key = "potency", default = 60 },
	{ mod = "modifier_sand_king_scorpion_strike_attack_bonus", ability = "sand_king_pinpoint", key = "potency", default = 60 },
	{ mod = "modifier_sand_king_scorpion_strike_attack_bonus_inner", ability = "sand_king_pinpoint", key = "potency", default = 60 },
	{ mod = "modifier_sand_king_scorpion_strike_attack_bonus_outer", ability = "sand_king_pinpoint", key = "potency", default = 60 },
	-- только доп. цели Flak Cannon (основная цель атаки - полная потенция)
	{ mod = "modifier_gyrocopter_flak_cannon", ability = "gyrocopter_flak_cannon", key = "attack_effectiveness", default = 50, secondary = true },
}

-- способности, которые добавляют +X% потенции
local BONUS_SOURCES = {
	{ mod = "modifier_weaver_geminate_attack_bonus", ability = "weaver_geminate_attack", key = "bonus_potency", default = 15 },
	{ mod = "modifier_sniper_assassinate_crit", ability = "sniper_assassinate", key = "bonus_potency", default = 20 },
	{ mod = "modifier_void_spirit_astral_step_caster", ability = "void_spirit_astral_step", key = "bonus_potency", default = 25 },
	{ mod = "modifier_item_enhancement_evolved", ability = "item_enhancement_evolved", key = "bonus_potency", default = 0, item = true },
}

local function SafeValue(unit, ability_name, key, default, is_item)
	if not ability_name or not key then return default end
	local ability
	if is_item then
		ability = unit.FindItemInInventory and unit:FindItemInInventory(ability_name)
	else
		ability = unit.FindAbilityByName and unit:FindAbilityByName(ability_name)
	end
	if ability and not ability:IsNull() and ability:GetLevel() > 0 then
		local v = ability:GetSpecialValueFor(key)
		if v and v ~= 0 then return v end
	end
	return default
end

-- % потенции иллюзии; кэш на сущности - источник у иллюзии не меняется
function AttackPotency:IllusionPct(unit)
	if unit.__aa_potency_ill then return unit.__aa_potency_ill end

	local pct
	for _, src in ipairs(ILLUSION_SOURCES) do
		local mod = unit:FindModifierByName(src.mod)
		if mod then
			pct = src.default
			local ab = mod:GetAbility()
			if ab and not ab:IsNull() and src.key then
				local v = ab:GetSpecialValueFor(src.key)
				if v and v > 0 then pct = v end
			end
			break
		end
	end

	-- обычная иллюзия: modifier_illusion держит способность-создателя (Manta и др.)
	if not pct then
		local mod = unit:FindModifierByName("modifier_illusion")
		local ab = mod and mod:GetAbility()
		if ab and not ab:IsNull() then
			local v = ab:GetSpecialValueFor("illusion_effectiveness")
			if v and v > 0 then pct = v end
		end
	end

	pct = pct or ILLUSION_DEFAULT
	unit.__aa_potency_ill = pct
	return pct
end

-- удар из-за спины по правилу Riki Backstab (угол backstab_angle от взгляда цели)
local function IsBackstab(attacker, target, angle)
	if not target or target:IsNull() then return false end
	local to_attacker = attacker:GetAbsOrigin() - target:GetAbsOrigin()
	to_attacker.z = 0
	if to_attacker:Length2D() < 1 then return false end
	local fwd = target:GetForwardVector()
	local cos = (fwd.x * to_attacker.x + fwd.y * to_attacker.y) / to_attacker:Length2D()
	-- за спиной: угол между взглядом цели и направлением на атакующего > 180 - angle/2
	return cos < math.cos(math.rad(180 - angle / 2))
end

-- Множитель действенности атаки (1.0 = 100%). params - событие атаки (может быть nil).
function AttackPotency:Get(attacker, params)
	if not attacker or attacker:IsNull() then return 1 end
	local target = params and (params.target or params.unit)

	local pct = 100
	if attacker:IsIllusion() then
		pct = self:IllusionPct(attacker)
	end

	for _, src in ipairs(MULT_SOURCES) do
		if attacker:HasModifier(src.mod) then
			local ok = true
			if src.secondary then ok = target ~= nil and target ~= attacker:GetAttackTarget() end
			if ok then pct = pct * SafeValue(attacker, src.ability, src.key, src.default) / 100 end
		end
	end

	-- отскок Moon Glaive: цель не та, которую Луна бьёт
	if attacker:HasModifier("modifier_luna_moon_glaive") and target and target ~= attacker:GetAttackTarget() then
		pct = pct * (100 - SafeValue(attacker, "luna_moon_glaive", "effectiveness_reduction_percent", 40)) / 100
	end

	local bonus = 0
	for _, src in ipairs(BONUS_SOURCES) do
		if attacker:HasModifier(src.mod) then
			bonus = bonus + SafeValue(attacker, src.ability, src.key, src.default, src.item)
		end
	end

	-- Celestial Quiver: модификатор висит со стаками зарядов
	local quiver = attacker:FindModifierByName("modifier_mirana_celestial_quiver")
	if quiver and quiver:GetStackCount() > 0 then
		bonus = bonus + SafeValue(attacker, "mirana_celestial_quiver", "bonus_potency", 20)
	end

	-- Backstab (Riki): удар из-за спины
	if attacker:HasModifier("modifier_riki_backstab") and target and not attacker:PassivesDisabled() then
		local angle = SafeValue(attacker, "riki_innate_backstab", "backstab_angle", 105)
		if IsBackstab(attacker, target, angle) then
			bonus = bonus + SafeValue(attacker, "riki_innate_backstab", "bonus_potency", 10)
		end
	end

	-- бонус потенции, как и в доте, масштабируется у иллюзии её действенностью
	if attacker:IsIllusion() then bonus = bonus * self:IllusionPct(attacker) / 100 end

	pct = math.max(0, pct + bonus)
	return pct / 100
end

-- шанс прока в % с учётом потенции, не больше 100
function AttackPotency:Chance(chance, potency)
	return math.min(100, (chance or 0) * (potency or 1))
end

function AttackPotency:Scale(value, potency)
	return (value or 0) * (potency or 1)
end

-- таблица параметров AddNewModifier с потенцией (без потенции 100% ничего не добавляем)
function AttackPotency:Kv(potency, kv)
	kv = kv or {}
	if potency and potency ~= 1 then kv.aa_potency = potency end
	return kv
end

-- в OnCreated/OnRefresh дебафа: запомнить потенцию из kv. При обновлении
-- берётся большая из двух: удар иллюзии не ослабляет уже висящий дебаф героя
-- (длительность при этом обновляется как обычно).
function AttackPotency:Attach(mod, kv)
	if not IsServer() then return end
	local p = (kv and tonumber(kv.aa_potency)) or 1
	if mod.aa_potency and not (kv and kv.aa_potency_reset) then p = math.max(p, mod.aa_potency) end
	local changed = mod.aa_potency ~= nil and mod.aa_potency ~= p
	mod.aa_potency = p
	if not mod.__aa_potency_tx and mod.SetHasCustomTransmitterData then
		mod.__aa_potency_tx = true
		mod:SetHasCustomTransmitterData(true)
	elseif changed and mod.SendBuffRefreshToClients then
		mod:SendBuffRefreshToClients()
	end
end

-- навесить на класс модификатора передачу потенции клиенту и метод Potency()
function AttackPotency:Transmitter(cls)
	local prev_add, prev_handle = cls.AddCustomTransmitterData, cls.HandleCustomTransmitterData
	cls.AddCustomTransmitterData = function(self)
		local data = prev_add and prev_add(self) or {}
		data.aa_potency = self.aa_potency or 1
		return data
	end
	cls.HandleCustomTransmitterData = function(self, data)
		if prev_handle then prev_handle(self, data) end
		self.aa_potency = tonumber(data.aa_potency) or 1
	end
	cls.Potency = function(self) return self.aa_potency or 1 end
end

return AttackPotency
