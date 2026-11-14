-- Косметические умения премиума через невидимый юнит-кастер (схема aaf, cosmetic_abilities.lua).
--
-- На каждого премиум-игрока создаётся юнит npc_dota_aa_cosmetic_caster (npc_units_custom.txt)
-- с модификатором modifier_aa_cosmetic_caster: неуязвим, невидим, вне игры, ходит за героем
-- (FollowEntity). На нём:
--   * aa_cos_spray и aa_cos_high_five - граффити и "Дай пять" (lib/cosmetics/social.lua).
--
-- Клиент (cosmetic_bar.js) кастует так же, как aaf: выделяет кастера, ExecuteAbility, возвращает
-- выделение. Прицел, кулдаун и тултип - движковые.
--
-- Ивенты (через защиту):
--   клиент -> сервер  aa_cos_caster_req {}          - запрос entindex (переподключение, перезагрузка UI)
--   сервер -> клиент  aa_cos_caster { entindex }    - entindex кастера игрока (-1 - кастера нет)
--
-- Сезонные умения (снежок, снеговик, салют, хлопушки, ёлка) убраны 2026-11-12 по решению владельца.

if not IsServer() then return end

if CosmeticsCaster ~= nil then return end

CosmeticsCaster = {}

local K = CosmeticsCaster

local CASTER_UNIT = "npc_dota_aa_cosmetic_caster"
local CHECK_PERIOD = 5   -- сверка: премиум пришёл позже спавна, репик сменил героя

-- порядок = порядок кнопок на панели (cosmetic_bar.js знает те же имена)
local SKILLS = {
	"aa_cos_high_five",
	"aa_cos_spray",
}

K.casters = K.casters or {}   -- pid -> юнит
K.heroes = K.heroes or {}     -- pid -> герой, за которым ходит кастер

local function IsPremium(pid)
	return CosmeticsCore ~= nil and type(CosmeticsCore.IsPremium) == "function" and CosmeticsCore:IsPremium(pid) == true
end

function K:Send(pid)
	local player = PlayerResource:GetPlayer(pid)

	if player == nil then return end

	local unit = self.casters[pid]
	local idx = (unit and IsValidEntity(unit)) and unit:entindex() or -1

	CustomGameEventManager:Send_ServerToPlayer(player, "aa_cos_caster", { entindex = idx })
end

function K:Ensure(pid)
	if pid == nil or pid < 0 or not IsPremium(pid) then return end

	local hero = PlayerResource:GetSelectedHeroEntity(pid)

	if not IsValidEntity(hero) then return end

	local unit = self.casters[pid]

	if unit and IsValidEntity(unit) then
		-- репик: кастер переезжает к новому герою
		if self.heroes[pid] ~= hero then
			self.heroes[pid] = hero
			unit:SetOwner(hero)
			unit:FollowEntity(nil, false)
			unit:SetAbsOrigin(hero:GetAbsOrigin())
			unit:FollowEntity(hero, true)
			self:Send(pid)
		end

		return
	end

	unit = CreateUnitByName(CASTER_UNIT, hero:GetAbsOrigin(), false, hero, hero, hero:GetTeamNumber())

	if not unit then return end

	unit:SetControllableByPlayer(pid, true)
	unit:SetOwner(hero)
	unit:SetAbsOrigin(hero:GetAbsOrigin())
	unit:FollowEntity(hero, true)
	unit:AddNewModifier(unit, nil, "modifier_aa_cosmetic_caster", { duration = -1 })

	for _, name in ipairs(SKILLS) do
		if not unit:HasAbility(name) then
			local ab = unit:AddAbility(name)

			if ab then
				ab:SetLevel(1)
				ab:SetHidden(false)
			end
		end
	end

	self.casters[pid] = unit
	self.heroes[pid] = hero

	print("[CosmeticsCaster] кастер для pid " .. pid .. ": " .. unit:entindex())

	self:Send(pid)
end

function K:Remove(pid)
	local unit = self.casters[pid]

	self.casters[pid] = nil
	self.heroes[pid] = nil

	if unit and IsValidEntity(unit) then unit:RemoveSelf() end
end

CustomGameEventManager:RegisterListener("aa_cos_caster_req", function(_, e)
	if type(e) ~= "table" or e.PlayerID == nil then return end

	local pid = e.PlayerID

	pcall(K.Ensure, K, pid)
	pcall(K.Send, K, pid)
end)

ListenToGameEvent("npc_spawned", function(data)
	local unit = data and data.entindex and EntIndexToHScript(data.entindex)

	if not unit or not IsValidEntity(unit) or not unit.IsRealHero or not unit:IsRealHero() then return end

	local pid = unit:GetPlayerOwnerID()

	Timers:CreateTimer(0.5, function()
		pcall(K.Ensure, K, pid)
	end)
end, nil)

ListenToGameEvent("player_disconnect", function(data)
	local pid = data and data.PlayerID

	if pid ~= nil and pid >= 0 then K:Remove(pid) end
end, nil)

-- премиум приходит с бэкенда позже спавна героя - сверяемся редко
Timers:CreateTimer(CHECK_PERIOD, function()
	for pid = 0, 23 do
		if PlayerResource:IsValidPlayerID(pid) then pcall(K.Ensure, K, pid) end
	end

	return CHECK_PERIOD
end)

return K
