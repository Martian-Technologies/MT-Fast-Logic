dofile "../util/util.lua"
local string = string
local table = table

function FastLogicRunner.internalAddBlock(self, path, id, inputs, outputs, state, timerLength)
    -- path data
    if type(path) == "string" then
        path = self.pathIndexs[path]
    end
    self.runnableBlockPaths[id] = self.pathNames[path]
    self.runnableBlockPathIds[id] = path
    self.blocksSortedByPath[path][#self.blocksSortedByPath[path] + 1] = id

    -- init data
    -- self.displayedBlockStates[id] = self.creation.AllFastBlocks[self.unhashedLookUp[id]].state
    self.blockStates[id] = false
    self.blockInputs[id] = false
    self.blockInputsHash[id] = {}
    self.blockOutputs[id] = {}
    self.blockOutputsHash[id] = {}
    self.numberOfBlockInputs[id] = 0
    self.numberOfOtherInputs[id] = 0
    self.numberOfBlockOutputs[id] = 0
    self.countOfOnInputs[id] = 0
    self.countOfOnOtherInputs[id] = 0
    self.numberOfStateChanges[id] = 0
    self.numberOfOptimizedInputs[id] = 0
    self.optimizedBlockOutputs[id] = {}
    self.optimizedBlockOutputsPosHash[id] = {}
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
                self:internalAddOutput(v, id)
            end
        else
            self:internalAddOutput(inputs, id)
        end
    end

    -- outputs
    if path ~= self.pathIndexs["lightBlocks"] or path ~= self.pathIndexs["EndTickButtons"] then
        if outputs ~= nil then
            if type(outputs) == "table" then
                for _, v in pairs(outputs) do
                    self:internalAddOutput(id, v)
                end
            else
                self:internalAddOutput(id, outputs)
            end
        end
    end
    if path == self.pathIndexs["timerBlocks"] then
        self.timerLengths[id] = timerLength + 1
        self.timerInputStates[id] = false
        self:updateLongestTimer()
    end

    -- add block to next update tick
    self:internalAddBlockToUpdate(id)
end

function FastLogicRunner.internalRemoveBlock(self, id)
    if self.blockInputs[id] ~= false then
        if (type(self.blockInputs[id]) == "number") then
            self:internalRemoveOutput(self.blockInputs[id], id)
        else
            while self.blockInputs[id][1] ~= nil do
                self:internalRemoveOutput(self.blockInputs[id][1], id)
            end
        end
    end
    if self.blockOutputs[id] ~= false then
        while self.blockOutputs[id][1] ~= nil do
            self:internalRemoveOutput(id, self.blockOutputs[id][1])
        end
    end
    self:internalRemoveBlockFromUpdate(id)
    table.removeValue(self.blocksSortedByPath[self.runnableBlockPathIds[id]], id)
    self.numberOfStateChanges[id] = false
    self.blockStates[id] = false
    self.blockInputs[id] = false
    self.blockInputsHash[id] = false
    self.blockOutputs[id] = false
    self.blockOutputsHash[id] = false
    self.numberOfBlockInputs[id] = false
    self.numberOfOtherInputs[id] = false
    self.numberOfBlockOutputs[id] = false
    self.countOfOnInputs[id] = false
    self.countOfOnOtherInputs[id] = false
    self.runnableBlockPaths[id] = false
    self.nextRunningBlocks[id] = false
    self.runnableBlockPathIds[id] = false
    self.timerLengths[id] = false
    self.timerInputStates[id] = false
    self.numberOfOptimizedInputs[id] = false
    self.optimizedBlockOutputs[id] = false
    self.optimizedBlockOutputsPosHash[id] = false

    table.removeFromConstantKeysOnlyHash(self.hashData, self.unhashedLookUp[id])
end

function FastLogicRunner.internalAddInput(self, id, idToConnect)
    self:internalAddOutput(idToConnect, id)
end

function FastLogicRunner.internalRemoveInput(self, id, idToDeconnect)
    self:internalRemoveInput(idToConnect, id)
end

function FastLogicRunner.internalAddOutput(self, id, idToConnect)
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
                self.numberOfBlockInputs[idToConnect] = self.numberOfBlockInputs[idToConnect] + 1
            end
        elseif self.blockInputs[idToConnect] ~= id then      --if the block it is outputting too has one input
            local LL = { 2, 3 }
            if (self.blockInputs[idToConnect] ~= false) then --if there is already a block connected to that input
                self:internalRemoveOutput(self.blockInputs[idToConnect], idToConnect)
                -- print("WARNING: in addblock when creating block output confilct found (removing connection), line 139")
            end
            self.blockInputs[idToConnect] = id
            self.blockInputsHash[idToConnect][id] = true
            self.numberOfBlockInputs[idToConnect] = 1
        end

        -- update states
        self:fixBlockOutputData(id)
        self:fixBlockInputData(idToConnect)

        self:internalAddBlockToUpdate(idToConnect)
    end
end

function FastLogicRunner.internalRemoveOutput(self, id, idToDeconnect)
    if self.runnableBlockPaths[id] ~= false and self.runnableBlockPaths[idToDeconnect] ~= false and table.removeValue(self.blockOutputs[id], idToDeconnect) ~= nil then
        if self.optimizedBlockOutputsPosHash[id][idToDeconnect] ~= nil then
            local outputs = self.optimizedBlockOutputs[id]
            local outputsPosHash = self.optimizedBlockOutputsPosHash[id]
            local otherId = outputs[#outputs]                 -- get the top item on optimizedBlockOutputs
            outputs[outputsPosHash[idToDeconnect]] = otherId        -- set the pos of id in optimizedBlockOutputs to otherId
            outputs[#outputs] = nil                           -- sets the top item on optimizedBlockOutputs to nil
            outputsPosHash[otherId] = outputsPosHash[idToDeconnect] -- set otherId's pos to id's pos in posHash
            outputsPosHash[idToDeconnect] = nil                     -- remove id from posHash
        end

        self.blockOutputsHash[id][idToDeconnect] = nil
        self.numberOfBlockOutputs[id] = self.numberOfBlockOutputs[id] - 1
        if type(self.blockInputs[idToDeconnect]) == "table" then
            if table.removeValue(self.blockInputs[idToDeconnect], id) ~= nil then
                self.blockInputsHash[idToDeconnect][id] = nil
                self.numberOfBlockInputs[idToDeconnect] = self.numberOfBlockInputs[idToDeconnect] - 1
            end
        else
            self.blockInputs[idToDeconnect] = false
            self.blockInputsHash[idToDeconnect][id] = nil
            self.numberOfBlockInputs[idToDeconnect] = 0
        end

        self:fixBlockOutputData(id)
        self:fixBlockInputData(idToDeconnect)

        -- OLD update states
        -- if not table.contains({ 5 }, self.runnableBlockPathIds[id]) and self.blockStates[id] then
        --     self.countOfOnInputs[idToDeconnect] = self.countOfOnInputs[idToDeconnect] - 1
        --     self:internalAddBlockToUpdate(idToDeconnect)
        -- end
    end
end

function FastLogicRunner.fixBlockOutputData(self, id)
    local usedPosHash = {}
    local optimizedOutputs = self.optimizedBlockOutputs[id]
    for inputId, index in pairs(self.optimizedBlockOutputsPosHash[id]) do
        usedPosHash[index] = inputId
        if optimizedOutputs[index] == nil or (optimizedOutputs[index] ~= inputId and optimizedOutputs[index] ~= -1) then
            optimizedOutputs[index] = -1
        end
    end
    local i = 1
    while i <= #optimizedOutputs do
        if (
                usedPosHash[i] == nil or
                self.countOfOnInputs[usedPosHash[i]] == nil or
                self.countOfOnInputs[usedPosHash[i]] == false or
                self.blockOutputsHash[id][usedPosHash[i]] == nil
            ) then
            usedPosHash[i] = usedPosHash[#optimizedOutputs]
            usedPosHash[#optimizedOutputs] = nil

            local otherId = optimizedOutputs[#optimizedOutputs] -- get the top item on optimizedBlockOutputs
            optimizedOutputs[i] = otherId                       -- set the pos i in optimizedBlockOutputs to otherId
            optimizedOutputs[#optimizedOutputs] = nil           -- sets the top item on optimizedBlockOutputs to nil
            self.optimizedBlockOutputsPosHash[id][otherId] = i  -- set otherId's pos to i in posHash
        else
            i = i + 1
        end
    end
end

function FastLogicRunner.fixBlockInputData(self, id)
    if table.contains({ 6, 9 }, self.runnableBlockPathIds[id]) then -- all on blocks
        if self.numberOfBlockInputs[id] == 0 then
            self.numberOfOptimizedInputs[id] = 0
            self.countOfOnInputs[id] = 0
        else
            -- count number of on inputs
            self.numberOfOptimizedInputs[id] = 1
            local countedInputsHash = { [self.blockInputs[id][1]] = true }
            self.countOfOnInputs[id] = 0
            while self.blockStates[self.blockInputs[id][self.numberOfOptimizedInputs[id]]] do
                self.countOfOnInputs[id] = self.countOfOnInputs[id] + 1
                if self.numberOfOptimizedInputs[id] == self.numberOfBlockInputs[id] then
                    break
                end
                self.numberOfOptimizedInputs[id] = self.numberOfOptimizedInputs[id] + 1
                countedInputsHash[self.blockInputs[id][self.numberOfOptimizedInputs[id]]] = true
            end
            -- update the inputs
            for i = 1, self.numberOfBlockInputs[id] do
                local inputId = self.blockInputs[id][i]
                if self.optimizedBlockOutputsPosHash[inputId][id] == nil then
                    self.optimizedBlockOutputsPosHash[inputId][id] = #self.optimizedBlockOutputs[inputId] + 1
                    self.optimizedBlockOutputs[inputId][self.optimizedBlockOutputsPosHash[inputId][id]] = -1
                end
                if countedInputsHash[inputId] then
                    if not table.contains(self.optimizedBlockOutputs[inputId], id) then
                        self.optimizedBlockOutputs[inputId][self.optimizedBlockOutputsPosHash[inputId][id]] = id
                    end
                elseif table.contains(self.optimizedBlockOutputs[inputId], id) then
                    -- table.removeValue(self.optimizedBlockOutputs[inputId], id)
                    -- self.optimizedBlockOutputsPosHash[inputId][id] = nil

                    -- local outputs = self.optimizedBlockOutputs[inputId]
                    -- local outputsPosHash = self.optimizedBlockOutputsPosHash[inputId]
                    -- local otherId = outputs[#outputs]                 -- get the top item on optimizedBlockOutputs
                    -- outputs[outputsPosHash[id]] = otherId        -- set the pos of id in optimizedBlockOutputs to otherId
                    -- outputs[#outputs] = nil                           -- sets the top item on optimizedBlockOutputs to nil
                    -- outputsPosHash[otherId] = outputsPosHash[id] -- set otherId's pos to id's pos in posHash
                    -- outputsPosHash[id] = nil                     -- remove id from posHash

                    self.optimizedBlockOutputs[inputId][self.optimizedBlockOutputsPosHash[inputId][id]] = -1
                end
            end
        end
    elseif table.contains({ 7, 10 }, self.runnableBlockPathIds[id]) then -- all off blocks
        if self.numberOfBlockInputs[id] == 0 then
            self.numberOfOptimizedInputs[id] = 0
            self.countOfOnInputs[id] = 0
        else
            -- count number of off inputs
            self.numberOfOptimizedInputs[id] = 1
            local countedInputsHash = { [self.blockInputs[id][1]] = true }
            self.countOfOnInputs[id] = 1
            while not self.blockStates[self.blockInputs[id][self.numberOfOptimizedInputs[id]]] do
                if self.numberOfOptimizedInputs[id] == self.numberOfBlockInputs[id] then
                    self.countOfOnInputs[id] = 0
                    break
                end
                self.numberOfOptimizedInputs[id] = self.numberOfOptimizedInputs[id] + 1
                countedInputsHash[self.blockInputs[id][self.numberOfOptimizedInputs[id]]] = true
            end
            -- update the inputs
            for i = 1, self.numberOfBlockInputs[id] do
                local inputId = self.blockInputs[id][i]
                if self.optimizedBlockOutputsPosHash[inputId][id] == nil then
                    self.optimizedBlockOutputsPosHash[inputId][id] = #self.optimizedBlockOutputs[inputId] + 1
                    self.optimizedBlockOutputs[inputId][self.optimizedBlockOutputsPosHash[inputId][id]] = -1
                end
                if countedInputsHash[inputId] then
                    if not table.contains(self.optimizedBlockOutputs[inputId], id) then
                        self.optimizedBlockOutputs[inputId][self.optimizedBlockOutputsPosHash[inputId][id]] = id
                    end
                elseif table.contains(self.optimizedBlockOutputs[inputId], id) then
                    -- table.removeValue(self.optimizedBlockOutputs[inputId], id)
                    -- self.optimizedBlockOutputsPosHash[inputId][id] = nil

                    -- local outputs = self.optimizedBlockOutputs[inputId]
                    -- local outputsPosHash = self.optimizedBlockOutputsPosHash[inputId]
                    -- local otherId = outputs[#outputs]                 -- get the top item on optimizedBlockOutputs
                    -- outputs[outputsPosHash[id]] = otherId        -- set the pos of id in optimizedBlockOutputs to otherId
                    -- outputs[#outputs] = nil                           -- sets the top item on optimizedBlockOutputs to nil
                    -- outputsPosHash[otherId] = outputsPosHash[id] -- set otherId's pos to id's pos in posHash
                    -- outputsPosHash[id] = nil                     -- remove id from posHash

                    self.optimizedBlockOutputs[inputId][self.optimizedBlockOutputsPosHash[inputId][id]] = -1
                end
            end
        end
    elseif type(self.blockInputs[id]) == "table" then -- other
        if self.numberOfBlockInputs[id] == 0 then
            self.numberOfOptimizedInputs[id] = 0
            self.countOfOnInputs[id] = 0
        else
            self.numberOfOptimizedInputs[id] = self.numberOfBlockInputs[id]
            self.countOfOnInputs[id] = 0
            for i = 1, self.numberOfBlockInputs[id] do
                local inputId = self.blockInputs[id][i]
                if self.blockStates[inputId] then
                    self.countOfOnInputs[id] = self.countOfOnInputs[id] + 1
                end
                if self.optimizedBlockOutputsPosHash[inputId][id] == nil then
                    self.optimizedBlockOutputsPosHash[inputId][id] = #self.optimizedBlockOutputs[inputId] + 1
                    self.optimizedBlockOutputs[inputId][self.optimizedBlockOutputsPosHash[inputId][id]] = -1
                end
                if not table.contains(self.optimizedBlockOutputs[inputId], id) then
                    self.optimizedBlockOutputs[inputId][self.optimizedBlockOutputsPosHash[inputId][id]] = id
                end
            end
        end
    else
        if self.numberOfBlockInputs[id] == 0 then
            self.numberOfOptimizedInputs[id] = 0
            self.countOfOnInputs[id] = 0
        else
            local inputId = self.blockInputs[id]
            self.numberOfOptimizedInputs[id] = 1
            self.countOfOnInputs[id] = self.blockStates[inputId] and 1 or 0
            if not table.contains(self.optimizedBlockOutputs[inputId], id) then
                if self.optimizedBlockOutputsPosHash[inputId][id] == nil then
                    self.optimizedBlockOutputsPosHash[inputId][id] = #self.optimizedBlockOutputs[inputId] + 1
                end
                self.optimizedBlockOutputs[inputId][self.optimizedBlockOutputsPosHash[inputId][id]] = id
            end
        end
    end
    self:internalAddBlockToUpdate(id)
end

function FastLogicRunner.internalAddBlockToUpdate(self, id)
    if self.nextRunningBlocks[id] ~= self.nextRunningIndex and self.blockInputs[id] ~= false then
        self.nextRunningBlocks[id] = self.nextRunningIndex
        local pathId = self.runnableBlockPathIds[id]
        self.runningBlockLengths[pathId] = self.runningBlockLengths[pathId] + 1
        self.runningBlocks[pathId][self.runningBlockLengths[pathId]] = id
    end
end

function FastLogicRunner.internalRemoveBlockFromUpdate(self, id)
    if self.nextRunningBlocks[id] == self.nextRunningIndex then
        self.nextRunningBlocks[id] = self.nextRunningIndex - 1
        local pathId = self.runnableBlockPathIds[id]
        table.removeValue(self.runningBlocks[pathId], id)
        self.runningBlockLengths[pathId] = self.runningBlockLengths[pathId] - 1
    end
end

function FastLogicRunner.updateLongestTimer(self)
    for id, length in pairs(self.timerLengths) do
        if length ~= false and length > self.longestTimer then
            self.longestTimer = length
        end
    end
    while #self.timerData < self.longestTimer + 1 do
        self.timerData[#self.timerData + 1] = {}
    end
end

function FastLogicRunner.internalChangeTimerTime(self, id, time)
    if self.timerLengths[id] ~= time + 1 then
        self.timerLengths[id] = time + 1
        self:updateLongestTimer()
    end
end

--------------------------------------------------------

function FastLogicRunner.externalAddNonFastConnection(self, uuid)
    local id = self.hashedLookUp[uuid]
    if id ~= nil then
        self.numberOfOtherInputs[id] = self.numberOfOtherInputs[id] + 1
        self:internalAddBlockToUpdate(id)
    end
end

function FastLogicRunner.externalRemoveNonFastConnection(self, uuid)
    local id = self.hashedLookUp[uuid]
    if id ~= nil then
        self.numberOfOtherInputs[id] = self.numberOfOtherInputs[id] - 1
        self:internalAddBlockToUpdate(id)
    end
end

function FastLogicRunner.externalAddNonFastOnInput(self, uuid)
    local id = self.hashedLookUp[uuid]
    if id ~= nil then
        self.countOfOnOtherInputs[id] = self.countOfOnOtherInputs[id] + 1
        self:internalAddBlockToUpdate(id)
    end
end

function FastLogicRunner.externalRemoveNonFastOnInput(self, uuid)
    local id = self.hashedLookUp[uuid]
    if id ~= nil then
        self.countOfOnOtherInputs[id] = self.countOfOnOtherInputs[id] - 1
        self:internalAddBlockToUpdate(id)
    end
end

function FastLogicRunner.externalChangeNonFastOnInput(self, uuid, amount)
    local id = self.hashedLookUp[uuid]
    if id ~= nil then
        self.countOfOnOtherInputs[id] = self.countOfOnOtherInputs[id] + amount
        self:internalAddBlockToUpdate(id)
    end
end

function FastLogicRunner.externalAddBlock(self, block)
    if self.hashedLookUp[block.uuid] == nil then
        table.addToConstantKeysOnlyHash(self.hashData, block.uuid)
        local id = self.hashedLookUp[block.uuid]
        local inputs = table.hashArrayValues(self.hashData, block.inputs)
        local outputs = table.hashArrayValues(self.hashData, block.outputs)
        self:internalAddBlock(block.type, id, inputs, outputs, block.state, block.timerLength)
        local missingInputs = table.getMissingHashValues(self.hashData, block.inputs)
        for i = 1, #missingInputs do
            self.blocksToAddInputs[#self.blocksToAddInputs + 1] = { block.uuid, missingInputs[i] }
        end
        local missingOutputs = table.getMissingHashValues(self.hashData, block.outputs)
        for i = 1, #missingOutputs do
            self.blocksToAddInputs[#self.blocksToAddInputs + 1] = { missingOutputs[i], block.uuid }
        end
    end
end

function FastLogicRunner.externalRemoveBlock(self, uuid)
    local id = self.hashedLookUp[uuid]
    if id ~= nil then
        self:internalRemoveBlock(id)
    end
end

function FastLogicRunner.externalAddInput(self, uuid, uuidToConnect)
    local id = self.hashedLookUp[uuid]
    local idToConnect = self.hashedLookUp[uuidToConnect]
    if id ~= nil and idToConnect ~= nil then
        self:internalAddInput(id, idToConnect)
    end
end

function FastLogicRunner.externalRemoveInput(self, uuid, uuidToDeconnect)
    local id = self.hashedLookUp[uuid]
    local idToDeconnect = self.hashedLookUp[uuidToDeconnect]
    if id ~= nil and idToDeconnect ~= nil then
        self:internalRemoveInput(id, idToDeconnect)
    end
end

function FastLogicRunner.externalAddOutput(self, uuid, uuidToConnect)
    local id = self.hashedLookUp[uuid]
    local idToConnect = self.hashedLookUp[uuidToConnect]
    if id ~= nil and idToConnect ~= nil then
        self:internalAddOutput(id, idToConnect)
    end
end

function FastLogicRunner.externalRemoveOutput(self, uuid, uuidToDeconnect)
    local id = self.hashedLookUp[uuid]
    local idToDeconnect = self.hashedLookUp[uuidToDeconnect]
    if id ~= nil and idToDeconnect ~= nil then
        self:internalRemoveOutput(id, idToDeconnect)
    end
end

function FastLogicRunner.externalAddBlockToUpdate(self, uuid)
    local id = self.hashedLookUp[uuid]
    if id ~= nil then
        self:internalAddBlockToUpdate(id)
    end
end

function FastLogicRunner.externalRemoveBlockFromUpdate(self, uuid)
    local id = self.hashedLookUp[uuid]
    if id ~= nil then
        self:internalRemoveBlockFromUpdate(id)
    end
end
