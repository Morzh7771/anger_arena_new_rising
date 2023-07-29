if not IsServer() then return end
Bounty = Bounty or class({})
local boutyName = {
    "bounty_bot",
    "bounty_top",
}
local spot = {}
local needTimeBounty = 0.001
local needTimeWisdom = 5.001
function Bounty:Init()
	for _,name in pairs(boutyName) do
        local entity = Entities:FindByName( nil, name )
        table.insert(spot,entity)
    end
    Timers:CreateTimer(1, function()
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
        return 1
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
    needTimeBounty = needTimeBounty + 2
end
function Bounty:SpawnWisdom()
    for _,entity in pairs(spot) do
        local FindAll = Entities:FindAllByClassnameWithin("dota_item_rune", entity:GetAbsOrigin(), 80)
        for _,entity in pairs(FindAll) do
            entity:RemoveSelf()
        end
        CreateRune(entity:GetAbsOrigin(), DOTA_RUNE_XP )
    end
    needTimeWisdom = needTimeWisdom + 10
end