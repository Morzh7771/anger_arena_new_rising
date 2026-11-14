-- Визуальные эффекты премиум-косметики. Только серверные вызовы ParticleManager.
--
-- Ничего из геймплея здесь не меняется: партиклы создаются и гаснут, урон,
-- перезарядки и телепорт остаются движковыми. Все вызовы обёрнуты в pcall
-- в core.lua, сбой косметики не должен ронять матч.
--
-- Жизненный цикл. Любой партикл создаётся через Spawn: индекс попадает в таблицу
-- live, в счётчик live_count. Погасить его можно только через Free (DestroyParticle
-- с false + ReleaseParticleIndex). Одноразовые эффекты гасятся по таймеру (FreeAfter),
-- ауры и радианс - по смене экипировки, смерти, дисконнекту, TP - по концу канала.
-- Раз в 60 с в лог уходит "[Cosmetics] live particles N" (только наши партиклы).
--
-- Кто что делает:
--   ауры и эффекты героя - ApplyHeroFx / ClearHeroFx (крепятся к телу героя, один раз на надевание);
--   радианс владельца    - SyncRadiance (раз в секунду, пересоздаёт только при смене варианта/героя);
--   радианс на врагах    - TickRadiance (раз в 0.25 с, партикл на каждого врага с дебаффом радианса);
--   эффект убийства      - PlayKill (бурст фейерверков в точке гибели, всё гаснет через KILL_LIFE);
--   телепорт             - BeginTp при касте (vanilla свиток/ботинки), TP_GRACE..TP_WINDOW проверки;
--   петы                 - SpawnUnitFx/FreeList вызывает lib/cosmetics/core.lua.

if not IsServer() then return end

CosmeticsEffects = CosmeticsEffects or {}

local FX = CosmeticsEffects

local RADIANCE_ITEMS = {
	item_radiance = true,
	item_radiance_2 = true,
	item_radiance_3 = true,
}

-- Предметы, которыми движок телепортирует героя (события dota_player_used_ability).
-- Snake Boots сюда не входят: его свиток сам берёт пути через TpPaths (items/item_snake_tpscroll.lua).
FX.TP_ITEMS = {
	item_tpscroll = true,
	item_travel_boots = true,
	item_travel_boots_2 = true,
}

-- скачок позиции за один тик 0.1 с, который считаем телепортом
local TP_JUMP = 1200
-- окно наблюдения после каста (канал свитка ~3 с, с запасом)
local TP_WINDOW = 10
local TP_TICK = 0.1
-- сколько ждём, пока канал стартует, прежде чем считать каст отменённым
local TP_GRACE = 0.5
local TP_END_LIFE = 3

-- бурст убийства
-- 2026-11-12: владелец просил ярче - больше залпов, шире разброс, дольше
local KILL_BURST = 10
local KILL_SPREAD = 340
local KILL_DELAY = 1.0
local KILL_LIFE = 5

-- радианс: радиус ауры 700 плюс запас; проверка дебаффа раз в RAD_TICK
local RAD_RADIUS = 760
local RAD_TICK = 0.25
-- FPS: партикл радианса вешался на КАЖДОГО врага с дебаффом, включая крипов -
-- в пачке крипов это десятки живых партиклов на клиенте. Ограничиваем числом,
-- герои в приоритете (FIND_CLOSEST, сначала герои). На урон/дебафф не влияет.
local RAD_MAX_TARGETS = 5

local live = {}        -- индекс партикла -> серийный номер (есть, пока не погашен)
local live_count = 0
local serial = 0

local hero_fx = {}     -- pid -> список индексов аур и эффектов героя
local radiance_fx = {} -- pid -> { item, ent, hero, list, target, targets = { [entindex] = {unit, idx} } }
local tp_state = {}    -- pid -> { start = {индексы} }, пока идёт канал телепорта

---------------------------------------------------------------------------------------------------
-- Партикл: создать, запомнить, погасить
---------------------------------------------------------------------------------------------------

-- Создать партикл. attach == PATTACH_WORLDORIGIN - в точке pos, иначе - на юните unit.
-- cps = { [номер] = Vector | число } - контрольные точки (число -> Vector(число, 0, 0), радиус ауры).
-- point - точка крепления модели (крылья: "attach_hitloc"), тогда CP0 цепляется к ней.
local function Spawn(path, attach, unit, pos, cps, point)
	if not path then return nil end

	local idx

	if attach == PATTACH_WORLDORIGIN then
		idx = ParticleManager:CreateParticle(path, PATTACH_WORLDORIGIN, nil)

		if idx and pos then ParticleManager:SetParticleControl(idx, 0, pos) end
	else
		if not unit or unit:IsNull() then return nil end

		idx = ParticleManager:CreateParticle(path, attach, unit)

		if idx and point then
			ParticleManager:SetParticleControlEnt(idx, 0, unit, PATTACH_POINT_FOLLOW, point, unit:GetAbsOrigin(), true)
		end
	end

	if not idx then return nil end

	for k, v in pairs(cps or {}) do
		ParticleManager:SetParticleControl(idx, k, type(v) == "number" and Vector(v, 0, 0) or v)
	end

	serial = serial + 1
	live[idx] = serial
	live_count = live_count + 1

	return idx
end

-- Погасить партикл: доигрывает и уходит. Повторный вызов безопасен.
local function Free(idx)
	if idx == nil or live[idx] == nil then return end

	live[idx] = nil
	live_count = live_count - 1

	pcall(function()
		ParticleManager:DestroyParticle(idx, false)
		ParticleManager:ReleaseParticleIndex(idx)
	end)
end

local function FreeList(list)
	for _, idx in ipairs(list or {}) do Free(idx) end
end

-- Погасить через life секунд. Проверка серийного номера: индекс мог переиспользоваться.
local function FreeAfter(idx, life)
	if idx == nil or live[idx] == nil then return end

	local s = live[idx]

	Timers:CreateTimer(life, function()
		if live[idx] == s then Free(idx) end

		return nil
	end)
end

-- Список партиклов предмета на юните (follow), без хранения вне списка
local function CreateList(item_particles, unit)
	local out = {}

	for _, p in ipairs(item_particles or {}) do
		local idx = Spawn(p.path, p.attach, unit, nil, p.cps, p.point)

		if idx then out[#out + 1] = idx end
	end

	return out
end

-- Счётчик живых партиклов: раз в минуту в лог
Timers:CreateTimer(60, function()
	print("[Cosmetics] live particles " .. live_count)

	return 60
end)

function FX.FreeList(list)
	FreeList(list)
end

-- Партиклы предмета на юните (пет): вызывается из core.lua, гасится через FreeList
function FX.SpawnUnitFx(unit, item_particles)
	return CreateList(item_particles, unit)
end

---------------------------------------------------------------------------------------------------
-- Ауры и эффекты героя
---------------------------------------------------------------------------------------------------

-- Только ауры и эффекты героя (радианс и телепорт не трогаем)
local function ClearHeroFx(pid)
	FreeList(hero_fx[pid])
	hero_fx[pid] = nil
end

-- Ауры и эффекты героя из экипировки. items = { item, item, ... } (уже найденные по id).
-- Старые партикли гасятся до создания новых: один набор на героя.
function FX.ApplyHeroFx(hero, pid, items)
	ClearHeroFx(pid)

	local list = {}

	for _, item in ipairs(items or {}) do
		for _, idx in ipairs(CreateList(item.particles, hero)) do
			list[#list + 1] = idx
		end
	end

	hero_fx[pid] = list
end

---------------------------------------------------------------------------------------------------
-- Радианс: владелец
---------------------------------------------------------------------------------------------------

local function HasRadiance(hero)
	for i = 0, 16 do
		local it = hero:GetItemInSlot(i)

		if it and RADIANCE_ITEMS[it:GetAbilityName()] then return true end
	end

	return false
end

-- Гасит и owner-партикл, и партиклы на врагах
local function ClearRadiance(pid)
	local rad = radiance_fx[pid]

	if not rad then return end

	for _, t in pairs(rad.targets) do Free(t.idx) end

	FreeList(rad.list)
	radiance_fx[pid] = nil
end

-- Вызывается раз в секунду из core.lua. Владелец с предметом radiance - есть owner-партикл
-- выбранного варианта. Пересоздаётся только при смене варианта или героя (entindex),
-- а не каждый тик.
function FX.SyncRadiance(hero, pid, item)
	local cur = radiance_fx[pid]

	if not item or not hero or hero:IsNull() or not hero:IsAlive() or not HasRadiance(hero) then
		ClearRadiance(pid)

		return
	end

	-- ресурсы варианта ещё догружаются: ждём, следующий тик создаст партикл
	if CosmeticsLoader and not CosmeticsLoader.IsReady(item) then
		CosmeticsLoader.Ensure(item)

		return
	end

	local ent = hero:entindex()

	if cur and cur.item == item.id and cur.ent == ent then return end

	ClearRadiance(pid)

	radiance_fx[pid] = {
		item = item.id,
		ent = ent,
		hero = hero,
		list = CreateList(item.particles, hero),
		target = item.target,
		targets = {},
		dbg = false,
	}
end

-- Есть ли у врага дебафф радианса от этого владельца. Имя модификатора ищем по подстроке
-- "radiance": точное имя движковое, в исходниках мода его нет.
local function HasRadianceDebuff(unit, owner)
	for i = 0, unit:GetModifierCount() - 1 do
		local name = unit:GetModifierNameByIndex(i)

		if name and string.find(string.lower(name), "radiance", 1, true) then
			local m = unit:FindModifierByName(name)
			local src = m and (m:GetCaster() or (m:GetAbility() and m:GetAbility():GetCaster()))

			if src == owner then return true end
		end
	end

	return false
end

-- Имена модификаторов врага - разовая подсказка в лог, если дебаффа радианса не нашли
local function ModifierNames(unit)
	local names = {}

	for i = 0, unit:GetModifierCount() - 1 do
		names[#names + 1] = unit:GetModifierNameByIndex(i)
	end

	return table.concat(names, ", ")
end

-- Раз в RAD_TICK: у каждого врага в радиусе с дебаффом радианса владельца - один партикл
-- варианта (target). Создаётся при появлении дебаффа, гаснет при его снятии, смерти врага
-- или смерти/смене владельца.
function FX.TickRadiance()
	for pid, rad in pairs(radiance_fx) do
		local hero = rad.hero

		if not hero or hero:IsNull() or not hero:IsAlive() then
			ClearRadiance(pid)
		elseif rad.target then
			local found = {}
			local units = FindUnitsInRadius(hero:GetTeamNumber(), hero:GetAbsOrigin(), nil, RAD_RADIUS,
				DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_ALL, DOTA_UNIT_TARGET_FLAG_NONE, FIND_CLOSEST, false)
			local matched = 0
			local heroFirst = false

			for _, u in ipairs(units) do
				if u:IsHero() then heroFirst = true break end
			end

			for _, u in ipairs(units) do
				if matched < RAD_MAX_TARGETS and (u:IsHero() or not heroFirst) and HasRadianceDebuff(u, hero) then
					local ent = u:entindex()

					found[ent] = true
					matched = matched + 1

					if not rad.targets[ent] then
						local idx = Spawn(rad.target, PATTACH_ABSORIGIN_FOLLOW, u, nil, nil)

						if idx then rad.targets[ent] = { unit = u, idx = idx } end
					end
				end
			end

			-- враги в радиусе есть, дебаффа ни у кого не нашли: один раз пишем в лог их модификаторы
			if matched == 0 and #units > 0 and not rad.dbg then
				rad.dbg = true
				print("[Cosmetics] radiance: дебаффа с 'radiance' от владельца не найдено; модификаторы врага: " .. ModifierNames(units[1]))
			end

			for ent, t in pairs(rad.targets) do
				if not found[ent] or t.unit:IsNull() or not t.unit:IsAlive() then
					Free(t.idx)
					rad.targets[ent] = nil
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Снятие всего героя (смерть, дисконнект, репик)
---------------------------------------------------------------------------------------------------

-- Снять всё, что висит на герое игрока: ауры, радианс (и врагов), телепорт
function FX.ClearHero(pid)
	if pid == nil or pid < 0 then return end

	ClearHeroFx(pid)
	ClearRadiance(pid)
	FX.ClearTp(pid)
end

---------------------------------------------------------------------------------------------------
-- Эффект убийства
---------------------------------------------------------------------------------------------------

-- Бурст: KILL_BURST фейерверков из предмета, разброс по KILL_SPREAD и во времени 0..KILL_DELAY,
-- плюс вспышка на земле в точке гибели. Каждый партикл гаснет через KILL_LIFE после своего старта.
function FX.PlayKill(item, pos, victim)
	if not item or not pos or not item.particles or #item.particles == 0 then return end

	if CosmeticsLoader and not CosmeticsLoader.IsReady(item) then
		CosmeticsLoader.Ensure(item)

		return
	end

	-- single - эффект из aaf: один партикл в точке гибели, без бурста и вспышки
	-- Как в aaf: партикл на убитом (PATTACH_ABSORIGIN - стоит на месте трупа), CP 1-3 в точку гибели:
	-- в мировой точке без них часть эффектов не раскрывалась и оставалась горящая точка.
	-- В конце гасим сразу (true), а не даём доиграть.
	if item.single then
		FreeAfter(Spawn(COSMETIC_KILL_FLASH, PATTACH_WORLDORIGIN, nil, pos), KILL_LIFE)

		for _, p in ipairs(item.particles) do
			local idx

			if victim and not victim:IsNull() then
				idx = ParticleManager:CreateParticle(p.path, PATTACH_ABSORIGIN, victim)
			else
				idx = ParticleManager:CreateParticle(p.path, PATTACH_WORLDORIGIN, nil)
			end

			if idx then
				for cp = 0, 3 do ParticleManager:SetParticleControl(idx, cp, pos) end

				Timers:CreateTimer(KILL_LIFE, function()
					ParticleManager:DestroyParticle(idx, true)
					ParticleManager:ReleaseParticleIndex(idx)
				end)
			end
		end

		return
	end

	FreeAfter(Spawn(COSMETIC_KILL_FLASH, PATTACH_WORLDORIGIN, nil, pos), KILL_LIFE)

	for i = 1, KILL_BURST do
		local delay = (i == 1) and 0 or RandomFloat(0, KILL_DELAY)
		local off = RandomVector(RandomFloat(0, KILL_SPREAD))
		local at = pos + Vector(off.x, off.y, 0)

		Timers:CreateTimer(delay, function()
			for _, p in ipairs(item.particles) do
				FreeAfter(Spawn(p.path, PATTACH_WORLDORIGIN, nil, at, p.cps), KILL_LIFE)
			end

			return nil
		end)
	end
end

---------------------------------------------------------------------------------------------------
-- Телепорт
---------------------------------------------------------------------------------------------------

-- Пути телепорта для Snake Boots (items/item_snake_tpscroll.lua). Вернёт nil, если выбран дефолт.
-- Возвращает start_path, end_path.
function FX.TpPaths(hero)
	if not hero or hero:IsNull() or not CosmeticsCore or not CosmeticsCore.GetEquipped then return nil end

	local pid = hero:GetPlayerOwnerID()

	if pid == nil or pid < 0 then return nil end

	local item = CosmeticsCore:GetEquipped(pid, "tp_effect")

	if not item or not item.particles or not item.particles[1] then return nil end

	-- не догружено: дефолтный свиток в этот раз, на следующем касте уже косметика
	if CosmeticsLoader and not CosmeticsLoader.IsReady(item) then
		CosmeticsLoader.Ensure(item)

		return nil
	end

	local e = item.end_particles and item.end_particles[1]

	return item.particles[1].path, e and e.path or nil
end

-- Погасить старт телепорта (отмена или прибытие)
function FX.ClearTp(pid)
	local st = tp_state[pid]

	if not st then return end

	tp_state[pid] = nil
	FreeList(st.start)
end

-- Старт в точке каста. Вызывать из dota_player_used_ability с именем предмета из TP_ITEMS.
-- Наблюдение: если позиция скакнула - прибытие (старт гасим, в новой точке - end на TP_END_LIFE);
-- если канал закончился без скачка - отмена (старт гасим сразу, без хвоста).
function FX.BeginTp(item, hero, pid)
	if not item or not hero or hero:IsNull() or pid == nil or pid < 0 then return end

	if CosmeticsLoader and not CosmeticsLoader.IsReady(item) then
		CosmeticsLoader.Ensure(item)

		return
	end

	FX.ClearTp(pid)

	local st = { start = {} }

	tp_state[pid] = st

	for _, p in ipairs(item.particles or {}) do
		local idx = Spawn(p.path, PATTACH_WORLDORIGIN, nil, hero:GetAbsOrigin(), p.cps)

		if idx then st.start[#st.start + 1] = idx end
	end

	local last = hero:GetAbsOrigin()
	local elapsed = 0

	Timers:CreateTimer(TP_TICK, function()
		if tp_state[pid] ~= st then return nil end

		if not hero or hero:IsNull() or not hero:IsAlive() then
			FX.ClearTp(pid)

			return nil
		end

		local pos = hero:GetAbsOrigin()
		local jump = (pos - last):Length2D()

		last = pos
		elapsed = elapsed + TP_TICK

		if jump >= TP_JUMP then
			FX.ClearTp(pid)

			for _, p in ipairs(item.end_particles or {}) do
				FreeAfter(Spawn(p.path, PATTACH_WORLDORIGIN, nil, pos, p.cps), TP_END_LIFE)
			end

			return nil
		end

		if elapsed >= TP_GRACE and not hero:IsChanneling() then
			FX.ClearTp(pid)

			return nil
		end

		if elapsed >= TP_WINDOW then
			FX.ClearTp(pid)

			return nil
		end

		return TP_TICK
	end)
end
