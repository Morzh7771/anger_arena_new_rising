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
local function timer_err(err)
  err = tostring(err)
  return debug.traceback(err, 2)
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
function Timers:Think()
  if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
    return
  end

  local profileStart = GetSystemTimeMS()
  local profileFunctions = {}

  for k, v in pairs(Timers.timers) do
    local useGameTime = (v.useGameTime ~= false)
    local oldStyle = (v.useOldStyle == true)

    local now = useGameTime and GameRules:GetGameTime() or Time()

    if v.endTime == nil then
      v.endTime = now
    end

    if now >= v.endTime then
      Timers.timers[k] = nil

      local funcTime = GetSystemTimeMS()

      local status, nextCall = xpcall(function()
        if v.context then
          return v.callback(v.context, v)
        end
        return v.callback(v)
      end, timer_err)

      table.insert(profileFunctions, {v.callback, GetSystemTimeMS() - funcTime})

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

  if profileTime > Timers._timeLimit and #profileFunctions > 0 then
    print("[Warning.Timers] slow frame:", profileTime, "ms")

    for _, data in pairs(profileFunctions) do
      local funcObj = data[1]
      local funcTime = data[2]

      if funcObj then
        local info = debug.getinfo(funcObj)
        print("[Warning.Timers] Function",
          info.short_src, ":", info.linedefined,
          "took", funcTime, "ms")
      end
    end
  end

  return TIMERS_THINK
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