-- Косметика премиума на игровых событиях (2026-11-12).
--
--   levelup_effect  - партикл на герое при новом уровне (dota_player_gained_level), без кулдауна;
--   fountain_effect - пока на герое баф фонтана (modifier_fountain_aura_buff), на нём висит свой реген;
--   hero_skin       - шейдер модели (status) + партикл на теле: модификатор modifier_aa_cos_body;
--   projectile      - снаряд атаки дальника, тот же модификатор (самый низкий приоритет);
--   kill_banner     - экранный баннер мультикилла ВСЕМ игрокам: 2 / 3 / 4 / 5+ убийств подряд
--                     (окно MULTIKILL_WINDOW между убийствами) и первая кровь;
--   duel_win        - эффект на героях победившей в дуэли команды (зовёт lib/duel/duel_controller.lua).
-- Эффекты предметов (блинк, фазы, мьёльнир, хекс) - в самих предметах через AACosmeticItem (core.lua).

if not IsServer() then return end
if CosmeticsEventsFx ~= nil then return end

CosmeticsEventsFx = {}

local X = CosmeticsEventsFx

local TICK = 1
local LEVELUP_LIFE = 4
local BANNER_LIFE = 4
local DUEL_WIN_LIFE = 6
local HERO_SKIN_ENABLED = false
local MULTIKILL_WINDOW = 18     -- как в доте: между убийствами мультикилла не больше 18 с

X.fountain = X.fountain or {}   -- pid -> { idx, path }
X.body = X.body or {}           -- pid -> подпись надетого (status|projectile|skin id)
X.kills = X.kills or {}         -- pid -> { last = время, count = n }
X.first_blood = X.first_blood or false

local function Equipped(pid, slot)
	return AACosmeticItem and AACosmeticItem(PlayerResource:GetSelectedHeroEntity(pid), slot) or nil
end

local function FirstPath(item, n)
	local p = item and item.particles and item.particles[n or 1]

	return p and p.path or nil
end

local function FreeLater(idx, life)
	if not idx then return end

	Timers:CreateTimer(life, function()
		ParticleManager:DestroyParticle(idx, false)
		ParticleManager:ReleaseParticleIndex(idx)
	end)
end

-- ------------------------------------------------------------------ новый уровень

ListenToGameEvent("dota_player_gained_level", function(keys)
	local pid = keys.player_id or keys.PlayerID or (keys.player and keys.player - 1)

	if pid == nil or pid < 0 then return end

	local hero = PlayerResource:GetSelectedHeroEntity(pid)
	local path = FirstPath(Equipped(pid, "levelup_effect"))

	if not path or not hero or hero:IsNull() then return end

	FreeLater(ParticleManager:CreateParticle(path, PATTACH_ABSORIGIN_FOLLOW, hero), LEVELUP_LIFE)
end, nil)

-- ------------------------------------------------------------------ фонтан, скин, снаряд (раз в секунду)

local function TickFountain(pid, hero)
	local cur = X.fountain[pid]
	local path = hero:IsAlive() and hero:HasModifier("modifier_fountain_aura_buff") and FirstPath(Equipped(pid, "fountain_effect")) or nil

	if cur and cur.path == path then return end

	if cur then
		ParticleManager:DestroyParticle(cur.idx, false)
		ParticleManager:ReleaseParticleIndex(cur.idx)
		X.fountain[pid] = nil
	end

	if path then
		X.fountain[pid] = { idx = ParticleManager:CreateParticle(path, PATTACH_ABSORIGIN_FOLLOW, hero), path = path }
	end
end

local function TickBody(pid, hero)
	-- скин героя выключен 2026-11-12 (владелец): вернуть - HERO_SKIN_ENABLED = true и слот в catalog.lua / хабе
	local skin = HERO_SKIN_ENABLED and Equipped(pid, "hero_skin") or nil
	local proj = hero:IsRangedAttacker() and FirstPath(Equipped(pid, "projectile")) or nil
	local sig = (skin and skin.id or "") .. "|" .. (proj or "")
	local mod = hero:FindModifierByName("modifier_aa_cos_body")

	if X.body[pid] == sig and (mod ~= nil) == (sig ~= "|") then return end

	X.body[pid] = sig

	if mod then mod:Destroy() end

	if sig == "|" then return end

	local part = skin and skin.particles and skin.particles[1]

	hero:AddNewModifier(hero, nil, "modifier_aa_cos_body", {
		status = skin and skin.status or "",
		projectile = proj or "",
		particle = part and part.path or "",
		point = part and part.point or "",
	})
end

Timers:CreateTimer(TICK, function()
	for pid = 0, 23 do
		if PlayerResource:IsValidPlayerID(pid) then
			local hero = PlayerResource:GetSelectedHeroEntity(pid)

			if hero and not hero:IsNull() then
				pcall(TickFountain, pid, hero)
				pcall(TickBody, pid, hero)
			end
		end
	end

	return TICK
end)

-- ------------------------------------------------------------------ баннеры мультикиллов

-- баннер всем игрокам: экранный партикл у каждого на его камере
local function ShowBanner(path)
	for pid = 0, 23 do
		local player = PlayerResource:IsValidPlayerID(pid) and PlayerResource:GetPlayer(pid)

		if player then
			local hero = PlayerResource:GetSelectedHeroEntity(pid)
			local ok, idx = pcall(ParticleManager.CreateParticleForPlayer, ParticleManager, path, PATTACH_MAIN_VIEW, hero, player)

			if ok then FreeLater(idx, BANNER_LIFE) end
		end
	end
end

ListenToGameEvent("entity_killed", function(keys)
	local victim = keys.entindex_killed and EntIndexToHScript(keys.entindex_killed)
	local attacker = keys.entindex_attacker and EntIndexToHScript(keys.entindex_attacker)

	if not victim or victim:IsNull() or not victim.IsRealHero or not victim:IsRealHero() or victim:IsReincarnating() then return end

	-- смерть обнуляет серию самого убитого
	local vpid = victim:GetPlayerOwnerID()

	if vpid and vpid >= 0 then X.kills[vpid] = nil end

	if not attacker or attacker:IsNull() or not attacker.GetPlayerOwnerID then return end

	local pid = attacker:GetPlayerOwnerID()

	if pid == nil or pid < 0 or pid == vpid then return end
	if attacker:GetTeamNumber() == victim:GetTeamNumber() then return end

	local now = GameRules:GetGameTime()
	local k = X.kills[pid]

	if k and now - k.last <= MULTIKILL_WINDOW then
		k.count = k.count + 1
		k.last = now
	else
		k = { last = now, count = 1 }
		X.kills[pid] = k
	end

	local first = not X.first_blood

	X.first_blood = true

	local item = Equipped(pid, "kill_banner")

	if not item then return end

	-- particles: [1] двойное, [2] тройное, [3] 4 подряд, [4] 5+ (rampage), [5] первая кровь
	local n = nil

	if k.count == 1 and first then n = 5
	elseif k.count == 2 then n = 1
	elseif k.count == 3 then n = 2
	elseif k.count == 4 then n = 3
	elseif k.count >= 5 then n = 4 end

	local path = n and FirstPath(item, n)

	if path then ShowBanner(path) end
end, nil)

-- ------------------------------------------------------------------ хекс и фазы (все уровни)
-- Ванильные дебафф хекса / баф фаз висят и на 1-м уровне (ванильные предметы), и на наших Lua-уровнях.
-- Механику не трогаем: поверх вешаем косметику на ту же длительность.
--   modifier_sheepstick_debuff        -> модель превращения кастующего (modifier_aa_cos_hex_model)
--   modifier_item_phase_boots_active  -> эффект фаз на всё время бафа
local HEX_MODS = { modifier_sheepstick_debuff = true }   -- наш Lua-хекс (modifier_sheepstick_hex) ставит модель сам

local function OnModifierGained(keys)
	local name = keys.name_const
	local parent = keys.entindex_parent_const and EntIndexToHScript(keys.entindex_parent_const)
	local caster = keys.entindex_caster_const and EntIndexToHScript(keys.entindex_caster_const)
	local duration = keys.duration or -1

	if not parent or parent:IsNull() then return end

	if HEX_MODS[name] and caster and not caster:IsNull() then
		local item = AACosmeticItem and AACosmeticItem(caster, "hex_skin")

		if item and item.model and duration > 0 then
			-- создаём в следующем кадре: фильтр зовётся до появления самого дебаффа
			Timers:CreateTimer(0, function()
				if parent:IsNull() or not parent:IsAlive() then return end

				parent:AddNewModifier(caster, nil, "modifier_aa_cos_hex_model", { duration = duration, model = item.model })
			end)
		end
	elseif name == "modifier_item_phase_boots_active" then
		local path = AACosmeticPath and AACosmeticPath(parent, "phase_effect", 1, nil)

		if path and duration > 0 then
			FreeLater(ParticleManager:CreateParticle(path, PATTACH_ABSORIGIN_FOLLOW, parent), duration)
		end
	end
end

Timers:CreateTimer(1, function()
	local gm = GameRules:GetGameModeEntity()

	if not gm then return 1 end

	gm:SetModifierGainedFilter(function(_, keys)
		pcall(OnModifierGained, keys)

		return true
	end, X)
end)

-- ------------------------------------------------------------------ победа в дуэли

function AACosDuelWin(team)
	for pid = 0, 23 do
		if PlayerResource:IsValidPlayerID(pid) and PlayerResource:GetTeam(pid) == team then
			local hero = PlayerResource:GetSelectedHeroEntity(pid)
			local path = FirstPath(Equipped(pid, "duel_win"))

			if path and hero and not hero:IsNull() then
				-- героев переносят с арены в этот же момент - создаём чуть позже, на новом месте
				Timers:CreateTimer(0.6, function()
					if hero:IsNull() then return end

					FreeLater(ParticleManager:CreateParticle(path, PATTACH_ABSORIGIN_FOLLOW, hero), DUEL_WIN_LIFE)
				end)
			end
		end
	end
end

return X
