--[[
	Перемножение снижений входящего урона (MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE).

	Движок СКЛАДЫВАЕТ все -X% входящего урона: амулет 60 + Nyx Burrow 40 + сила 20 = 120%,
	то есть бессмертие. Здесь считаем, как они должны были бы стакаться перемножением:
	  итог = 1 - (1-a)(1-b)(1-c)...   (60/40/20 -> 80.8%, до 100% не доходит никогда)
	и возвращаем положительную поправку, которую modifier_aa_hero добавляет к своему значению.

	Считается на КАЖДЫЙ удар по params (attacker и т.д.), поэтому условные снижения
	(Bristleback - только спина/бок) идут в расчёт только когда реально сработали для этого удара.

	Источники:
	  * все Lua-модификаторы с GetModifierIncomingDamage_Percentage - вызываем их геттер
	    с теми же params (они сами решают, срабатывают ли на этот урон);
	  * ванильные способности - таблица VANILLA ниже: значение берём из AbilityValues
	    способности (GetSpecialValueFor, с талантами и нашими уровнями).
	Неизвестные источники остаются как в движке - складываются; поправка их не трогает.
	Усиления урона (+X%) не трогаем. 100% (Winter's Curse, Fowl Play) работают как раньше.
]]

AADamageReductionStack = AADamageReductionStack or {}

-- угол между взглядом юнита и направлением НА атакующего (0 = атака в лицо, 180 = в спину)
local function HitAngleFromBack(parent, attacker)
	if not attacker or attacker:IsNull() then return nil end
	local dir = attacker:GetAbsOrigin() - parent:GetAbsOrigin()
	dir.z = 0
	if dir:Length2D() < 1 then return nil end
	local face = VectorToAngles(parent:GetForwardVector()).y
	local to_attacker = VectorToAngles(dir).y
	-- 0 = атакующий ровно за спиной
	return 180 - math.abs(AngleDiff(face, to_attacker))
end

-- ability = имя ванильной способности; fn(mod, ability, parent, params) -> снижение в % (>=0) или 0
local VANILLA = {
	-- Bristleback: только удары со спины/боков. Ломается Break.
	bristleback_bristleback = function(mod, ab, parent, params)
		if parent:PassivesDisabled() then return 0 end
		if not params then return 0 end
		local from_back = HitAngleFromBack(parent, params.attacker)
		if not from_back then return 0 end
		if from_back <= ab:GetSpecialValueFor("back_angle") / 2 then
			return ab:GetSpecialValueFor("back_damage_reduction")
		elseif from_back <= ab:GetSpecialValueFor("side_angle") / 2 then
			return ab:GetSpecialValueFor("side_damage_reduction")
		end
		return 0
	end,
	-- Nyx Burrow
	nyx_assassin_burrow = function(mod, ab)
		if mod:GetName() ~= "modifier_nyx_assassin_burrow" then return 0 end
		return ab:GetSpecialValueFor("damage_reduction")
	end,
	-- Ursa Enrage
	ursa_enrage = function(mod, ab)
		if mod:GetName() ~= "modifier_ursa_enrage" then return 0 end
		return ab:GetSpecialValueFor("damage_reduction")
	end,
	-- Bounty Hunter Shadow Walk (талант 9 / союзник от шарда): невидимость с -X% урона
	bounty_hunter_wind_walk = function(mod, ab)
		if mod:IsDebuff() then return 0 end
		if not string.find(mod:GetName(), "wind_walk", 1, true) then return 0 end
		return ab:GetSpecialValueFor("damage_reduction_pct")
	end,
	-- Leshrac Pulse Nova: талант на сопротивление урону, пока включена
	leshrac_pulse_nova = function(mod, ab)
		if not ab:GetToggleState() then return 0 end
		return ab:GetSpecialValueFor("damage_resistance")
	end,
	-- Visage Gravekeeper's Cloak: слой = damage_reduction, только урон от игроков и не меньше minimum_damage
	visage_gravekeepers_cloak = function(mod, ab, parent, params)
		if mod:GetCaster() ~= parent or parent:PassivesDisabled() then return 0 end
		local layers = mod:GetStackCount()
		if layers <= 0 then return 0 end
		if params then
			local att = params.attacker
			if not att or att:IsNull() or not att.GetPlayerOwnerID or att:GetPlayerOwnerID() < 0 then return 0 end
			if (params.original_damage or params.damage or 0) < ab:GetSpecialValueFor("minimum_damage") then return 0 end
		end
		return math.min(layers * ab:GetSpecialValueFor("damage_reduction"), ab:GetSpecialValueFor("max_damage_reduction"))
	end,
	-- Enigma Gravity Well: союзникам рядом с Enigma, от 0 на max_dist до полной на min_dist
	enigma_gravity_well = function(mod, ab, parent)
		local caster = mod:GetCaster()
		if not caster or caster:IsNull() or caster == parent then return 0 end
		local max_dist = ab:GetSpecialValueFor("max_dist")
		local min_dist = ab:GetSpecialValueFor("min_dist")
		local d = (caster:GetAbsOrigin() - parent:GetAbsOrigin()):Length2D()
		local k
		if d <= min_dist then k = 1
		elseif d >= max_dist then k = 0
		else k = (max_dist - d) / math.max(1, max_dist - min_dist) end
		return ab:GetSpecialValueFor("damage_reduction") * k
	end,
}

-- геттер есть, но свойство может быть не объявлено (закомментировано) - тогда движок его не зовёт
local function DeclaresIncoming(mod)
	if mod._aa_dr_declared ~= nil then return mod._aa_dr_declared end
	local res = false
	if type(mod.DeclareFunctions) == "function" then
		local ok, list = pcall(mod.DeclareFunctions, mod)
		if ok and type(list) == "table" then
			for _, p in pairs(list) do
				if p == MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE then res = true break end
			end
		end
	end
	mod._aa_dr_declared = res
	return res
end

-- own_pct: снижение от самого modifier_aa_hero (положительное число, %).
-- Возвращает поправку (>= 0), которую надо ПРИБАВИТЬ к значению модификатора.
function AADamageReductionStack:Correction(parent, params, own_pct, self_mod)
	if not IsServer() or not parent or not parent.FindAllModifiers then return 0 end

	local sum = 0      -- как сложит движок
	local keep = 1     -- произведение (1 - r)
	local function add(r)
		if r <= 0 then return end
		if r > 100 then r = 100 end
		sum = sum + r
		keep = keep * (1 - r / 100)
	end
	add(own_pct or 0)

	local seen_ability = {}
	for _, mod in ipairs(parent:FindAllModifiers()) do
		if mod ~= self_mod and not mod:IsNull() then
			local getter = mod.GetModifierIncomingDamage_Percentage
			if type(getter) == "function" and DeclaresIncoming(mod) then
				-- Lua-модификатор: спрашиваем его самого
				local ok, v = pcall(getter, mod, params)
				if ok and type(v) == "number" and v < 0 then add(-v) end
			else
				local ab = mod:GetAbility()
				if ab and not ab:IsNull() then
					local name = ab:GetAbilityName()
					local fn = VANILLA[name]
					if fn and not seen_ability[ab] then
						local ok, v = pcall(fn, mod, ab, parent, params)
						if ok and type(v) == "number" and v > 0 then
							seen_ability[ab] = true
							add(v)
						end
					end
				end
			end
		end
	end

	local target = (1 - keep) * 100
	local corr = sum - target
	if corr < 0 then corr = 0 end
	return corr
end
