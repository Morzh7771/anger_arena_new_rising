-- Нетворс игрока для систем мода (отстающая команда, награды за убийства, делёжка, статистика).
--
-- У Monkey King солдаты Wukong's Command - герои того же игрока с копией его предметов,
-- то же у Tempest Double и клонов. Движковый PlayerResource:GetNetWorth их предметы
-- может приплюсовывать, и нетворс MK выходил в разы больше настоящего: отстающей
-- считалась не та команда. Здесь считается только основной герой:
--   движковый НВ - стоимость предметов на чужих героях игрока,
--   но не меньше "золото + предметы основного героя" (если движок их не считал)
--   и не больше движкового НВ.
-- Плюс запас золота сверх лимита кошелька (AngelArena.tPlayers[pid].gold).

AANetWorth = AANetWorth or {}

local N = AANetWorth
local ITEM_SLOTS = 16 -- 0..16: инвентарь, рюкзак, тайник, ТП, нейтралка

local cache = {} -- [pid] = { t = время, v = значение }

local function ItemsCost(unit, lastSlot)
	local sum = 0

	for slot = 0, lastSlot do
		local it = unit:GetItemInSlot(slot)

		if it and not it:IsNull() then sum = sum + (it:GetCost() or 0) end
	end

	return sum
end

-- стоимость предметов на героях игрока pid, кроме основного hero
local function ExtraHeroesCost(pid, hero)
	local sum, found = 0, false

	for _, h in pairs(HeroList:GetAllHeroes()) do
		if h ~= hero and not h:IsNull() and h:GetPlayerOwnerID() == pid then
			found = true
			sum = sum + ItemsCost(h, 8)
		end
	end

	return sum, found
end

local function Calc(pid)
	local nw = PlayerResource:GetNetWorth(pid) or 0
	local hero = PlayerResource:GetSelectedHeroEntity(pid)

	if hero and not hero:IsNull() then
		local extra, found = ExtraHeroesCost(pid, hero)

		if found and extra > 0 then
			local own = (PlayerResource:GetGold(pid) or 0) + ItemsCost(hero, ITEM_SLOTS)

			nw = math.min(nw, math.max(own, nw - extra))
		end
	end

	local bank = AngelArena and AngelArena.tPlayers and AngelArena.tPlayers[pid]

	return nw + (bank and tonumber(bank.gold) or 0)
end

-- нетворс с запасом золота; кэш на кадр (делёжка зовёт на каждое золото)
function N:Get(pid)
	local now = GameRules:GetGameTime()
	local c = cache[pid]

	if c and c.t == now then return c.v end

	local ok, v = pcall(Calc, pid)

	if not ok then
		print("[AANetWorth] " .. tostring(v))
		v = PlayerResource:GetNetWorth(pid) or 0
	end

	cache[pid] = { t = now, v = v }

	return v
end
