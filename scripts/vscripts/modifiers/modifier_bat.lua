--[[
	Единая точка BAT героя (висит на каждом герое, см. addon_game_mode.lua OnNPCSpawned).

	Движок из нескольких BASE_ATTACK_TIME_CONSTANT применяет только один, поэтому
	всё, что ЗАДАЁТ BAT, собирается здесь, берётся самое низкое, а потом вычитаются
	все снижения:

	  BAT = max(MIN_BAT, задано - (задано - 0.8) * (1 - П(1 - снижение_i / 0.9))),  задано = min(база, все "задать")

	  база           - собственный BAT героя (запоминается при наложении);
	                   у Kez - текущая стойка (Katana/Sai), читается каждый пересчёт.
	  bat_constant   - ванильные "задать BAT" по имени модификатора и ключу в KV;
	  Lua-"задать"   - любые наши Lua-модификаторы с GetModifierBaseAttackTimeConstant
	                   (Huntress Aim Shot, оружие Gun Joe и т.п.) - находятся сами;
	  bat_dynamic    - "снизить BAT на X" (стакаются с убыванием, см. Recalc).

	НЕ сюда: эффекты, которые движок применяет ПОВЕРХ константы сам, иначе снижение
	будет двойным: чары Crude/Manic (bat_reduce, %), Insatiable Hunger у Broodmother
	(bat_bonus от таланта). Проверка - строка [modifier_bat] в консоли против панели статов.

	Итог передаётся клиенту стаками (сотые доли), чтобы панель статов видела то же.
]]

-- "снизить BAT на X": имя модификатора -> ключ в KV его способности/предмета
local bat_dynamic = {
	-- False Promise союзнику, только если у Oracle есть шард (RequiresShard гейтит лишь тултип)
	modifier_oracle_false_promise_timer = { key = 'shard_bat_bonus', shard = true },
	modifier_item_swift_blink_aa_active = 'bat_reduction',
	-- дерево Тини: в KV bat_increase = 0 (движок не трогает), снижение тут, только с аганимом
	modifier_tiny_tree_grab = 'bat_reduction_aa',
}

-- "задать BAT = X": имя модификатора -> ключ в KV
local bat_constant = {
	modifier_alchemist_chemical_rage = 'base_attack_time',
	modifier_terrorblade_metamorphosis = 'base_attack_time',
	modifier_snapfire_lil_shredder_buff = 'base_attack_time',
}

-- герои, у которых собственный BAT меняется на ходу (стойки) - базу читаем каждый раз
local live_base_heroes = {
	npc_dota_hero_kez = true,
}

local MIN_BAT = 0.4
-- Убывание снижений. Снижение X режет долю X / (REF_BAT - SOFT_FLOOR) от промежутка
-- "BAT героя - SOFT_FLOOR". У героя с BAT 1.7 одно снижение даёт ровно X; у кого
-- BAT ниже - меньше, у кого выше - больше. Несколько снижений перемножаются, и
-- BAT только приближается к SOFT_FLOOR: около 1.0 каждое следующее почти не работает.
local REF_BAT = 1.7
local SOFT_FLOOR = 0.8
local THINK = 0.1

modifier_bat = class({
	IsHidden = function (self) return true end,
	IsPurgable = function (self) return false end,
	RemoveOnDeath = function (self) return false end,
	GetAttributes = function (self) return MODIFIER_ATTRIBUTE_PERMANENT end,
	GetPriority = function (self) return 4 end,
	DeclareFunctions = function (self) return {
		MODIFIER_PROPERTY_BASE_ATTACK_TIME_CONSTANT,
	} end
})

-- BAT, который движок посчитал бы без нас (наш геттер на время чтения молчит)
function modifier_bat:EngineBAT()
	self.reading = true
	local bat = self:GetParent():GetBaseAttackTime(false)
	self.reading = false
	return bat
end

function modifier_bat:OnCreated()
	if not IsServer() then return end

	local parent = self:GetParent()

	self.live_base = live_base_heroes[parent:GetUnitName()] == true
	self.base = parent:GetBaseAttackTime(false)	-- стаков ещё 0, наш геттер молчит
	if not self.base or self.base <= 0 then self.base = 1.7 end

	self:Recalc()
	self:StartIntervalThink(THINK)
end

-- солдаты Wukong's Command - тоже "реальные герои", им BAT не считаем
local function IsMonkeySoldier(unit)
	return unit:HasModifier("modifier_monkey_king_fur_army_soldier")
		or unit:HasModifier("modifier_monkey_king_fur_army_soldier_hidden")
end

function modifier_bat:OnIntervalThink()
	if IsMonkeySoldier(self:GetParent()) then self:Destroy() return end
	self:Recalc()
end

local function ValueFrom(modifier, key)
	local ability = modifier and modifier:GetAbility()
	if not ability or ability:IsNull() then return nil end
	return ability:GetSpecialValueFor(key)
end

function modifier_bat:Recalc()
	local parent = self:GetParent()
	if not parent or parent:IsNull() then return end

	local base = self.base
	if self.live_base then
		local engine = self:EngineBAT()
		if engine and engine > 0 then base = engine end
	end

	local constant = base

	-- ванильные "задать"
	for name, key in pairs(bat_constant) do
		local value = ValueFrom(parent:FindModifierByName(name), key)
		if value and value > 0 and value < constant then constant = value end
	end

	-- Troll: модификатор Berserker's Rage висит в обеих стойках, а свой BAT стойки
	-- движок модификатором не задаёт - смотрим на стойку сами: в ближней берём
	-- base_attack_time способности стойки (с талантом -0.2)
	if parent:GetUnitName() == "npc_dota_hero_troll_warlord" and not parent:IsRangedAttacker() then
		local stance = parent:FindAbilityByName("troll_warlord_switch_stance") or parent:FindAbilityByName("troll_warlord_berserkers_rage")
		if stance and not stance:IsNull() then
			local value = stance:GetSpecialValueFor("base_attack_time")
			if value > 0 and value < constant then constant = value end
		end
	end

	-- наши Lua-"задать": любой чужой модификатор с GetModifierBaseAttackTimeConstant
	local forced
	for _, modifier in pairs(parent:FindAllModifiers()) do
		if modifier ~= self and type(modifier.GetModifierBaseAttackTimeConstant) == "function" then
			local ok, value = pcall(modifier.GetModifierBaseAttackTimeConstant, modifier, {})
			if ok and type(value) == "number" and value > 0 then
				-- AA_BAT_FORCE: стойка, которая ЗАМЕДЛЯЕТ атаку (Huntress Aim Shot, BAT 3.0
				-- больше базового 1.7) - берётся как есть, иначе min() её отбрасывал
				if modifier.AA_BAT_FORCE then
					forced = math.max(forced or 0, value)
				elseif value < constant then
					constant = value
				end
			end
		end
	end
	if forced then constant = forced end

	-- снижения: коэффициенты (1 - X / (REF_BAT - SOFT_FLOOR)) перемножаются и
	-- применяются к промежутку над SOFT_FLOOR (см. константы вверху). Примеры при
	-- BAT героя 1.7: -0.4 -> 1.30; -0.4 и -0.3 -> 1.13; ещё -0.4 -> 0.99.
	-- BAT 1.4: -0.4 -> 1.13. Под "задать" ниже пола (Alchemist 0.5) снижения не нужны.
	local factor = 1
	for name, key in pairs(bat_dynamic) do
		for _, modifier in pairs(parent:FindAllModifiersByName(name)) do
			local k, need_shard = key, false
			if type(key) == "table" then k, need_shard = key.key, key.shard end

			local caster = modifier:GetCaster()
			if not need_shard or (caster and not caster:IsNull() and caster:HasModifier("modifier_item_aghanims_shard")) then
				local value = ValueFrom(modifier, k)
				if value and value ~= 0 then
					factor = factor * math.max(0, 1 - math.abs(value) / (REF_BAT - SOFT_FLOOR))
				end
			end
		end
	end

	local gap = math.max(0, constant - SOFT_FLOOR)
	local delta = gap * (1 - factor)
	local stacks = math.floor(math.max(MIN_BAT, constant - delta) * 100 + 0.5)

	if stacks ~= self:GetStackCount() then
		self:SetStackCount(stacks)

		print(string.format("[modifier_bat] %s: база %.2f, задано %.2f, снижение %.2f -> BAT %.2f",
			parent:GetUnitName(), base, constant, delta, stacks / 100))
	end
end

function modifier_bat:GetModifierBaseAttackTimeConstant()
	if self.reading then return end

	local stacks = self:GetStackCount()
	if stacks <= 0 then return end

	return stacks / 100
end
