-- Версии героев Angel Arena: у шести ванильных героев есть "своя" версия (Gun Joe у Sniper и т.д.).
--
-- В пике (ванильном, премиум-окне, репике) у базового героя жёлтая обводка и тумблер
-- "Sniper | Gun Joe" над карточкой. Версии AA в сетке не показываются (прячет клиент).
-- Пара одна на всю игру: взяли одну версию - вторая недоступна всем.
--
--   нет-таблица aa_alt["pairs"]  = { alt = base }
--               aa_alt["info"]   = { alt = { name, attr, str, str_gain, agi, agi_gain, int, int_gain,
--                                            dmg_min, dmg_max, armor, bat, ms, range, ranged, hp, mana,
--                                            hp_regen, mana_regen } }
--               aa_alt["taken"]  = { hero = 1 } - выбранные (любой версии) герои пар
--   клиент -> сервер  aa_alt_pick { hero }  - взять версию AA в ванильном пике
--   сервер -> клиент  aa_alt_error { msg }

if not IsServer() then return end
if AltHeroes ~= nil then return end

AltHeroes = {
	PAIRS = {
		npc_dota_hero_forgotten_hero = "npc_dota_hero_monkey_king",
		npc_dota_hero_gun_joe        = "npc_dota_hero_sniper",
		npc_dota_hero_hola           = "npc_dota_hero_omniknight",
		npc_dota_hero_joe_black      = "npc_dota_hero_necrolyte",
		npc_dota_hero_reaver_lord    = "npc_dota_hero_terrorblade",
		npc_dota_hero_spike          = "npc_dota_hero_bristleback",
		npc_dota_hero_shadowsong     = "npc_dota_hero_antimage",
		npc_dota_hero_fireblade      = "npc_dota_hero_ember_spirit",
		npc_dota_hero_huntress       = "npc_dota_hero_mirana",
		npc_dota_hero_charon         = "npc_dota_hero_visage",
		npc_dota_hero_satan          = "npc_dota_hero_doom_bringer",
	},
	BASE = {},
	blacklisted = {},
}

local A = AltHeroes

for alt, base in pairs(A.PAIRS) do A.BASE[base] = alt end

-- Партнёр героя по паре (или nil)
function A:Partner(hero)
	return self.PAIRS[hero] or self.BASE[hero]
end

function A:IsAlt(hero)
	return self.PAIRS[hero] ~= nil
end

local ATTR = {
	DOTA_ATTRIBUTE_STRENGTH = "str",
	DOTA_ATTRIBUTE_AGILITY = "agi",
	DOTA_ATTRIBUTE_INTELLECT = "int",
	DOTA_ATTRIBUTE_ALL = "all",
}

local function num(v, d) return tonumber(v) or d end

-- Статы для карточки. Формулы как в доте 7.42: 22 HP и 0.1 реген за силу, 12 маны и 0.05 реген за интеллект.
function A:BuildInfo(alt)
	local short = alt:gsub("^npc_dota_hero_", "")
	local kv = LoadKeyValues("scripts/npc/heroes/" .. short .. "/hero_data.txt")
	kv = kv and kv[alt]
	if not kv then return nil end

	local str, int = num(kv.AttributeBaseStrength, 0), num(kv.AttributeBaseIntelligence, 0)

	return {
		name = alt,
		attr = ATTR[kv.AttributePrimary or ""] or "all",
		str = str, str_gain = num(kv.AttributeStrengthGain, 0),
		agi = num(kv.AttributeBaseAgility, 0), agi_gain = num(kv.AttributeAgilityGain, 0),
		int = int, int_gain = num(kv.AttributeIntelligenceGain, 0),
		dmg_min = num(kv.AttackDamageMin, 0), dmg_max = num(kv.AttackDamageMax, 0),
		armor = num(kv.ArmorPhysical, 0),
		bat = num(kv.AttackRate, 1.7),
		ms = num(kv.MovementSpeed, 300),
		range = num(kv.AttackRange, 150),
		ranged = kv.AttackCapabilities == "DOTA_UNIT_CAP_RANGED_ATTACK" and 1 or 0,
		hp = 120 + str * 22,
		mana = 75 + int * 12,
		hp_regen = num(kv.StatusHealthRegen, 0) + str * 0.1,
		mana_regen = num(kv.StatusManaRegen, 0) + int * 0.05,
	}
end

function A:Publish()
	local info = {}

	for alt, _ in pairs(self.PAIRS) do
		info[alt] = self:BuildInfo(alt)
	end

	CustomNetTables:SetTableValue("aa_alt", "pairs", self.PAIRS)
	CustomNetTables:SetTableValue("aa_alt", "info", info)
	CustomNetTables:SetTableValue("aa_alt", "taken", {})
end

-- герой выбран кем-то (в движке или бронью премиум-пика)
function A:IsHeroTaken(hero, except)
	for pid = 0, DOTA_MAX_PLAYERS - 1 do
		if pid ~= except and PlayerResource:IsValidPlayerID(pid) and PlayerResource:HasSelectedHero(pid)
			and PlayerResource:GetSelectedHeroName(pid) == hero then
			return true
		end
	end

	if AAPick and AAPick.picks then
		for pid, h in pairs(AAPick.picks) do
			if pid ~= except and h == hero then return true end
		end
	end

	return false
end

-- Пара занята: взят любой из двух
function A:IsPairTaken(hero, except)
	local partner = self:Partner(hero)
	return self:IsHeroTaken(hero, except) or (partner ~= nil and self:IsHeroTaken(partner, except))
end

local function Error(pid, msg)
	local player = PlayerResource:GetPlayer(pid)
	if player then CustomGameEventManager:Send_ServerToPlayer(player, "aa_alt_error", { msg = msg }) end
end

-- Во время пика: публикуем занятых и закрываем партнёров в движке (ванильная сетка и рандом).
function A:Think()
	if GameRules:State_Get() > DOTA_GAMERULES_STATE_HERO_SELECTION then return nil end

	local taken = {}

	for alt, base in pairs(self.PAIRS) do
		for _, hero in ipairs({ alt, base }) do
			if self:IsHeroTaken(hero) then
				taken[hero] = 1

				local partner = self:Partner(hero)

				if not self.blacklisted[partner] and GameRules.AddHeroToBlacklist then
					self.blacklisted[partner] = true
					pcall(function() GameRules:AddHeroToBlacklist(partner) end)
				end
			end
		end
	end

	CustomNetTables:SetTableValue("aa_alt", "taken", taken)

	return 0.25
end

function A:OnPick(data)
	local pid = data and tonumber(data.PlayerID)
	local hero = data and tostring(data.hero or "")

	if pid == nil then return end
	if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_HERO_SELECTION then return Error(pid, "not_now") end
	if GameRules.IsInBanPhase and GameRules:IsInBanPhase() then return Error(pid, "not_now") end
	if AAPick and AAPick.stage == "premium" then return Error(pid, "not_now") end
	if not self:IsAlt(hero) then return Error(pid, "bad_hero") end
	if PlayerResource:HasSelectedHero(pid) then return Error(pid, "already") end
	if self:IsPairTaken(hero, pid) then return Error(pid, "taken") end

	local player = PlayerResource:GetPlayer(pid)
	if not player then return end

	print(string.format("[AltHeroes] pid %d -> %s", pid, hero))
	player:SetSelectedHero(hero)
end

CustomGameEventManager:RegisterListener("aa_alt_pick", function(_, data)
	local ok, err = pcall(A.OnPick, A, data)
	if not ok then print("[AltHeroes] pick: " .. tostring(err)) end
end)

ListenToGameEvent("game_rules_state_change", function()
	local st = GameRules:State_Get()

	if st == DOTA_GAMERULES_STATE_HERO_SELECTION then
		pcall(A.Publish, A)

		-- реальное время: игровое на паузе и в стадиях пика может стоять
		Timers:CreateTimer({
			endTime = 0.25,
			useGameTime = false,
			callback = function()
				local ok, res = pcall(A.Think, A)
				if not ok then print("[AltHeroes] think: " .. tostring(res)) return 0.25 end
				return res
			end,
		})
	end
end, nil)

-- данные для карточки нужны и до пика (экран команд), публикуем сразу
Timers:CreateTimer(1, function() pcall(A.Publish, A) end)

return A
