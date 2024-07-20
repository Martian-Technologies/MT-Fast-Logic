Heatmap = {}

function Heatmap.inject(multitool)
    multitool.Heatmap = {}
    local self = multitool.Heatmap
    self.creationTracking = nil
    self.updateNametags = NametagManager.createController(multitool)
    self.blockUsageTracker = {}
    self.blockUsageSum = {}
    self.sumMaximum = 0
end

function Heatmap.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.Heatmap
    multitool.BlockSelector.enabled = false
    multitool.VolumeSelector.enabled = false
    if self.creationTracking ~= nil then
        sm.gui.setInteractionText("Heatmap is tracking a creation.     ", sm.gui.getKeyBinding("Attack", true),
            "Stop tracking")
        if secondaryState == 1 then
            self.creationTracking = nil
            self.updateNametags(nil)
        end
    else
        local origin = sm.camera.getPosition()
        local direction = sm.camera.getDirection()
        local hit, res = sm.physics.raycast(sm.camera.getPosition(),
            sm.camera.getPosition() + sm.camera.getDirection() * 128, sm.localPlayer.getPlayer().character)
        -- print(res.type)
        local body = nil
        if hit and res.type == "body" then
            body = res:getBody()
        end
        if hit and res.type == "joint" then
            body = res:getJoint().shapeA.body
        end
        if body == nil then
            sm.gui.setInteractionText("Aim at a creation", "", "")
            return
        end
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Track creation")
        if primaryState == 1 then
            self.creationTracking = body:getCreationBodies()
            self.blockUsageTracker = {}
            self.blockUsageSum = {}
        end

        sm.visualization.setCreationBodies(body:getCreationBodies())
        sm.visualization.setCreationFreePlacement(false)
        sm.visualization.setCreationValid(true, true)
        sm.visualization.setLiftValid(true)
        sm.visualization.setCreationVisible(true)
    end
end

function Heatmap.server_onFixedUpdate(multitool, dt)
    local self = multitool.Heatmap
    if self.creationTracking == nil then
        return
    end
    local success = false
    for i, body in pairs(self.creationTracking) do
        if sm.exists(body) then
            success = true
            self.creationTracking = body:getCreationBodies()
            break
        end
    end
    if not success then
        self.creationTracking = nil
        return
    end
    local creationId = sm.MTFastLogic.CreationUtil.getCreationId(self.creationTracking[1])
    local creation = sm.MTFastLogic.Creations[creationId]
    if creation == nil then
        return
    end
    local FLR = creation.FastLogicRunner
    local numberOfTimesRun = FLR.numberOfTimesRun
    -- numberOfTimesRun[runnerId] = 0
    local usageTable = {}
    for rID, usage in ipairs(numberOfTimesRun) do
        if FLR.numberOfBlockOutputs[rID] ~= false then
            local trueLoad = usage / FLR.numberOfUpdatesPerTick * FLR.numberOfBlockOutputs[rID]
            usageTable[rID] = trueLoad
            self.blockUsageSum[rID] = (self.blockUsageSum[rID] or 0) + trueLoad
            numberOfTimesRun[rID] = 0
        end
    end
    table.insert(self.blockUsageTracker, usageTable)
    if #self.blockUsageTracker > 40 then
        for i = 1, #self.blockUsageTracker[1] do
            self.blockUsageSum[i] = (self.blockUsageSum[i] or 0) - (self.blockUsageTracker[1][i] or 0)
        end
        table.remove(self.blockUsageTracker, 1)
    end
    self.sumMaximum = 0
    for i = 1, #self.blockUsageSum do
        self.sumMaximum = math.max(self.sumMaximum, self.blockUsageSum[i])
    end
    -- local sumTable = {}
    -- for rID, usage in ipairs(numberOfTimesRun) do
    --     local sum = 0
    --     for i, usageTable in ipairs(self.blockUsageTracker) do
    --         sum = sum + (usageTable[rID] or 0)
    --     end
    --     sumTable[rID] = sum
    -- end
    -- self.blockUsageSum = sumTable
end

local function HSVtoRGB(h, s, v)
    local r, g, b

    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)

    i = i % 6

    if i == 0 then
        r, g, b = v, t, p
    elseif i == 1 then
        r, g, b = q, v, p
    elseif i == 2 then
        r, g, b = p, v, t
    elseif i == 3 then
        r, g, b = p, q, v
    elseif i == 4 then
        r, g, b = t, p, v
    elseif i == 5 then
        r, g, b = v, p, q
    end

    return sm.color.new(r, g, b, 1)
end

function Heatmap.client_onUpdate(multitool, dt)
    local self = multitool.Heatmap
    if self.creationTracking == nil then
        return
    end
    local success = false
    for i, body in pairs(self.creationTracking) do
        if sm.exists(body) then
            success = true
            self.creationTracking = body:getCreationBodies()
            break
        end
    end
    if not success then
        self.creationTracking = nil
        self.updateNametags(nil)
        return
    end
    local creationId = sm.MTFastLogic.CreationUtil.getCreationId(self.creationTracking[1])
    local creation = sm.MTFastLogic.Creations[creationId]
    if creation == nil then
        return
    end
    local FLR = creation.FastLogicRunner
    local blocks = creation.blocks
    local fastLogicGates = creation.FastLogicGates
    local siliconBlocks = creation.SiliconBlocks
    local tags = {}

    local camPos = sm.camera.getPosition()
    -- dots decreasing in size
    local scaleConstant = 41 * 0.95 * 5
    local dots = {"●", "•", "·"}
    local offsets = { 0.02, 0.02, 0.02 }
    local distanceMargin = { scaleConstant/41, scaleConstant/23, scaleConstant/11 }

    for i, block in pairs(blocks) do
        local body
        if block.isSilicon then
            local siliconId = block.siliconBlockId
            local silicon = siliconBlocks[siliconId]
            if silicon == nil then
                advPrint("Silicon block not found", 5, 100, true)
                goto continue
            end
            body = silicon.shape:getBody()
        else
            local gate = fastLogicGates[i]
            if gate == nil then
                -- advPrint("Gate not found", 5, 100, true)
                goto continue
            end
            body = gate.shape:getBody()
        end
        local position = body:transformPoint(block.pos / 4)
        local runnerId = FLR.hashedLookUp[i]
        local computationalLoad = (self.blockUsageSum[runnerId] or 0)
        -- if #self.blockUsageTracker ~= 0 then
        --     computationalLoad = computationalLoad / #self.blockUsageTracker
        -- end
        if self.sumMaximum ~= 0 then
            computationalLoad = math.sqrt(computationalLoad / self.sumMaximum)
        end
        -- table.insert(tags, {
        --     txt = tostring(timesRun),
        --     pos = position,
        --     color = sm.color.new(1, 0, 0, 1),
        -- })
        if computationalLoad < 0.01 then
            goto continue
        end
        -- local text = "·"
        -- if computationalLoad > 0.3 then
        --     text = "•"
        -- end
        -- if computationalLoad > 0.7 then
        --     text = "●"
        -- end
        local distance = (camPos - position):length() / (computationalLoad + 0.1)
        local dotIndex = 1
        for j = 1, #distanceMargin do
            if (distance > distanceMargin[j]) then
                dotIndex = j
            end
        end
        local clr = HSVtoRGB((1-computationalLoad)/3, 1, 1)
        table.insert(tags, {
            txt = dots[dotIndex],
            pos = position,-- + sm.vec3.new(0, 0, computationalLoad/8),
            color = clr,
        })
        ::continue::
    end
    self.updateNametags(tags)
    -- advPrint(FLR, 3, 100, true)
end

function Heatmap.cleanUp(multitool)
    local self = multitool.Heatmap
    self.updateNametags(nil)
end