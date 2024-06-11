dofile "../util/util.lua"
local string = string
local table = table
local type = type
local pairs = pairs

function FastLogicRunner.internalAddBlock(self, path, id, inputs, outputs, state, timerLength)
    -- path data
    local pathName
    if type(path) == "string" then
        pathName = path
        path = self.pathIndexs[pathName]
    else
        pathName = self.pathNames[path]
    end
    self.runnableBlockPaths[id] = pathName
    self.runnableBlockPathIds[id] = path
    self.blocksSortedByPath[path][#self.blocksSortedByPath[path] + 1] = id

    -- init data
    -- self.displayedBlockStates[id] = self.creation.AllFastBlocks[self.unhashedLookUp[id]].state
    self.blockStates[id] = false
    self.blockInputs[id] = {}
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
    if pathName == "multiBlocks" then
        if type(inputs) == "number" then
            inputs = {inputs}
        elseif inputs == nil then
            inputs = {}
        end
        self.multiBlockData[id] = {0, {}, {}, {}, {}, 0} -- id, all blocks, inputs, outputs, score, otherdata...
    else
        self.multiBlockData[id] = false

        if type(inputs) == "table" then
            for i = 1, #inputs do
                if inputs[i] ~= nil then
                    self:internalAddOutput(inputs[i], id, false)
                    self:fixBlockOutputData(inputs[i])
                end
            end
        elseif inputs ~= nil then
            self:internalAddOutput(inputs, id, false)
            self:fixBlockOutputData(inputs)
        end
        self:fixBlockInputData(id)
        self:shouldBeThroughBlock(id)

        -- outputs
        if pathName ~= "lightBlocks" or pathName ~= "EndTickButtons" then
            if type(outputs) == "table" then
                for i = 1, #outputs do
                    if outputs[i] ~= nil then
                        self:internalAddOutput(id, outputs[i], false)
                        self:fixBlockInputData(outputs[i])
                        self:shouldBeThroughBlock(outputs[i])
                    end
                end
            elseif outputs ~= nil then
                self:internalAddOutput(id, outputs, false)
                self:fixBlockInputData(outputs)
                self:shouldBeThroughBlock(outputs)
            end
        end
        self:fixBlockOutputData(id)

        if pathName == "timerBlocks" then
            self.timerLengths[id] = timerLength + 1
            self.timerInputStates[id] = false
            self:updateLongestTimer()
        end
    end
    -- add block to next update tick
    -- self:internalAddBlockToUpdate(id) -- dont need to do because self.fixBlockInputData also calls this
end

function FastLogicRunner.internalRemoveBlock(self, id)
    if self.runnableBlockPaths[id] == "multiBlocks" then
        local states = self:internalGetMultiBlockInternalStates(id)
        local multiData = self.multiBlockData[id]
        for i = 1, #multiData[2] do
            local blockId = multiData[2][i]
            self.multiBlockData[blockId] = false
        end
        for i = 1, #multiData[3] do
            local blockId = multiData[3][i]
            self:revertBlockType(blockId)
            self:shouldBeThroughBlock(blockId)
        end
        if multiData[1] == 1 then
            for i = 1, #multiData[3] do
                local blockId = multiData[3][i]
                -- update blockOutputs
                local outputs = self.optimizedBlockOutputs[blockId]
                for j = 1, #outputs do
                    local outputId = outputs[j]
                    if outputId ~= -1 then
                        self:externalAddBlockToUpdate(outputId)
                    end
                end
            end
        else
        end
    else
        if self.multiBlockData[id] ~= false then
            self:internalRemoveBlock(self.multiBlockData[id])
        end
        local inputs = self.blockInputs[id]
        if inputs ~= false then
            local inputId = inputs[1]
            while inputId ~= nil do
                self:internalRemoveOutput(inputId, id, false)
                self:fixBlockOutputData(inputId)
                inputId = inputs[1]
            end
        end
        local outputs = self.blockOutputs[id]
        if outputs ~= false then
            local outputId = outputs[1]
            while outputId ~= nil do
                self:internalRemoveOutput(id, outputId, false)
                self:fixBlockInputData(outputId)
                self:shouldBeThroughBlock(outputId)
                self:internalAddBlockToUpdate(outputId)
                outputId = outputs[1]
            end
        end
        self:clearTimerData(id)
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
    self.altBlockData[id] = false
    self.multiBlockData[id] = false

    table.removeFromConstantKeysOnlyHash(self.hashData, self.unhashedLookUp[id])
end

function FastLogicRunner.internalGetMultiBlockInternalStates(self, multiBlockId)
    local multiData = self.multiBlockData[multiBlockId]
    if multiData[1] == nil then
    else
        
    end
end

function FastLogicRunner.internalFakeAddBlock(self, path, inputs, outputs, state, timerLength)
    local newBlockId = table.addBlankToConstantKeysOnlyHash(self.hashData)
    self:internalAddBlock(path, newBlockId, inputs, outputs, state, timerLength)
    return newBlockId
end

function FastLogicRunner.internalAddMultiBlock(self, multiBlockType)
    local multiBlockId =  self:internalFakeAddBlock(16, {}, {}, false, nil) -- 16 is the multiBlocks id
    self.multiBlockData[multiBlockId][1] = multiBlockType
    return multiBlockId
end

function FastLogicRunner.internalAddBlockToMultiBlock(self, id, multiBlockId, isInput, isOutput)
    multiBlockData = self.multiBlockData
    if multiBlockData[id] == false then
        multiBlockData[id] = multiBlockId
        multiBlockData[multiBlockId][2][#multiBlockData[multiBlockId][2]+1] = id
    end
    if isInput and (multiBlockData[id] == false or not table.contains(multiBlockData[multiBlockId][3], id))then
        multiBlockData[multiBlockId][3][#multiBlockData[multiBlockId][3]+1] = id
    end
    if isOutput and (self.multiBlockData[id] == false or not table.contains(multiBlockData[multiBlockId][4], id)) then
        multiBlockData[multiBlockId][4][#multiBlockData[multiBlockId][4]+1] = id
    end
end

function FastLogicRunner.internalAddInput(self, id, idToConnect, withFixes)
    self:internalAddOutput(idToConnect, id, withFixes)
end

function FastLogicRunner.internalRemoveInput(self, id, idToDeconnect, withFixes)
    self:internalRemoveInput(idToConnect, id, withFixes)
end

function FastLogicRunner.internalAddOutput(self, id, idToConnect, withFixes)
    if self.runnableBlockPaths[id] ~= false and self.runnableBlockPaths[idToConnect] ~= false and not table.contains(self.blockOutputs[id], idToConnect) then
        -- remove from multi blocks
        if self.multiBlockData[id] ~= false then
            self:internalRemoveBlock(self.multiBlockData[id])
        end
        if self.multiBlockData[idToConnect] ~= false then
            self:internalRemoveBlock(self.multiBlockData[idToConnect])
        end
        -- add outputs
        self.blockOutputs[id][#self.blockOutputs[id] + 1] = idToConnect
        self.blockOutputsHash[id][idToConnect] = true
        self.numberOfBlockOutputs[id] = self.numberOfBlockOutputs[id] + 1
        -- inputs
        if not table.contains(self.blockInputs[idToConnect], id) then
            self.blockInputs[idToConnect][#self.blockInputs[idToConnect] + 1] = id
            self.blockInputsHash[idToConnect][id] = true
            self.numberOfBlockInputs[idToConnect] = self.numberOfBlockInputs[idToConnect] + 1
        end

        -- update states
        if withFixes ~= false then
            self:fixBlockOutputData(id)
            self:fixBlockInputData(idToConnect)
            self:shouldBeThroughBlock(idToConnect)
        end
    end
end

function FastLogicRunner.internalRemoveOutput(self, id, idToDeconnect, withFixes)
    if self.runnableBlockPaths[id] ~= false and self.runnableBlockPaths[idToDeconnect] ~= false and table.removeValue(self.blockOutputs[id], idToDeconnect) ~= nil then
        -- if self.optimizedBlockOutputsPosHash[id][idToDeconnect] ~= nil then
        --     local outputs = self.optimizedBlockOutputs[id]
        --     local outputsPosHash = self.optimizedBlockOutputsPosHash[id]
        --     local otherId = outputs[#outputs]                 -- get the top item on optimizedBlockOutputs
        --     outputs[outputsPosHash[idToDeconnect]] = otherId        -- set the pos of id in optimizedBlockOutputs to otherId
        --     outputs[#outputs] = nil                           -- sets the top item on optimizedBlockOutputs to nil
        --     outputsPosHash[otherId] = outputsPosHash[idToDeconnect] -- set otherId's pos to id's pos in posHash
        --     outputsPosHash[idToDeconnect] = nil                     -- remove id from posHash
        -- end

        -- remove from multi blocks
        if self.multiBlockData[id] ~= false then
            self:internalRemoveBlock(self.multiBlockData[id])
        end
        if self.multiBlockData[idToDeconnect] ~= false then
            self:internalRemoveBlock(self.multiBlockData[idToDeconnect])
        end

        self.blockOutputsHash[id][idToDeconnect] = nil
        self.numberOfBlockOutputs[id] = self.numberOfBlockOutputs[id] - 1
        if table.removeValue(self.blockInputs[idToDeconnect], id) ~= nil then
            self.blockInputsHash[idToDeconnect][id] = nil
            self.numberOfBlockInputs[idToDeconnect] = self.numberOfBlockInputs[idToDeconnect] - 1
        end

        if withFixes ~= false then
            self:fixBlockOutputData(id)
            self:fixBlockInputData(idToDeconnect)
            self:shouldBeThroughBlock(idToDeconnect)
        end

        -- OLD update states
        -- if not table.contains({ 5 }, self.runnableBlockPathIds[id]) and self.blockStates[id] then
        --     self.countOfOnInputs[idToDeconnect] = self.countOfOnInputs[idToDeconnect] - 1
        --     self:internalAddBlockToUpdate(idToDeconnect)
        -- end
    end
end

function FastLogicRunner.fixBlockOutputData(self, id)
    -- if self.optimizedBlockOutputsPosHash[id] == nil then return end
    -- print(self.optimizedBlockOutputsPosHash[id])
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
            if usedPosHash[i] ~= nil then
                self.optimizedBlockOutputsPosHash[id][usedPosHash[i]] = nil -- set usedPosHash[i]'s pos to nil in posHash
            end
            usedPosHash[i] = usedPosHash[#optimizedOutputs]
            usedPosHash[#optimizedOutputs] = nil

            local otherId = optimizedOutputs[#optimizedOutputs]         -- get the top item on optimizedBlockOutputs
            optimizedOutputs[i] = otherId                               -- set the pos i in optimizedBlockOutputs to otherId
            optimizedOutputs[#optimizedOutputs] = nil                   -- sets the top item on optimizedBlockOutputs to nil
            self.optimizedBlockOutputsPosHash[id][otherId] = i          -- set otherId's pos to i in posHash
            
        else
            i = i + 1
        end
    end
end

function FastLogicRunner.fixBlockInputData(self, id)
    local path = self.runnableBlockPathIds[id]
    if runnableBlockPathIds == 7 or runnableBlockPathIds == 12 then -- all on blocks
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
                    self.optimizedBlockOutputs[inputId][self.optimizedBlockOutputsPosHash[inputId][id]] = -1
                end
            end
        end
    elseif runnableBlockPathIds == 9 or runnableBlockPathIds == 14 then -- all off blocks
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
                    self.optimizedBlockOutputs[inputId][self.optimizedBlockOutputsPosHash[inputId][id]] = -1
                end
            end
        end
    else -- other
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

function FastLogicRunner.updateLongestTimerToLength(self, length)
    if length > self.longestTimer then
        self.longestTimer = length
    end
    while #self.timerData < self.longestTimer + 1 do
        self.timerData[#self.timerData + 1] = {}
    end
end

function FastLogicRunner.clearTimerData(self, id)
    for i = 1, #self.timerData do
        for ii = 1, #self.timerData[i] do
            if self.timerData[i][ii] == id then
                table.remove(self.timerData[i], ii)
            end
        end
    end
    if self.timerInputStates[id] ~= self.blockStates[id] then
        self.blockStates[id] = not self.blockStates[id]
        local stateNumber = self.blockStates[id] and 1 or -1
        for i = 1, #self.blockOutputs[id] do
            local outputId = self.blockOutputs[id][i]
            self:internalAddBlockToUpdate(outputId)
            self.countOfOnInputs[outputId] = self.countOfOnInputs[outputId] + stateNumber
        end
    end
end

function FastLogicRunner.internalChangeTimerTime(self, id, time)
    if self.timerLengths[id] ~= time + 1 then
        -- remove from multi blocks
        if self.multiBlockData[id] ~= false then
            self:internalRemoveBlock(self.multiBlockData[id])
        end
        -- change to timer
        self:revertBlockType(id)
        -- change time
        self:clearTimerData(id)
        self.timerLengths[id] = time + 1
        self:updateLongestTimer()
        self:shouldBeThroughBlock(id)
    end
end

function FastLogicRunner.internalChangeBlockType(self, id, path)
    if type(path) == "string" then
        path = self.pathIndexs[path]
    end
    if (self.runnableBlockPathIds[id] ~= path and self.altBlockData[id] == nil) or (self.altBlockData[id] ~= path and self.altBlockData[id] ~= nil) then
        self.altBlockData[id] = false
        local oldPath = self.runnableBlockPathIds[id]
        -- remove from multi blocks
        if self.multiBlockData[id] ~= false then
            self:internalRemoveBlock(self.multiBlockData[id])
        end

        -- remove old
        table.removeValue(self.blocksSortedByPath[oldPath], id)

        -- add new
        self.runnableBlockPaths[id] = self.pathNames[path]
        self.runnableBlockPathIds[id] = path
        self.blocksSortedByPath[path][#self.blocksSortedByPath[path] + 1] = id
        if self.nextRunningBlocks[id] == self.nextRunningIndex then
            for i = 1, self.runningBlockLengths[oldPath] do
                if (self.runningBlocks[oldPath][i] == id) then
                    table.remove(self.runningBlocks[oldPath], i)
                    self.runningBlockLengths[oldPath] = self.runningBlockLengths[oldPath] - 1
                    self.runningBlockLengths[path] = self.runningBlockLengths[path] + 1
                    self.runningBlocks[path][self.runningBlockLengths[path]] = id
                    break
                end
            end
        end

        self:fixBlockOutputData(id)
        self:fixBlockInputData(id)
        self:shouldBeThroughBlock(id)
    end
end

function FastLogicRunner.makeBlockAlt(self, id, blockType)
    local oldType = self.runnableBlockPathIds[id]

    if type(blockType) == "string" then
        blockType = self.pathIndexs[blockType]
    end
    if self.altBlockData[id] == blockType then
        self:revertBlockType(id)
    elseif oldType ~= blockType then
        if self.altBlockData[id] == false then
            self.altBlockData[id] = self.runnableBlockPathIds[id]
        end
        -- remove old
        table.removeValue(self.blocksSortedByPath[oldType], id)

        -- add new
        self.runnableBlockPaths[id] = self.pathNames[blockType]
        self.runnableBlockPathIds[id] = blockType
        self.blocksSortedByPath[blockType][#self.blocksSortedByPath[blockType] + 1] = id
        if self.nextRunningBlocks[id] == self.nextRunningIndex then
            for i = 1, self.runningBlockLengths[oldType] do
                if (self.runningBlocks[oldType][i] == id) then
                    table.remove(self.runningBlocks[oldType], i)
                    self.runningBlockLengths[oldType] = self.runningBlockLengths[oldType] - 1
                    self.runningBlockLengths[blockType] = self.runningBlockLengths[blockType] + 1
                    self.runningBlocks[blockType][self.runningBlockLengths[blockType]] = id
                    break
                end
            end
        end


        self:fixBlockOutputData(id)
        self:fixBlockInputData(id)
    end
end

function FastLogicRunner.revertBlockType(self, id)
    if self.altBlockData[id] ~= false then
        local blockType = self.altBlockData[id]
        local oldType = self.runnableBlockPathIds[id]
        if oldType ~= blockType then
            -- remove old
            table.removeValue(self.blocksSortedByPath[oldType], id)

            -- add new
            self.runnableBlockPaths[id] = self.pathNames[blockType]
            self.runnableBlockPathIds[id] = blockType
            self.blocksSortedByPath[blockType][#self.blocksSortedByPath[blockType] + 1] = id
            if self.nextRunningBlocks[id] == self.nextRunningIndex then
                for i = 1, self.runningBlockLengths[oldType] do
                    if (self.runningBlocks[oldType][i] == id) then
                        table.remove(self.runningBlocks[oldType], i)
                        self.runningBlockLengths[oldType] = self.runningBlockLengths[oldType] - 1
                        self.runningBlockLengths[blockType] = self.runningBlockLengths[blockType] + 1
                        self.runningBlocks[blockType][self.runningBlockLengths[blockType]] = id
                        break
                    end
                end
            end
            self:fixBlockOutputData(id)
            self:fixBlockInputData(id)
        end
    end
end

function FastLogicRunner.shouldBeThroughBlock(self, id)
    if self.numberOfBlockInputs[id] + self.numberOfOtherInputs[id] <= 1 then
        if self.runnableBlockPathIds[id] < 16 then
            if self.runnableBlockPathIds[id] >= 11 then    -- nand nor xnor
                self:makeBlockAlt(id, 4)
            elseif self.runnableBlockPathIds[id] >= 6 then -- and or xor
                self:makeBlockAlt(id, 3)
            elseif self.runnableBlockPathIds[id] == 5 then -- timer
                if self.timerLengths[id] == 1 then
                    self:makeBlockAlt(id, 3)
                else
                    self:revertBlockType(id)
                end
            end
        end
    else
        self:revertBlockType(id)
    end
end

--------------------------------------------------------

function FastLogicRunner.externalAddNonFastConnection(self, uuid)
    local id = self.hashedLookUp[uuid]
    if id ~= nil then
        self.numberOfOtherInputs[id] = self.numberOfOtherInputs[id] + 1
        self:shouldBeThroughBlock(id)
        self:internalAddBlockToUpdate(id)
    end
end

function FastLogicRunner.externalRemoveNonFastConnection(self, uuid)
    local id = self.hashedLookUp[uuid]
    if id ~= nil then
        self.numberOfOtherInputs[id] = self.numberOfOtherInputs[id] - 1
        self:shouldBeThroughBlock(id)
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
        local inputs = table.hashArrayValues(self.hashData, block.inputs)
        local outputs = table.hashArrayValues(self.hashData, block.outputs)
        self:internalAddBlock(block.type, self.hashedLookUp[block.uuid], inputs, outputs, block.state, block.timerLength)
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

function FastLogicRunner.externalAddInput(self, uuid, uuidToConnect, withFixes)
    local id = self.hashedLookUp[uuid]
    local idToConnect = self.hashedLookUp[uuidToConnect]
    if id ~= nil and idToConnect ~= nil then
        self:internalAddOutput(idToConnect, id, withFixes)
    end
end

function FastLogicRunner.externalRemoveInput(self, uuid, uuidToDeconnect, withFixes)
    local id = self.hashedLookUp[uuid]
    local idToDeconnect = self.hashedLookUp[uuidToDeconnect]
    if id ~= nil and idToDeconnect ~= nil then
        self:internalRemoveOutput(idToDeconnect, id, withFixes)
    end
end

function FastLogicRunner.externalAddOutput(self, uuid, uuidToConnect, withFixes)
    local id = self.hashedLookUp[uuid]
    local idToConnect = self.hashedLookUp[uuidToConnect]
    if id ~= nil and idToConnect ~= nil then
        self:internalAddOutput(id, idToConnect, withFixes)
    end
end

function FastLogicRunner.externalRemoveOutput(self, uuid, uuidToDeconnect, withFixes)
    local id = self.hashedLookUp[uuid]
    local idToDeconnect = self.hashedLookUp[uuidToDeconnect]
    if id ~= nil and idToDeconnect ~= nil then
        self:internalRemoveOutput(id, idToDeconnect, withFixes)
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

function FastLogicRunner.externalChangeTimerTime(self, uuid, time)
    if self.hashedLookUp[uuid] ~= nil then
        self:internalChangeTimerTime(self.hashedLookUp[uuid], time)
    end
end

function FastLogicRunner.externalChangeBlockType(self, uuid, type)
    if self.hashedLookUp[uuid] ~= nil then
        self:internalChangeBlockType(self.hashedLookUp[uuid], type)
    end
end
