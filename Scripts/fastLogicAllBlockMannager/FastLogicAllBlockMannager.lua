
FastLogicAllBlockMannager = FastLogicAllBlockMannager or {}

dofile "../util/util.lua"

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
    if table.length(self.blocks) == 0 then
        sm.MTFastLogic.Creations[self.creationId] = nil
    end
    return realBlocksToUpdate
end

function FastLogicAllBlockMannager.addBlock(self, block)
    if self.blocks[block.id] ~= nil then
        self:removeBlock(block.id)
    end
    local pos = block:getLocalCenter()
    local rot = { block.shape.xAxis, block.shape.yAxis, block.shape.zAxis }
    if block.type == "LogicGate" then
        if (block.data.mode == 0) then
            self:makeBlockData("andBlocks", block.id, pos, rot, block:getParentIds(), block:getChildIds(), block.interactable.active,
                false)
        elseif (block.data.mode == 1) then
            self:makeBlockData("orBlocks", block.id, pos, rot, block:getParentIds(), block:getChildIds(), block.interactable.active,
                false)
        elseif (block.data.mode == 2) then
            self:makeBlockData("xorBlocks", block.id, pos, rot, block:getParentIds(), block:getChildIds(), block.interactable.active,
                false)
        elseif (block.data.mode == 3) then
            self:makeBlockData("nandBlocks", block.id, pos, rot, block:getParentIds(), block:getChildIds(), block.interactable
                .active, false)
        elseif (block.data.mode == 4) then
            self:makeBlockData("norBlocks", block.id, pos, rot, block:getParentIds(), block:getChildIds(), block.interactable.active,
                false)
        elseif (block.data.mode == 5) then
            self:makeBlockData("xnorBlocks", block.id, pos, rot, block:getParentIds(), block:getChildIds(), block.interactable
                .active, false)
        end
    elseif block.type == "Timer" then
        self:makeBlockData("timerBlocks", block.id, pos, rot, block:getChildIds(), {}, block.interactable.active, false, block.data.time)
    elseif block.type == "EndTickButton" then
        self:makeBlockData("EndTickButtons", block.id, pos, rot, block:getParentIds(), {}, block.interactable.active, false)
    elseif block.type == "Light" then
        self:makeBlockData("lightBlocks", block.id, pos, rot, block:getParentIds(), {}, block.interactable.active, false)
    end
end

function FastLogicAllBlockMannager.addSiliconBlock(self, type, id, pos, rot, inputs, outputs, state, timerLength)
    if self.blocks[block.id] == nil then
        self:makeBlockData(type, id, pos, inputs, outputs, state, true, timerLength)
    end
end

function FastLogicAllBlockMannager.removeBlock(self, id)
    local block = self.blocks[id]
    if block == nil then return end
    for i = 0, #block.outputs do
        self:removeOutput(block.outputs[i], id)
    end
    for i = 0, #block.inputs do
        self:removeOutput(id, block.inputs[i])
    end
    local keyPos = (
        tostring(math.floor(block.pos.x)) .. "," ..
        tostring(math.floor(block.pos.y)) .. "," ..
        tostring(math.floor(block.pos.z))
    )
    table.removeValue(self.locationCash[keyPos], id)
    if #self.locationCash[keyPos] == 0 then
        self.locationCash[keyPos] = nil
    end
    self.FastLogicRunner:externalRemoveBlock(id)
    self.blocks[id] = nil
end

function FastLogicAllBlockMannager.addInput(self, id, idToConnect)
    self:addOutput(idToConnect, id)
end

function FastLogicAllBlockMannager.removeInput(self, id, idToDeconnect)
    self:removeOutput(idToDeconnect, id)
end

function FastLogicAllBlockMannager.addOutput(self, id, idToConnect)
    if self.blocks[id] ~= nil and self.blocks[idToConnect] ~= nil then
        self.blocks[id].outputs[#self.blocks[id].outputs + 1] = idToConnect
        self.blocks[idToConnect].inputs[#self.blocks[idToConnect].inputs + 1] = id
        self.FastLogicRunner:externalAddOutput(id, idToConnect)
    end
end

function FastLogicAllBlockMannager.removeOutput(self, id, idToDeconnect)
    if self.blocks[id] ~= nil and self.blocks[idToDeconnect] ~= nil then
        table.removeValue(self.blocks[id].outputs, idToDeconnect)
        table.removeValue(self.blocks[idToDeconnect].inputs, id)
        self.FastLogicRunner:externalRemoveOutput(id, idToDeconnect)
    end
end

function FastLogicAllBlockMannager.makeBlockData(self, type, id, pos, rot, inputs, outputs, state, isSilicon, timerLength)
    local keyPos = (
        tostring(math.floor(pos.x)) .. "," ..
        tostring(math.floor(pos.y)) .. "," ..
        tostring(math.floor(pos.z))
    )
    if self.locationCash[keyPos] == nil then
        self.locationCash[keyPos] = {}
    end
    self.locationCash[keyPos][#self.locationCash[keyPos] + 1] = id
    self.blocks[id] = {
        ["type"] = type,
        ["id"] = id,
        ["pos"] = pos,
        ["rot"] = rot,
        ["inputs"] = inputs,
        ["outputs"] = outputs,
        ["state"] = state,
        ["timerLength"] = timerLength,
        ["isSilicon"] = isSilicon,
    }
    self.FastLogicRunner:externalAddBlock(self.blocks[id])
end
