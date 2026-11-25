--[[
	Бюджет на создание крипов за один кадр.

	CreateUnitByName + FindClearSpaceForUnit + колбэки спавна стоят 5-10 мс
	(бывает до 40) на ОДНОГО юнита. Когда независимые таймеры лагерей попадают
	в один кадр (горн, стак на :00, пробуждение спящих лагерей), кадр выходил
	на 50-500 мс - это и были микрофризы в [AA.perf] (2026-11-24).

	Правило: в кадре один юнит создаётся всегда, следующие - только пока
	колбэки таймеров этого кадра не съели BUDGET_MS. Кто не влез, повторяет
	попытку в следующем кадре. Без нагрузки поведение то же, что было.

	Вне Think таймеров (игровые события) бюджет считается уже потраченным,
	если в этом кадре кто-то уже спавнил: такие вызовы уходят в следующий кадр.
]]

require('lib/timers')

SpawnBudget = SpawnBudget or {}

local BUDGET_MS = 8

-- можно ли создать юнита прямо сейчас; true - место в кадре занято за вызывающим
function SpawnBudget:TryTake()
	local frame = Timers._frameId or 0

	if self._frame ~= frame then
		self._frame = frame
		self._count = 0
	end

	if self._count > 0 then
		local start = Timers._frameStart
		if not start or GetSystemTimeMS() - start > BUDGET_MS then return false end
	end

	self._count = self._count + 1
	return true
end

-- Выполнить fn сейчас, если в кадре есть место, иначе - в общей очереди.
-- Раньше каждый не влезший крип сам перепроверял бюджет своим таймером каждый
-- кадр: на горне это 90-110 лишних колбэков в кадре (лог 2026-11-24 21:04).
-- Очередь разбирает один таймер. Пока очередь не пуста, новые встают в хвост,
-- чтобы порядок спавна не путался.
function SpawnBudget:Run(fn)
	self._queue = self._queue or {}

	if #self._queue == 0 and self:TryTake() then
		local ok, err = pcall(fn)
		if not ok then print("[SpawnBudget] " .. tostring(err)) end
		return
	end

	self._queue[#self._queue + 1] = fn

	if self._running then return end
	self._running = true

	Timers:CreateTimer(function()
		local q = self._queue

		while #q > 0 do
			if not self:TryTake() then return FrameTime() end

			local ok, err = pcall(table.remove(q, 1))
			if not ok then print("[SpawnBudget] " .. tostring(err)) end
		end

		self._running = nil
		return nil
	end)
end
