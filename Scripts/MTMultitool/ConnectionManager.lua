ConnectionManager = {}

function ConnectionManager.inject(multitool)
    multitool.ConnectionManager = {}
    local self = multitool.ConnectionManager
    self.taskQueue = {}
    self.taskQueueIndex = 0
    self.taskQueueSize = 0
    self.preview = {}
    self.travellingDots = {}
    self.lastSpawn = 0
    self.mode = "connect"
    self.displayMode = "fast"
end

function ConnectionManager.toggleMode(multitool)
    local self = multitool.ConnectionManager
    if self.mode == "connect" then
        self.mode = "disconnect"
    else
        self.mode = "connect"
    end
    print("Mode: " .. self.mode)
end

function ConnectionManager.client_onUpdate(multitool)
    local self = multitool.ConnectionManager
    local spawnParticles = false
    if self.displayMode == "fast" then
        if os.clock() - self.lastSpawn > 0.05 then
            spawnParticles = true
        end
    elseif self.displayMode == "slow" then
        if #self.travellingDots == 0 then
            spawnParticles = true
        end
    else -- if the display mode is something else, spawn particles every frame
        spawnParticles = true
    end
    if spawnParticles then
        if spawnParticles and #self.preview > 0 then
            -- print('spawnParticles')
            self.lastSpawn = os.clock()
            for i = 1, #self.preview do
                local task = self.preview[i]
                if task.visible == false then
                    goto continue
                end

                local color = sm.color.new(1, 1, 1, 1)
                if self.mode == "disconnect" then
                    color = sm.color.new(1, 0, 0, 1)
                end
                local distance = (task.to:getWorldPosition() - task.from:getWorldPosition()):length()
                local intermediate = nil
                if task.polarity ~= true then
                    intermediate = task.from:getWorldPosition() + (task.to:getWorldPosition() - task.from:getWorldPosition()) * 0.5 + sm.vec3.new(0, 0, 1+distance*0.1)
                else
                    intermediate = task.from:getWorldPosition() + (task.to:getWorldPosition() - task.from:getWorldPosition()) * 0.5 - sm.vec3.new(0, 0, 1+distance*0.1)
                end
                table.insert(self.travellingDots, {
                    start = task.from:getWorldPosition(),
                    final = task.to:getWorldPosition(),
                    intermediate = intermediate,
                    startTime = os.clock(),
                    duration = 1,--math.max(0.5, 0.5*distance),
                    color = color
                })
                ::continue::
            end
        end
    end
    -- remove dots that have reached their final position
    for i, dot in pairs(self.travellingDots) do
        if os.clock() - dot.startTime > dot.duration then
            table.remove(self.travellingDots, i)
            -- self.travellingDots[i].startTime = os.clock()+i/20000
        end
    end
    -- complete 1 task in the queue per frame
    for i = 1, 100 do
        if self.taskQueueIndex < self.taskQueueSize then
            self.taskQueueIndex = self.taskQueueIndex + 1
            local task = self.taskQueue[self.taskQueueIndex]
            -- send packet to server
            local packet = {
                task.from,
                task.to
            }
            local color = sm.color.new(1, 1, 1, 1)
            if task.action == "connect" then
                multitool.network:sendToServer("server_makeConnections", packet)
            elseif task.action == "disconnect" then
                multitool.network:sendToServer("server_breakConnections", packet)
                color = sm.color.new(1, 0, 0, 1)
            end
            local distance = (task.to:getWorldPosition() - task.from:getWorldPosition()):length()
            local intermediate = task.from:getWorldPosition() + (task.to:getWorldPosition() - task.from:getWorldPosition()) * 0.5
            table.insert(self.travellingDots, {
                start = task.from:getWorldPosition(),
                final = task.to:getWorldPosition(),
                intermediate = intermediate,
                startTime = os.clock(),
                duration = math.max(0.1, 0.2*math.sqrt(distance)),
                color = color
            })
        end
        -- if there are no tasks left, reset the queue
        if self.taskQueueIndex == self.taskQueueSize then
            self.taskQueueIndex = 0
            self.taskQueueSize = 0
        end
    end
end

function ConnectionManager.createVertexSubsription(multitool)
    local self = multitool.ConnectionManager
    local function getVertices()
        local vertices = {}
        for i, dot in pairs(self.travellingDots) do
            -- bezier the dot position from the dot's start and end positions based on os clock
            local t = (os.clock() - dot.startTime) / dot.duration
            if t > 1 then
                t = 1
            end
            local dotPosition = dot.start * (1 - t) ^ 2 + dot.intermediate * 2 * (1 - t) * t + dot.final * t ^ 2
            table.insert(vertices, {
                pos = dotPosition,
                color = dot.color,
                txt = "•"
            })
        end
        return vertices
    end
    return getVertices
end

function ConnectionManager.commitPreview(multitool)
    local self = multitool.ConnectionManager
    for _, task in pairs(self.preview) do
        self.taskQueueSize = self.taskQueueSize + 1
        task.action = self.mode
        self.taskQueue[self.taskQueueSize] = task
    end
    self.preview = {}
end

function ConnectionManager.server_makeConnections(multitool, data)
    local from = data[1]
    local to = data[2]
    local fromInt = from:getInteractable()
    local toInt = to:getInteractable()
    if fromInt == nil or toInt == nil then
        return
    end
    fromInt:connect(toInt)
end

function ConnectionManager.server_breakConnections(multitool, data)
    local from = data[1]
    local to = data[2]
    local fromInt = from:getInteractable()
    local toInt = to:getInteractable()
    if fromInt == nil or toInt == nil then
        return
    end
    fromInt:disconnect(toInt)
end