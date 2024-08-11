dofile "../util/util.lua"

local string = string
local table = table
local type = type
local pairs = pairs

dofile "../fastLogicBlock/FastLogicRunner.lua"

function FastLogicRealBlockManager.checkForNewInputs(self)
    local FastLogicRunner = self.FastLogicRunner
    for id, data in pairs(FastLogicRunner.nonFastBlocks) do
        local interactible = data[4]
        if sm.exists(interactible) then
            FastLogicRunner:externalSetNonFastBlockState(id, interactible.active)
        else
            FastLogicRunner:externalRemoveNonFastBlock(id)
        end
    end
end

function FastLogicRealBlockManager.checkForCreationDeletion(self)
    if not sm.exists(self.creation.body) then
        for _, block in pairs(self.creation.AllFastBlocks) do
            if block ~= nil and block.shape ~= nil then
                if sm.exists(block.shape) then
                    block:deepRescanSelf(true)
                end
            end
        end
        for _, block in pairs(self.creation.SiliconBlocks) do
            if block ~= nil and block.shape ~= nil  then
                if sm.exists(block.shape) then
                    block:deepRescanSelf(true)
                end
            end
        end
        sm.MTFastLogic.Creations[self.creationId] = nil
        return true
    end
    return false
end

function FastLogicRealBlockManager.checkForBodyUpdate(self)
    if self:checkForCreationDeletion() then
        return
    elseif sm.MTFastLogic.CreationUtil.checkIfCreationHasChanged(self.creation.body, self.creation.lastBodyUpdate) then
        self.creation.lastBodyUpdate = sm.game.getCurrentTick()
        self.scanNext = self.creation.AllFastBlocks
        self:scanSiliconBlocks()
    end
    local scanNext = self.scanNext

    if FastLogicRunner.isNew ~= nil and FastLogicRunner.isNew ~= 1 then return end

    if table.length(scanNext) > 0 then
        local ids = self.creation.ids
        local creationId = self.creationId
        local blocks = self.creation.blocks
        local uuids = self.creation.uuids
        local FastLogicAllBlockManager = self.FastLogicAllBlockManager
        local FastLogicRunner = self.FastLogicRunner
        local exists = sm.exists
        local getCreationIdFromBlock = sm.MTFastLogic.CreationUtil.getCreationIdFromBlock
        for uuid, block in pairs(scanNext) do
            if block == nil or block.shape == nil then
            elseif creationId ~= getCreationIdFromBlock(block) then
                block:deepRescanSelf()
            else
                local blockData = blocks[uuid]
                local inputs = block.interactable:getParents()
                local inputHash = blockData.inputsHash
                local newInputsHash = {}
                FastLogicAllBlockManager:setColor(uuid, block.shape.color)
                for i = 1, #inputs do
                    local interactable = inputs[i]
                    if exists(interactable) then
                        local inputId = interactable.id
                        local inputUuid = uuids[inputId]
                        if inputUuid ~= nil then
                            newInputsHash[inputUuid] = true
                            local blockToConnect = blocks[inputUuid]
                            if (
                                blockToConnect ~= nil and
                                (inputHash[inputUuid] == nil or blockToConnect.outputsHash[uuid] == nil)
                            ) then
                                FastLogicAllBlockManager:addOutput(inputUuid, uuid)
                            end
                        else
                            FastLogicRunner:externalAddNonFastBlock(inputId, interactable.active, interactable)
                        end
                    end
                end
                local inputUuids = blockData.inputs
                for i = 0, #inputUuids do
                    local inputUuid = inputUuids[i]
                    if newInputsHash[inputUuid] == nil then
                        local inputBlock = blocks[inputUuid]
                        if inputBlock ~= nil and inputBlock.isSilicon == false then
                            FastLogicAllBlockManager:removeOutput(inputUuid, uuid)
                        end
                    end
                end
            end
            ::continue::
        end
        for id, data in pairs(FastLogicRunner.nonFastBlocks) do
            local interactable = data[4]
            if sm.exists(interactable) then
                local children = interactable:getChildren()
                local allOutputUuids = {}
                for i = 1, #children do
                    local uuid = uuids[children[i].id]
                    if uuid ~= nil then
                        allOutputUuids[#allOutputUuids+1] = uuid
                    end
                end
                FastLogicRunner:externalUpdateNonFastOutput(id, allOutputUuids)
            else
                FastLogicRunner:externalRemoveNonFastBlock(id)
            end
        end
    end
    self.scanNext = {}
end

function FastLogicRealBlockManager.scanSiliconBlocks(self)
    for _, block in pairs(self.creation.SiliconBlocks) do
        if block == nil or block.shape == nil then return end
        if self.creationId ~= sm.MTFastLogic.CreationUtil.getCreationIdFromBlock(block) then
            block:deepRescanSelf()
        end
    end
end