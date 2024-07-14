dofile "../util/util.lua"

local string = string
local table = table
local type = type
local pairs = pairs

dofile "../fastLogicBlock/FastLogicRunner.lua"

function FastLogicRealBlockManager.checkForNewInputs(self)
    for uuid, data in pairs(self.creation.AllNonFastBlocks) do
        local isActive = data.interactable.active
        if data.currentState ~= isActive then
            data.currentState = isActive
            local stateNumber = isActive and 1 or -1
            local outputs = data.outputs
            for i = 1, #outputs do
                self.FastLogicRunner:externalChangeNonFastOnInput(outputs[i], stateNumber)
            end
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
    local blocks = self.creation.blocks
    local uuids = self.creation.uuids
    local ids = self.creation.ids
    local AllNonFastBlocks = self.creation.AllNonFastBlocks
    local AllFastBlocks = self.creation.AllFastBlocks
    local FastLogicAllBlockManager = self.FastLogicAllBlockManager
    local FastLogicRunner = self.FastLogicRunner
    local creationId = self.creationId
    local getCreationIdFromBlock = sm.MTFastLogic.CreationUtil.getCreationIdFromBlock
    local exists = sm.exists
    local scanNext
    local bodyHasChanged = false
    if self:checkForCreationDeletion() then
        return
    elseif sm.MTFastLogic.CreationUtil.checkIfCreationHasChanged(self.creation.body, self.creation.lastBodyUpdate) then
        bodyHasChanged = true
        self.creation.lastBodyUpdate = sm.game.getCurrentTick()
        self.scanNext = AllFastBlocks
        self:scanSiliconBlocks()
    end
    scanNext = self.scanNext

    if FastLogicRunner.isNew ~= nil and FastLogicRunner.isNew ~= 1 then return end
    if table.length(scanNext) > 0 then
        for uuid, block in pairs(scanNext) do
            -- sm.MTUtil.Profiler.Time.on("checkForBodyUpdate" .. tostring(creationId))
            if block == nil or block.shape == nil then
            elseif creationId ~= getCreationIdFromBlock(block) then
                block:deepRescanSelf()
            else
                local blockData = blocks[uuid]
                local activeInputs = block.activeInputs
                local inputs = block.interactable:getParents()
                local inputsLength = #inputs
                local inputUuids = blockData.inputs
                local inputUuidsLength = #inputUuids
                local inputsHash = {}
                local inputUuidsHash = blockData.inputsHash
                local newInputCount = 0
                FastLogicAllBlockManager:setColor(uuid, block.shape.color)
                for i = 1, inputsLength do
                    local interactable = inputs[i]
                    if exists(interactable) then
                        local inputId = interactable.id
                        local inputUuid = uuids[inputId]
                        inputsHash[inputId] = true
                        if inputUuid ~= nil then
                            local blockToConnect = blocks[inputUuid]
                            if (
                                blockToConnect ~= nil and
                                (inputUuidsHash[inputUuid] == nil or blockToConnect.outputsHash[uuid] == nil)
                            ) then
                                newInputCount = newInputCount + 1
                                bodyHasChanged = true
                                FastLogicAllBlockManager:addOutput(inputUuid, uuid)
                            end
                        else
                            newInputCount = newInputCount + 256
                            local nonFastBlock = AllNonFastBlocks[inputId]
                            if nonFastBlock == nil then
                                bodyHasChanged = true
                                local currentState = interactable.active
                                nonFastBlock = {
                                    ["interactable"] = interactable,
                                    ["currentState"] = currentState,
                                    ["outputs"] = {uuid},
                                    ["outputsHash"] = {[uuid] = true}
                                }
                                AllNonFastBlocks[inputId] = nonFastBlock
                                FastLogicRunner:externalAddNonFastConnection(uuid)
                                if currentState then
                                    FastLogicRunner:externalAddNonFastOnInput(uuid)
                                    activeInputs[inputId] = true
                                else
                                    activeInputs[inputId] = false
                                end
                            end
                        end
                    end
                end

                local maxInputsRemoved = newInputCount - (inputsLength - inputUuidsLength)
                if maxInputsRemoved > 0 then
                    for i = 0, #inputUuids do
                        local inputUuid = inputUuids[i]
                        if inputsHash[ids[inputUuid]] == nil and blocks[inputUuid] ~= nil and blocks[inputUuid].isSilicon == false then
                            FastLogicAllBlockManager:removeOutput(inputUuid, uuid)
                            if maxInputsRemoved == 1 then
                                break
                            end
                            maxInputsRemoved = maxInputsRemoved - 1
                        end
                    end
                end
            end
            -- sm.MTUtil.Profiler.Time.off("checkForBodyUpdate" .. tostring(creationId))
            -- sm.MTUtil.Profiler.Count.increment("checkForBodyUpdate" .. tostring(creationId))
        end
        -- print("-----------------------------------------------")
        -- print("time per block: " .. tostring(
        --     sm.MTUtil.Profiler.Time.get("checkForBodyUpdate" .. tostring(self.creationId)) /
        --     sm.MTUtil.Profiler.Count.get("checkForBodyUpdate" .. tostring(self.creationId))
        -- ))
        -- print("time: " .. tostring(sm.MTUtil.Profiler.Time.get("checkForBodyUpdate" .. tostring(self.creationId))))
        -- print("count: " .. sm.MTUtil.Profiler.Count.get("checkForBodyUpdate" .. tostring(self.creationId)))
    end
    if bodyHasChanged then                
        for id, data in pairs(self.creation.AllNonFastBlocks) do
            -- sm.MTUtil.Profiler.Count.increment("2checkForBodyUpdate" .. tostring(creationId))
            -- sm.MTUtil.Profiler.Time.on("2checkForBodyUpdate" .. tostring(creationId))
            local outputs = data.outputs
            local state = data.currentState
            if sm.exists(data.interactable) then
                local outputsHash = data.outputsHash
                local newOutputsHash = {}
                data.outputsHash = newOutputsHash
                local children = data.interactable:getChildren()
                for i = 1, #children do
                    local uuid = uuids[children[i].id]
                    if uuid ~= nil then
                        newOutputsHash[uuid] = true
                        if outputsHash[uuid] == nil then
                            outputs[#outputs+1] = uuid
                            FastLogicRunner:externalAddNonFastConnection(uuid)
                            if state then
                                FastLogicRunner:externalAddNonFastOnInput(uuid)
                                AllFastBlocks[uuid].activeInputs[id] = true
                            else
                                AllFastBlocks[uuid].activeInputs[id] = false
                            end
                        end
                    end
                end
                for i = 1, #outputs do
                    local uuid = outputs[i]
                    if newOutputsHash[uuid] == nil then
                        if #outputs == 1 then
                            AllNonFastBlocks[id] = nil
                        else
                            table.removeValue(outputs, uuid)
                        end
                        local block = AllFastBlocks[uuid]
                        if block ~= nil then
                            block.activeInputs[id] = nil
                            if state then
                                FastLogicRunner:externalRemoveNonFastOnInput(uuid)
                            end
                            FastLogicRunner:externalRemoveNonFastConnection(uuid)
                        end
                    end
                end
            else
                for i = 1, #outputs do
                    local uuid = outputs[i]
                    local block = AllFastBlocks[uuid]
                    if block ~= nil then
                        block.activeInputs[id] = nil
                        if state then
                            FastLogicRunner:externalRemoveNonFastOnInput(uuid)
                        end
                        FastLogicRunner:externalRemoveNonFastConnection(uuid)
                    end
                end
                AllNonFastBlocks[id] = nil
            end
            -- sm.MTUtil.Profiler.Time.off("2checkForBodyUpdate" .. tostring(creationId))
        end
        -- print("time per block2: " .. tostring(
        --     sm.MTUtil.Profiler.Time.get("2checkForBodyUpdate" .. tostring(self.creationId)) /
        --     sm.MTUtil.Profiler.Count.get("2checkForBodyUpdate" .. tostring(self.creationId))
        -- ))
        -- print("time: " .. tostring(sm.MTUtil.Profiler.Time.get("2checkForBodyUpdate" .. tostring(self.creationId))))
        -- print("count: " .. sm.MTUtil.Profiler.Count.get("2checkForBodyUpdate" .. tostring(self.creationId)))
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