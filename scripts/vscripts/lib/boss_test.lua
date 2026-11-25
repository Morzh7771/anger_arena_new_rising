-- Тест боссов с механиками без спавнера. В чате (лобби с читами):
--   -aa_boss <имя> [смертей], -aa_boss_clear, -aa_boss_list
-- (lib/chat_commands/cheat_commands.lua). То же в консоли:
--   aa_boss <имя> [смертей]   - босс в 600 перед твоим героем (имя: leoric,
--                               chrono, reaper, lycan, pudge, ursa, huskar
--                               или полное npc_aa_...). Статы как у нижнего
--                               слота: 15000 HP, 1000 урона, 50 брони
--                               (+10000 HP / +350 урона / +15 брони за смерть).
--   aa_boss_list              - список коротких имён
--   aa_boss_clear             - убрать всех заспавненных командой
-- Только в тулзах или у владельца (как aa_perf).

BossTest = BossTest or { spawned = {} }

local OWNER_ACCOUNT = 960329385

local ALIASES = {
	leoric = "npc_aa_leoric",
	chrono = "npc_aa_chronokeeper",
	reaper = "npc_aa_plague_reaper",
	lycan  = "npc_aa_lycan_boss",
	pudge  = "npc_aa_pudge_boss",
	ursa   = "npc_aa_ursa_boss",
	huskar = "npc_aa_huskar_boss",
	doom   = "boss_possessed_demon",
}

local function Allowed()
	if IsInToolsMode() then return true end
	local player = Convars:GetCommandClient()
	if not player then return false end
	local ok, acc = pcall(function() return PlayerResource:GetSteamAccountID(player:GetPlayerID()) end)
	return ok and acc == OWNER_ACCOUNT
end

local function CallerHero()
	local player = Convars:GetCommandClient()
	if player and player.GetAssignedHero then
		local h = player:GetAssignedHero()
		if h then return h end
	end
	for pid = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(pid) then
			local h = PlayerResource:GetSelectedHeroEntity(pid)
			if h then return h end
		end
	end
end

function BossTest:Spawn(hero, name, deaths)

	local unitName = ALIASES[tostring(name or "")] or tostring(name or "")
	if unitName == "" then
		print("[AA.boss_test] aa_boss <leoric|chrono|reaper|lycan|pudge|ursa|huskar> [смертей]")
		return
	end

	if not hero then print("[AA.boss_test] нет героя") return end

	deaths = tonumber(deaths) or 0

	local fwd = hero:GetForwardVector()
	local pos = hero:GetAbsOrigin() + Vector(fwd.x, fwd.y, 0):Normalized() * 600

	PrecacheUnitByNameAsync(unitName, function()
		local unit = CreateUnitByName(unitName, pos, true, nil, nil, DOTA_TEAM_NEUTRALS)
		if not unit then
			print("[AA.boss_test] не создался юнит", unitName)
			return
		end

		unit.aa_boss_deaths = deaths
		unit:AddNewModifier(unit, nil, "modifier_boss_cast_alert", { duration = -1 })
		unit:AddNewModifier(unit, nil, "modifier_boss_true_sight", { duration = -1 })
		unit:FaceTowards(hero:GetAbsOrigin())

		local hp    = 15000 + 10000 * deaths
		local dmg   = 1000 + 350 * deaths
		local armor = 50 + 15 * deaths

		unit:SetBaseMaxHealth(hp)
		unit:SetMaxHealth(hp)
		unit:SetHealth(hp)
		unit:SetBaseDamageMin(dmg)
		unit:SetBaseDamageMax(dmg)
		unit:SetPhysicalArmorBaseValue(armor)

		for i = 0, unit:GetAbilityCount() - 1 do
			local ab = unit:GetAbilityByIndex(i)
			if ab and ab:GetLevel() == 0 then ab:SetLevel(1) end
		end

		table.insert(BossTest.spawned, unit)
		print(string.format("[AA.boss_test] %s: HP %d, урон %d, броня %d, смертей %d", unitName, hp, dmg, armor, deaths))
	end)
	return true
end

function BossTest:Clear()
	for _, u in pairs(self.spawned) do
		if u and not u:IsNull() then
			for _, w in pairs(u.aa_wolves or {}) do
				if w and not w:IsNull() then UTIL_Remove(w) end
			end
			UTIL_Remove(u)
		end
	end
	self.spawned = {}
end

function BossTest:Names()
	local res = {}
	for k in pairs(ALIASES) do table.insert(res, k) end
	table.sort(res)
	return table.concat(res, ", ")
end

Convars:RegisterCommand("aa_boss", function(_, name, deaths)
	if not Allowed() then return end
	BossTest:Spawn(CallerHero(), name, deaths)
end, "Тест босса: aa_boss <имя> [смертей]", 0)

Convars:RegisterCommand("aa_boss_list", function()
	if not Allowed() then return end
	for k, v in pairs(ALIASES) do print("  " .. k .. " -> " .. v) end
end, "Список боссов для aa_boss", 0)

-- ротация боссов спавнера: шаг сетки сразу (переход всё равно ждёт 30 с
-- без урона и 5 с канала) и состояние пар
Convars:RegisterCommand("aa_boss_rotate", function()
	if not Allowed() then return end
	if not BossSpawner or not BossSpawner.ShiftRotation then return end
	BossSpawner:ShiftRotation()
	print("[AA.boss_test] сетка ротации сдвинута")
	for _, l in pairs(BossSpawner:RotationInfo()) do print("  " .. l) end
end, "Ротация боссов: шаг сетки сейчас", 0)

Convars:RegisterCommand("aa_boss_rotation", function()
	if not Allowed() then return end
	if not BossSpawner or not BossSpawner.RotationInfo then return end
	for _, l in pairs(BossSpawner:RotationInfo()) do print("  " .. l) end
end, "Ротация боссов: состояние", 0)

Convars:RegisterCommand("aa_boss_clear", function()
	if not Allowed() then return end
	BossTest:Clear()
	print("[AA.boss_test] убраны")
end, "Убрать боссов aa_boss", 0)
