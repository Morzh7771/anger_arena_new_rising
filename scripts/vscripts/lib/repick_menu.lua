if RepickMenu then return end 

RepickMenu = class({})

require('lib/utils')
require('lib/hero_change')
require('lib/kv_preloaded_data')
require('lib/boss/boss_spawner')
require('lib/duel/duel_controller')

-- I hate this hardcode, but we cannon access that stats WITHOUT unit and WITHOUT GameMode entity
local HP_PER_STR 		= 20
local HP_REGEN_PER_STR  = 0.09
local MP_PER_INT 		= 12
local MP_REGEN_PER_INT  = 0.05
local ARMOR_PER_AGI     = 0.16

local DUEL_CANT_PICK_PERIOD = 10 -- same as in scripts/custom_game/repick_menu.js. TODO: Send it from server

local BOSS_FOR_REPICK = "boss_mid_bott"

local attribute_table = {
	["DOTA_ATTRIBUTE_STRENGTH"] = DOTA_ATTRIBUTE_STRENGTH,
	["DOTA_ATTRIBUTE_AGILITY"] = DOTA_ATTRIBUTE_AGILITY,
	["DOTA_ATTRIBUTE_INTELLECT"] = DOTA_ATTRIBUTE_INTELLECT,
	["DOTA_ATTRIBUTE_ALL"] = DOTA_ATTRIBUTE_ALL,
}

function RepickMenu:init()
	if self.gods_data then return end

	local hero_data = PreloadCache:GetHeroData()
	print("RepickMenu:init")

	DeepPrintTable(self.gods_data)
	print('dasdsadasdasdasdasdd')
	
	self.gods_data = {}
	local banned = GameRules:GetBannedHeroes()
	for int,_ in pairs(banned) do
		--print('roll')
		if RollPercentage(20) then
			--print('unbanned')
			--Attentions:SendChatMessage(banned[int].." #un_banned")
			table.remove(banned,int)
		end
		--DeepPrintTable(banned)
	end
	table.insert(banned,'blablabla')
	for hero_name, hero_info in pairs(hero_data) do
		local data = {}

		local abilities = {}
			
		for i = 1, 6 do
			local key = "Ability" .. tostring(i)
			local ability_name = hero_info[key]

			if ability_name and #ability_name ~= 0 and ability_name ~= "generic_hidden" then
				table.insert(abilities, ability_name)
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
		
		self.isPicked = 0
		for i,heroOnMap in pairs(HeroList:GetAllHeroes()) do
			if heroOnMap:GetUnitName() == hero_name then
				self.isPicked = 1
				--print(self.isPicked)
			end
		end
		data['picked'] = self.isPicked
		--print(data['picked'])
		local togledHero = LoadKeyValues('scripts/npc/herolist.txt')
		self.isBan = false
		for _,ban in pairs(banned) do
			if "npc_dota_hero_"..ban == hero_name then
				self.isBan = true
			end
		end
		if self.isBan == false then
			for name,toggleState in pairs(togledHero) do
				if name == hero_name then
					if toggleState ~= 0 then
						self.gods_data[hero_name] = data
					end
				end
			end
		end
	end
	
	
	CustomGameEventManager:RegisterListener("aa_repick_menu_retrive_data", Dynamic_Wrap(self, '_retriveHeroData'))
	CustomGameEventManager:RegisterListener("aa_repick_menu_start_repick", Dynamic_Wrap(self, '_repickHero'))
	CustomGameEventManager:Send_ServerToAllClients("aa_repick_menu_set_data", self.gods_data )
	
end

function RepickMenu:CanPickNow()
	return DuelController:GetTimeToDuel() > DUEL_CANT_PICK_PERIOD and BossSpawner:GetDeathCount(BOSS_FOR_REPICK) ~= 0 and not BossSpawner:IsBossAlive(BOSS_FOR_REPICK)
end

function RepickMenu:PickHero(player, newHeroName)
	local hero = player:GetAssignedHero() -- is we need to allow repick other team-mate heroes(or just controlled heroes)?

	-- no old hero - no repick
	if not hero or not IsConnected(hero) then 
		return false 
	end

	-- if hero already picked, ignore second pick
	if self.gods_data[newHeroName]['picked'] ~= 0 then 
		return true 
	end

	local checkFunction = function()
		if not self:CanPickNow() then return false end
		return true
	end

	if not checkFunction() then return false end

	-- all is ok, lets inform all clients about it
	local oldHeroName = hero:GetUnitName()

	-- say to everybody: that player now owns a new hero
	self.gods_data[newHeroName]['picked'] = 1

	CustomGameEventManager:Send_ServerToAllClients("aa_repick_menu_set_hero_picked", { 
		["hero_name"] = newHeroName, 
		["picked"]    = 1, 
	})
	print("1")

	-- and close menu for player that request repick
	self:Close(player)

	-- if repick was ok -> lets free old hero if someone can repick to it
	local onSuccess = function()
		if self.gods_data[oldHeroName] then
			self.gods_data[oldHeroName]['picked'] = 0

			CustomGameEventManager:Send_ServerToAllClients("aa_repick_menu_set_hero_picked", { 
				["hero_name"] = oldHeroName, 
				["picked"]    = 0,
			})
			print("2")
		end
	end

	-- if repick failed -> free new hero to allow any another player repick to it
	local onFailed = function()
		self.gods_data[newHeroName]['picked'] = 0
	
		CustomGameEventManager:Send_ServerToAllClients("aa_repick_menu_set_hero_picked", { 
			["hero_name"] = newHeroName, 
			["picked"]    = 0,
		})
		print("3")
	end

	-- and finally start real repicking
	ChangeHero(player, hero, newHeroName, onSuccess, onFailed, checkFunction)

	return true
end

function RepickMenu:GetData()
	--print(self.gods_data)
	return self.gods_data
end

function RepickMenu:Open(player)
	CustomGameEventManager:Send_ServerToPlayer(player, "aa_repick_menu_open", {} )
	print('aa_repick_menu_open')
end

function RepickMenu:Close(player)
	CustomGameEventManager:Send_ServerToPlayer(player, "aa_repick_menu_close", {} )
	print('aa_repick_menu_close')
end

function RepickMenu:_repickHero(data)
	
	local player_id = data['PlayerID']

	if not player_id then return end

	local player = PlayerResource:GetPlayer(player_id)

	if not player then return end

	local hero_name = data['hero_name']

	RepickMenu:PickHero( player, hero_name )
end

function RepickMenu:_retriveHeroData(data)
	local player_id = data['PlayerID']

	if not player_id then return end

	local player = PlayerResource:GetPlayer(player_id)

	if not player then return end

	local data = RepickMenu:GetData()

	CustomGameEventManager:Send_ServerToPlayer(player, "aa_repick_menu_set_data", data )
end

