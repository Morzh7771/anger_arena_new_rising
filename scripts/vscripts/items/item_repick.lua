item_repick = class({})
LinkLuaModifier("modifier_item_repick", "items/item_repick", LUA_MODIFIER_MOTION_NONE)
local hero_table = require('lib/hero_table')
function item_repick:GetIntrinsicModifierName()
    return "modifier_item_repick"
end
function item_repick:OnSpellStart()
    self.caster = self:GetCaster()
    if hero_table[self.caster:GetUnitName()] then
        self.caster:FindItemInInventory("item_repick"):Destroy()
        local oldHero = self.caster
		local hero = PlayerResource:ReplaceHeroWith( self.caster:GetPlayerID(), hero_table[self.caster:GetUnitName()], oldHero:GetGold(), 0 )

        hero:FindAbilityByName("guardian_of_the_ancients_confident_stance"):SetLevel(1)
        
        local point = 0 
        if hero:GetTeamNumber() == DOTA_TEAM_GOODGUYS then
            point = Entities:FindByName( nil, RADIANT_BASE_POINT ):GetAbsOrigin()
        elseif hero:GetTeamNumber() == DOTA_TEAM_BADGUYS then
            point = Entities:FindByName( nil, DIRE_BASE_POINT ):GetAbsOrigin()
        end
        
        if point == 0 then return end

        FindClearSpaceForUnit(hero, point, false)

        hero:Stop()
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