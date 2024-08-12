dofile "../util/util.lua"
local string = string
local table = table

FastLogicAllBlockManager = FastLogicAllBlockManager or {}

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.UsedUuids = sm.MTFastLogic.UsedUuids or {}

FastLogicAllBlockManager.blockUuidToConnectionColorID = {
    ["6a9dbff5-7562-4e9a-99ae-3590ece88087"] = 0,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88088"] = 1,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88089"] = 2,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88090"] = 3,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88091"] = 4,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88092"] = 5,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88093"] = 6,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88094"] = 7,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88095"] = 8,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88096"] = 9,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88097"] = 10,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88098"] = 11,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88099"] = 12,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88100"] = 13,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88101"] = 14,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88102"] = 15,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88103"] = 16,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88104"] = 17,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88105"] = 18,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88106"] = 19,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88107"] = 20,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88108"] = 21,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88109"] = 22,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88110"] = 23,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88111"] = 24,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88112"] = 25,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88113"] = 26,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88114"] = 27,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88115"] = 28,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88116"] = 29,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88117"] = 30,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88118"] = 31,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88119"] = 32,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88120"] = 33,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88121"] = 34,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88122"] = 35,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88123"] = 36,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88124"] = 37,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88125"] = 38,
    ["6a9dbff5-7562-4e9a-99ae-3590ece88126"] = 39,
}

FastLogicAllBlockManager.fastLogicGateBlockUuids = {} -- only the keys from the above table
for k, _ in pairs(FastLogicAllBlockManager.blockUuidToConnectionColorID) do
    table.insert(FastLogicAllBlockManager.fastLogicGateBlockUuids, k)
end

function FastLogicAllBlockManager.getNew(creationId)
    local new = table.deepCopy(FastLogicAllBlockManager)
    new.getNew = nil
    new.creationId = creationId
    return new
end

function FastLogicAllBlockManager.init(self)
    self.creation = sm.MTFastLogic.Creations[self.creationId]
    self.FastLogicRunner = self.creation.FastLogicRunner
    self.dataToSetToDo = {}
    self.dataToSetDelay1 = {}
    self.dataToSetDelay2 = {}
    self.dataToSetDelay3 = {}
    self.blocks = self.creation.blocks
    self.locationCash = {}
end

function FastLogicAllBlockManager.update(self)
    local dataToSetLength = #self.dataToSetToDo
    if dataToSetLength > 0 then
        for i = 1, dataToSetLength do
            local uuid = self.dataToSetToDo[i][1]
            local inputs = self.dataToSetToDo[i][2]
            if inputs ~= nil then
                for j = 1, #inputs do
                    if inputs[j] ~= nil then
                        self:addOutput(inputs[j], uuid, true, true)
                    end
                end
            end
            local outputs = self.dataToSetToDo[i][3]
            if outputs ~= nil then
                for j = 1, #outputs do
                    if outputs[j] ~= nil then
                        self:addOutput(uuid, outputs[j], true, true)
                    end
                end
            end
        end
        for i = 1, dataToSetLength do
            local uuid = self.dataToSetToDo[i][1]
            self.FastLogicRunner:externalShouldBeThroughBlock(uuid)
            self.FastLogicRunner:externalFindRamInterfaces(uuid)
            self.FastLogicRunner:externalAddBlockToUpdate(uuid)
        end
    end
    self.dataToSetToDo = self.dataToSetDelay1
    self.dataToSetDelay1 = self.dataToSetDelay2
    self.dataToSetDelay2 = self.dataToSetDelay3
    self.dataToSetDelay3 = {}
    -- create interfaces
    self.FastLogicRunner:makeAllRamInterfaces()
    -- run fast gates
    self.FastLogicRunner:update()
    -- do state updates
    local realBlocksToUpdate = {}
    local updatedIds = self.FastLogicRunner:getUpdatedIds()
    local unhashedLookUp = self.FastLogicRunner.unhashedLookUp
    local blockStates = self.FastLogicRunner.blockStates
    for i = 1, #updatedIds do
        local block = self.blocks[unhashedLookUp[updatedIds[i]]]
        if block ~= nil then
            block.state = blockStates[updatedIds[i]]
            if not block.isSilicon then
                realBlocksToUpdate[#realBlocksToUpdate + 1] = unhashedLookUp[updatedIds[i]]
            end
        end
    end
    if table.length(self.blocks) == 0 and table.length(self.creation.SiliconBlocks) == 0 then
        sm.MTFastLogic.Creations[self.creationId] = nil
    end
    return realBlocksToUpdate
end

function FastLogicAllBlockManager.addBlock(self, block)
    if self.blocks[block.data.uuid] ~= nil then
        return
    end
    local pos = block:getLocalCenter()
    local rot = { block.shape.xAxis, block.shape.yAxis, block.shape.zAxis }
    if block.type == "LogicGate" then
        local connectionColorId = FastLogicAllBlockManager.blockUuidToConnectionColorID[tostring(block.shape:getShapeUuid())]
        if (block.data.mode == 0) then
            self:makeBlockData("andBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color, connectionColorId, false, false)
        elseif (block.data.mode == 1) then
            self:makeBlockData("orBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color, connectionColorId, false, false)
        elseif (block.data.mode == 2) then
            self:makeBlockData("xorBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color, connectionColorId, false, false)
        elseif (block.data.mode == 3) then
            self:makeBlockData("nandBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color, connectionColorId, false, false)
        elseif (block.data.mode == 4) then
            self:makeBlockData("norBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color, connectionColorId, false, false)
        elseif (block.data.mode == 5) then
            self:makeBlockData("xnorBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color, connectionColorId, false, false)
        end
    elseif block.type == "Timer" then
        self:makeBlockData("timerBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color, 0, false, block.time, false)
    elseif block.type == "EndTickButton" then
        self:makeBlockData("EndTickButtons", block.data.uuid, pos, rot, block:getParentUuids(), {}, block.interactable.active, block.shape.color, 0, false, false)
    elseif block.type == "Light" then
        self:makeBlockData("lightBlocks", block.data.uuid, pos, rot, block:getParentUuids(), {}, block.interactable.active, block.shape.color, 0, false, false)
    elseif block.type == "Interface" then
        if (block.data.mode == 1) then
            self:makeBlockData("Address", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color, 0, false, false)
        elseif (block.data.mode == 2) then
            self:makeBlockData("DataIn", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color, 0, false, false)
        elseif (block.data.mode == 3) then
            self:makeBlockData("DataOut", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color, 0, false, false)
        elseif (block.data.mode == 4) then
            self:makeBlockData("WriteData", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color, 0, false, false)
        end
    elseif block.type == "BlockMemory" then
        self:makeBlockData("BlockMemory", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color, 0, false, false)
    end
end

function FastLogicAllBlockManager.addSiliconBlock(self, type, uuid, pos, rot, inputs, outputs, state, color, connectionColorId, siliconBlockId)
    if self.blocks[uuid] == nil then
        self:makeBlockData(type, uuid, pos, rot, inputs, outputs, state, color, connectionColorId, true, nil, siliconBlockId)
    end
end

function FastLogicAllBlockManager.removeBlock(self, uuid, skipSiliconChanges)
    local block = self.blocks[uuid]
    if block == nil then return end
    if skipSiliconChanges ~= true then
        for i = 0, #block.outputs do
            self:removeOutput(block.outputs[i], uuid)
        end
        for i = 0, #block.inputs do
            self:removeOutput(uuid, block.inputs[i])
        end
    end
    local keyPos = string.vecToString(block.pos)
    table.removeValue(self.locationCash[keyPos], uuid)
    if #self.locationCash[keyPos] == 0 then
        self.locationCash[keyPos] = nil
    end
    self.FastLogicRunner:externalRemoveBlock(uuid)
    self.blocks[uuid] = nil
end

function FastLogicAllBlockManager.setColor(self, uuid, color)
    if self.blocks[uuid] == nil then return end
    self.blocks[uuid].color = color
end

function FastLogicAllBlockManager.addInput(self, uuid, uuidToConnect, skipSiliconChanges, skipChecksAndUpdates)
    self:addOutput(uuidToConnect, uuid, skipSiliconChanges, skipChecksAndUpdates)
end

function FastLogicAllBlockManager.removeInput(self, uuid, uuidToDisconnect)
    self:removeOutput(uuidToDisconnect, uuid)
end

function FastLogicAllBlockManager.addOutput(self, uuid, uuidToConnect, skipSiliconChanges, skipChecksAndUpdates)
    local blocks = self.blocks
    local block = blocks[uuid]
    local blockToConnect = blocks[uuidToConnect]
    if (
        block ~= nil and blockToConnect ~= nil and
        (block.outputsHash[uuidToConnect] == nil or blockToConnect.inputsHash[uuid] == nil)
    ) then
        if skipSiliconChanges ~= true then
            if block.isSilicon then
                self.creation.SiliconBlocks[block.siliconBlockId]:addOutput(uuid, uuidToConnect)
            end
            if blockToConnect.isSilicon then
                self.creation.SiliconBlocks[blockToConnect.siliconBlockId]:addOutput(uuid, uuidToConnect)
            end
        end
        if block.outputsHash[uuidToConnect] == nil then
            block.outputs[#block.outputs + 1] = uuidToConnect
            block.outputsHash[uuidToConnect] = true
        end
        if blockToConnect.inputsHash[uuid] == nil then
            blockToConnect.inputs[#blockToConnect.inputs + 1] = uuid
            blockToConnect.inputsHash[uuid] = true
        end
        self.FastLogicRunner:externalAddOutput(uuid, uuidToConnect, skipChecksAndUpdates)
    end
end

function FastLogicAllBlockManager.removeOutput(self, uuid, uuidToDisconnect, skipSiliconChanges)
    local block = self.blocks[uuid]
    local blockToDisconnect = self.blocks[uuidToDisconnect]
    if (
        block ~= nil and blockToDisconnect ~= nil and
        (block.outputsHash[uuidToDisconnect] ~= nil or blockToDisconnect.inputsHash[uuid] ~= nil)
    ) then
        if skipSiliconChanges ~= true then
            if block.isSilicon and self.creation.SiliconBlocks[block.siliconBlockId] ~= nil then
                self.creation.SiliconBlocks[block.siliconBlockId]:removeOutput(uuid, uuidToDisconnect)
            end
            if blockToDisconnect.isSilicon and self.creation.SiliconBlocks[blockToDisconnect.siliconBlockId] ~= nil then
                self.creation.SiliconBlocks[blockToDisconnect.siliconBlockId]:removeOutput(uuid, uuidToDisconnect)
            end
        end
        if block.outputsHash[uuidToDisconnect] ~= nil then
            table.removeValue(block.outputs, uuidToDisconnect)
            block.outputsHash[uuidToDisconnect] = nil
        end
        if blockToDisconnect.inputsHash[uuid] ~= nil then
            table.removeValue(blockToDisconnect.inputs, uuid)
            blockToDisconnect.inputsHash[uuid] = nil
        end
        self.FastLogicRunner:externalRemoveOutput(uuid, uuidToDisconnect)
    end
end

function FastLogicAllBlockManager.makeBlockData(self, type, uuid, pos, rot, inputs, outputs, state, color, connectionColorId, isSilicon, timerLength, siliconBlockId)
    sm.MTFastLogic.UsedUuids[uuid] = true
    local keyPos = string.vecToString(pos)
    if self.locationCash[keyPos] == nil then
        self.locationCash[keyPos] = {}
    end
    self.dataToSetDelay3[#self.dataToSetDelay3+1] = {
        uuid,
        inputs,
        outputs
    }
    self.locationCash[keyPos][#self.locationCash[keyPos] + 1] = uuid
    self.blocks[uuid] = {
        type = type,
        uuid = uuid,
        pos = pos,
        rot = rot,
        inputs = {},
        inputsHash = {},
        outputs = {},
        outputsHash = {},
        state = state,
        timerLength = timerLength,
        color = color,
        connectionColorId = connectionColorId,
        isSilicon = isSilicon,
        siliconBlockId = siliconBlockId
    }
    self.FastLogicRunner:externalAddBlock(self.blocks[uuid], true)
end

function FastLogicAllBlockManager.changeBlockType(self, uuid, mode)
    self.creation.FastLogicRunner:externalChangeBlockType(uuid, mode)
    self.blocks[uuid].type = mode
end

function FastLogicAllBlockManager.changeTimerTime(self, uuid, time)
    self.creation.FastLogicRunner:externalChangeTimerTime(uuid, time)
    self.blocks[uuid].timerLength = time
end

function FastLogicAllBlockManager.changeConnectionColor(self, uuid, connectionColorId)
    self.blocks[uuid].connectionColorId = connectionColorId
end