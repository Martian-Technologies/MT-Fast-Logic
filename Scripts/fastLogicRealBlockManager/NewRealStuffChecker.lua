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
    local scanNext
    if self:checkForCreationDeletion() then
        return
    elseif self.creation.body:hasChanged(self.creation.lastBodyUpdate) then
        self.creation.lastBodyUpdate = sm.game.getCurrentTick()
        self.scanNext = self.creation.AllFastBlocks
        self:scanSiliconBlocks()
    end
    scanNext = self.scanNext

    -- if table.length(scanNext) > 0 then
    --     sm.MTUtil.Profiler.Time.on("checkForBodyUpdate" .. tostring(self.creationId))
    if self.FastLogicRunner.isNew ~= nil then return end
    for uuid, block in pairs(scanNext) do
        if block == nil or block.shape == nil then
        elseif self.creationId ~= sm.MTFastLogic.CreationUtil.getCreationIdFromBlock(block) then
            block:deepRescanSelf()
        else
            self.FastLogicAllBlockManager:setColor(uuid, block.shape.color:getHexStr())
            local inputs = block.interactable:getParents()
            local inputsHash = {}
            local inputUuidsHash = self.creation.blocks[uuid].inputsHash
            for _, v in pairs(inputs) do
                if sm.exists(v) then
                    local inputId = v:getId()
                    local inputUuid = self.creation.uuids[inputId]
                    inputsHash[inputId] = true
                    if inputUuid ~= nil then
                        self.FastLogicAllBlockManager:addOutput(inputUuid, uuid)
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
                    self.FastLogicAllBlockManager:removeOutput(inputUuid, uuid)
                end
            end
        end
    end
    -- sm.MTUtil.Profiler.Time.off("checkForBodyUpdate" .. tostring(self.creationId))
    -- print("time per blocks")
    -- print("time: " .. tostring(sm.MTUtil.Profiler.Time.get("checkForBodyUpdate" .. tostring(self.creationId))))
    -- print("count: " .. tostring(table.length(scanNext)))
    -- sm.MTUtil.Profiler.Time.reset("checkForBodyUpdate" .. tostring(self.creationId))
    -- end
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