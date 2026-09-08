local ceil = math.ceil
local floor = math.floor

local UV_ALL_ON = 1023
local SLOT_POWERS = { 1, 2, 4, 8, 16, 32, 64, 128, 256, 512 }

local timerWindowCache = {}

local function getTimerWindows(delay)
    local windows = timerWindowCache[delay]
    if windows ~= nil then
        return windows
    end

    local width = floor(delay / 10)
    if width < 1 then
        width = 1
    end
    windows = {}
    for slot = 1, 10 do
        local first = delay - ceil(slot * delay / 10) + 1
        windows[slot * 2 - 1] = first
        windows[slot * 2] = first + width - 1
    end
    timerWindowCache[delay] = windows
    return windows
end

local function addUvBit(uv, slot)
    local power = SLOT_POWERS[slot]
    if uv % (power * 2) < power then
        return uv + power
    end
    return uv
end

local function addTrueInterval(self, id, first, last)
    if first > last then
        return
    end

    local delay = self.timerLengths[id] - 1
    local uv = self.timerUvScratchFrames[id]
    local windows = getTimerWindows(delay)
    for slot = 1, 10 do
        local windowFirst = windows[slot * 2 - 1]
        local windowLast = windows[slot * 2]
        if first <= windowLast and windowFirst <= last then
            uv = addUvBit(uv, slot)
        end
    end
    self.timerUvScratchFrames[id] = uv
end

local function addTransition(self, id, time, epoch)
    local timerLength = self.timerLengths[id]
    if timerLength == false or timerLength == nil then
        return
    end

    local delay = timerLength - 1
    if time < 1 or time > delay then
        return
    end

    local epochs = self.timerUvScratchEpochs
    if epochs[id] ~= epoch then
        epochs[id] = epoch
        self.timerUvScratchStates[id] = self.blockStates[id]
        self.timerUvScratchStarts[id] = 1
        self.timerUvScratchFrames[id] = 0
    end

    local start = self.timerUvScratchStarts[id]
    if self.timerUvScratchStates[id] and start < time then
        addTrueInterval(self, id, start, time - 1)
    end
    self.timerUvScratchStates[id] = not self.timerUvScratchStates[id]
    self.timerUvScratchStarts[id] = time
end

function FastLogicRunner.makeTimerUvLineProjections(self, blocks)
    local projections = {}
    local downstreamLength = 0
    local timerLengths = self.timerLengths

    for i = #blocks, 1, -1 do
        local id = blocks[i]
        local timerLength = timerLengths[id]
        if timerLength ~= false and timerLength ~= nil then
            local delay = timerLength - 1
            if delay > 0 then
                projections[#projections + 1] = {
                    id,
                    downstreamLength,
                    downstreamLength + 1,
                    downstreamLength + delay
                }
            end
            downstreamLength = downstreamLength + timerLength
        else
            downstreamLength = downstreamLength + 1
        end
    end

    return projections
end

function FastLogicRunner.beginTimerUvImplicitEvents(self)
    self.timerUvImplicitRows = {}
end

function FastLogicRunner.addTimerUvImplicitEvent(self, projections, time)
    if projections == nil or #projections == 0 then
        return
    end

    local low = 1
    local high = #projections
    local candidate = 0
    while low <= high do
        local middle = floor((low + high) / 2)
        if projections[middle][3] <= time then
            candidate = middle
            low = middle + 1
        else
            high = middle - 1
        end
    end

    if candidate == 0 then
        return
    end

    local projection = projections[candidate]
    if time > projection[4] then
        return
    end

    local timerTime = time - projection[2]
    local row = self.timerUvImplicitRows[timerTime]
    if row == nil then
        row = {}
        self.timerUvImplicitRows[timerTime] = row
    end
    row[#row + 1] = projection[1]
end

function FastLogicRunner.computeTimerUvFrames(self)
    self.timerUvNeedsUpdate = false
    self.timerUvEpoch = self.timerUvEpoch + 1
    local epoch = self.timerUvEpoch
    local timerLengths = self.timerLengths
    local timerIds = self.timerBlockIds
    local maxDelay = 0

    for i = 1, #timerIds do
        local delay = timerLengths[timerIds[i]] - 1
        if delay > maxDelay then
            maxDelay = delay
        end
    end

    local implicitRows = self.timerUvImplicitRows
    for time = 1, maxDelay do
        local timerRow = self:getTimeDataRow(1, time)
        for i = 1, #timerRow do
            addTransition(self, timerRow[i], time, epoch)
        end

        local implicitRow = implicitRows[time]
        if implicitRow ~= nil then
            for i = 1, #implicitRow do
                addTransition(self, implicitRow[i], time, epoch)
            end
        end
    end

    local frames = self.timerUvFrames
    local epochs = self.timerUvScratchEpochs
    for i = 1, #timerIds do
        local id = timerIds[i]
        local delay = timerLengths[id] - 1
        if delay <= 0 then
            frames[id] = self.blockStates[id] and UV_ALL_ON or 0
        elseif epochs[id] == epoch then
            if self.timerUvScratchStates[id] then
                addTrueInterval(self, id, self.timerUvScratchStarts[id], delay)
            end
            frames[id] = self.timerUvScratchFrames[id]
        else
            frames[id] = self.blockStates[id] and UV_ALL_ON or 0
        end
    end

    return frames
end
