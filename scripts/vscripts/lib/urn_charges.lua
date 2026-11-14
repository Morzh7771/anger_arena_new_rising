if not IsServer() then return end

--[[
	Заряды и стаки урны/вессела (сами предметы - items/item_urn_aa.lua).

	1. Заряд за смерть вражеского героя, как в доте: среди урн/весселов команды
	   врагов погибшего, чей владелец жив и стоит в soul_radius от трупа, заряд
	   получает только ближайшая. Пустая получает soul_initial_charge, иначе
	   soul_additional_charges.

	2. Заряд по времени: раз в CHARGE_INTERVAL сек. первая урна/вессел героя в
	   основных шести слотах получает +1 заряд. Без предмета таймер сбрасывается.

	3. Стаки Soul Keeper как в 1х6: вражеский герой умер в STACK_RADIUS от
	   владельца урны или убит им - владелец навсегда получает стак
	   (modifiers/modifier_urn_soul_stacks.lua), максимум STACK_MAX.
]]

UrnCharges = UrnCharges or {}

-- числа берутся из KV предмета (charge_interval, soul_keeper_*), здесь - запасные
local CHARGE_INTERVAL = 120
local THINK = 1
local STACK_RADIUS = 700
local STACK_MAX = 15

local function Value(item, key, default)
	local v = item and item:GetSpecialValueFor(key) or 0

	return v > 0 and v or default
end

local URN_ITEMS = {
	item_urn_of_shadows = true,
	item_spirit_vessel = true,
	item_spirit_vessel_2 = true,
	item_spirit_vessel_3 = true,
}

local STACK_MODIFIER = "modifier_urn_soul_stacks"

local function IsOwnerHero(hero)
	return hero and not hero:IsNull() and hero:IsRealHero() and not hero:IsTempestDouble() and not hero:IsClone()
end

function UrnCharges:FindUrn(hero)
	for slot = 0, 5 do
		local item = hero:GetItemInSlot(slot)

		if item and not item:IsNull() and URN_ITEMS[item:GetAbilityName()] then
			return item
		end
	end
end

function UrnCharges:Think()
	local now = GameRules:GetGameTime()

	for _, hero in ipairs(HeroList:GetAllHeroes()) do
		if IsOwnerHero(hero) then
			local urn = self:FindUrn(hero)

			if not urn then
				hero.aa_urn_next_charge = nil
			elseif not hero.aa_urn_next_charge then
				hero.aa_urn_next_charge = now + Value(urn, "charge_interval", CHARGE_INTERVAL)
			elseif now >= hero.aa_urn_next_charge then
				urn:SetCurrentCharges(urn:GetCurrentCharges() + 1)
				hero.aa_urn_next_charge = now + Value(urn, "charge_interval", CHARGE_INTERVAL)
			end
		end
	end
end

-- как в доте: заряд только ближайшей урне в радиусе
function UrnCharges:GiveKillCharge(victim)
	local pos = victim:GetAbsOrigin()
	local best, best_dist

	for _, hero in ipairs(HeroList:GetAllHeroes()) do
		if IsOwnerHero(hero) and hero:IsAlive() and hero:GetTeamNumber() ~= victim:GetTeamNumber() then
			for slot = 0, 5 do
				local item = hero:GetItemInSlot(slot)

				if item and not item:IsNull() and URN_ITEMS[item:GetAbilityName()] then
					local dist = (hero:GetAbsOrigin() - pos):Length2D()

					if dist <= item:GetSpecialValueFor("soul_radius") and (not best_dist or dist < best_dist) then
						best, best_dist = item, dist
					end
				end
			end
		end
	end

	if not best then return end

	local charges = best:GetCurrentCharges()
	local add = charges == 0 and best:GetSpecialValueFor("soul_initial_charge") or best:GetSpecialValueFor("soul_additional_charges")

	best:SetCurrentCharges(charges + math.max(1, add))
end

function UrnCharges:GiveStacks(victim, attacker)
	local killer = attacker and not attacker:IsNull() and attacker.GetPlayerOwnerID and attacker:GetPlayerOwnerID()

	for _, hero in ipairs(HeroList:GetAllHeroes()) do
		local urn = IsOwnerHero(hero) and hero:GetTeamNumber() ~= victim:GetTeamNumber() and self:FindUrn(hero)

		if urn then
			local by_owner = killer ~= nil and killer >= 0 and killer == hero:GetPlayerOwnerID()
			local near = hero:IsAlive()
				and (hero:GetAbsOrigin() - victim:GetAbsOrigin()):Length2D() <= Value(urn, "soul_keeper_radius", STACK_RADIUS)

			if by_owner or near then
				local mod = hero:FindModifierByName(STACK_MODIFIER)
					or hero:AddNewModifier(hero, nil, STACK_MODIFIER, {})

				if mod and mod:GetStackCount() < Value(urn, "soul_keeper_max", STACK_MAX) then
					mod:IncrementStackCount()
				end
			end
		end
	end
end

-- 4. Перенос зарядов при сборке и разборке. Движок при апгрейде (урна -> вессел,
--    вессел + вессел -> вессел 2) и при разборке создаёт новый предмет с нуля, и
--    заряды пропадали. Раз в TRANSFER_THINK сек. запоминаем заряды урн/весселов героя
--    (весь инвентарь, рюкзак и тайник); если какие-то исчезли и в тот же момент
--    появился новый - новый получает их сумму (если у него меньше). Продали или
--    выбросили без нового предмета - ничего не переносим.
local TRANSFER_THINK = 0.2

function UrnCharges:TransferThink()
	for _, hero in ipairs(HeroList:GetAllHeroes()) do
		if IsOwnerHero(hero) then
			local now = {}
			local fresh = {}

			for slot = 0, 16 do
				local item = hero:GetItemInSlot(slot)

				if item and not item:IsNull() and URN_ITEMS[item:GetAbilityName()] then
					local id = item:entindex()
					now[id] = item

					if hero.aa_urn_seen and hero.aa_urn_seen[id] == nil then
						table.insert(fresh, item)
					end
				end
			end

			local seen = hero.aa_urn_seen or {}
			local lost = 0

			for id, charges in pairs(seen) do
				if not now[id] then lost = lost + charges end
			end

			if lost > 0 and #fresh > 0 then
				-- обычно новый предмет один; если вдруг больше - всё первому
				local item = fresh[1]

				if item:GetCurrentCharges() < lost then item:SetCurrentCharges(lost) end
			end

			local remember = {}

			for id, item in pairs(now) do remember[id] = item:GetCurrentCharges() end

			hero.aa_urn_seen = remember
		end
	end
end

function UrnCharges:OnEntityKilled(event)
	local victim = event.entindex_killed and EntIndexToHScript(event.entindex_killed)

	if not victim or victim:IsNull() or not victim:IsRealHero() then return end
	if victim:IsReincarnating() or victim:IsTempestDouble() or victim:IsClone() then return end

	local attacker = event.entindex_attacker and EntIndexToHScript(event.entindex_attacker)

	self:GiveKillCharge(victim)
	self:GiveStacks(victim, attacker)
end

if not UrnCharges.started then
	UrnCharges.started = true

	ListenToGameEvent("entity_killed", function(event)
		local ok, err = pcall(UrnCharges.OnEntityKilled, UrnCharges, event)
		if not ok then print("[urn_charges] " .. tostring(err)) end
	end, nil)

	Timers:CreateTimer(TRANSFER_THINK, function()
		local ok, err = pcall(UrnCharges.TransferThink, UrnCharges)
		if not ok then print("[urn_charges] transfer: " .. tostring(err)) end
		return TRANSFER_THINK
	end)

	Timers:CreateTimer(THINK, function()
		local ok, err = pcall(UrnCharges.Think, UrnCharges)
		if not ok then print("[urn_charges] " .. tostring(err)) end
		return THINK
	end)
end
