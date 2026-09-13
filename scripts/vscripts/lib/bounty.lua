if not IsServer() then return end
Bounty = Bounty or class({})
local boutyName = {
    "bounty_bot",
    "bounty_top",
}
local spot = {}
local needTimeBounty = 0.001
local needTimeWisdom = 5.001

-- Точки, по которым alt-клик по кружкам рун ставит пинги (lib/panorama_pings.lua).
-- Баунти и мудрость мы спавним сами в bounty_top/bounty_bot, руны усиления
-- спавнит движок в своих спавнерах: их ищем по классу, а если карта окажется
-- нестандартной - берём спавнер из фильтра спавна, он приходит туда с каждой
-- руной усиления (AngelArena:ModifierRuneSpawn).
local POWER_SPAWNER_CLASSES = {
    "dota_item_rune_spawner_powerup",
    "dota_item_rune_spawner",
}
local BOUNTY_SPOT_RADIUS = 200
local power_spot = {}      -- найденные по классу
local power_spot_seen = {} -- пришедшие из фильтра, им доверяем больше

-- Храним сами энтити, а не координаты: MinimapEvent держит одно событие на
-- энтити, и если вешать все пинги на одного героя, на миникарте остаётся
-- только последний. У каждой точки своя энтити - и пингуются все.
local function AddSpot(list, entity)
    if not entity or not IsValidEntity(entity) then return end

    local pos = entity:GetAbsOrigin()

    for _, known in pairs(list) do
        if (known:GetAbsOrigin() - pos):Length2D() < 64 then return end
    end

    table.insert(list, entity)
end

-- Точки баунти и мудрости общие, спавн стирает то, что там лежало. Расписание:
--   баунти  - каждые 2 минуты  (0, 2, 4, 6, 8, 10, ...)
--   мудрость - каждые 10 минут с 5-й (5, 15, 25, ...)
-- То есть мудрость на 5-й минуте живёт до 6-й, пока её не сменит баунти.
--
-- Время до следующих спавнов уходит в нет-таблицу rune_timers: панорама рисует
-- по ней кружки под таймером (см. panorama/scripts/custom_game/rune_timers.js).
-- Считать это на клиенте нельзя - расписание живёт здесь и может поменяться.
local BOUNTY_INTERVAL = 2
local WISDOM_INTERVAL = 10

function Bounty:PublishTimers()
    CustomNetTables:SetTableValue("rune_timers", "next", {
        -- в секундах игрового времени, клиент вычитает своё текущее
        bounty = needTimeBounty * 60,
        wisdom = needTimeWisdom * 60,
        power  = _G.NEXT_POWER_RUNE_TIME or -1,
    })
end

function Bounty:Init()
	for _,name in pairs(boutyName) do
        local entity = Entities:FindByName( nil, name )
        table.insert(spot,entity)
    end

    self:PublishTimers()

    Timers:CreateTimer(0.1, function()
        local time = GameRules:GetDOTATime(false,false) / 60
        --print(time)
        if time > needTimeBounty then
            --print("Руну спавним")
            Bounty:SpawnBounty()
        end
        if time > needTimeWisdom then
            --print("Руну спавним")
            Bounty:SpawnWisdom()
        end
        return 0.1
    end)

    -- Отдельным редким таймером, чтобы не дёргать сеть каждые 0.1 с: время до
    -- следующей руны усиления меняется само по себе, без наших спавнов.
    Timers:CreateTimer(1.0, function()
        Bounty:PublishTimers()
        return 1.0
    end)
end
function Bounty:SpawnBounty()
    for _,entity in pairs(spot) do
        local FindAll = Entities:FindAllByClassnameWithin("dota_item_rune", entity:GetAbsOrigin(), 80)
        for _,entity in pairs(FindAll) do
            entity:RemoveSelf()
        end
        CreateRune(entity:GetAbsOrigin(), DOTA_RUNE_BOUNTY )
    end
    if MinimapSpots then MinimapSpots:OnRuneSpawn("bounty") end
    needTimeBounty = needTimeBounty + BOUNTY_INTERVAL
    Bounty:PublishTimers()
end
function Bounty:SpawnWisdom()
    for _,entity in pairs(spot) do
        local FindAll = Entities:FindAllByClassnameWithin("dota_item_rune", entity:GetAbsOrigin(), 80)
        for _,entity in pairs(FindAll) do
            entity:RemoveSelf()
        end
        CreateRune(entity:GetAbsOrigin(), DOTA_RUNE_XP )
    end
    if MinimapSpots then MinimapSpots:OnRuneSpawn("wisdom") end
    needTimeWisdom = needTimeWisdom + WISDOM_INTERVAL
    Bounty:PublishTimers()
end

-- Куда падают руны: bounty_top/bounty_bot для баунти и мудрости, движковые
-- спавнеры для усиления. По этим точкам alt-клик по кружку под таймером ставит
-- пинги, см. PanoramaPingManager:OnRuneTimerClick в lib/panorama_pings.lua.
function Bounty:GetRuneSpots(kind)
    if kind ~= "power" then
        local res = {}

        for _, entity in pairs(spot) do
            if entity and IsValidEntity(entity) then
                AddSpot(res, entity)
            end
        end

        return res
    end

    -- фильтр уже показывал, где реально появляются руны усиления
    if #power_spot_seen > 0 then return power_spot_seen end

    if #power_spot == 0 then
        for _, classname in pairs(POWER_SPAWNER_CLASSES) do
            for _, entity in pairs(Entities:FindAllByClassname(classname)) do
                -- общий класс спавнера может стоять и на точках баунти: у них
                -- свой кружок, второй раз пинговать их незачем
                if not Bounty:IsBountySpot(entity:GetAbsOrigin()) then
                    AddSpot(power_spot, entity)
                end
            end

            -- нашли на своём классе - общий смотреть уже незачем
            if #power_spot > 0 then break end
        end
    end

    return power_spot
end

function Bounty:IsBountySpot(pos)
    for _, entity in pairs(spot) do
        if entity and IsValidEntity(entity) and (entity:GetAbsOrigin() - pos):Length2D() < BOUNTY_SPOT_RADIUS then
            return true
        end
    end

    return false
end

-- Зовётся из фильтра спавна рун усиления (AngelArena:ModifierRuneSpawn):
-- спавнер оттуда - самый точный источник координат, поиск по классу нужен
-- только до первой руны.
function Bounty:RememberPowerSpawner(entindex)
    if not entindex then return end

    local entity = EntIndexToHScript(entindex)

    if not entity or not IsValidEntity(entity) then return end

    AddSpot(power_spot_seen, entity)
end
