-- Alt-клик по баффу/дебаффу -> сообщение в чат команды (как ванильный пинг модификатора).
-- В кастомках движок сам этого не делает, поэтому повторяем (подсмотрено во Frontier,
-- ping_modifier_fix). Клиент: panorama ping_modifiers.js.
--
--   клиент -> сервер  aa_ping_modifier { entity, modifier, name, who }
--     name - название модификатора, уже переведённое на клиенте отправителя;
--     who  - имя юнита, если пингуют не своего героя.
-- Сервер проверяет, что модификатор правда висит и юнит свой или виден команде,
-- добавляет стаки и время и пишет от имени игрока в чат команды.

if not IsServer() then return end
if AAPingModifiers ~= nil then return end

AAPingModifiers = { last = {} }

local P = AAPingModifiers

local COOLDOWN = 1.0
local MAX_TEXT = 120 -- в байтах: кириллица по 2 байта на букву

local function Clean(s, max)
	s = tostring(s or ""):gsub("[<>%c]", "")
	max = max or MAX_TEXT
	if #s > max then s = s:sub(1, max) end
	return s
end

local function Secs(t)
	return tostring(math.max(0, math.ceil(t))) .. "s"
end

function P:OnPing(data)
	local pid = data and tonumber(data.PlayerID)
	if pid == nil then return end

	local player = PlayerResource:GetPlayer(pid)
	if not player then return end

	local now = GameRules:GetGameTime()
	if self.last[pid] and now - self.last[pid] < COOLDOWN then return end

	local unit = EntIndexToHScript(tonumber(data.entity) or -1)
	if not unit or unit:IsNull() or not unit.FindModifierByName then return end

	local team = PlayerResource:GetTeam(pid)
	if unit:GetTeamNumber() ~= team and not unit:CanBeSeenByAnyOpponent() then return end

	local mod = unit:FindModifierByName(tostring(data.modifier or ""))
	if not mod or mod:IsNull() then return end

	local name = Clean(data.name, 300)
	if name == "" then return end

	self.last[pid] = now

	local text = name
	local stacks = mod:GetStackCount()
	-- у усталости процент уже в тексте, стаки не дописываем
	if stacks and stacks > 1 and not mod.expires then text = text .. " x" .. stacks end

	-- у усталости от боссов у каждого стака своё время - пишем все
	if mod.expires and type(mod.expires) == "table" and #mod.expires > 0 then
		local list = {}
		for _, t in ipairs(mod.expires) do list[#list + 1] = t end
		table.sort(list)
		local parts = {}
		for _, t in ipairs(list) do parts[#parts + 1] = Secs(t - now) end
		text = text .. " (" .. table.concat(parts, " / ") .. ")"
	else
		local left = mod:GetRemainingTime()
		if left and left > 0 and not mod:GetAuraOwner() then text = text .. ": " .. Secs(left) end
	end

	local who = Clean(data.who)
	if who ~= "" then text = who .. " - " .. text end

	Say(player, "> " .. text, true)
end

CustomGameEventManager:RegisterListener("aa_ping_modifier", function(_, data)
	local ok, err = pcall(P.OnPing, P, data)
	if not ok then print("[AAPingModifiers] " .. tostring(err)) end
end)

return P
