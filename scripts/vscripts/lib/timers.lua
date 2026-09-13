TIMERS_VERSION = "1.04_fixed"

TIMERS_THINK = 0.01

if Timers == nil then
  print('[Timers] creating Timers')
  Timers = {}
  Timers.__index = Timers
  Timers._timeLimit = 5.0
end

---------------------------------------------------------------------
-- SAFE ERROR HANDLER
---------------------------------------------------------------------
-- На боевом сервере (не tools mode) движок не отдаёт библиотеку debug: там
-- debug == nil, и любой debug.traceback/debug.getinfo - хард-эррор.
-- Из-за этого умирал сам Think: на первом же медленном кадре он уходил в
-- debug.getinfo, падал и больше не перезапускался - вместе с ним разом
-- вставали ВСЕ таймеры (дуэли, GPM, счётчик золота, респавн и стак лагерей,
-- кулдауны шрайна и похвалы). В tools mode debug есть, поэтому в одиночку
-- баг не воспроизводился.
local function timer_traceback(msg)
  if debug and debug.traceback then
    return debug.traceback(msg, 3)
  end

  return msg
end

local function timer_func_location(func)
  if not (debug and debug.getinfo) then
    return "?"
  end

  local ok, info = pcall(debug.getinfo, func)

  if not ok or not info then
    return "?"
  end

  return tostring(info.short_src) .. ":" .. tostring(info.linedefined)
end

local function timer_err(err)
  return timer_traceback(tostring(err))
end

-- Раньше на каждый сработавший таймер аллоцировалось новое замыкание для xpcall.
-- Здесь одна функция на весь модуль, а таймер передаётся через переменную:
-- xpcall в Lua 5.1 не умеет прокидывать аргументы. Вложенных вызовов быть не
-- может - Think дёргает движок, а не колбэки.
local invokeTimer = nil

local function timer_invoke()
  local v = invokeTimer

  if v.context then
    return v.callback(v.context, v)
  end

  return v.callback(v)
end

---------------------------------------------------------------------
-- CONSTRUCTOR
---------------------------------------------------------------------
function Timers:new(o)
  o = o or {}
  setmetatable(o, Timers)
  return o
end

---------------------------------------------------------------------
-- START
---------------------------------------------------------------------
function Timers:start()
  Timers = self
  self.timers = {}

  local ent = Entities:CreateByClassname("info_target")
  ent:SetThink("Think", self, "timers", TIMERS_THINK)
end

---------------------------------------------------------------------
-- THINK LOOP
---------------------------------------------------------------------
function Timers:_Think()
  if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
    return
  end

  local profileStart = GetSystemTimeMS()

  -- время одинаково для всех таймеров в рамках одного тика, а вызовов тут
  -- получалось по одному на каждый живой таймер 100 раз в секунду
  local gameTime = GameRules:GetGameTime()
  local realTime = Time()

  -- худший вызов за тик; полную таблицу замеров раньше собирали каждый тик,
  -- хотя нужна она только если кадр оказался медленным
  local worstFunc = nil
  local worstTime = 0

  -- Сколько времени кадра реально съели наши колбэки и сколько их сработало.
  -- Нужно, чтобы отличать "тормозит наш Lua" от "тормозит весь сервер, а наш
  -- Think просто попал под раздачу": если fired мало и sum сильно меньше
  -- общего времени кадра - причина снаружи (движок, GC, спавн моделей).
  local callbackTime = 0
  local callbackCount = 0

  for k, v in pairs(Timers.timers) do
    local useGameTime = (v.useGameTime ~= false)
    local oldStyle = (v.useOldStyle == true)

    local now = useGameTime and gameTime or realTime

    if v.endTime == nil then
      v.endTime = now
    end

    if now >= v.endTime then
      Timers.timers[k] = nil

      local funcTime = GetSystemTimeMS()

      invokeTimer = v
      local status, nextCall = xpcall(timer_invoke, timer_err)

      local elapsed = GetSystemTimeMS() - funcTime

      callbackTime = callbackTime + elapsed
      callbackCount = callbackCount + 1

      if elapsed > worstTime then
        worstTime = elapsed
        worstFunc = v.callback
      end

      if status then
        if nextCall then
          if oldStyle then
            v.endTime = v.endTime + nextCall - now
          else
            v.endTime = v.endTime + nextCall
          end
          Timers.timers[k] = v
        end
      else
        self:HandleEventError("Timer", k, nextCall)
      end
    end
  end

  local profileTime = GetSystemTimeMS() - profileStart

  if profileTime > Timers._timeLimit then
    print(string.format(
      "[Warning.Timers] slow frame: %.2f ms | колбэков: %d, в них %.2f ms (%.0f%%), вне них %.2f ms",
      profileTime,
      callbackCount,
      callbackTime,
      profileTime > 0 and (callbackTime / profileTime * 100) or 0,
      profileTime - callbackTime))

    if worstFunc then
      print(string.format("[Warning.Timers] худший колбэк: %s - %.2f ms",
        timer_func_location(worstFunc), worstTime))
    end

    -- "вне них" близко к общему времени = наш Lua ни при чём, тормозит сервер
    if profileTime - callbackTime > profileTime * 0.5 then
      print("[Warning.Timers] большая часть кадра ушла НЕ в наши таймеры - искать причину снаружи Lua")
    end
  end

  return TIMERS_THINK
end

-- Движок НЕ перезапускает Think, который кинул ошибку: один такой случай
-- останавливал все таймеры мода до конца матча. Поэтому тело Think идёт
-- через xpcall, и что бы внутри ни рвануло - тик продолжается.
local thinkSelf = nil

local function think_invoke()
  return Timers._Think(thinkSelf)
end

function Timers:Think()
  thinkSelf = self

  local ok, res = xpcall(think_invoke, timer_err)

  if not ok then
    print("========== TIMERS THINK ERROR ==========")
    print(tostring(res))
    print("========================================")

    return TIMERS_THINK
  end

  return res
end

---------------------------------------------------------------------
-- ERROR HANDLER
---------------------------------------------------------------------
function Timers:HandleEventError(name, event, err)
  print("========== TIMER ERROR ==========")
  print("Name:", tostring(name))
  print("Event:", tostring(event))
  print(tostring(err))
  print("=================================")

  if not self.errorHandled then
    self.errorHandled = true
  end
end

---------------------------------------------------------------------
-- CREATE TIMER
---------------------------------------------------------------------
function Timers:CreateTimer(name, args, context)
  if type(name) == "function" then
    context = args
    args = {callback = name}
    name = DoUniqueString("timer")

  elseif type(name) == "table" then
    args = name
    name = DoUniqueString("timer")

  elseif type(name) == "number" then
    args = {endTime = name, callback = args}
    name = DoUniqueString("timer")
  end

  if not args or not args.callback then
    print("Invalid timer:", tostring(name))
    return
  end

  local now = GameRules:GetGameTime()
  if args.useGameTime == false then
    now = Time()
  end

  if args.endTime == nil then
    args.endTime = now
  elseif not args.useOldStyle then
    args.endTime = now + args.endTime
  end

  args.context = context

  Timers.timers[name] = args
  return name
end

---------------------------------------------------------------------
-- REMOVE TIMER
---------------------------------------------------------------------
function Timers:RemoveTimer(name)
  Timers.timers[name] = nil
end

function Timers:RemoveTimers(killAll)
  local newTimers = {}

  if not killAll then
    for k, v in pairs(Timers.timers) do
      if v.persist then
        newTimers[k] = v
      end
    end
  end

  Timers.timers = newTimers
end

---------------------------------------------------------------------
-- INIT
---------------------------------------------------------------------
if not Timers.timers then
  Timers:start()
end