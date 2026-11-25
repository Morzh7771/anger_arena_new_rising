require('lib/random/generators')

local CONFIG_PATH = "scripts/npc/dropbox.kv"
local POS_RANDOM_TYPE = "uniform"
local ITEM_DESTROY_TIME = 120

-- Internals
local POS_RAND_GEN = RandomGeneratorFactory:GetGenerator(POS_RANDOM_TYPE)

local types = {
	['uniform_list'] = require('lib/dropbox_types/uniform_list'),
	['garant_list']  = require('lib/dropbox_types/garant_list'),
}

DropBox = DropBox or class({})

function DropBox:_Init()
	if self.inited then return end

	if not IsInToolsMode() then
		self.intied = true
	end

	local kv = LoadKeyValues(CONFIG_PATH)

	local data = {}

	for boxName, boxData in pairs(kv) do
		local boxType = boxData['type']

		if not boxType then
			print("[DropBox] Failed to parse loot-box named", boxName, "no lootbox type")
			return
		end

		local classGenerator = types[boxType]

		if not classGenerator then
			print("[DropBox] Failed to parse loot-box named", boxName, "lootbox type '", boxType ,"'is not supported")
			return
		end

		local childList

		local childData = boxData['childs']

		if childData then
			local childs = {}

			for childName, _ in pairs(childData) do
				table.insert(childs, childName)
			end

			childList = childs
		end

		data[boxName] = {
			["generator"] = classGenerator( boxData ),
			["childList"] = childList,
		}
	end

	self.data = data
end

function DropBox:GetDropbox( boxName )
	local boxData = self.data[boxName]

	if not boxData then
		-- debug на боевом сервере nil: раньше вместо сообщения об отсутствующем
		-- боксе тут прилетала ошибка индексации nil и рвался вызывающий код
		local trace = (debug and debug.traceback) and debug.traceback() or "[debug library недоступна]"
		print("[DropBox] Failed to get box, there is no box named", boxName, trace )
		return nil
	end

	local childList = boxData['childList']

	local childs = {}

	if childList then
		for _, childName in pairs(childList) do
			local child = DropBox:GetDropbox( childName )

			if not child then
				print("[DropBox] failed to get box child for box ", boxName )
				return nil
			end

			table.insert(childs, child)
		end
	end

	local result = DropBox()

	result.identifier = boxName
	result.generator  = boxData["generator"]
	result.childs 	  = childs

	return result
end

function DropBox:GetItemNames()
	local items = self.generator:GetItems()
	return self.generator:GetItems()
end

local ItemDestroyer = class({})

function ItemDestroyer:LaunchCountdown(items)
	local res = ItemDestroyer()

	res.items = items
	res:start()
end

function ItemDestroyer:start()
	if not self.items then return end

	Timers:CreateTimer( ITEM_DESTROY_TIME, function()
		--print("Starting destroy items")
		for _, data in pairs(self.items) do
			local item = data[1]
			local drop = data[2]

			if item and IsValidEntity(item) and not item:GetOwnerEntity() then
				if drop and IsValidEntity(drop) then 
					UTIL_Remove(drop) 
				end

				UTIL_Remove(item)
			end
		end

		--print("End destroy items")
	end)
end

-- Книга на земле (рядом был враг): кольцо радиуса подбора, и кто из героев
-- первым зайдёт в кольцо - тому книга и применяется, кликать не надо.
-- Поднятая кликом в инвентарь тоже работает: тогда просто гасим кольцо.
local TOME_PICKUP_RADIUS = 150
local TOME_RING_PARTICLE = "particles/ui_mouseactions/range_display.vpcf"

function DropBox:_WatchTomePickup(item, drop, pos)
	local itemName = item:GetAbilityName()

	local fx = ParticleManager:CreateParticle(TOME_RING_PARTICLE, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, pos)
	ParticleManager:SetParticleControl(fx, 1, Vector(TOME_PICKUP_RADIUS, 0, 0))

	local function Stop()
		ParticleManager:DestroyParticle(fx, false)
		ParticleManager:ReleaseParticleIndex(fx)
	end

	-- даём книге долететь, потом проверяем раз в 0.1 с
	Timers:CreateTimer(0.6, function()
		if not item or item:IsNull() or not drop or drop:IsNull() or item:GetOwnerEntity() then
			Stop()
			return
		end

		local heroes = FindUnitsInRadius(DOTA_TEAM_NEUTRALS, pos, nil, TOME_PICKUP_RADIUS,
			DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_HERO,
			DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
			FIND_CLOSEST, false)

		for _, hero in pairs(heroes) do
			if hero:IsRealHero() and hero:IsAlive() and not hero:IsIllusion() then
				local count = math.max(1, item:GetCurrentCharges())

				if ShiftBuy:GiveTome(hero, itemName, count) then
					EmitSoundOnLocationWithCaster(pos, "Item.TomeOfKnowledge", hero)
					Stop()
					UTIL_Remove(drop)
					UTIL_Remove(item)
					return
				end
			end
		end

		return 0.1
	end)
end

-- receiver - герой, которому книги из дропа достаются сразу, не падая на
-- землю (ShiftBuy:GiveTome). Передают его только крипы: это тот, кто убил.
function DropBox:DropAtPos(pos, radius, manualLifetime, receiver)
	--print("[DropBox] Starting drop", self.identifier)

	local items = self:GetItemNames()

	local result = {}

	for _, itemData in pairs(items) do
		local function MakeItem(itemName)
			local randomOffset = RandomVector(radius)
			local itemPos = randomOffset + pos
			
			local item = CreateItem(itemName, nil, nil)

			if not item then return nil end

			item:SetCurrentCharges( item:GetInitialCharges() )

			item:SetPurchaseTime(0)

			local isTome = ShiftBuy and ShiftBuy:_GetTomes()[itemName]

			-- книгу подбрасываем из точки смерти, остальное как раньше
			local drop = CreateItemOnPositionSync( isTome and pos or itemPos, item )

			if not drop then return end

			if isTome then
				if CreepPickups then CreepPickups:Toss(drop, pos, itemPos, 250, 0.6) end
				DropBox:_WatchTomePickup(item, drop, itemPos)
			end

			table.insert( result, {item, drop} )

			return item
		end

		local itemName  = itemData[1]
		local itemCount = itemData[2]

		
		local item = nil

		local isTome = ShiftBuy and ShiftBuy:_GetTomes()[itemName]

		if receiver and isTome and IsValidEntity(receiver) and receiver:IsRealHero() and CreepPickups then
			-- книга видимо летит к убийце и применяется по прилёту
			CreepPickups:FlyTo(itemName, pos, receiver, function(hero)
				ShiftBuy:GiveTome(hero, itemName, itemCount)
			end)
		elseif not (receiver and ShiftBuy and ShiftBuy:GiveTome(receiver, itemName, itemCount)) then
			item = MakeItem( itemName )
		end

		if item then
			if item:IsStackable() then
				item:SetCurrentCharges(itemCount)
			else
				for i = 1, itemCount - 1 do
					MakeItem(itemName)
				end
			end
		end
	end

	for _, child in pairs( self.childs ) do
		child:DropAtPos(pos, radius, nil, receiver)
	end

	--print("[DropBox] Stop dropping items")

	if not manualLifetime then
		return ItemDestroyer:LaunchCountdown( result )
	else
		return result
	end

end

DropBox:_Init()