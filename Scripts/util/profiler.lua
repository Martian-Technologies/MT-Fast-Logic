sm.MTUtil = sm.MTUtil
sm.MTUtil.Profiler = sm.MTUtil.Profiler or {}


-- time
local Timers = sm.MTUtil.Profiler.Count.Timers or {}
sm.MTUtil.Profiler.Time = {
    Timers = Timers,
    -- starts timer for Timer named name
    on = function(name)
        if name == nil then
            return
        end
        if Timers[name] == nil then
            Timers[name] = {
                time = 0,
                startTime = os.clock()
            }
        elseif Timers[name].startTime == nil then
            Timers[name].startTime = os.clock()
        end
    end,

    -- ends timer for Timer named name
    off = function(name)
        if name == nil or Timers[name] == nil or Timers[name].startTime == nil then
            return
        end
        Timers[name].time = Timers[name].time + os.clock() - Timers[name].startTime
        Timers[name].startTime = nil
    end,

    -- gets the amount of time that the Timer was on (not real time unless used over long intervals)
    get = function(name)
        if name == nil or Timers[name] == nil then
            return 0
        end
        if Timers[name].startTime ~= nil then
            return Timers[name].time + os.clock() - Timers[name].startTime
        end
        return Timers[name].time
    end,

    -- gets the precent of a timer compaired another timer (defaluts to "main")
    getPrecent = function(name, otherName)
        if otherName == nil then
            otherName = "main"
        end
        if (
            name == nil or
            Timers[name] == nil or
            Timers[otherName] == nil
        ) then
            return 0
        end
        local t2 = sm.MTUtil.Profiler.Time.get(otherName)
        if t1 == 0 then return nil end
        local t1 = sm.MTUtil.Profiler.Time.get(name)
        return t1 / t2 * 100
    end,

    -- if a name is given it resets the timer. else it resets all timers
    reset = function(name)
        if name == nil then
            for k,v in pairs(Timers) do
                if v ~= nil then
                    v.time = 0
                    if v.startTime ~= nil then
                        v.startTime = os.clock()
                    end
                end
            end
        elseif Timers[name] ~= nil then
            Timers[name].time = 0
        end
    end
}

sm.MTUtil.Profiler.Time.reset() -- just for testing so that I can reset the timers
sm.MTUtil.Profiler.Time.on("main")

-- counter
print(Counters)
local Counters = sm.MTUtil.Profiler.Count.Counters or {}
sm.MTUtil.Profiler.Count = {
    Counters = Counters,

    -- increment counter for Counter named name
    increment = function(name)
        if name == nil then
            return
        end
        if Counters[name] == nil then
            Counters[name] = 0
        end
        Counters[name] = Counters[name] + 1
    end,

    -- get counter count for Counter named name
    get = function(name)
        if name == nil or Counters[name] == nil then
            return 0
        end
        return Counters[name]
    end,

    -- if a name is given it resets that counter. else it resets all counters
    reset = function(name)
        if name == nil then
            for k,v in pairs(Counters) do
                Counters[k] = 0
            end
        elseif Counters[name] ~= nil then
            Counters[name] = 0
        end
    end
}

sm.MTUtil.Profiler.Count.reset() -- just for testing so that I can reset the counters

