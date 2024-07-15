Heatmap = {}

function Heatmap.inject(multitool)
    multitool.Heatmap = {}
    local self = multitool.Heatmap
    self.creationTracking = nil
    self.updateNametags = NametagManager.createController(multitool)
    self.blockUsageTracker = {}
    self.blockUsageAverage = {}
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
        self.updateNametags(nil)
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
        local trueLoad = usage / FLR.numberOfUpdatesPerTick * FLR.numberOfBlockOutputs[rID]
        usageTable[rID] = trueLoad
        numberOfTimesRun[rID] = 0
    end
    table.insert(self.blockUsageTracker, usageTable)
    if #self.blockUsageTracker > 40 then
        table.remove(self.blockUsageTracker, 1)
    end
    local average = {}
    local maximum = 0
    for rID, usage in ipairs(numberOfTimesRun) do
        local sum = 0
        for i, usageTable in ipairs(self.blockUsageTracker) do
            sum = sum + (usageTable[rID] or 0)
        end
        average[rID] = sum / #self.blockUsageTracker
        maximum = math.max(maximum, average[rID])
    end
    if maximum ~= 0 then
        for rID, usage in ipairs(numberOfTimesRun) do
            average[rID] = math.sqrt(average[rID] / maximum)
        end
    end
    self.blockUsageAverage = average
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
        local computationalLoad = self.blockUsageAverage[runnerId]
        -- table.insert(tags, {
        --     txt = tostring(timesRun),
        --     pos = position,
        --     color = sm.color.new(1, 0, 0, 1),
        -- })
        if computationalLoad < 0.05 then
            goto continue
        end
        table.insert(tags, {
            txt = "•",
            pos = position + sm.vec3.new(0, 0, computationalLoad),
            color = sm.color.new(computationalLoad, 1-computationalLoad, 0, 1),
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