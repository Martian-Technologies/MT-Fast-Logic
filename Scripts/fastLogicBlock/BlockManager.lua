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
                end
            end
        elseif inputs ~= nil then
            self:internalAddOutput(inputs, id, false)
        end
        self:shouldBeThroughBlock(id)

        -- outputs
        if pathName ~= "lightBlocks" or pathName ~= "EndTickButtons" then
            if type(outputs) == "table" then
                for i = 1, #outputs do
                    if outputs[i] ~= nil then
                        self:internalAddOutput(id, outputs[i], false)
                        self:shouldBeThroughBlock(outputs[i])
                    end
                end
            elseif outputs ~= nil then
                self:internalAddOutput(id, outputs, false)
                self:shouldBeThroughBlock(outputs)
            end
        end

        if pathName == "timerBlocks" then
            self.timerLengths[id] = timerLength + 1
            self.timerInputStates[id] = false
            self:updateLongestTimer()
        end
    end
    -- add block to next update tick
    self:internalAddBlockToUpdate(id)
end

function FastLogicRunner.internalRemoveBlock(self, id)
    if self.runnableBlockPaths[id] == "multiBlocks" then
        -- set new states of blocks
        local idStatePairs = self:internalGetMultiBlockInternalStates(id)
        self:internalSetBlockStates(idStatePairs)
        -- clear anything to do with multiBlock in timerData
        local multiData = self.multiBlockData[id]
        local endBlockId = multiData[4][1]
        local timerData = self.timerData
        for i = 1, multiData[7] do
            local timeDataAtTime = timerData[i]
            for k = 1, #timeDataAtTime do
                local item = timeDataAtTime[k]
                if type(item) ~= "number" and type(item[1]) == "boolean" and item[2] == endBlockId then
                    table.remove(timeDataAtTime, k)
                    break
                end
            end
        end
        -- do removal
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
                local outputs = self.blockOutputs[blockId]
                for j = 1, #outputs do
                    self:externalAddBlockToUpdate(outputs[j])
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
                inputId = inputs[1]
            end
        end
        local outputs = self.blockOutputs[id]
        if outputs ~= false then
            local outputId = outputs[1]
            while outputId ~= nil do
                self:internalRemoveOutput(id, outputId, false)
                self:shouldBeThroughBlock(outputId)
                self:internalAddBlockToUpdate(outputId)
                outputId = outputs[1]
            end
        end
        self:clearTimerData(id)
    end
    self:internalRemoveBlockFromUpdate(id)
    table.removeValue(self.blocksSortedByPath[self.runnableBlockPathIds[id]], id)
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
    self.altBlockData[id] = false
    self.multiBlockData[id] = false

    table.removeFromConstantKeysOnlyHash(self.hashData, self.unhashedLookUp[id])
end

function FastLogicRunner.internalSetBlockStates(self, idStatePairs, withUpdates)
    local blocksToFixInputData = {}
    for i = 1, #idStatePairs do
        local id = idStatePairs[i][1]
        self.blockStates[id] = idStatePairs[i][2]
        for k = 1, #self.blockOutputs[id] do
            blocksToFixInputData[self.blockOutputs[id][k]] = true
        end
    end
    if withUpdates ~= false then
        for id, _ in pairs(blocksToFixInputData) do
            self:fixBlockInputData(id)
        end
    end
end

function FastLogicRunner.internalGetMultiBlockInternalStates(self, multiBlockId)
    -- multiData = [id, all blocks, inputs, outputs, score, otherdata...]
    local runnableBlockPathIds = self.runnableBlockPathIds
    local blockStates = self.blockStates
    local timerData = self.timerData
    local multiData = self.multiBlockData[multiBlockId]
    local idStatePairs = {} -- fill with states to set/update
    if multiData[1] == nil then
    elseif multiData[1] == 1 or multiData[1] == 2 then
        local state = blockStates[multiData[3][1]]
        local endBlockId = multiData[4][1]
        idStatePairs[#idStatePairs+1] = {multiData[3][1], state}
        for i = 2, multiData[7] do
            local id = multiData[2][i]
            local timeDataAtTime = timerData[multiData[7]-i+2]
            for k = 1, #timeDataAtTime do
                local item = timeDataAtTime[k]
                if type(item) ~= "number" and type(item[1]) == "boolean" and item[2] == endBlockId then
                    state = not state
                    break
                end
            end
            if self.nextRunningBlocks[id] >= self.nextRunningIndex - 1 then
                idStatePairs[#idStatePairs+1] = {id, blockStates[id]}
                break
            end
            
            if runnableBlockPathIds[id] == 4 then
                state = not state
            elseif runnableBlockPathIds[id] ~= 3 then
                print("this should never happen (internalGetMultiBlockInternalStates, multiData[1] = 1 or 2)")
            end
            idStatePairs[#idStatePairs+1] = {id, state}
        end
    else
    end
    return idStatePairs
end

function FastLogicRunner.internalGetLastMultiBlockInternalStates(self, multiBlockId)
    -- multiData = [id, all blocks, inputs, outputs, score, otherdata...]
    local runnableBlockPathIds = self.runnableBlockPathIds
    local blockStates = self.blockStates
    local timerData = self.timerData
    local multiData = self.multiBlockData[multiBlockId]
    local lastIdStatePairs = {} -- fill with states to set/update
    local idStatePairs = nil
    if multiData[1] == nil then
    elseif multiData[1] == 1 or multiData[1] == 2 then
        idStatePairs = self:internalGetMultiBlockInternalStates(multiBlockId)
        local idStateHash = { [multiData[2]] = blockStates[multiData[2][#multiData[2]]] }
        for i = 1, #idStatePairs do
            idStateHash[idStatePairs[i][1]] = idStatePairs[i][2]
        end
        for i = 2, #multiData[2] do
            local id = multiData[2][i]
            if idStateHash[id] ~= nil then
                lastIdStatePairs[#lastIdStatePairs+1] = {multiData[2][i-1],  idStateHash[id]}
            end
        end
    else
    end
    return {lastIdStatePairs, idStatePairs} -- if idStatePairs is also calulated here return idStatePairs else nil
end

function FastLogicRunner.internalFakeAddBlock(self, path, inputs, outputs, state, timerLength)
    local newBlockId = table.addBlankToConstantKeysOnlyHash(self.hashData)
    self:internalAddBlock(path, newBlockId, inputs, outputs, state, timerLength)
    return newBlockId
end

function FastLogicRunner.internalAddMultiBlock(self, multiBlockType)
    local multiBlockId = self:internalFakeAddBlock(16, {}, {}, false, nil) -- 16 is the multiBlocks id
    self.multiBlockData[multiBlockId][1] = multiBlockType
    return multiBlockId
end

function FastLogicRunner.internalAddBlockToMultiBlock(self, id, multiBlockId, isInput, isOutput)
    local multiBlockData = self.multiBlockData
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

function FastLogicRunner.internalRemoveInput(self, id, idToDisconnect, withFixes)
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
        self.blockInputs[idToConnect][#self.blockInputs[idToConnect] + 1] = id
        self.blockInputsHash[idToConnect][id] = true
        self.numberOfBlockInputs[idToConnect] = self.numberOfBlockInputs[idToConnect] + 1
        -- update states
        if self.blockStates[id] and self.runnableBlockPathIds[id] ~= 5 then
            self.countOfOnInputs[idToConnect] = self.countOfOnInputs[idToConnect] + 1
            self:internalAddBlockToUpdate(idToConnect)
        end
        -- do fixes
        if withFixes ~= false then
            self:shouldBeThroughBlock(idToConnect)
        end
    end
end

function FastLogicRunner.internalRemoveOutput(self, id, idToDisconnect, withFixes)
    if self.runnableBlockPaths[id] ~= false and self.runnableBlockPaths[idToDisconnect] ~= false and table.removeValue(self.blockOutputs[id], idToDisconnect) ~= nil then
        -- remove from multi blocks
        if self.multiBlockData[id] ~= false then
            self:internalRemoveBlock(self.multiBlockData[id])
        end
        if self.multiBlockData[idToDisconnect] ~= false then
            self:internalRemoveBlock(self.multiBlockData[idToDisconnect])
        end

        self.blockOutputsHash[id][idToDisconnect] = nil
        self.numberOfBlockOutputs[id] = self.numberOfBlockOutputs[id] - 1
        if table.removeValue(self.blockInputs[idToDisconnect], id) ~= nil then
            self.blockInputsHash[idToDisconnect][id] = nil
            self.numberOfBlockInputs[idToDisconnect] = self.numberOfBlockInputs[idToDisconnect] - 1
        end
        -- update states
        if self.blockStates[id] and self.runnableBlockPathIds[id] ~= 5 then
            self.countOfOnInputs[idToDisconnect] = self.countOfOnInputs[idToDisconnect] - 1
            self:internalAddBlockToUpdate(idToDisconnect)
        end
        -- do fixes
        if withFixes ~= false then
            self:shouldBeThroughBlock(idToDisconnect)
        end
    end
end

function FastLogicRunner.fixBlockInputData(self, id)
        if self.numberOfBlockInputs[id] == 0 then
            self.countOfOnInputs[id] = 0
        else
            self.countOfOnInputs[id] = 0
            for i = 1, self.numberOfBlockInputs[id] do
                local inputId = self.blockInputs[id][i]
                if self.blockStates[inputId] then
                    self.countOfOnInputs[id] = self.countOfOnInputs[id] + 1
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
        self:internalAddBlockToUpdate(id)
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

        self:shouldBeThroughBlock(id)
        self:internalAddBlockToUpdate(id)
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
    end
end

function FastLogicRunner.revertBlockType(self, id)
    if self.altBlockData[id] ~= false then
        -- remove from multi blocks
        if self.multiBlockData[id] ~= false then
            self:internalRemoveBlock(self.multiBlockData[id])
        end
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

function FastLogicRunner.externalRemoveInput(self, uuid, uuidToDisconnect, withFixes)
    local id = self.hashedLookUp[uuid]
    local idToDisconnect = self.hashedLookUp[uuidToDisconnect]
    if id ~= nil and idToDisconnect ~= nil then
        self:internalRemoveOutput(idToDisconnect, id, withFixes)
    end
end

function FastLogicRunner.externalAddOutput(self, uuid, uuidToConnect, withFixes)
    local id = self.hashedLookUp[uuid]
    local idToConnect = self.hashedLookUp[uuidToConnect]
    if id ~= nil and idToConnect ~= nil then
        self:internalAddOutput(id, idToConnect, withFixes)
    end
end

function FastLogicRunner.externalRemoveOutput(self, uuid, uuidToDisconnect, withFixes)
    local id = self.hashedLookUp[uuid]
    local idToDisconnect = self.hashedLookUp[uuidToDisconnect]
    if id ~= nil and idToDisconnect ~= nil then
        self:internalRemoveOutput(id, idToDisconnect, withFixes)
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

function FastLogicRunner.externalChangeBlockType(self, uuid, blockType)
    if self.hashedLookUp[uuid] ~= nil then
        self:internalChangeBlockType(self.hashedLookUp[uuid], blockType)
    end
end

function FastLogicRunner.externalSetBlockState(self, uuid, state)
    if self.hashedLookUp[uuid] ~= nil then
        self:internalSetBlockStates({{self.hashedLookUp[uuid], state}})
    end
end