if not IsServer() then return end

-- Покупка из блока "Рекомендуем" на стадии стратегии (panorama strategy_farm.js, 2026-11-15).
-- Ячейки магазина до начала игры не покупают (магазин закрыт), поэтому покупает сервер:
--   клиент -> сервер aa_strategy_buy { item }   - купить
--   клиент -> сервер aa_strategy_costs { items } - цены (через запятую), ответ aa_strategy_costs { item = цена }
--   сервер -> клиент aa_strategy_buy_fail        - не хватает золота / нельзя сейчас
-- Золото списывается сразу. Если героя ещё нет на карте - предмет отдаём, когда он появится.

StrategyBuy = StrategyBuy or { pending = {} }

local S = StrategyBuy

-- покупать можно с выбора героя до начала игры (пик, стратегия, пре-гейм)
local function CanBuyNow()
	local s = GameRules:State_Get()

	return s >= DOTA_GAMERULES_STATE_HERO_SELECTION and s <= DOTA_GAMERULES_STATE_PRE_GAME
end

local function Fail(pid)
	local player = PlayerResource:GetPlayer(pid)

	if player then CustomGameEventManager:Send_ServerToPlayer(player, "aa_strategy_buy_fail", {}) end
end

local function Give(hero, item)
	local it = hero:AddItemByName(item)

	if it then
		it:SetPurchaser(hero)
		it:SetPurchaseTime(GameRules:GetGameTime())
	end
end

function S:OnBuy(data)
	local pid = tonumber(data.PlayerID)
	local item = tostring(data.item or "")

	if pid == nil or item:sub(1, 5) ~= "item_" or not CanBuyNow() then return Fail(pid) end

	local cost = GetItemCost(item)

	if not cost or cost <= 0 then return Fail(pid) end
	if PlayerResource:GetGold(pid) < cost then return Fail(pid) end

	PlayerResource:SpendGold(pid, cost, DOTA_ModifyGold_PurchaseItem)

	local hero = PlayerResource:GetSelectedHeroEntity(pid)

	if hero and not hero:IsNull() then
		Give(hero, item)
	else
		self.pending[pid] = self.pending[pid] or {}
		table.insert(self.pending[pid], item)
	end

	EmitSoundOnClient("General.Buy", PlayerResource:GetPlayer(pid))
end

function S:OnCosts(data)
	local pid = tonumber(data.PlayerID)
	local player = pid and PlayerResource:GetPlayer(pid)

	if not player then return end

	local out = {}

	for name in string.gmatch(tostring(data.items or ""), "[^,]+") do
		out[name] = GetItemCost(name) or 0
	end

	CustomGameEventManager:Send_ServerToPlayer(player, "aa_strategy_costs", out)
end

-- герой появился - отдаём купленное, пока его не было
ListenToGameEvent("npc_spawned", function(e)
	local ok, err = pcall(function()
		local u = e.entindex and EntIndexToHScript(e.entindex)

		if not u or not u:IsRealHero() then return end

		local pid = u:GetPlayerOwnerID()
		local list = S.pending[pid]

		if not list then return end

		S.pending[pid] = nil

		for _, item in ipairs(list) do Give(u, item) end
	end)

	if not ok then print("[StrategyBuy] spawn: " .. tostring(err)) end
end, nil)

CustomGameEventManager:RegisterListener("aa_strategy_buy", function(_, data)
	local ok, err = pcall(S.OnBuy, S, data)

	if not ok then print("[StrategyBuy] buy: " .. tostring(err)) end
end)

CustomGameEventManager:RegisterListener("aa_strategy_costs", function(_, data)
	local ok, err = pcall(S.OnCosts, S, data)

	if not ok then print("[StrategyBuy] costs: " .. tostring(err)) end
end)
