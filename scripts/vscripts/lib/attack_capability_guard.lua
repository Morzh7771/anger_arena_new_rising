if not IsServer() then return end

-- Заглушка от "вечной стойки" (2026-11-26): Morphling скопировал Lycan и аганимом
-- трижды наложил Wolf Bite на Gun Joe - эффект ушёл, а ближняя атака осталась навсегда.
-- Раз в TICK сек сверяем тип атаки героя с его KV. Если он другой и на герое нет
-- ни одного модификатора, который законно меняет тип атаки, - возвращаем как в KV.
-- Чинить только после двух проверок подряд: смена формы может идти не в один кадр.

AttackCapabilityGuard = AttackCapabilityGuard or {}

local G = AttackCapabilityGuard
local TICK = 1

-- подстроки имён модификаторов, которые законно меняют тип атаки
local LEGIT = {
	"shapeshift", "wolf_bite", "berserkers_rage", "dragon_form", "metamorphosis",
	"true_form", "morphling_replicate", "morphling_morph", "command_height",
	"rubick_spell_steal", "transform",
}

local CAPS = {
	DOTA_UNIT_CAP_MELEE_ATTACK  = DOTA_UNIT_CAP_MELEE_ATTACK,
	DOTA_UNIT_CAP_RANGED_ATTACK = DOTA_UNIT_CAP_RANGED_ATTACK,
}

local baseCap = {} -- [имя юнита] = тип атаки из KV или false

local function BaseCap(name)
	if baseCap[name] == nil then
		local kv = GetUnitKeyValuesByName(name)
		baseCap[name] = kv and CAPS[kv.AttackCapabilities] or false
	end

	return baseCap[name]
end

local function HasLegitModifier(hero)
	for _, m in pairs(hero:FindAllModifiers()) do
		local n = m:GetName()

		for _, sub in ipairs(LEGIT) do
			if string.find(n, sub, 1, true) then return true end
		end
	end

	return false
end

function G:Tick()
	for _, hero in pairs(HeroList:GetAllHeroes()) do
		if hero and not hero:IsNull() and hero:IsAlive() and not hero.aa_mk_soldier then
			local base = BaseCap(hero:GetUnitName())
			local cur = hero:GetAttackCapability()

			if base and cur ~= base and cur ~= DOTA_UNIT_CAP_NO_ATTACK and not HasLegitModifier(hero) then
				if hero.aa_cap_suspect then
					hero.aa_cap_suspect = nil
					hero:SetAttackCapability(base)
					print("[AttackCapabilityGuard] " .. hero:GetUnitName() .. ": тип атаки " .. tostring(cur) .. " -> " .. tostring(base))
				else
					hero.aa_cap_suspect = true
				end
			else
				hero.aa_cap_suspect = nil
			end
		end
	end

	return TICK
end

if not G.started then
	G.started = true

	Timers:CreateTimer(TICK, function()
		local ok, res = pcall(G.Tick, G)

		if not ok then print("[AttackCapabilityGuard] " .. tostring(res)) end

		return TICK
	end)
end
