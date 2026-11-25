if not IsServer() then return end

-- АФК-детектор: игрок, который AFK_TIME секунд игрового времени не отдал ни одного
-- приказа, считается АФК. Такие игроки (и отключившиеся/ливнувшие) выпадают из
-- формул, которые смотрят на уровни героев (CreepLeveling). Первый же приказ
-- возвращает игрока в расчёт.
-- Активность отмечается из AngelArena:ExecuteOrderFilterCustom.
AfkTracker = AfkTracker or {}

local AFK_TIME = 300

AfkTracker.lastOrder = AfkTracker.lastOrder or {}

local function Now()
	return GameRules:GetGameTime()
end

function AfkTracker:Touch(playerId)
	if playerId == nil or playerId < 0 then return end
	self.lastOrder[playerId] = Now()
end

function AfkTracker:IsAfk(playerId)
	if playerId == nil or playerId < 0 then return false end
	if PlayerResource:IsFakeClient(playerId) then return false end

	local conn = PlayerResource:GetConnectionState(playerId)
	if conn ~= DOTA_CONNECTION_STATE_CONNECTED then return true end

	-- первая отметка ставится лениво: до неё таймер считаем от первого вопроса
	local last = self.lastOrder[playerId]
	if not last then
		self.lastOrder[playerId] = Now()
		return false
	end

	return Now() - last >= AFK_TIME
end

-- герой участвует в расчётах уровня крипов
function AfkTracker:IsActiveHero(hero)
	if not hero or hero:IsNull() or not IsValidEntity(hero) or not hero:IsRealHero() then return false end
	local pid = hero:GetPlayerOwnerID()
	if pid == nil or pid < 0 then return false end
	return not self:IsAfk(pid)
end
