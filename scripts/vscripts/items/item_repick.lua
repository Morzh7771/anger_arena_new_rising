item_repick = class({})
LinkLuaModifier("modifier_item_repick", "items/item_repick", LUA_MODIFIER_MOTION_NONE)
local hero_table = require('lib/hero_table')
function item_repick:GetIntrinsicModifierName()
    return "modifier_item_repick"
end
function item_repick:OnSpellStart()
    self.caster = self:GetCaster()
    local newHeroName = hero_table[self.caster:GetUnitName()]

    if newHeroName then
        self.caster:FindItemInInventory("item_repick"):Destroy()
        local oldHero = self.caster
        local playerid = oldHero:GetPlayerID()
        local gold = oldHero:GetGold()
        -- Четвёртый аргумент ReplaceHeroWith - это опыт. С нулём новый герой
        -- приходит первого уровня, отсюда и терялись уровень со статами.
        -- Читаем ДО прекеша: к моменту колбэка старого героя может уже не быть.
        local xp = oldHero:GetCurrentXP() or 0

        -- без прекеша новый герой появляется с error-моделью и без партиклов.
        -- Третий аргумент - playerid: без него прекешится только дефолтный
        -- набор, а надетая игроком косметика остаётся nonresident и вместо неё
        -- рисуется error-модель.
        PrecacheUnitByNameAsync(newHeroName, function()
            local hero = PlayerResource:ReplaceHeroWith( playerid, newHeroName, gold, xp )

            if not hero or hero:IsNull() then return end

            local stance = hero:FindAbilityByName("guardian_of_the_ancients_confident_stance")
            if stance then stance:SetLevel(1) end

            local point = 0
            if hero:GetTeamNumber() == DOTA_TEAM_GOODGUYS then
                point = Entities:FindByName( nil, RADIANT_BASE_POINT ):GetAbsOrigin()
            elseif hero:GetTeamNumber() == DOTA_TEAM_BADGUYS then
                point = Entities:FindByName( nil, DIRE_BASE_POINT ):GetAbsOrigin()
            end

            if point == 0 then return end

            FindClearSpaceForUnit(hero, point, false)

            hero:Stop()
        end, playerid)
    end
end
modifier_item_repick = class({
    RemoveOnDeath = function(self) return false end
})

function modifier_item_repick:OnCreated()
    self.duration = self:GetAbility():GetSpecialValueFor("duration")
    self.thick = 1
    self:StartIntervalThink(1)
end

function modifier_item_repick:OnIntervalThink()
	if self.thick >= self.duration then
        self:GetCaster():FindItemInInventory("item_repick"):Destroy()
    end
    self.thick = self.thick + 1
end