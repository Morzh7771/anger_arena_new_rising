item_choose_hero = class({})

-- Инициализация предмета
function item_choose_hero:OnSpellStart()
    -- Получаем данные игрока
    local caster = self:GetCaster()
    local playerID = caster:GetPlayerID()

    -- Создаем таблицу со списком героев для выбора
    local heroPool = {
        "npc_dota_hero_abaddon"	,
        "npc_dota_hero_alchemist",
        "npc_dota_hero_ancient_apparition",
        "npc_dota_hero_antimage",
        "npc_dota_hero_arc_warden",
        "npc_dota_hero_snapfire",
        "npc_dota_hero_axe",
        "npc_dota_hero_bane",
        "npc_dota_hero_batrider",
        "npc_dota_hero_beastmaster",
        "npc_dota_hero_bloodseeker"
        -- Добавьте сюда остальные герои для выбора
    }

    -- Генерируем 6 случайных героев для выбора
    local randomHeroes = {}
    for i = 1, 6 do
        local randomIndex = RandomInt(1, #heroPool)
        table.insert(randomHeroes, heroPool[randomIndex])
        table.remove(heroPool, randomIndex)
    end
    DeepPrintTable(randomHeroes)

    -- Создаем таблицу для передачи данных о выбранном герое
    local selectHeroData = {
        playerID = playerID,
        randomHeroes = randomHeroes,
    }

    -- Показываем выбор героев на кастере
    CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerID), "show_hero_selection", selectHeroData)
end
