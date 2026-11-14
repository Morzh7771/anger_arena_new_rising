if not IsServer() then return end

--[[
	Свиток телепортации и травела.

	Сам свиток - ванильный item_tpscroll, поэтому прицел с кольцом, слот
	телепорта, радиус 800 у строений, приземление на юнита и все текстуры -
	движковые.

	Цели свитку в KV прописаны максимально широкие (DOTA_UNIT_TARGET_ALL),
	иначе движок вообще не даёт наводиться на юнитов. Кому что из этого
	доступно, решает тир травел в основных шести слотах:

	  нет травел / тир 1 (Boots of Travel)  - только союзные строения;
	  тир 2 (Boots of Travel 2)             - плюс союзные герои и крипы;
	  тир 3 (Snake Boots)                   - плюс всё остальное союзное:
	                                          варды, призванные, ракета гиро
	                                          и прочие вспомогательные юниты.

	Первые два тира - ванильные предметы, им движок сам ускоряет свиток и
	перестаёт тратить заряды. Третьего тира в движке нет, поэтому Snake Boots -
	свой предмет, а его часть работы делаем здесь: держим у героя свиток (после
	телепорта выдаём новый) и опускаем перезарядку до tp_cooldown.

	Ещё отсюда выдаётся свиток на первом спавне: движок этого не делает.
]]

TpScroll = TpScroll or {}

local SCROLL = "item_tpscroll"
local SNAKE_SCROLL = "item_snake_tpscroll"

local BOOTS_TIER = {
	item_travel_boots = 1,
	item_travel_boots_2 = 2,
	-- Snake Boots снова старые (датадривен, свой телепорт активкой), третьего
	-- тира свитка нет: для свитка они как Boots of Travel 2
	item_snake_boots = 2,
}

-- опорой для телепорта не бывает никогда: в портал ходят ногами
local FORBIDDEN_ANCHORS = {
	npc_teleport = "#aa_tp_no_portal",
	-- аванпосты: телепорт на них запрещён
	npc_dota_watch_tower = "#aa_tp_no_outpost",
}

-- 0..5 инвентарь, 6..8 рюкзак, 9..14 склад, 15 слот телепорта, 16 нейтралка
local LAST_SLOT = 16

local WATCH_INTERVAL = 1.0

local watching = false

---------------------------------------------------------------------------------------------------
-- Герой, травела, свиток
---------------------------------------------------------------------------------------------------

function TpScroll:IsValidOwner(hero)
	if not hero or hero:IsNull() or not IsValidEntity(hero) then return false end
	if not hero.GetItemInSlot then return false end
	if not hero:IsRealHero() or hero:IsIllusion() then return false end
	if hero.IsTempestDouble and hero:IsTempestDouble() then return false end
	if not hero:HasInventory() then return false end

	local playerid = hero:GetPlayerOwnerID()

	return playerid ~= nil and PlayerResource:IsValidPlayerID(playerid)
end

-- травела считаем только в основных шести слотах: в рюкзаке предметы не работают
function TpScroll:GetBoots(hero)
	local best, best_tier

	for slot = 0, 5 do
		local item = hero:GetItemInSlot(slot)
		local tier = item and not item:IsNull() and BOOTS_TIER[item:GetAbilityName()]

		if tier and (not best_tier or tier > best_tier) then
			best = item
			best_tier = tier
		end
	end

	return best, best_tier or 0
end

function TpScroll:GetTier(hero)
	local _, tier = self:GetBoots(hero)

	return tier
end

function TpScroll:FindScroll(hero)
	for slot = 0, LAST_SLOT do
		local item = hero:GetItemInSlot(slot)

		if item and not item:IsNull() and item:GetAbilityName() == SCROLL then
			return item
		end
	end

	return nil
end

function TpScroll:Give(hero)
	local item = CreateItem(SCROLL, hero, hero)

	if not item then return nil end

	item:SetPurchaser(hero)
	hero:AddItem(item)

	return item
end

function TpScroll:FindItem(hero, name)
	for slot = 0, LAST_SLOT do
		local item = hero:GetItemInSlot(slot)

		if item and not item:IsNull() and item:GetAbilityName() == name then
			return item
		end
	end

	return nil
end

function TpScroll:GiveIfMissing(hero)
	if not self:IsValidOwner(hero) then return end
	-- со Snake Boots у героя свой свиток (KeepScroll)
	if self:GetTier(hero) >= 3 then return end
	if self:FindScroll(hero) then return end

	self:Give(hero)
end

---------------------------------------------------------------------------------------------------
-- Что годится в опору для телепорта
---------------------------------------------------------------------------------------------------

-- Служебные юниты без тела: тинкеры аур и заклинаний, иконки миникарты. Движок
-- свитка их видит (цели ALL + неуязвимые), но решать по ним нельзя: у фонтана
-- такой тинкер легко окажется ближе к клику, чем само здание.
local function IsPhantom(unit)
	if unit:GetClassname() == "npc_dota_thinker" then return true end
	if unit:HasModifier("modifier_hidden_from_map") then return true end

	return false
end

-- какой тир травел нужен, чтобы опереться на эту цель
local function RequiredTier(unit)
	if unit:IsBuilding() then return 0 end

	-- обычные союзные герои и крипы - второй тир
	local plain = (unit:IsRealHero() or unit:IsCreep())
		and not unit:IsCourier()
		and not (unit.IsSummoned and unit:IsSummoned())
		and not (unit.IsOther and unit:IsOther())
		and not unit:IsInvulnerable()
		and not string.find(unit:GetUnitName(), "ward")

	if plain then return 2 end

	-- всё остальное: варды, призванные, курьеры, ракета гиро, служебные юниты
	return 3
end

-- возвращает true и текст ошибки, если такой каст свитка разрешать нельзя.
--
-- Движок сам выбирает ближайшую к клику подходящую цель и о травелах ничего не
-- знает. Поэтому ищем цели теми же правилами, что прописаны свитку в KV
-- (союзные, ALL, с неуязвимыми), и решаем по той, которую возьмёт движок.
function TpScroll:BlocksTeleport(hero, ability, point)
	if not self:IsValidOwner(hero) then return false end
	if not point then return false end

	local tier = self:GetTier(hero)

	local radius = ability and ability:GetSpecialValueFor("maximum_distance") or 800

	if radius <= 0 then radius = 800 end

	local units = FindUnitsInRadius(hero:GetTeamNumber(), point, nil, radius,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_ALL,
		DOTA_UNIT_TARGET_FLAG_INVULNERABLE, FIND_CLOSEST, false)

	local closest_any, closest_real

	for _, unit in ipairs(units) do
		if unit and not unit:IsNull() and unit ~= hero and unit:IsAlive() then
			closest_any = closest_any or unit

			if not IsPhantom(unit) then
				closest_real = unit
				break
			end
		end
	end

	-- целей нет вовсе - пусть откажет сам движок
	if not closest_any then return false end

	-- рядом одни служебные юниты: движок полетит на них, это как на любого юнита
	local target = closest_real

	if not target then
		if tier >= 3 then return false end

		return true, "#aa_tp_need_snake_boots"
	end

	if FORBIDDEN_ANCHORS[target:GetUnitName()] then
		return true, FORBIDDEN_ANCHORS[target:GetUnitName()]
	end

	local required = RequiredTier(target)

	if tier >= required then return false end

	if required >= 3 then
		return true, "#aa_tp_need_snake_boots"
	end

	return true, "#aa_tp_need_travel_boots"
end

---------------------------------------------------------------------------------------------------
-- Присмотр за свитком у третьего тира
---------------------------------------------------------------------------------------------------

-- Движок знает только два предмета-травела, поэтому Snake Boots он за них не
-- считает: свиток снова тратится и катится 40 секунд. Возвращаем это руками.
function TpScroll:KeepScroll(hero)
	local _, tier = self:GetBoots(hero)

	if tier >= 3 then
		-- Snake Boots: вместо ванильного свитка - свой (items/item_snake_tpscroll)
		local scroll = self:FindScroll(hero)

		if scroll then hero:RemoveItem(scroll) end

		if not self:FindItem(hero, SNAKE_SCROLL) then
			local item = CreateItem(SNAKE_SCROLL, hero, hero)

			if item then
				item:SetPurchaser(hero)
				hero:AddItem(item)

				-- НЕ в слот телепорта: оттуда движок кастует только ванильный
				-- item_tpscroll, а на свой предмет пишет "поместите предмет в
				-- инвентарь". Свиток ложится в обычный инвентарь.
			end
		end

		return
	end

	-- ботинок нет - свой свиток забираем, обычный возвращаем
	local snake = self:FindItem(hero, SNAKE_SCROLL)

	if snake then
		hero:RemoveItem(snake)
		self:GiveIfMissing(hero)
	end
end

function TpScroll:StartWatch()
	if watching then return end

	watching = true

	Timers:CreateTimer(WATCH_INTERVAL, function()
		TeamHelper:ApplyForPlayers(nil, function(playerid)
			local hero = PlayerResource:GetSelectedHeroEntity(playerid)

			if hero and TpScroll:IsValidOwner(hero) and hero:IsAlive() then
				TpScroll:KeepScroll(hero)
			end
		end)

		return WATCH_INTERVAL
	end)
end

---------------------------------------------------------------------------------------------------
-- Хуки
---------------------------------------------------------------------------------------------------

function TpScroll:OnHeroSpawned(hero)
	if not self:IsValidOwner(hero) then return end

	self:StartWatch()

	-- свиток на старте; при смене героя второй не выдаём
	if hero.aa_tp_scroll_given then return end

	hero.aa_tp_scroll_given = true

	Timers:CreateTimer(0.2, function()
		TpScroll:GiveIfMissing(hero)
	end)
end

-- на смерти свиток выдаёт сам движок; страхуемся на случай, если не выдал
function TpScroll:OnHeroDied(hero)
	if not self:IsValidOwner(hero) then return end

	Timers:CreateTimer(0.5, function()
		TpScroll:GiveIfMissing(hero)
	end)
end

