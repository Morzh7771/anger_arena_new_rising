require('lib/dropbox')

BossClass = BossClass or class({})

local BOUNTY_AOE = 1200
local LOOT_RADIUS = 75

-- Босс кричит на всю карту, когда его бьёт команда, которая уже убила его
-- ATTACK_ALERT_TEAM_KILLS раз, - как рошан в доте: вторая команда успевает
-- прийти. Кричит не чаще раза в кулдаун.
local ATTACK_ALERT_TEAM_KILLS = 1
local ATTACK_ALERT_COOLDOWN = 30
-- пинги миникарты при атаке босса: сколько раз и через сколько секунд
local ATTACK_ALERT_PING_COUNT = 3
local ATTACK_ALERT_PING_INTERVAL = 2

-- крик по виду босса; вид - хвост on_death.message (#on_boss_die_<вид>).
-- Кого тут нет, тот не кричит вовсе - так сделаны Торменторы (miniboss).
local ATTACK_ALERT_SOUNDS = {
	possessed     = "Boss_Possessed.Curse.Cast",
	soul_guardian = "Hero_Omniknight.Purification",
	abyss_warrior = "Hero_Warlock.FatalBonds",
	leoric        = "Hero_SkeletonKing.Reincarnate",
	chronokeeper  = "Hero_FacelessVoid.Chronosphere",
	pudge         = "Hero_Pudge.Dismember.Cast",
	huskar        = "Hero_Huskar.Life_Break",
	keymaster     = "Boss_Keymaster.Howl.Cast",
	plague_reaper = "Hero_Necrolyte.ReapersScythe.Cast",
	ursa          = "Hero_Ursa.Enrage",
	lycan         = "Hero_Lycan.Howl",
}

-- вид босса для пула (unit_pool): от него крик "атакуют", строка в чате
-- и килфид (#aa_boss_attacked_<вид>, #aa_feed_boss_<вид>)
local POOL_KIND = {
	npc_aa_leoric        = "leoric",
	npc_aa_chronokeeper  = "chronokeeper",
	npc_aa_plague_reaper = "plague_reaper",
	npc_aa_pudge_boss    = "pudge",
	npc_aa_huskar_boss   = "huskar",
	npc_aa_ursa_boss     = "ursa",
	npc_aa_lycan_boss    = "lycan",
}

function BossClass:Create( name, description, allTables )
	local masterName = description["master"]

	local master

	if masterName ~= nil then
		master = allTables[masterName]
	end

	function GetField(field)
		local res = description[field]

		if res == nil and master ~= nil then
			res = master[field]
		end

		return res
	end

	boss = BossClass()

	boss.name = name

	local unitName = GetField("unit_name")

	boss.unitName = unitName

	local point = GetField("point_name")

	if not point then 
		print("[BossClass] Create failed, no point name in configuration for boss", name)
		return
	end

	local pointEnt = Entities:FindByName(nil, point)

	if not pointEnt then
		print("[BossClass] Create failed, no point entity named ", point, " for boss", name)
		return
	end

	boss.point 	 = pointEnt:GetAbsOrigin()
	boss.forward = pointEnt:GetForwardVector()
	boss.pointName = point

	-- Ротация: босс ходит по rotation_points (первая - point_name), меняя
	-- точку каждые rotation_interval секунд от первого спавна. Пока его бьют,
	-- переход ждёт rotation_quiet секунд без урона (BossSpawner:_RotationTick).
	local rotation = GetField("rotation_points")
	if rotation then
		local r = {
			points   = {},
			interval = tonumber(GetField("rotation_interval")) or 300,
			quiet    = tonumber(GetField("rotation_quiet")) or 30,
		}
		local names = {}

		for pname in tostring(rotation):gmatch("%S+") do
			local ent = Entities:FindByName(nil, pname)
			if ent then
				table.insert(r.points, { name = pname, pos = ent:GetAbsOrigin(), forward = ent:GetForwardVector() })
				table.insert(names, pname)
			else
				print("[BossClass] rotation point not found", pname, "boss", name)
			end
		end

		if #r.points >= 2 and r.interval > 0 then
			-- боссы с одинаковым набором точек меняются местами вместе
			table.sort(names)
			r.group = table.concat(names, " ")
			boss.rotation = r
			boss.rotationIndex = 1
		end
	end

	boss.spawnDelay 	= GetField("spawn_delay") or 0
	boss.spawnInterval 	= GetField("spawn_interval") or 0

	if boss.spawnInterval == 0 then
		print("[BossClass] Create failed, boss haven't spawn interval, boss", name)
		return
	end

	boss.spawnIntervalRandom = GetField("spawn_interval_random") or 0

	boss.stats = GetField('stats')

	if not boss.stats then
		print("[BossClass] Create failed, boss haven't stats, boss", name)
		return
	end

	boss.onDeath = GetField('on_death')

	if not boss.onDeath then
		print("[BossClass] Create failed, boss haven't onDeath data, boss", name)
		return
	end

	local dropbox = boss.onDeath["dropbox"]

	if dropbox ~= nil then
		boss.dropbox = DropBox:GetDropbox( dropbox )
	end

	-- вид босса и половина карты - для сообщения "атакуют" в чат. Половину
	-- берём из имени в boss_spawners.kv: *radiant*, *dire*, остальные стоят
	-- по центру
	boss.kind = (tostring(boss.onDeath["message"] or ""):gsub("^#on_boss_die_", ""))
	boss.side = (point:find("radiant", 1, true) and "radiant") or (point:find("dire", 1, true) and "dire") or "mid"

	boss.deathCount = -1

	-- [команда] = сколько раз она убила этого босса
	boss.teamKills = {}

	PrecacheUnitByNameAsync(unitName, function(...) end)

	-- Пул: на каждом спавне на слот встаёт случайный юнит из unit_pool
	-- (BossSpawner:_PickPoolUnit). Статы и награда у слота общие.
	local pool = GetField("unit_pool")
	if pool then
		boss.unitPool = {}
		for u in tostring(pool):gmatch("%S+") do
			table.insert(boss.unitPool, u)
			if u ~= unitName then PrecacheUnitByNameAsync(u, function() end) end
		end
		if #boss.unitPool == 0 then boss.unitPool = nil end
	end

	-- Лут босса создаётся предметами в его инвентаре в момент спавна. Без
	-- прекеша первый CreateItem каждого предмета синхронно грузил ресурсы,
	-- и первый спавн минибоссов в 05:00 давал фриз ~0.5 с.
	if boss.dropbox and boss.dropbox.GetItemNames then
		for _, data in pairs(boss.dropbox:GetItemNames()) do
			if data[1] then PrecacheItemByNameAsync(data[1], function() end) end
		end
	end

	return boss
end

function BossClass:Spawn()
	print("[BossClass] Boss", self.name, "try to spawn")
	
	local unit = CreateUnitByName(self.unitName, self.point, true, nil, nil, DOTA_TEAM_NEUTRALS)

	if not unit then
		print("[BossClass] Failed to spawn boss unit, boss name", name, "unit name is", self.unitName)
		return
	end

	print("[BossClass] Boss", self.name, "unit spawned")

	unit:SetForwardVector(self.forward)
	
	unit:Stop()

	self:_SetStats(unit)
	self:_ShowLoot(unit)

	self.unit = unit
	self.lastAttackAlert = nil

	return unit
end

-- индекс точки ротации, где босс должен стоять в момент now (время доты)
function BossClass:RotationTarget(now)
	local r = self.rotation
	if not r then return nil end
	local slot = math.max(0, math.floor((now - self.spawnDelay) / r.interval))
	slot = slot + (BossSpawner and BossSpawner.rotationShift or 0)
	return (slot % #r.points) + 1
end

function BossClass:SetRotationIndex(index)
	local pt = self.rotation and self.rotation.points[index]
	if not pt then return end
	self.rotationIndex = index
	self.point = pt.pos
	self.forward = pt.forward
	self.pointName = pt.name
	self.side = (pt.name:find("radiant", 1, true) and "radiant") or (pt.name:find("dire", 1, true) and "dire") or "mid"
end

function BossClass:SetUnitName(unitName)
	self.unitName = unitName
	self.kind = POOL_KIND[unitName] or self.kind
end

function BossClass:GetInitialSpawnDelay()
	return max( self.spawnDelay, 0 )
end

function BossClass:GetSpawnTime()
	local spawnIntervalRandom = self.spawnIntervalRandom

	return max( self.spawnInterval + RandomFloat(-spawnIntervalRandom, spawnIntervalRandom), 0 )
end

-- в каких пределах выпадает GetSpawnTime
function BossClass:GetSpawnTimeRange()
	local spawnIntervalRandom = self.spawnIntervalRandom

	return max( self.spawnInterval - spawnIntervalRandom, 0 ), max( self.spawnInterval + spawnIntervalRandom, 0 )
end

function BossClass:GetDeathCount()
	return self.deathCount + 1
end

function BossClass:OnDeath(killerTeam,killer)
	local unit = self.unit

	self.unit = nil

	-- в инвентаре лежала только витрина дропа, на землю падает свежий
	self:_ClearLoot(unit)

	local pos = unit:GetAbsOrigin()

	-- кто убил босса - в своём килфиде (lib/kill_feed.lua), не в чате

	local deathCount = self:GetDeathCount()

	print("[BossClass] Boss", self.name, "now dead, death count", deathCount)

	self.deathCount = deathCount

	-- от этого счёта зависит крик "атакуют" (OnDamaged)
	if killerTeam == DOTA_TEAM_GOODGUYS or killerTeam == DOTA_TEAM_BADGUYS then
		self.teamKills[killerTeam] = (self.teamKills[killerTeam] or 0) + 1
	end

	local units = FindUnitsInRadius( DOTA_TEAM_NEUTRALS,
									 pos,
									 nil,
									 BOUNTY_AOE,
									 DOTA_UNIT_TARGET_TEAM_ENEMY,
									 DOTA_UNIT_TARGET_HERO,
									 DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_INVULNERABLE,
									 FIND_ANY_ORDER,
									 false )

	-- в статистику босс идёт всем, кто был рядом, а не только добившему
	if EndGameStats then EndGameStats:OnBossKilled(killer, killerTeam, units) end

	local bountyTable = self.onDeath

	local bountyGold = (bountyTable["base_gold"] or 0) + (bountyTable["gold_per_death"] or 0 ) * deathCount
	local bountyExp  = (bountyTable["base_exp"]  or 0) + (bountyTable["exp_per_death"]  or 0 ) * deathCount

	TeamHelper:ApplyForHeroes(killerTeam, function(playerid, hero)
		if hero == killer then
			-- через запас: награда растёт со смертями и переваливает за 50000
			AngelArena:GiveGold(playerid, bountyGold, false, DOTA_ModifyGold_RoshanKill)
			AngelArena:ShowGoldPopup(playerid, bountyGold)
			hero:AddExperience(bountyExp, DOTA_ModifyXP_RoshanKill, false, true)
		else
			AngelArena:GiveGold(playerid, bountyGold/2, false, DOTA_ModifyGold_RoshanKill)
			AngelArena:ShowGoldPopup(playerid, bountyGold/2)
			hero:AddExperience(bountyExp/2, DOTA_ModifyXP_RoshanKill, false, true)
		end
	end)

	-- усталость: ещё стак -30% урона по боссам на базовое время респавна этого босса
	local fatigue = self.spawnInterval or 0
	if fatigue > 0 and (killerTeam == DOTA_TEAM_GOODGUYS or killerTeam == DOTA_TEAM_BADGUYS) then
		TeamHelper:ApplyForHeroes(killerTeam, function(_, hero)
			hero:AddNewModifier(hero, nil, "modifier_boss_slayer_fatigue", { duration = fatigue })
		end)
	end

	if KillFeed then KillFeed:Boss(killer, unit:GetUnitName(), self.kind, killerTeam, bountyGold, bountyGold / 2) end

	self:_DropItems( pos )

	-- души растут каждые 2 смерти: к обычному дропу +0, +0, +1, +1, +2, +2...
	-- (при базовой 1 душе выходит 1 - 1 - 2 - 2 - 3 - 3). deathCount с нуля.
	local extraSouls = self:_ExtraSouls(deathCount)

	if extraSouls > 0 and self:_DropsBossSoul() then
		for i = 1, extraSouls do
			local soul = CreateItem("item_boss_soul", nil, nil)

			if soul then
				soul:SetPurchaseTime(0)
				CreateItemOnPositionSync(pos + RandomVector(LOOT_RADIUS), soul)
			end
		end
	end
end


function BossClass:_SetStats(unit)
	local deathCount = self:GetDeathCount()

	local hp 	= self.stats["base_health"] + self.stats["health_per_death"] * deathCount
	local armor = self.stats["base_armor"] + self.stats["armor_per_death"] * deathCount
	local dmg 	= self.stats["base_damage"] + self.stats["damage_per_death"] * deathCount

	unit:SetBaseMaxHealth(hp)
	unit:SetMaxHealth(hp)
	unit:SetHealth(hp)
	unit:SetBaseDamageMin(dmg)
	unit:SetBaseDamageMax(dmg)
	unit:SetPhysicalArmorBaseValue( armor )
end

-- Сколько душ сверх дропбокса за смерть с номером deathIndex (с нуля):
-- 0, 0, 1, 1, 2, 2... Один расчёт и для дропа, и для витрины в инвентаре.
function BossClass:_ExtraSouls(deathIndex)
	if not self:_DropsBossSoul() then return 0 end

	return math.floor((deathIndex or 0) / 2)
end

-- в дропе босса есть души (у Торменторов вместо них Аганим и шард)
function BossClass:_DropsBossSoul()
	if not self.dropbox then return false end

	for _, data in pairs(self.dropbox:GetItemNames()) do
		if data[1] == "item_boss_soul" then return true end
	end

	return false
end

function BossClass:_DropItems(pos)
	local dropbox = self.dropbox

	if not dropbox then return end

	dropbox:DropAtPos(pos, LOOT_RADIUS)
end

-- Что упадёт с босса, лежит у него в инвентаре: выделил босса - видно,
-- сколько душ за него дают (у Торментора - Аганим и шард). Сами эти
-- предметы не падают: перед смертью их убирает _ClearLoot, а на землю
-- кладёт свежие _DropItems.
function BossClass:_ShowLoot(unit)
	if not self.dropbox or not unit:HasInventory() then return end

	-- прибавка душ за эту (следующую) смерть - как упадёт в OnDeath
	local extraSouls = self:_ExtraSouls(self:GetDeathCount())

	for _, data in pairs(self.dropbox:GetItemNames()) do
		local count = tonumber(data[2]) or 1

		if data[1] == "item_boss_soul" then count = count + extraSouls end

		for i = 1, count do
			local item = CreateItem(data[1], nil, nil)

			if item then
				unit:AddItem(item)
			end
		end
	end
end

function BossClass:_ClearLoot(unit)
	if not unit or unit:IsNull() or not unit:HasInventory() then return end

	for i = 0, 8 do
		local item = unit:GetItemInSlot(i)

		if item then
			unit:RemoveItem(item)
		end
	end
end

-- Как рошан в доте: босс кричит на всю карту и в чат уходит, кого бьют.
-- Считаем по команде, которая бьёт: кричит, только если именно она уже
-- убила его ATTACK_ALERT_TEAM_KILLS раз. Убивали враги, а бьём мы - молчит.
function BossClass:OnDamaged(attacker)
	local sound = ATTACK_ALERT_SOUNDS[self.kind]

	if not sound then return end
	if not attacker or attacker:IsNull() or not attacker.GetTeamNumber then return end

	if (self.teamKills[attacker:GetTeamNumber()] or 0) < ATTACK_ALERT_TEAM_KILLS then return end

	local now = GameRules:GetGameTime()

	if self.lastAttackAlert and now - self.lastAttackAlert < ATTACK_ALERT_COOLDOWN then return end

	self.lastAttackAlert = now

	-- рёв рошана на всю карту (soundevents/aa_alerts.vsndevts) вместо звука
	-- способности: тот терялся в бою
	EmitGlobalSound("AA.Boss.Attacked")

	-- красная надпись всем, как "Рошана атакуют": в чат и по центру экрана
	local token = "#aa_boss_attacked_" .. tostring(self.kind)
	pcall(function() GameRules:SendCustomMessage(token, 0, 0) end)
	pcall(function()
		FireGameEvent("dota_hud_error_message", { splitscreenplayer = 0, reason = 80, message = token .. "_hud" })
	end)

	-- метки на миникарте обеим командам, чтобы было видно, какого именно:
	-- три пинга подряд, между ними по 2 секунды
	for i = 0, ATTACK_ALERT_PING_COUNT - 1 do
		Timers:CreateTimer(i * ATTACK_ALERT_PING_INTERVAL, function()
			if PanoramaPingManager and PanoramaPingManager.PingForAll
				and self.unit and not self.unit:IsNull() then
				PanoramaPingManager:PingForAll(self.unit:GetAbsOrigin())
			end
		end)
	end
end