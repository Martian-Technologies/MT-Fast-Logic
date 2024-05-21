dofile "../util/util.lua"
local string = string
local table = table

FastLogicAllBlockMannager = FastLogicAllBlockMannager or {}

dofile "FastLogicAllBlockFixer.lua"

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.UsedUuids = sm.MTFastLogic.UsedUuids or {}

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
        if (block.data.mode == 0) then
            self:makeBlockData("andBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color:getHexStr(), false, false)
        elseif (block.data.mode == 1) then
            self:makeBlockData("orBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color:getHexStr(), false, false)
        elseif (block.data.mode == 2) then
            self:makeBlockData("xorBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color:getHexStr(), false, false)
        elseif (block.data.mode == 3) then
            self:makeBlockData("nandBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color:getHexStr(), false, false)
        elseif (block.data.mode == 4) then
            self:makeBlockData("norBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color:getHexStr(), false, false)
        elseif (block.data.mode == 5) then
            self:makeBlockData("xnorBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color:getHexStr(), false, false)
        end
    elseif block.type == "Timer" then
        self:makeBlockData("timerBlocks", block.data.uuid, pos, rot, block:getParentUuids(), block:getChildUuids(), block.interactable.active, block.shape.color:getHexStr(), false, block.time, false)
    elseif block.type == "EndTickButton" then
        self:makeBlockData("EndTickButtons", block.data.uuid, pos, rot, block:getParentUuids(), {}, block.interactable.active, block.shape.color:getHexStr(), false, false)
    elseif block.type == "Light" then
        self:makeBlockData("lightBlocks", block.data.uuid, pos, rot, block:getParentUuids(), {}, block.interactable.active, block.shape.color:getHexStr(), false, false)
    end
end

function FastLogicAllBlockMannager.addSiliconBlock(self, type, uuid, pos, rot, inputs, outputs, state, color, siliconBlockId)
    if self.blocks[uuid] == nil then
        self:makeBlockData(type, uuid, pos, rot, inputs, outputs, state, color, true, nil, siliconBlockId)
    end
end

function FastLogicAllBlockMannager.removeBlock(self, uuid)
    local block = self.blocks[uuid]
    if block == nil then return end
    for i = 0, #block.outputs do
        self:removeOutput(block.outputs[i], uuid)
    end
    for i = 0, #block.inputs do
        self:removeOutput(uuid, block.inputs[i])
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

function FastLogicAllBlockMannager.removeInput(self, uuid, uuidToDeconnect)
    self:removeOutput(uuidToDeconnect, uuid)
end

function FastLogicAllBlockMannager.addOutput(self, uuid, uuidToConnect)
    if self.blocks[uuid] ~= nil and self.blocks[uuidToConnect] ~= nil and
    (self.blocks[uuid].outputHash[uuidToConnect] == nil or self.blocks[uuidToConnect].inputHash[uuid] == nil) then
        if self.blocks[uuid].isSilicon then
            self.creation.SiliconBlocks[self.blocks[uuid].siliconBlockId]:addOutput(uuid, uuidToConnect)
        end
        if self.blocks[uuidToConnect].isSilicon then
            self.creation.SiliconBlocks[self.blocks[uuidToConnect].siliconBlockId]:addOutput(uuid, uuidToConnect)
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

function FastLogicAllBlockMannager.removeOutput(self, uuid, uuidToDeconnect)
    if self.blocks[uuid] ~= nil and self.blocks[uuidToDeconnect] ~= nil and
        (self.blocks[uuidToDeconnect].inputHash[uuid] ~= nil or self.blocks[uuid].outputHash[uuidToDeconnect] ~= nil) then
        if self.blocks[uuid].outputHash[uuidToDeconnect] ~= nil then
            table.removeValue(self.blocks[uuid].outputs, uuidToDeconnect)
            self.blocks[uuid].outputHash[uuidToDeconnect] = nil
        end
        if self.blocks[uuidToDeconnect].inputHash[uuid] ~= nil then
            table.removeValue(self.blocks[uuidToDeconnect].inputs, uuid)
            self.blocks[uuidToDeconnect].inputHash[uuid] = nil
        end
        self.FastLogicRunner:externalRemoveOutput(uuid, uuidToDeconnect)
        -- if self.blocks[uuid] ~= nil then
        --     self:doFixOnBlock(uuid)
        -- end
        -- if self.blocks[uuidToDeconnect] ~= nil then
        --     self:doFixOnBlock(uuidToDeconnect)
        -- end
    end
end

function FastLogicAllBlockMannager.makeBlockData(self, type, uuid, pos, rot, inputs, outputs, state, color, isSilicon, timerLength, siliconBlockId)
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
        isSilicon = isSilicon,
        siliconBlockId = siliconBlockId
    }
    self.FastLogicRunner:externalAddBlock(self.blocks[uuid])
    self:doFixOnBlock(uuid)
end