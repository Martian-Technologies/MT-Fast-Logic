dofile "../util/util.lua"
dofile "../fastLogicBlock/FastLogicRunner.lua"

function FastLogicRealBlockMannager.checkForNewInputs(self)
    for id, data in pairs(self.creation.AllNonFastBlocks) do
        if sm.exists(data.interactable) then
            if data.currentState ~= data.interactable.active then
                data.currentState = data.interactable.active
                local stateNumber = data.currentState and 1 or -1
                local i = 1
                while i <= #data.outputs do
                    local outputId = data.outputs[i]
                    if type(self.creation.AllFastBlocks[outputId]) ~= nil then
                        self.FastLogicRunner:externalChangeNonFastOnInput(outputId, stateNumber)
                    else
                        if table.contains(data.outputs, outputId) then
                            if #data.outputs == 1 then
                                self.creation.AllNonFastBlocks[id] = nil
                            else
                                table.removeValue(data.outputs, outputId)
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

function FastLogicRealBlockMannager.checForBodyUpdate(self)
    local scanNext
    if not sm.exists(self.creation.body) or self.creation.body:hasChanged(self.creation.lastBodyUpdate) then
        self.creation.lastBodyUpdate = sm.game.getCurrentTick()
        scanNext = self.creation.AllFastBlocks
    else
        scanNext = self.scanNext
    end

    for id, block in pairs(scanNext) do
        if self.creationId ~= sm.MTFastLogic.FastLogicRunnerRunner:getCreationId(block.shape:getBody()) then
            block:deepRescanSelf()
        else
            local id = block.id
            -- self.FastLogicRunner:externalAddBlockToUpdate(id)
            local inputs = block.interactable:getParents()
            local inputsHash = {}
            for _, v in pairs(inputs) do
                local inputId = v:getId()
                inputsHash[inputId] = true
                if self.creation.AllFastBlocks[inputId] ~= nil then
                    self.FastLogicAllBlockMannager:addOutput(inputId, id)
                else
                    local currentState = v.active
                    if self.creation.AllNonFastBlocks[inputId] == nil then
                        self.creation.AllNonFastBlocks[inputId] = { ["interactable"] = v, ["currentState"] = currentState, ["outputs"] = {} }
                    end
                    if not table.contains(self.creation.AllNonFastBlocks[inputId].outputs, id) then
                        self.creation.AllNonFastBlocks[inputId].outputs[#self.creation.AllNonFastBlocks[inputId].outputs + 1] = id
                    end
                    local activeInput = block.activeInputs[inputId]
                    if (activeInput == nil) then
                        self.FastLogicRunner:externalAddNonFastConnection(id)
                        if currentState then
                            self.FastLogicRunner:externalAddNonFastOnInput(id)
                            block.activeInputs[inputId] = true
                        else
                            block.activeInputs[inputId] = false
                        end
                    elseif activeInput ~= currentState then
                        block.activeInputs[inputId] = currentState
                        self.FastLogicRunner:externalAddBlockToUpdate(id)
                    end
                end
            end
            for k, state in pairs(block.activeInputs) do
                if inputsHash[k] == nil then
                    if table.contains(self.creation.AllNonFastBlocks[k].outputs, id) then
                        if self.creation.AllNonFastBlocks[k].currentState then
                            self.FastLogicRunner:externalRemoveNonFastOnInput(id)
                        end
                        if #self.creation.AllNonFastBlocks[k].outputs == 1 then
                            self.creation.AllNonFastBlocks[k] = nil
                        else
                            table.removeValue(self.creation.AllNonFastBlocks[k].outputs, id)
                        end
                    end
                    block.activeInputs[k] = nil
                    self.FastLogicRunner:externalRemoveNonFastConnection(id)
                end
            end
            local inputs = self.creation.blocks[id].inputs
            for i = 0, #inputs do
                if inputsHash[inputs[i]] == nil then
                    self.FastLogicAllBlockMannager:removeOutput(inputs[i], id)
                end
            end
        end
    end
    self.scanNext = {}
end
