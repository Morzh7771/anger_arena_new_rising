-- Ворота под торментором (основание divine_sentinel, как в доте).
-- Пока торментора нет - закрыты, при появлении открываются, после смерти
-- закрываются.
--
-- На карте основание стоит только у Тьмы, и у него включён анимграф, через
-- который входы SetAnimation могут не работать. Поэтому на обеих точках
-- ставим своё основание без анимграфа (картовое, если есть, убираем,
-- забрав его положение, размер и цвет) и управляем им последовательностями
-- модели: closed_idle -> spawn_open -> open_idle -> spawn_close.
-- Редактор карты для этого не нужен.

TormentorGates = TormentorGates or {}

local MODEL = "models/props_gameplay/divine_sentinel/divine_sentinel.vmdl"
local SCALE = 0.7          -- как у картового основания
local FIND_RADIUS = 400    -- где искать картовое основание вокруг точки

local ANIM_CLOSED      = "divine_sentinel_closed_idle"
local ANIM_OPENING     = "divine_sentinel_spawn_open"
local ANIM_OPEN        = "divine_sentinel_open_idle"
local ANIM_CLOSING     = "divine_sentinel_spawn_close"

local SOUND_OPEN  = "Miniboss.Tormenter.Base.Open"
local SOUND_CLOSE = "Miniboss.Tormenter.Base.Close"

TormentorGates.gates = TormentorGates.gates or {}

local function IsDire(bossName)
	return bossName and bossName:find("dire") ~= nil
end

local function FindMapBase(point)
	for _, ent in ipairs(Entities:FindAllByClassnameWithin("prop_dynamic", point, FIND_RADIUS)) do
		if ent.GetModelName and ent:GetModelName() == MODEL then
			return ent
		end
	end
end

-- Ставит основание на точку босса. Зовётся до первого спавна.
function TormentorGates:Create(bossName, point)
	if self.gates[bossName] and IsValidEntity(self.gates[bossName]) then
		return self.gates[bossName]
	end

	local origin = GetGroundPosition(point, nil)
	local angles = QAngle(0, 0, 0)

	local mapBase = FindMapBase(point)
	if mapBase then
		origin = mapBase:GetAbsOrigin()
		angles = mapBase:GetAngles()
		UTIL_Remove(mapBase)
	end

	local gate = SpawnEntityFromTableSynchronous("prop_dynamic", {
		model = MODEL,
		origin = origin,
		angles = angles,
		skin = IsDire(bossName) and "1" or "0",
		solid = "0",
		DefaultAnim = ANIM_CLOSED,
		use_animgraph = "0",
	})

	if not gate then
		print("[TormentorGates] failed to spawn gate for", bossName)
		return
	end

	gate:SetModelScale(SCALE)
	gate:SetSkin(IsDire(bossName) and 1 or 0)

	self.gates[bossName] = gate
	return gate
end

local function Play(gate, anim, default)
	DoEntFireByInstanceHandle(gate, "SetDefaultAnimation", default, 0, nil, nil)
	DoEntFireByInstanceHandle(gate, "SetAnimation", anim, 0, nil, nil)
end

function TormentorGates:Open(bossName)
	local gate = self.gates[bossName]
	if not gate or not IsValidEntity(gate) then return end
	Play(gate, ANIM_OPENING, ANIM_OPEN)
	EmitSoundOnLocationWithCaster(gate:GetAbsOrigin(), SOUND_OPEN, gate)
end

function TormentorGates:Close(bossName)
	local gate = self.gates[bossName]
	if not gate or not IsValidEntity(gate) then return end
	Play(gate, ANIM_CLOSING, ANIM_CLOSED)
	EmitSoundOnLocationWithCaster(gate:GetAbsOrigin(), SOUND_CLOSE, gate)
end
