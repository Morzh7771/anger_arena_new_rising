--[[
	Кто считается суммоном игрока. Общее для дуэлей (кто едет с героем на арену)
	и для усиления суммонов от хозяина (lib/summon_power.lua).

	Суммон - подвижный юнит, которым владеет герой игрока: медведь друида,
	фамильяры Визажа, голем Варлока, духи Брюмастера, волки, пауки, эйдолоны,
	Некрономикон, подчинённые крипы и т.п.

	НЕ суммоны:
	  иллюзии, Tempest Double и любые копии героя;
	  курьеры;
	  всё неподвижное: варды (обычные, Веномансера, Шамана, Пугны, Death Ward,
	    Healing Ward), мины и ловушки Течиса, надгробие Андаинга, шестерни
	    Клокверка, яйцо Феникса, камни Земляного духа, ловушки Темплар;
	  вспомогательные невидимые юниты (тинкеры, дамми);
	  снаряды-юниты (ракета Гиро и т.п.).
]]

SummonUtils = SummonUtils or {}

-- имена, которые никогда не считаем суммонами (подстрока в имени юнита)
SummonUtils.EXCLUDED_NAME_PARTS = {
	"ward",              -- все варды, включая Плейг-варды Веномансера и змей Шамана
	"techies",           -- мины, ловушки
	"tombstone",         -- Андаинг
	"rattletrap_cog",    -- шестерни Клокверка
	"phoenix_sun",       -- яйцо Феникса
	"stone_remnant",     -- камни Земляного духа
	"psionic_trap",      -- ловушки Темплар
	"homing_missile",    -- ракета Гиро
	"monkey_king_soldier", -- солдаты арены MK живут только внутри арены
	"dummy",
	"thinker",
	"zeus_cloud",        -- облако Зевса
	"ignis_fatuus",      -- фонарики Кипера
	"tusk_frozen_sigil", -- сигил Таска стоит в бою на месте героя-владельца
	"astral_spirit",     -- дух Элдер Титана: прыжок на арену сломает его возврат
}

-- Обработчики «суммон появился»: всё, что надо выдать суммону сразу при
-- спавне (предметы хозяина, ауры и т.п.), регистрируется здесь. Зовутся
-- из lib/summon_power.lua в момент, когда суммон получил своё усиление -
-- то есть в кадр появления (или следующий, если владелец ставится позже).
SummonUtils.spawnHandlers = SummonUtils.spawnHandlers or {}

function SummonUtils:OnSummonSpawned(key, handler)
	self.spawnHandlers[key] = handler
end

function SummonUtils:FireSpawned(unit, hero)
	for key, handler in pairs(self.spawnHandlers) do
		local ok, err = pcall(handler, unit, hero)
		if not ok then
			print("[SummonUtils] spawn handler " .. tostring(key) .. " failed: " .. tostring(err))
		end
	end
end

function SummonUtils:GetOwnerHero(unit)
	if not unit or unit:IsNull() then return nil end

	local owner = unit:GetOwner()

	-- владелец может быть игроком или юнитом-цепочкой (суммон суммона)
	for _ = 1, 4 do
		if not owner or owner:IsNull() then break end

		if owner.IsRealHero and owner:IsRealHero() then
			return owner
		end

		if owner.GetAssignedHero then
			return owner:GetAssignedHero()
		end

		owner = owner.GetOwner and owner:GetOwner() or nil
	end

	local pid = unit:GetPlayerOwnerID()

	if pid and pid >= 0 and PlayerResource:IsValidPlayerID(pid) then
		return PlayerResource:GetSelectedHeroEntity(pid)
	end

	return nil
end

function SummonUtils:IsExcludedName(unit)
	local name = string.lower(unit:GetUnitName() or "")

	for _, part in ipairs(self.EXCLUDED_NAME_PARTS) do
		if string.find(name, part, 1, true) then return true end
	end

	return false
end

-- неподвижные юниты: для дуэлей не суммоны, но бафф от характеристик
-- хозяина (modifier_summon_power) получать должны
SummonUtils.POWER_EXTRA_NAME_PARTS = {
	"venomancer_plague_ward",
	"witch_doctor_death_ward",
}

-- кому положен modifier_summon_power
function SummonUtils:IsPowerTarget(unit)
	if self:IsSummon(unit) then return true end
	if not unit or unit:IsNull() or not unit:IsAlive() or unit:IsIllusion() then return false end

	-- Статичные стрелки из файлов героев (скелеты Клинкза, варды Шамана/Пугны и т.п.): у них
	-- прописана summon_power_passive, но IsSummon их отсекает как неподвижных - модификатор
	-- не находил хозяина и через полсекунды удалялся, бафф пропадал (2026-11-14).
	-- Даём бафф всем атакующим юнитам с этой способностью; неатакующие (надгробие, мины,
	-- шестерни) как были - без бафа. ХП вардам не даётся (modifier_summon_power, no_health).
	if unit.HasAbility and unit:HasAbility("summon_power_passive")
		and unit:GetAttackCapability() ~= DOTA_UNIT_CAP_NO_ATTACK then
		local owner = self:GetOwnerHero(unit)

		if owner ~= nil and not owner:IsNull() and owner ~= unit then return true end
	end

	local name = string.lower(unit:GetUnitName() or "")

	for _, part in ipairs(self.POWER_EXTRA_NAME_PARTS) do
		if string.find(name, part, 1, true) then
			local owner = self:GetOwnerHero(unit)
			return owner ~= nil and not owner:IsNull() and owner ~= unit
		end
	end

	return false
end

-- юнит - суммон героя-игрока (если hero передан - именно этого героя)
function SummonUtils:IsSummon(unit, hero)
	if not unit or unit:IsNull() or not unit:IsAlive() then return false end
	if not unit.IsCreature and not unit.IsHero then return false end

	if unit:IsRealHero() then return false end
	if unit:IsIllusion() then return false end
	if unit.IsTempestDouble and unit:IsTempestDouble() then return false end
	if unit:IsCourier() then return false end
	if unit:IsBuilding() or unit:IsTower() then return false end
	if unit.IsOther and unit:IsOther() then return false end
	if not unit:HasMovementCapability() then return false end
	if unit:GetClassname() == "npc_dota_thinker" then return false end
	if self:IsExcludedName(unit) then return false end

	local owner = self:GetOwnerHero(unit)

	if not owner or owner:IsNull() or owner == unit then return false end
	if hero and owner ~= hero then return false end

	return true
end

-- все суммоны героя на карте
function SummonUtils:FindSummons(hero)
	local result = {}

	if not hero or hero:IsNull() then return result end

	local units = FindUnitsInRadius(hero:GetTeamNumber(), Vector(0, 0, 0), nil, FIND_UNITS_EVERYWHERE,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_ALL,
		DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD + DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS,
		FIND_ANY_ORDER, false)

	for _, unit in ipairs(units) do
		if unit ~= hero and self:IsSummon(unit, hero) then
			table.insert(result, unit)
		end
	end

	return result
end
