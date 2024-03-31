-- print("loading FastLogicAllBlockMannager")

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
            if not block.isFake then
                realBlocksToUpdate[#realBlocksToUpdate+1] = unhashedLookUp[updatedIds[i]]
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
    if block.type == "LogicGate" then
        if (block.data.mode == 0) then
            self:makeBlockData("andBlocks", block.id, block:getParentIds(), block:getChildIds(), block.interactable.active, false)
        elseif (block.data.mode == 1) then
            self:makeBlockData("orBlocks", block.id, block:getParentIds(), block:getChildIds(), block.interactable.active, false)
        elseif (block.data.mode == 2) then
            self:makeBlockData("xorBlocks", block.id, block:getParentIds(), block:getChildIds(), block.interactable.active, false)
        elseif (block.data.mode == 3) then
            self:makeBlockData("nandBlocks", block.id, block:getParentIds(), block:getChildIds(), block.interactable.active, false)
        elseif (block.data.mode == 4) then
            self:makeBlockData("norBlocks", block.id, block:getParentIds(), block:getChildIds(), block.interactable.active, false)
        elseif (block.data.mode == 5) then
            self:makeBlockData("xnorBlocks", block.id, block:getParentIds(), block:getChildIds(), block.interactable.active, false)
        end
    elseif block.type == "Timer" then
        self:makeBlockData("timerBlocks", block.id, block:getParentIds(), block:getChildIds(), block.interactable.active, false, block.data.time)
    elseif block.type == "EndTickButton" then
        self:makeBlockData("EndTickButtons", block.id, block:getParentIds(), {}, block.interactable.active, false)
    elseif block.type == "Light" then
        self:makeBlockData("lightBlocks", block.id, block:getParentIds(), {}, block.interactable.active, false)
    end
end

function FastLogicAllBlockMannager.addFakeBlock(self, type, id, inputs, outputs, state, timerLength)
    if self.blocks[block.id] == nil then
        self:makeBlockData(type, id, inputs, outputs, state, true, timerLength)
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
        self.blocks[id].outputs[#self.blocks[id].outputs+1] = idToConnect
        self.blocks[idToConnect].inputs[#self.blocks[idToConnect].inputs+1] = id
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

function FastLogicAllBlockMannager.makeBlockData(self, type, id, inputs, outputs, state, isFake, timerLength)
    self.blocks[id] = {
        ["type"] = type,
        ["id"] = id,
        ["inputs"] = inputs,
        ["outputs"] = outputs,
        ["state"] = state,
        ["timerLength"] = timerLength,
        ["isFake"] = isFake,
    }
    self.FastLogicRunner:externalAddBlock(self.blocks[id])
end