item_repick_hero = class({})
LinkLuaModifier("modifier_item_repick", "items/item_repick_hero", LUA_MODIFIER_MOTION_NONE)
local attribute_table = {
	["DOTA_ATTRIBUTE_STRENGTH"] = DOTA_ATTRIBUTE_STRENGTH,
	["DOTA_ATTRIBUTE_AGILITY"] = DOTA_ATTRIBUTE_AGILITY,
	["DOTA_ATTRIBUTE_INTELLECT"] = DOTA_ATTRIBUTE_INTELLECT,
	["DOTA_ATTRIBUTE_ALL"] = DOTA_ATTRIBUTE_ALL,
}

local HP_PER_STR 		= 20
local HP_REGEN_PER_STR  = 0.09
local MP_PER_INT 		= 12
local MP_REGEN_PER_INT  = 0.05
local ARMOR_PER_AGI     = 0.16

function item_repick_hero:OnSpellStart()
    self.firstHero = nil
    self.secondHero = nil
    self.herodata = {}
    local heroes_repic_table = {
        { "npc_dota_hero_elder_titan", "npc_dota_hero_guardian_of_the_ancients" },
    }
    for _,data in pairs(heroes_repic_table) do
        if data[1] == self:GetCaster():GetUnitName() or data[2] == self:GetCaster():GetUnitName() then
            self.herodata[data[1]] = item_repick_hero:getHeroByName(data[1])
            self.herodata[data[2]] = item_repick_hero:getHeroByName(data[2])
        end
    end
    CustomGameEventManager:Send_ServerToPlayer(self:GetCaster():GetPlayerOwner(),"repick_hero_data",self.herodata)
    CustomGameEventManager:Send_ServerToPlayer(self:GetCaster():GetPlayerOwner(), "aa_repick_hero_menu_open", {} )
    CustomGameEventManager:RegisterListener("aa_repick_menu_hero_start_repick", Dynamic_Wrap(self, '_repickHero'))
end
function item_repick_hero:getHeroByName(name)
    local hero_data = PreloadCache:GetHeroData()
    local data = {}

    for hero_name, hero_info in pairs(hero_data) do
        if hero_name == name then

            local abilities = {}
            local talantes = {}
            for i = 1, 6 do
                local key = "Ability" .. tostring(i)
                local ability_name = hero_info[key]

                if ability_name and #ability_name ~= 0 and ability_name ~= "generic_hidden" then
                    table.insert(abilities, ability_name)
                end
            end

            for i = 10, 17 do
                local key = "Ability" .. tostring(i)
                local ability_name = hero_info[key]

                if ability_name and #ability_name ~= 0 and ability_name ~= "generic_hidden" then
                    table.insert(talantes, ability_name)
                end
            end

            local str = hero_info['AttributeBaseStrength'] or 0
            local agi = hero_info['AttributeBaseAgility'] or 0
            local int = hero_info['AttributeBaseIntelligence'] or 0

            local primary_attribute = attribute_table[ hero_info['AttributePrimary'] ]

            local main_att = 0

            if primary_attribute == DOTA_ATTRIBUTE_STRENGTH then
                main_att = str
            elseif primary_attribute == DOTA_ATTRIBUTE_AGILITY then
                main_att = agi
            elseif primary_attribute == DOTA_ATTRIBUTE_INTELLECT then
                main_att = int
            end

            data['abilities'] 	= abilities
            data['talantes'] 	= talantes

            data['base_att'] 	= primary_attribute

            data['str'] 	 	= str
            data['agi'] 	 	= agi
            data['int'] 	 	= int

            data['str_gain'] 	= hero_info['AttributeStrengthGain'] or 0
            data['agi_gain'] 	= hero_info['AttributeAgilityGain'] or 0
            data['int_gain'] 	= hero_info['AttributeIntelligenceGain'] or 0

            data['bat'] 		= hero_info['AttackRate'] or 0
            data['movespeed'] 	= hero_info['MovementSpeed'] or 0

            data['dmg_min'] 	= (hero_info['AttackDamageMin'] or 0) + main_att
            data['dmg_max'] 	= (hero_info['AttackDamageMax'] or 0) + main_att

            data['hp'] 			= (hero_info['StatusHealth'] or 100) + str * HP_PER_STR
            data['mp'] 			= (hero_info['StatusMana']   or 0  ) + int * MP_PER_INT

            data['hp_reg'] 		= (hero_info['StatusHealthRegen'] or 0) + str * HP_REGEN_PER_STR
            data['mp_reg'] 		= (hero_info['StatusManaRegen']   or 0) + int * MP_REGEN_PER_INT

            data['armor'] 		= (hero_info['ArmorPhysical'] or 0) + agi * ARMOR_PER_AGI
            data['item_name']	= hero_info['GodRepickItem'] or "item_invalid"

            data['id'] = DOTAGameManager:GetHeroIDByName(hero_name)

            print(DOTAGameManager:GetHeroIDByName(hero_name))
        end
	end
    return data
end

function item_repick_hero:PickHero(player, newHeroName)
	local hero = player:GetAssignedHero() -- is we need to allow repick other team-mate heroes(or just controlled heroes)?

	-- no old hero - no repick
	if not hero or not IsConnected(hero) then 
		return false 
	end

    local newhero = PlayerResource:ReplaceHeroWith( hero:GetPlayerID(), newHeroName, hero:GetGold(), 0 )
    local turn = 0
    Timers:CreateTimer(0.1, function()
        turn = turn + 1
        if turn < 100 then
            newhero:FindItemInInventory("item_repick_hero"):Destroy()
            return 0.1
        end
    end)

	return true
end

function item_repick_hero:_repickHero(data)
	
	local player_id = data['PlayerID']

	if not player_id then return end

	local player = PlayerResource:GetPlayer(player_id)

	if not player then return end

	local hero_name = data['hero_name']

	item_repick_hero:PickHero( player, hero_name )
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
        self:GetCaster():FindItemInInventory("item_repick_hero"):Destroy()
    end
    self.thick = self.thick + 1
end