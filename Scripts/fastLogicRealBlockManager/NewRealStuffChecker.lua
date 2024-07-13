dofile "../util/util.lua"
dofile "../CreationUtil.lua"
local string = string
local table = table
local type = type
local pairs = pairs

dofile "../fastLogicBlock/FastLogicRunner.lua"

function FastLogicRealBlockManager.checkForNewInputs(self)
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
    local FastLogicAllBlockManager = self.FastLogicAllBlockManager
    local FastLogicRunner = self.FastLogicRunner
    local creationId = self.creationId
    local getCreationIdFromBlock = sm.MTFastLogic.CreationUtil.getCreationIdFromBlock
    local exists = sm.exists
    local scanNext
    if self:checkForCreationDeletion() then
        return
    elseif self.creation.body:hasChanged(self.creation.lastBodyUpdate) then
        self.creation.lastBodyUpdate = sm.game.getCurrentTick()
        self.scanNext = self.creation.AllFastBlocks
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
                -- sm.MTUtil.Profiler.Count.increment("2checkForBodyUpdate" .. tostring(creationId))
                -- sm.MTUtil.Profiler.Time.on("2checkForBodyUpdate" .. tostring(creationId))
                FastLogicAllBlockManager:setColor(uuid, block.shape.color)
                -- sm.MTUtil.Profiler.Time.off("2checkForBodyUpdate" .. tostring(creationId))

                local inputs = block.interactable:getParents()
               
                local inputsHash = {}
                local inputUuidsHash = blocks[uuid].inputsHash
                for i = 1, #inputs do
                    local v = inputs[i]
                    if exists(v) then
                        local inputId = v.id
                        local inputUuid = uuids[inputId]
                        inputsHash[inputId] = true
                        if inputUuid ~= nil then
                            local blockToConnect = blocks[inputUuid]
                            if (
                                blockData ~= nil and blockToConnect ~= nil and
                                (blockData.outputsHash[inputUuid] == nil or blockToConnect.inputsHash[uuid] == nil)
                            ) then
                                FastLogicAllBlockManager:addOutput(inputUuid, uuid)
                            end
                        else
                            local currentState = v.active
                            if AllNonFastBlocks[inputId] == nil then
                                AllNonFastBlocks[inputId] = {
                                    ["interactable"] = v,
                                    ["currentState"] = currentState,
                                    ["outputs"] = {}
                                }
                            end
                            if not table.contains(AllNonFastBlocks[inputId].outputs, uuid) then
                                AllNonFastBlocks[inputId].outputs[#AllNonFastBlocks[inputId].outputs + 1] = uuid
                            end
                            local activeInput = block.activeInputs[inputId]
                            if (activeInput == nil) then
                                FastLogicRunner:externalAddNonFastConnection(uuid)
                                if currentState then
                                    FastLogicRunner:externalAddNonFastOnInput(uuid)
                                    block.activeInputs[inputId] = true
                                else
                                    block.activeInputs[inputId] = false
                                end
                            elseif activeInput ~= currentState then
                                block.activeInputs[inputId] = currentState
                                FastLogicRunner:externalAddBlockToUpdate(uuid)
                            end
                        end
                    end
                end
               
                for k, state in pairs(block.activeInputs) do
                    if inputsHash[k] == nil then
                        if table.contains(AllNonFastBlocks[k].outputs, uuid) then
                            if AllNonFastBlocks[k].currentState then
                                FastLogicRunner:externalRemoveNonFastOnInput(uuid)
                            end
                            if #AllNonFastBlocks[k].outputs == 1 then
                                AllNonFastBlocks[k] = nil
                            else
                                table.removeValue(AllNonFastBlocks[k].outputs, uuid)
                            end
                        end
                        block.activeInputs[k] = nil
                        FastLogicRunner:externalRemoveNonFastConnection(uuid)
                    end
                end
                
                local inputs = blocks[uuid].inputs
                for i = 0, #inputs do
                    local inputUuid = inputs[i]
                    if inputsHash[ids[inputUuid]] == nil and blocks[inputUuid] ~= nil and blocks[inputUuid].isSilicon == false then
                        FastLogicAllBlockManager:removeOutput(inputUuid, uuid)
                    end
                end

            end
            -- sm.MTUtil.Profiler.Count.increment("checkForBodyUpdate" .. tostring(creationId))
            -- sm.MTUtil.Profiler.Time.off("checkForBodyUpdate" .. tostring(creationId))
        end
        
        -- print("-----------------------------------------------")
        -- print("time per block2: " .. tostring(
        --     sm.MTUtil.Profiler.Time.get("2checkForBodyUpdate" .. tostring(self.creationId)) /
        --     sm.MTUtil.Profiler.Count.get("2checkForBodyUpdate" .. tostring(self.creationId))
        -- ))
        -- print("time: " .. tostring(sm.MTUtil.Profiler.Time.get("2checkForBodyUpdate" .. tostring(self.creationId))))
        -- print("count: " .. sm.MTUtil.Profiler.Count.get("2checkForBodyUpdate" .. tostring(self.creationId)))
        -- print("time per block: " .. tostring(
        --     sm.MTUtil.Profiler.Time.get("checkForBodyUpdate" .. tostring(self.creationId)) /
        --     sm.MTUtil.Profiler.Count.get("checkForBodyUpdate" .. tostring(self.creationId))
        -- ))
        -- print("time: " .. tostring(sm.MTUtil.Profiler.Time.get("checkForBodyUpdate" .. tostring(self.creationId))))
        -- print("count: " .. sm.MTUtil.Profiler.Count.get("checkForBodyUpdate" .. tostring(self.creationId)))
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