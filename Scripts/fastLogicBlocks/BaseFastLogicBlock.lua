dofile "../util/util.lua"
dofile "../util/compressionUtil/compressionUtil.lua"
-- dofile "../allCreationStuff/CreationUtil.lua"
local string = string
local table = table

BaseFastLogicBlock = {}
BaseFastLogicBlock.maxParentCount = -1 -- infinite
BaseFastLogicBlock.maxChildCount = -1  -- infinite
BaseFastLogicBlock.connectionInput = sm.interactable.connectionType.logic
BaseFastLogicBlock.connectionOutput = sm.interactable.connectionType.logic
BaseFastLogicBlock.colorNormal = sm.color.new(0x5612CCff)
BaseFastLogicBlock.colorHighlight = sm.color.new(0xA530C2ff)

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.FastLogicBlockLookUp = sm.MTFastLogic.FastLogicBlockLookUp or {}
sm.MTFastLogic.client_FastLogicBlockLookUp = sm.MTFastLogic.client_FastLogicBlockLookUp or {}
sm.MTFastLogic.Creations = sm.MTFastLogic.Creations or {}
sm.MTFastLogic.dataToSet = sm.MTFastLogic.dataToSet or {}

function BaseFastLogicBlock.deepRescanSelf(self, noRemove)
    if self.creation ~= nil then
        self.lastSeenSpeed = self.creation.FastLogicRunner.numberOfUpdatesPerTick
        if noRemove ~= true then
            self.lastSeenSpeed = self.creation.FastLogicRunner.numberOfUpdatesPerTick
            self.creation.FastLogicAllBlockManager:removeBlock(self.data.uuid)
            self.creation.AllFastBlocks[self.data.uuid] = nil
        end
    end
    self.FastLogicRunner = nil
    self.creation = nil
    self.creationId = nil
    self:getData()
end

function BaseFastLogicBlock.getParentUuids(self)
    local uuids = {}
    for _, v in ipairs(self.interactable:getParents()) do
        local otherUuid = self.creation.uuids[v:getId()]
        if otherUuid ~= nil then
            uuids[#uuids + 1] = otherUuid
        end
    end
    return uuids
end

function BaseFastLogicBlock.getChildUuids(self)
    local uuids = {}
    for _, v in ipairs(self.interactable:getChildren()) do
        local otherUuid = self.creation.uuids[v:getId()]
        if otherUuid ~= nil then
            uuids[#uuids + 1] = otherUuid
        end
    end
    return uuids
end

function BaseFastLogicBlock.getCreationData(self)
    self.creationId = sm.MTFastLogic.CreationUtil.getCreationId(self.shape:getBody())
    if (sm.MTFastLogic.Creations[self.creationId] == nil) then
        sm.MTFastLogic.CreationUtil.MakeCreationData(self.creationId, self.shape:getBody(), self.lastSeenSpeed)
    end
    self.creation = sm.MTFastLogic.Creations[self.creationId]
    self.FastLogicRunner = self.creation.FastLogicRunner
    self.FastLogicAllBlockManager = self.creation.FastLogicAllBlockManager
end

function BaseFastLogicBlock.getData(self)
    self.state = self.state or nil
    self.removeAllData = self.removeAllData or true
    self:getCreationData()
    if self.creation.AllFastBlocks[self.data.uuid] == nil then
        self.lastSeenSpeed = self.creation.FastLogicRunner.numberOfUpdatesPerTick
        self.creation.lastBodyUpdate = 0
        self.creation.AllFastBlocks[self.data.uuid] = self
        self.creation.BlocksToScan[#self.creation.BlocksToScan + 1] = self
        self.creation.uuids[self.id] = self.data.uuid
        self.creation.ids[self.data.uuid] = self.id
    end
    sm.MTFastLogic.FastLogicBlockLookUp[self.data.uuid] = self
    self:getData2()
end

function BaseFastLogicBlock.getData2(self)
    -- your code
end

function BaseFastLogicBlock.server_onCreate(self)
    local success, result = pcall(self.pcalled_server_onCreate, self)
    if not success then
        self:sendMessageToAll("AN ERROR OCCURRED IN FAST LOGIC (id: 5). Please report to ItchyTrack on discord")
        self:sendMessageToAll(result)
    end
end

function BaseFastLogicBlock.pcalled_server_onCreate(self)
    self:getCreationData()
    self.data = self.data or {}
    self.isFastLogic = true
    self.type = nil
    self.id = self.interactable:getId()
    if sm.MTFastLogic.dataToSet[self.id] ~= nil then
        self.creation.FastLogicRealBlockManager:setData(self, sm.MTFastLogic.dataToSet[self.id])
        sm.MTFastLogic.dataToSet[self.id] = nil
    else
        if self.storage:load() ~= nil then
            self.data = self.storage:load()
            if self.data.uuid == nil then
                self.data.uuid = sm.MTFastLogic.CreationUtil.newUuid()
            else
                self.data.uuid = sm.MTFastLogic.CreationUtil.updateOldUuid(self.data.uuid, self.creationId)
            end
        else
            self.data.uuid = sm.MTFastLogic.CreationUtil.newUuid()
        end
    end
    sm.MTFastLogic.FastLogicBlockLookUp[self.data.uuid] = self
    self.storage:save(self.data)
    self:server_onCreate2()
    self:getData()
end

function BaseFastLogicBlock.server_onCreate2(self)
    -- your code
end

function BaseFastLogicBlock.server_onDestroy(self)
    local success, result = pcall(self.pcalled_server_onDestroy, self)
    if not success then
        sm.event.sendToTool(
            sm.MTFastLogic.FastLogicRunnerRunner.tool,
            "sendMessageToAll",
            "AN ERROR OCCURRED IN FAST LOGIC (id: 6). Please report to ItchyTrack on discord"
        )
        sm.event.sendToTool(
            sm.MTFastLogic.FastLogicRunnerRunner.tool,
            "sendMessageToAll",
            result
        )
    end
end

function BaseFastLogicBlock.pcalled_server_onDestroy(self)
    sm.MTFastLogic.FastLogicBlockLookUp[self.data.uuid] = nil
    if self.creation ~= nil and sm.MTFastLogic.Creations[self.creationId] ~= nil then
        if self.creation.FastLogicRealBlockManager:checkForCreationDeletion() == false then
            self.creation.AllFastBlocks[self.data.uuid] = nil
            self.creation.uuids[self.id] = nil
            self.creation.ids[self.data.uuid] = nil

            self.creation.AllFastBlocks[self.data.uuid] = nil
            if self.removeAllData then
                self.FastLogicAllBlockManager:removeBlock(self.data.uuid) -- remove
            end
        end
    end
    self:server_onDestroy2()
end

function BaseFastLogicBlock.server_onDestroy2(self)
    -- your code
end

function BaseFastLogicBlock.server_onrefresh(self)
    self:server_onCreate()
end

function BaseFastLogicBlock.client_onCreate(self)
    sm.MTFastLogic.client_FastLogicBlockLookUp[self.interactable:getId()] = self
    self:client_onCreate2()
end

function BaseFastLogicBlock.client_onCreate2(self)
    -- your code
end

function BaseFastLogicBlock.client_onDestroy(self)
    sm.MTFastLogic.client_FastLogicBlockLookUp[self.interactable:getId()] = nil
    self:client_onDestroy2()
end

function BaseFastLogicBlock.client_onDestroy2(self)
    -- your code
end

function BaseFastLogicBlock.client_onrefresh(self)
    self:client_onCreate()
end

function BaseFastLogicBlock.client_onTinker(self, character, state)
    if state then
        self.network:sendToServer("server_changeSpeed", character:isCrouching())
    end
end

function BaseFastLogicBlock.server_onProjectile(self, position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid)
    local runnrerId = self.FastLogicRunner.hashedLookUp[self.data.uuid]
    -- local totalTime = sm.MTUtil.Profiler.Time.get("doUpdate")
    -- local totalCalls = sm.MTUtil.Profiler.Count.get("doUpdate")
    -- local average = totalTime / totalCalls
    -- local maxErrorPerCall = 0.0005
    -- local standardDeviation = maxErrorPerCall / math.sqrt(3 * totalCalls)
    -- print("Profiler (onUpdate):",
    --     sm.MTUtil.Profiler.Time.get("doUpdate") / sm.MTUtil.Profiler.Count.get("doUpdate") * 1000000, "±",
    --     standardDeviation * 1000000, "µs")
    -- local fullLoopTime = sm.MTUtil.Profiler.Time.get("doUpdateFullLoop")
    -- local fullLoopAverage = fullLoopTime / totalCalls
    -- local standardDeviationFullLoop = maxErrorPerCall / math.sqrt(3 * totalCalls)
    -- print("Profiler (fullLoop):",
    --     fullLoopAverage * 1000000, "±",
    --     standardDeviationFullLoop * 1000000, "µs")
    -- print("Profiler (onUpdate % of fullLoop):", sm.MTUtil.Profiler.Time.getPrecent("doUpdate", "doUpdateFullLoop"))
    -- sm.MTUtil.Profiler.Time.reset()
    -- sm.MTUtil.Profiler.Count.reset()
    -- real data
    -- print(runnrerId)
    -- print(self.FastLogicRunner.blockStates[runnrerId])
    -- print(self.FastLogicRunner.countOfOnInputs[runnrerId] + self.FastLogicRunner.countOfOnOtherInputs[runnrerId])
    -- print(self.FastLogicRunner.pathNames[self.FastLogicRunner.altBlockData[runnrerId]])
    -- print(self.FastLogicRunner.pathNames[self.FastLogicRunner.runnableBlockPathIds[runnrerId]])
    -- print(self.FastLogicRunner.numberOfBlockInputs[runnrerId])
    -- print(self.FastLogicRunner.numberOfBlockOutputs[runnrerId])
    -- print(self.FastLogicRunner.numberOfOtherInputs[runnrerId])
    -- print(self.FastLogicRunner.blockInputs[runnrerId])
    -- print(self.FastLogicRunner.blockOutputs[runnrerId])
    -- print(self.data.uuid)
    -- print(self.interactable.id)
    -- print(self.creation.blocks[self.data.uuid].inputsHash)
    -- self.FastLogicRunner.fixBlockInputData = FastLogicRunner.fixBlockInputData
    -- self.FastLogicRunner.internalChangeBlockType = FastLogicRunner.internalChangeBlockType
    -- print(self.creation.AllNonFastBlocks)
    ----------------------------------------------
    print("------")
    print("id: " .. tostring(runnrerId))
    local layers, LayerHash, outputBlocks, outputHash, farthestOutput, deletionBlame = sm.MTFastLogic.BalencedLogicFinder.findBalencedLogic(self.FastLogicRunner, runnrerId)
    local dontReset = {}
    for i = 1, #layers do
        for ii = 1, #layers[i] do
            local id = self.creation.ids[self.FastLogicRunner.unhashedLookUp[layers[i][ii]]]
            if id ~= nil then
                self.creation.FastLogicRealBlockManager:changeConnectionColor(id, i%36+4)
                dontReset[id] = true
            end
        end
    end
    for uuid, id in pairs(self.creation.ids) do
        if id ~= nil and dontReset[id] == nil then
            if deletionBlame[runnrerId] == nil then
                self.creation.FastLogicRealBlockManager:changeConnectionColor(id, 0)
            elseif deletionBlame[runnrerId] == "removeBlockAndInputsRec" then
                self.creation.FastLogicRealBlockManager:changeConnectionColor(id, 1)
            elseif deletionBlame[runnrerId] == "removeBlockAndOutputsRec" then
                self.creation.FastLogicRealBlockManager:changeConnectionColor(id, 2)
            elseif deletionBlame[runnrerId] == "removeBlockAndOutputsRec2" then
                self.creation.FastLogicRealBlockManager:changeConnectionColor(id, 3)
            end
        end
    end
end

function BaseFastLogicBlock.server_changeBlockState(self)
    self.FastLogicRunner:externalSetBlockState(self.data.uuid, not self.state)
end

function BaseFastLogicBlock.server_changeSpeed(self, isCrouching)
    if self.creation.FastLogicRunner.numberOfUpdatesPerTick <= 0 then
        self.creation.FastLogicRunner.numberOfUpdatesPerTick = 1
    else
        if isCrouching then
            self.creation.FastLogicRunner.numberOfUpdatesPerTick = self.creation.FastLogicRunner.numberOfUpdatesPerTick / 2
        else
            self.creation.FastLogicRunner.numberOfUpdatesPerTick = self.creation.FastLogicRunner.numberOfUpdatesPerTick * 2
        end
    end
    self:sendMessageToAll("UpdatesPerTick = " .. tostring(self.creation.FastLogicRunner.numberOfUpdatesPerTick))
end

function BaseFastLogicBlock.client_updateTexture(self, state)
end

function BaseFastLogicBlock.sendMessageToAll(self, message)
    self.network:sendToClients("client_sendMessage", message)
end

function BaseFastLogicBlock.client_sendMessage(self, message)
    sm.gui.chatMessage(message)
end

function BaseFastLogicBlock.getLocalCenter(self)
    return self.shape:getLocalPosition() + (self.shape.xAxis + self.shape.yAxis + self.shape.zAxis) * 0.5
end

function BaseFastLogicBlock.remove(self, removeAllData)
    if removeAllData == false then
        self.removeAllData = false
    end
    self.shape:destroyShape()
end

function BaseFastLogicBlock.removeUuidData(self)
    for i = 1, #self.creation.blocks[self.data.uuid].inputs do
        local otherUuid = self.creation.blocks[self.data.uuid].inputs[i]
        if self.creation.blocks[otherUuid] ~= nil then
            if self.creation.blocks[otherUuid].isSilicon then
                return
            end
        end
    end
    for i = 1, #self.creation.blocks[self.data.uuid].outputs do
        local otherUuid = self.creation.blocks[self.data.uuid].outputs[i]
        if self.creation.blocks[otherUuid] ~= nil then
            if self.creation.blocks[otherUuid].isSilicon then
                return
            end
        end
    end
    local uuid = self.data.uuid
    self.data.uuid = nil
    self.storage:save(self.data)
    self.data.uuid = uuid
end
