-- Телеметрия боя с боссом (2026-11-25): событие матча "boss_fight" на каждый
-- исход боя - убит ("kill") или бросили ("reset": RESET_AFTER с без урона).
-- В событии: босс и номер его жизни, когда дали первую тычку и сколько длился
-- бой, ХП и броня босса, кто бил (урон по типам, уровень, нетворс, предметы),
-- сколько героев босс убил за бой, средние уровни команд. Для баланса боссов.

if not IsServer() then return end
if BossFightStats ~= nil then return end

BossFightStats = { fights = {} }   -- entindex босса -> бой

local F = BossFightStats
local RESET_AFTER = 30
local TICK = 5

local function Push(etype, pid, data)
	if MatchTracker and MatchTracker.Push then pcall(MatchTracker.Push, MatchTracker, etype, pid, data) end
end

local function OwnerPid(unit)
	if not unit or unit:IsNull() or not unit.GetPlayerOwnerID then return -1 end
	local ok, pid = pcall(unit.GetPlayerOwnerID, unit)
	return ok and pid or -1
end

local function HeroSnapshot(pid)
	local hero = PlayerResource:GetSelectedHeroEntity(pid)
	if not hero or hero:IsNull() then return {} end
	local items = {}
	for slot = 0, 5 do
		local it = hero:GetItemInSlot(slot)
		if it then table.insert(items, it:GetAbilityName()) end
	end
	local nt = hero:GetItemInSlot(16)
	local nw = 0
	pcall(function()
		nw = (MatchTracker and MatchTracker.NetWorthOf) and MatchTracker.NetWorthOf(pid) or PlayerResource:GetNetWorth(pid)
	end)
	return {
		hero = hero:GetUnitName(), lvl = hero:GetLevel(), nw = math.floor(nw or 0),
		items = items, neutral = nt and nt:GetAbilityName() or nil,
		dmg_attack = math.floor(hero:GetAverageTrueAttackDamage(nil)),
		team = hero:GetTeamNumber(),
	}
end

local function TeamAvg(team)
	local s, n = 0, 0
	for pid = 0, 23 do
		if PlayerResource:IsValidPlayerID(pid) and PlayerResource:GetTeam(pid) == team then
			local h = PlayerResource:GetSelectedHeroEntity(pid)
			if h then s = s + h:GetLevel(); n = n + 1 end
		end
	end
	return n > 0 and math.floor(s / n * 10 + 0.5) / 10 or 0
end

local function Start(unit)
	local f = {
		boss = unit.aa_boss_name, unit = unit:GetUnitName(), life = unit.aa_boss_deaths,
		start = GameRules:GetGameTime(), dota_t = GameRules:GetDOTATime(false, false),
		max_hp = unit:GetMaxHealth(), armor = math.floor(unit:GetPhysicalArmorValue(false) * 10 + 0.5) / 10,
		by = {}, hero_deaths = {}, last = GameRules:GetGameTime(), total = 0,
	}
	F.fights[unit:entindex()] = f
	return f
end

-- modifier_boss_power:OnTakeDamage
function F:OnDamaged(unit, attacker, damage, dtype, inflictor)
	if not unit or unit:IsNull() or not attacker or attacker:IsNull() then return end
	if attacker:GetTeamNumber() == unit:GetTeamNumber() then return end
	local f = self.fights[unit:entindex()] or Start(unit)
	local pid = OwnerPid(attacker)
	local key = pid >= 0 and pid or -1
	local b = f.by[key]
	if not b then
		b = { dmg = 0, phys = 0, magic = 0, pure = 0, hits = 0, summon = 0 }
		f.by[key] = b
	end
	damage = tonumber(damage) or 0
	b.dmg = b.dmg + damage
	b.hits = b.hits + 1
	if dtype == DAMAGE_TYPE_PHYSICAL then b.phys = b.phys + damage
	elseif dtype == DAMAGE_TYPE_MAGICAL then b.magic = b.magic + damage
	else b.pure = b.pure + damage end
	if not (attacker.IsRealHero and attacker:IsRealHero()) then b.summon = b.summon + damage end
	f.total = f.total + damage
	f.last = GameRules:GetGameTime()
end

local function Finish(idx, f, result, killer)
	F.fights[idx] = nil
	local now = GameRules:GetGameTime()
	local by = {}
	local teams = {}
	for pid, b in pairs(f.by) do
		local e = { pid = pid, dmg = math.floor(b.dmg), phys = math.floor(b.phys), magic = math.floor(b.magic),
			pure = math.floor(b.pure), summon = math.floor(b.summon), hits = b.hits }
		if pid >= 0 and PlayerResource:IsValidPlayerID(pid) then
			for k, v in pairs(HeroSnapshot(pid)) do e[k] = v end
			if e.team then teams[e.team] = true end
		end
		table.insert(by, e)
	end
	local avg = {}
	for team in pairs(teams) do avg[tostring(team)] = TeamAvg(team) end
	local deaths = {}
	for pid, n in pairs(f.hero_deaths) do table.insert(deaths, { pid = pid, n = n }) end

	Push("boss_fight", killer or -1, {
		result = result, boss = f.boss, unit = f.unit, life = f.life,
		first_hit = math.floor(f.dota_t), dur = math.floor((result == "kill" and now or f.last) - f.start),
		max_hp = f.max_hp, armor = f.armor, total_dmg = math.floor(f.total),
		heroes = #by, by = by, hero_deaths = deaths, team_avg = avg,
	})
end

-- BossSpawner:HandleUnitKill
function F:OnKilled(unit, killer)
	if not unit or unit:IsNull() then return end
	local f = self.fights[unit:entindex()]
	if not f then return end
	Finish(unit:entindex(), f, "kill", OwnerPid(killer))
end

-- герой умер от босса в бою
ListenToGameEvent("entity_killed", function(ev)
	pcall(function()
		local killed = ev.entindex_killed and EntIndexToHScript(ev.entindex_killed)
		local att = ev.entindex_attacker and EntIndexToHScript(ev.entindex_attacker)
		if not killed or not att or not killed.IsRealHero or not killed:IsRealHero() then return end
		-- урон мог прийти от призыва босса (волки, скелеты) - ищем владельца-босса
		local boss = att.aa_boss_name and att or (att.GetOwner and att:GetOwner())
		if not boss or boss:IsNull() or not boss.aa_boss_name then return end
		local f = F.fights[boss:entindex()]
		if not f then return end
		local pid = killed:GetPlayerOwnerID()
		f.hero_deaths[pid] = (f.hero_deaths[pid] or 0) + 1
	end)
end, nil)

Timers:CreateTimer(TICK, function()
	local now = GameRules:GetGameTime()
	for idx, f in pairs(F.fights) do
		local u = EntIndexToHScript(idx)
		if not u or u:IsNull() or not u:IsAlive() then
			F.fights[idx] = nil
		elseif now - f.last >= RESET_AFTER then
			pcall(Finish, idx, f, "reset", nil)
		end
	end
	return TICK
end)

return F
