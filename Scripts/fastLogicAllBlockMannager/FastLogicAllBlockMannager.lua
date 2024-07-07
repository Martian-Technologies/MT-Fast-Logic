dofile "../util/util.lua"
local string = string
local table = table

FastLogicAllBlockMannager = FastLogicAllBlockMannager or {}

dofile "FastLogicAllBlockFixer.lua"

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.UsedUuids = sm.MTFastLogic.UsedUuids or {}

FastLogicAllBlockMannager.blockUuidToConnectionColorID = {
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

FastLogicAllBlockMannager.fastLogicGateBlockUuids = {} -- only the keys from the above table
for k, _ in pairs(FastLogicAllBlockMannager.blockUuidToConnectionColorID) do
    table.insert(FastLogicAllBlockMannager.fastLogicGateBlockUuids, k)
end

function FastLogicAllBlockMannager.getNew(creationId)
    local new = table.deepCopy(FastLogicAllBlockMannager)
    new.getNew = nil
    new.creationId = creationId
    return new
end

function FastLogicAllBlockMannager.init(self)
    self.creation = sm.MTFastLogic.Creations[self.creationId]
    self.FastLogicRunner = self.creation.FastLogicRunner
    self.blocks = self.creation.blocks
    self.locationCash = {}
end

function FastLogicAllBlockMannager.update(self)
    -- run fast gates
    self.creation.FastLogicRunner:update()
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

function FastLogicAllBlockMannager.addBlock(self, block)
    if self.blocks[block.data.uuid] ~= nil then
        return
    end
    local pos = block:getLocalCenter()
    local rot = { block.shape.xAxis, block.shape.yAxis, block.shape.zAxis }
    if block.type == "LogicGate" then
        local connectionColorId = FastLogicAllBlockMannager.blockUuidToConnectionColorID[tostring(block.shape:getShapeUuid())]
        if (block.data.mode == 0) then
            self:makeBlockData("andBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color:getHexStr(), connectionColorId, false, false)
        elseif (block.data.mode == 1) then
            self:makeBlockData("orBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color:getHexStr(), connectionColorId, false, false)
        elseif (block.data.mode == 2) then
            self:makeBlockData("xorBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color:getHexStr(), connectionColorId, false, false)
        elseif (block.data.mode == 3) then
            self:makeBlockData("nandBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color:getHexStr(), connectionColorId, false, false)
        elseif (block.data.mode == 4) then
            self:makeBlockData("norBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color:getHexStr(), connectionColorId, false, false)
        elseif (block.data.mode == 5) then
            self:makeBlockData("xnorBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color:getHexStr(), connectionColorId, false, false)
        end
    elseif block.type == "Timer" then
        self:makeBlockData("timerBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color:getHexStr(), 0, false, block.time, false)
    elseif block.type == "EndTickButton" then
        self:makeBlockData("EndTickButtons", block.data.uuid, pos, rot, block:getParentUuids(), {}, block.interactable.active, block.shape.color:getHexStr(), 0, false, false)
    elseif block.type == "Light" then
        self:makeBlockData("lightBlocks", block.data.uuid, pos, rot, block:getParentUuids(), {}, block.interactable.active, block.shape.color:getHexStr(), 0, false, false)
    end
end

function FastLogicAllBlockMannager.addSiliconBlock(self, type, uuid, pos, rot, inputs, outputs, state, color, connectionColorId, siliconBlockId)
    if self.blocks[uuid] == nil then
        self:makeBlockData(type, uuid, pos, rot, inputs, outputs, state, color, connectionColorId, true, nil, siliconBlockId)
    end
end

function FastLogicAllBlockMannager.removeBlock(self, uuid, skipSiliconChanges)
    local block = self.blocks[uuid]
    if block == nil then return end
    for i = 0, #block.outputs do
        self:removeOutput(block.outputs[i], uuid, skipSiliconChanges)
    end
    for i = 0, #block.inputs do
        self:removeOutput(uuid, block.inputs[i], skipSiliconChanges)
    end
    local keyPos = string.vecToString(block.pos)
    table.removeValue(self.locationCash[keyPos], uuid)
    if #self.locationCash[keyPos] == 0 then
        self.locationCash[keyPos] = nil
    end
    self.FastLogicRunner:externalRemoveBlock(uuid)
    self.blocks[uuid] = nil
end

function FastLogicAllBlockMannager.setColor(self, uuid, colorStr)
    self.blocks[uuid].color = colorStr
end

function FastLogicAllBlockMannager.addInput(self, uuid, uuidToConnect)
    self:addOutput(uuidToConnect, uuid)
end

function FastLogicAllBlockMannager.removeInput(self, uuid, uuidToDisconnect)
    self:removeOutput(uuidToDisconnect, uuid)
end

function FastLogicAllBlockMannager.addOutput(self, uuid, uuidToConnect, skipSiliconSave)
    if (
        self.blocks[uuid] ~= nil and self.blocks[uuidToConnect] ~= nil and
        (self.blocks[uuid].outputHash[uuidToConnect] == nil or self.blocks[uuidToConnect].inputHash[uuid] == nil)
    ) then
        if self.blocks[uuid].isSilicon then
            self.creation.SiliconBlocks[self.blocks[uuid].siliconBlockId]:addOutput(uuid, uuidToConnect, skipSiliconSave)
        end
        if self.blocks[uuidToConnect].isSilicon then
            self.creation.SiliconBlocks[self.blocks[uuidToConnect].siliconBlockId]:addOutput(uuid, uuidToConnect, skipSiliconSave)
        end
        if self.blocks[uuid].outputHash[uuidToConnect] == nil then
            self.blocks[uuid].outputs[#self.blocks[uuid].outputs + 1] = uuidToConnect
            self.blocks[uuid].outputHash[uuidToConnect] = true
        end
        if self.blocks[uuidToConnect].inputHash[uuid] == nil then
            self.blocks[uuidToConnect].inputs[#self.blocks[uuidToConnect].inputs + 1] = uuid
            self.blocks[uuidToConnect].inputHash[uuid] = true
        end
        self.FastLogicRunner:externalAddOutput(uuid, uuidToConnect)
        -- self:doFixOnBlock(uuid)
        -- self:doFixOnBlock(uuidToConnect)
    end
end

function FastLogicAllBlockMannager.removeOutput(self, uuid, uuidToDisconnect, skipSiliconChanges)
    if (
        self.blocks[uuid] ~= nil and self.blocks[uuidToDisconnect] ~= nil and
        (self.blocks[uuid].outputHash[uuidToDisconnect] ~= nil or self.blocks[uuidToDisconnect].inputHash[uuid] ~= nil)
    ) then
        if skipSiliconChanges ~= true then
            if self.blocks[uuid].isSilicon and self.creation.SiliconBlocks[self.blocks[uuid].siliconBlockId] ~= nil then
                self.creation.SiliconBlocks[self.blocks[uuid].siliconBlockId]:removeOutput(uuid, uuidToDisconnect)
            end
            if self.blocks[uuidToDisconnect].isSilicon and self.creation.SiliconBlocks[self.blocks[uuidToDisconnect].siliconBlockId] ~= nil then
                self.creation.SiliconBlocks[self.blocks[uuidToDisconnect].siliconBlockId]:removeOutput(uuid, uuidToDisconnect)
            end
        end
        if self.blocks[uuid].outputHash[uuidToDisconnect] ~= nil then
            table.removeValue(self.blocks[uuid].outputs, uuidToDisconnect)
            self.blocks[uuid].outputHash[uuidToDisconnect] = nil
        end
        if self.blocks[uuidToDisconnect].inputHash[uuid] ~= nil then
            table.removeValue(self.blocks[uuidToDisconnect].inputs, uuid)
            self.blocks[uuidToDisconnect].inputHash[uuid] = nil
        end
        self.FastLogicRunner:externalRemoveOutput(uuid, uuidToDisconnect)
        -- if self.blocks[uuid] ~= nil then
        --     self:doFixOnBlock(uuid)
        -- end
        -- if self.blocks[uuidToDisconnect] ~= nil then
        --     self:doFixOnBlock(uuidToDisconnect)
        -- end
    end
end

function FastLogicAllBlockMannager.makeBlockData(self, type, uuid, pos, rot, inputs, outputs, state, color, connectionColorId, isSilicon, timerLength, siliconBlockId)
    sm.MTFastLogic.UsedUuids[uuid] = true
    local keyPos = string.vecToString(pos)
    if self.locationCash[keyPos] == nil then
        self.locationCash[keyPos] = {}
    end
    local betterInputs = {}
    local betterInputsHash = {}
    for i = 1, #inputs do
        if betterInputsHash[inputs[i]] == nil then
            betterInputsHash[inputs[i]] = true
            betterInputs[#betterInputs+1] = inputs[i]
        end
    end
    local betterOutputs = {}
    local betterOutputsHash = {}
    for i = 1, #outputs do
        if betterOutputsHash[outputs[i]] == nil then
            betterOutputsHash[outputs[i]] = true
            betterOutputs[#betterOutputs+1] = outputs[i]
        end
    end
    self.locationCash[keyPos][#self.locationCash[keyPos] + 1] = uuid
    self.blocks[uuid] = {
        type = type,
        uuid = uuid,
        pos = pos,
        rot = rot,
        inputs = betterInputs,
        inputHash = betterInputsHash,
        outputs = betterOutputs,
        outputHash = betterOutputsHash,
        state = state,
        timerLength = timerLength,
        color = color,
        connectionColorId = connectionColorId,
        isSilicon = isSilicon,
        siliconBlockId = siliconBlockId
    }
    self.FastLogicRunner:externalAddBlock(self.blocks[uuid])
    self:doFixOnBlock(uuid)
end

function FastLogicAllBlockMannager.changeBlockType(self, uuid, mode)
    self.creation.FastLogicRunner:externalChangeBlockType(uuid, mode)
    self.blocks[uuid].type = mode
end

function FastLogicAllBlockMannager.changeTimerTime(self, uuid, time)
    self.creation.FastLogicRunner:externalChangeTimerTime(uuid, time)
    self.blocks[uuid].timerLength = time
end

function FastLogicAllBlockMannager.changeConnectionColor(self, uuid, connectionColorId)
    self.blocks[uuid].connectionColorId = connectionColorId
end