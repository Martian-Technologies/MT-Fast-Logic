dofile "../util/util.lua"
dofile "../CreationUtil.lua"
local string = string
local table = table
local type = type
local pairs = pairs

dofile "../fastLogicBlock/FastLogicRunner.lua"

function FastLogicRealBlockMannager.checkForNewInputs(self)
    for uuid, data in pairs(self.creation.AllNonFastBlocks) do
        if sm.exists(data.interactable) then
            if data.currentState ~= data.interactable.active then
                data.currentState = data.interactable.active
                local stateNumber = data.currentState and 1 or -1
                local i = 1
                while i <= #data.outputs do
                    local outputUuid = data.outputs[i]
                    if type(self.creation.AllFastBlocks[outputUuid]) ~= nil then
                        self.FastLogicRunner:externalChangeNonFastOnInput(outputUuid, stateNumber)
                    else
                        if table.contains(data.outputs, outputUuid) then
                            self.FastLogicRunner:externalRemoveNonFastConnection(outputUuid)
                            if data.currentState then
                                self.FastLogicRunner:externalRemoveNonFastOnInput(outputUuid)
                            end
                            if #data.outputs == 1 then
                                self.creation.AllNonFastBlocks[uuid] = nil
                            else
                                table.removeValue(data.outputs, outputUuid)
                                i = i - 1
                            end
                        end
                    end
                    i = i + 1
                end
            end
        end
    end
end

function FastLogicRealBlockMannager.checkForCreationDeletion(self)
    if not sm.exists(self.creation.body) then
            for _, block in pairs(self.creation.AllFastBlocks) do
                if block ~= nil and block.shape ~= nil then
                    if sm.exists(block.shape) then
                        block:deepRescanSelf()
                    end
                end
            end
            for _, block in pairs(self.creation.SiliconBlocks) do
                if block ~= nil and block.shape ~= nil  then
                    if sm.exists(block.shape) then
                        block:deepRescanSelf()
                    end
                end
            end
            sm.MTFastLogic.Creations[self.creationId] = nil
            return true
    end
    return false
end

function FastLogicRealBlockMannager.checkForBodyUpdate(self)
    local scanNext
    if not sm.exists(self.creation.body) or self.creation.body:hasChanged(self.creation.lastBodyUpdate) then
        self.creation.lastBodyUpdate = sm.game.getCurrentTick()
        scanNext = self.creation.AllFastBlocks
        self:scanSiliconBlocks()
    else
        scanNext = self.scanNext
    end

    for uuid, block in pairs(scanNext) do
        if block == nil or block.shape == nil then
        elseif self.creationId ~= sm.MTFastLogic.CreationUtil.getCreationIdFromBlock(block) then
            block:deepRescanSelf()
        else
            self.FastLogicAllBlockMannager:setColor(uuid, block.shape.color:getHexStr())
            -- self.FastLogicRunner:externalAddBlockToUpdate(uuid)
            local inputs = block.interactable:getParents()
            local inputsHash = {}
            for _, v in pairs(inputs) do
                if sm.exists(v) then
                    local inputId = v:getId()
                    local inputUuid = self.creation.uuids[inputId]
                    inputsHash[inputId] = true
                    if inputUuid ~= nil then
                        self.FastLogicAllBlockMannager:addOutput(inputUuid, uuid)
                    else
                        local currentState = v.active
                        if self.creation.AllNonFastBlocks[inputId] == nil then
                            self.creation.AllNonFastBlocks[inputId] = {
                                ["interactable"] = v,
                                ["currentState"] = currentState,
                                ["outputs"] = {}
                            }
                        end
                        if not table.contains(self.creation.AllNonFastBlocks[inputId].outputs, uuid) then
                            self.creation.AllNonFastBlocks[inputId].outputs[#self.creation.AllNonFastBlocks[inputId].outputs + 1] = uuid
                        end
                        local activeInput = block.activeInputs[inputId]
                        if (activeInput == nil) then
                            self.FastLogicRunner:externalAddNonFastConnection(uuid)
                            if currentState then
                                self.FastLogicRunner:externalAddNonFastOnInput(uuid)
                                block.activeInputs[inputId] = true
                            else
                                block.activeInputs[inputId] = false
                            end
                        elseif activeInput ~= currentState then
                            block.activeInputs[inputId] = currentState
                            self.FastLogicRunner:externalAddBlockToUpdate(uuid)
                        end
                    end
                end
            end
            for k, state in pairs(block.activeInputs) do
                if inputsHash[k] == nil then
                    if table.contains(self.creation.AllNonFastBlocks[k].outputs, uuid) then
                        if self.creation.AllNonFastBlocks[k].currentState then
                            self.FastLogicRunner:externalRemoveNonFastOnInput(uuid)
                        end
                        if #self.creation.AllNonFastBlocks[k].outputs == 1 then
                            self.creation.AllNonFastBlocks[k] = nil
                        else
                            table.removeValue(self.creation.AllNonFastBlocks[k].outputs, uuid)
                        end
                    end
                    block.activeInputs[k] = nil
                    self.FastLogicRunner:externalRemoveNonFastConnection(uuid)
                end
            end
            local inputs = self.creation.blocks[uuid].inputs
            for i = 0, #inputs do
                local inputUuid = inputs[i]
                if inputsHash[self.creation.ids[inputUuid]] == nil and self.creation.blocks[inputUuid] ~= nil and self.creation.blocks[inputUuid].isSilicon == false then
                    self.FastLogicAllBlockMannager:removeOutput(inputUuid, uuid)
                end
            end
            -- self.FastLogicAllBlockMannager:doFixOnBlock(uuid)
        end
    end
    self.scanNext = {}
end

function FastLogicRealBlockMannager.scanSiliconBlocks(self)
    for _, block in pairs(self.creation.SiliconBlocks) do
        if block == nil or block.shape == nil then return end
        if self.creationId ~= sm.MTFastLogic.CreationUtil.getCreationId(block.shape:getBody()) then
            block:deepRescanSelf()
        end
    end
end