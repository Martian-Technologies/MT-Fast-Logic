dofile "../util/util.lua"

function FastLogicRunner.AddBlock(self, path, id, inputs, outputs, state, timerLength)
    -- path data
    if type(path) == "string" then
        path = self.pathIndexs[path]
    end
    self.runnableBlockPaths[id] = self.pathNames[path]
    self.runnableBlockPathIds[id] = path
    self.blocksSortedByPath[path][#self.blocksSortedByPath[path]+1] = id

    -- init data
    -- self.displayedBlockStates[id] = self.creation.AllFastBlocks[self.unhashedLookUp[id]].state
    self.scanNext[id] = self.unhashedLookUp[id]
    self.blockStates[id] = state or false
    self.blockInputs[id] = false
    self.blockInputsHash[id] = {}
    self.blockOutputs[id] = {}
    self.blockOutputsHash[id] = {}
    self.numberOfBlockInputs[id] = -1
    self.numberOfBlockOutputs[id] = 0
    self.countOfOnInputs[id] = 0

    if (
            path == self.pathIndexs["norThroughBlocks"] or
            path == self.pathIndexs["throughBlocks"] or
            path == self.pathIndexs["timerBlocks"] or
            path == self.pathIndexs["lightBlocks"]
        ) then
        self.blockInputs[id] = false
    else
        self.blockInputs[id] = {}
    end

    if inputs ~= nil then
        if type(inputs) == "table" then
            for _, v in pairs(inputs) do
                self:AddOutput(v, id)
            end
        else
            self:AddOutput(inputs, id)
        end
    end

    -- outputs
    if path ~= self.pathIndexs["lightBlocks"] or path ~= self.pathIndexs["EndTickButtons"] then
        if outputs ~= nil then
            if type(outputs) == "table" then
                for _, v in pairs(outputs) do
                    self:AddOutput(id, v)
                end
            else
                self:AddOutput(id, outputs)
            end
        end
    end
    if path == self.pathIndexs["timerBlocks"] then
        self.timerLengths[id] = timerLength + 1
        self.timerInputStates[id] = false
        self:UpdateLongestTimer()
    end

    if (self.numberOfBlockInputs[id] == 0) then
        self.numberOfBlockInputs = -1
    end

    -- add block to next update tick
    self:AddBlockToUpdate(id)

    self.blockCount = self.blockCount + 1
    self.isEmpty = false
end

function FastLogicRunner.RemoveBlock(self, id)
    table.removeFromConstantKeysOnlyHash(self.hashData, self.unhashedLookUp[id])
    if self.blockInputs[id] ~= false then
        if (type(self.blockInputs[id]) == "number") then
            self:RemoveOutput(self.blockInputs[id], id)
        else
            while self.blockInputs[id][1] ~= nil do
                self:RemoveOutput(self.blockInputs[id][1], id)
            end
        end
    end
    if self.blockOutputs[id] ~= false then
        while self.blockOutputs[id][1] ~= nil do
            self:RemoveOutput(id, self.blockOutputs[id][1])
        end
    end
    self:RemoveBlockFromUpdate(id)
    table.removeValue(self.blocksSortedByPath[self.runnableBlockPathIds[id]], id)
    self.scanNext[id] = nil
    self.blockStates[id] = false
    self.blockInputs[id] = false
    self.blockInputsHash[id] = false
    self.blockOutputs[id] = false
    self.blockOutputsHash[id] = false
    self.numberOfBlockInputs[id] = false
    self.numberOfBlockOutputs[id] = false
    self.countOfOnInputs[id] = false
    self.runnableBlockPaths[id] = false
    self.nextRunningBlocks[id] = false
    self.runnableBlockPathIds[id] = false
    self.timerLengths[id] = false
    self.timerInputStates[id] = false
    self.blockCount = self.blockCount - 1
    if self.blockCount <= 0 then
        self.isEmpty = true
    end
end

function FastLogicRunner.AddInput(self, id, idToConnect)
    self:AddOutput(idToConnect, id)
end

function FastLogicRunner.RemoveInput(self, id, idToDeconnect)
    self:RemoveInput(idToConnect, id)
end

function FastLogicRunner.AddOutput(self, id, idToConnect)
    if self.runnableBlockPaths[id] ~= false and self.runnableBlockPaths[idToConnect] ~= false and not table.contains(self.blockOutputs[id], idToConnect) then
        -- add outputs
        self.blockOutputs[id][#self.blockOutputs[id] + 1] = idToConnect
        self.blockOutputsHash[id][idToConnect] = true
        self.numberOfBlockOutputs[id] = self.numberOfBlockOutputs[id] + 1
        -- inputs
        if type(self.blockInputs[idToConnect]) == "table" then --if the block it is outputting too has a input table
            if not table.contains(self.blockInputs[idToConnect], id) then
                self.blockInputs[idToConnect][#self.blockInputs[idToConnect] + 1] = id
                self.blockInputsHash[idToConnect][id] = true
                if self.numberOfBlockInputs[idToConnect] == -1 then
                    self.numberOfBlockInputs[idToConnect] = 1
                else
                    self.numberOfBlockInputs[idToConnect] = self.numberOfBlockInputs[idToConnect] + 1
                end
            end
        else                                                     --if the block it is outputting too has one input
            if self.blockInputs[idToConnect] ~= id then
                if (self.blockInputs[idToConnect] ~= false) then --if there is already a block connected to that input
                    self:RemoveOutput(self.blockInputs[idToConnect], idToConnect)
                    print("WARNING: in addblock when creating block output confilct found (removing connection), line 71")
                end
                self.blockInputs[idToConnect] = id
                self.blockInputsHash[idToConnect][id] = true
                self.numberOfBlockInputs[idToConnect] = 1
            end
        end

        -- update states
        if self.blockStates[id] then
            self.countOfOnInputs[idToConnect] = self.countOfOnInputs[idToConnect] + 1
        end
        self:AddBlockToUpdate(idToConnect)
    end
end

function FastLogicRunner.RemoveOutput(self, id, idToDeconnect)
    if self.runnableBlockPaths[id] ~= false and self.runnableBlockPaths[idToDeconnect] ~= false and table.removeValue(self.blockOutputs[id], idToDeconnect) ~= nil then
        self.blockOutputsHash[id][idToDeconnect] = nil
        self.numberOfBlockOutputs[id] = self.numberOfBlockOutputs[id] - 1
        if type(self.blockInputs[idToDeconnect]) == "table" then
            if table.removeValue(self.blockInputs[idToDeconnect], id) ~= nil then
                self.blockInputsHash[idToDeconnect][id] = nil
                if self.numberOfBlockInputs[idToDeconnect] == 1 then
                    self.numberOfBlockInputs[idToDeconnect] = -1
                else
                    self.numberOfBlockInputs[idToDeconnect] = self.numberOfBlockInputs[idToDeconnect] - 1
                end
            end
        else
            self.blockInputs[idToDeconnect] = false
            self.blockInputsHash[idToDeconnect][id] = nil
            self.numberOfBlockInputs[idToDeconnect] = 0
        end

        -- update states
        if self.blockStates[id] then
            self.countOfOnInputs[idToDeconnect] = self.countOfOnInputs[idToDeconnect] - 1
            self:AddBlockToUpdate(idToDeconnect)
        end
    end
end

function FastLogicRunner.AddBlockToUpdate(self, id)
    if self.nextRunningBlocks[id] ~= self.nextRunningIndex then
        self.nextRunningBlocks[id] = self.nextRunningIndex
        local pathId = self.runnableBlockPathIds[id]
        self.runningBlockLengths[pathId] = self.runningBlockLengths[pathId] + 1
        self.runningBlocks[pathId][self.runningBlockLengths[pathId]] = id
    end
end

function FastLogicRunner.RemoveBlockFromUpdate(self, id)
    if self.nextRunningBlocks[id] == self.nextRunningIndex then
        self.nextRunningBlocks[id] = self.nextRunningIndex - 1
        local pathId = self.runnableBlockPathIds[id]
        table.removeValue(self.runningBlocks[pathId], id)
        self.runningBlockLengths[pathId] = self.runningBlockLengths[pathId] - 1
    end
end

function FastLogicRunner.UpdateLongestTimer(self)
    for id, length in pairs(self.timerLengths) do
        if length ~= false and length > self.longestTimer then
            self.longestTimer = length
        end
    end
    while #self.timerData < self.longestTimer + 1 do
        self.timerData[#self.timerData + 1] = {}
    end
end

function FastLogicRunner.ChangeTimerTime(self, id, time)
    if self.timerLengths[id] ~= time + 1 then
        self.timerLengths[id] = time + 1
        self:UpdateLongestTimer()
    end
end

--------------------------------------------------------

function FastLogicRunner.ExtAddOther(self, id)
    if self.numberOfBlockInputs[id] == -1 then
        self.numberOfBlockInputs[id] = 1
    else
        self.numberOfBlockInputs[id] = self.numberOfBlockInputs[id] + 1
    end
    self:AddBlockToUpdate(id)
end

function FastLogicRunner.ExtRemoveOther(self, id)
    if self.numberOfBlockInputs[id] == 1 then
        self.numberOfBlockInputs[id] = -1
    else
        self.numberOfBlockInputs[id] = self.numberOfBlockInputs[id] - 1
    end
    self:AddBlockToUpdate(id)
end

function FastLogicRunner.ExtRemoveBlock(self, id)
    if self.hashedLookUp[id] ~= nil then
        self:RemoveBlock(self.hashedLookUp[id])
    end
end
