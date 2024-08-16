dofile "../util/util.lua"

local string = string
local table = table
local type = type
local pairs = pairs

function FastLogicRunner.internalAddBlock(self, path, id, state, timerLength, skipChecksAndUpdates)
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
        self.multiBlockData[id] = {0, {}, {}, {}, {}, 0} -- id, all blocks, inputs, outputs,
                                                         -- blocks to update (dont mess with this), max time,
                                                         -- otherdata (different per multiBlock) ...
    else
        self.multiBlockData[id] = false
        if pathName == "timerBlocks" then
            self.timerLengths[id] = timerLength + 1
            self.timerInputStates[id] = false
            self:updateLongestTimer()
        elseif pathName == "BlockMemory" then
            self.ramBlockData[id] = self.creation.FastLogicBlockMemorys[self.unhashedLookUp[id]].memory
            self.ramBlockOtherData[id] = {{}, false}
        end
        if skipChecksAndUpdates ~= true then
            self:shouldBeThroughBlock(id)
            self:internalFindRamInterfaces(id)
            -- add block to next update tick
            self:internalAddBlockToUpdate(id)
        end
    end
end

function FastLogicRunner.internalRemoveBlock(self, id)
    if self.runnableBlockPaths[id] == "multiBlocks" then
        local multiBlockData = self.multiBlockData
        local multiData = multiBlockData[id]
        local multiBlockType = multiData[1]
        multiData.isDead = true
        -- set new states of blocks
        local idStatePairs = self:internalGetMultiBlockInternalStates(id)
        self:internalSetBlockStates(idStatePairs)
        -- clear anything to do with multiBlock in timerData
        local endBlockId = multiData[4][1]
        local timerData = self.timerData
        for i = 1, multiData[6] do
            local timeDataAtTime = timerData[i]
            if timeDataAtTime == nil then goto continue end
            for k = 1, #timeDataAtTime do
                local item = timeDataAtTime[k]
                if item ~= nil and type(item) ~= "number" then
                    local itemId = item[2]
                    if multiBlockData[itemId] ~= false and multiBlockData[itemId][id] then
                        table.remove(timeDataAtTime, k)
                    end
                end
            end
            ::continue::
        end
        -- do removal
        local allBlocks = multiData[2]
        for i = 1, #allBlocks do
            local blockId = allBlocks[i]
            multiBlockData[blockId][id] = nil
            if next(multiBlockData[blockId]) == nil then
                multiBlockData[blockId] = false
            end
        end
        local inputs = multiData[3]
        for i = 1, #inputs do
            local blockId = inputs[i]
            self.multiBlockInputMultiBlockId[allBlocks[i]] = false
            self:revertBlockType(blockId)
            self:shouldBeThroughBlock(blockId)
            self:internalFindRamInterfaces(blockId)
        end
    else
        if self.multiBlockData[id] ~= false then
            for k,_  in pairs(self.multiBlockData[id]) do
                self:internalRemoveBlock(k)
            end
        end
        local inputs = self.blockInputs[id]
        if inputs ~= false then
            local inputId = inputs[1]
            while inputId ~= nil do
                self:internalRemoveOutput(inputId, id, true)
                inputId = inputs[1]
            end
        end
        local outputs = self.blockOutputs[id]
        if outputs ~= false then
            local outputId = outputs[1]
            while outputId ~= nil do
                self:internalRemoveOutput(id, outputId, true)
                self:shouldBeThroughBlock(outputId)
                self:internalFindRamInterfaces(outputId)
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
    self.multiBlockInputMultiBlockId[id] = false
    self.ramBlockData[id] = false
    self.ramBlockOtherData[id] = false
    table.removeFromConstantKeysOnlyHash(self.hashData, self.unhashedLookUp[id])
end

function FastLogicRunner.internalSetBlockStates(self, idStatePairs, withUpdates)
    local blocksToFixInputData = {}
    local multiBlockData = self.multiBlockData
    local blockStates = self.blockStates
    local blockOutputs = self.blockOutputs
    if withUpdates ~= false then
        for i = 1, #idStatePairs do
            local id = idStatePairs[i][1]
            if withUpdates ~= false then
                local multiBlockIds = multiBlockData[id]
                if multiBlockIds ~= false then
                    for k,_ in pairs(multiBlockIds) do
                        if multiBlockData[k].isDead ~= true then
                            self:internalRemoveBlock(k)
                        end
                    end
                end
            end
            blockStates[id] = idStatePairs[i][2]
            blocksToFixInputData[id] = true
            for k = 1, #blockOutputs[id] do
                blocksToFixInputData[blockOutputs[id][k]] = true
            end
        end
        if withUpdates ~= false then
            for id, _ in pairs(blocksToFixInputData) do
                self:fixBlockInputData(id)
            end
        end
    else
        for i = 1, #idStatePairs do
            local id = idStatePairs[i][1]
            blockStates[id] = idStatePairs[i][2]
        end
    end
end

function FastLogicRunner.internalAddInput(self, id, idToConnect, skipChecksAndUpdates)
    self:internalAddOutput(idToConnect, id, skipChecksAndUpdates)
end

function FastLogicRunner.internalRemoveInput(self, id, idToDisconnect, skipChecksAndUpdates)
    self:internalRemoveInput(idToConnect, id, skipChecksAndUpdates)
end

function FastLogicRunner.internalAddOutput(self, id, idToConnect, skipChecksAndUpdates)
    if self.runnableBlockPaths[id] ~= false and self.runnableBlockPaths[idToConnect] ~= false and self.blockOutputsHash[id][idToConnect] == nil then
        -- remove from multi blocks
        if self.multiBlockData[id] ~= false then
            for k,_ in pairs(self.multiBlockData[id]) do
                self:internalRemoveBlock(k)
            end
        end
        if self.multiBlockData[idToConnect] ~= false then
            for k,_ in pairs(self.multiBlockData[idToConnect]) do
                self:internalRemoveBlock(k)
            end
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
        end
        -- do fixes
        if skipChecksAndUpdates ~= true then
            self:shouldBeThroughBlock(idToConnect)
            self:internalFindRamInterfaces(idToConnect)
            self:internalFindRamInterfaces(id)
            self:internalAddBlockToUpdate(idToConnect)
        end
    end
end

function FastLogicRunner.internalRemoveOutput(self, id, idToDisconnect, skipChecksAndUpdates)
    if self.runnableBlockPaths[id] ~= false and self.runnableBlockPaths[idToDisconnect] ~= false and table.removeValue(self.blockOutputs[id], idToDisconnect) ~= nil then
        -- remove from multi blocks
        if self.multiBlockData[id] ~= false then
            for k,_ in pairs(self.multiBlockData[id]) do
                self:internalRemoveBlock(k)
            end
        end
        if self.multiBlockData[idToDisconnect] ~= false then
            for k,_ in pairs(self.multiBlockData[idToDisconnect]) do
                self:internalRemoveBlock(k)
            end
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
        end
        if skipChecksAndUpdates ~= true then
            self:shouldBeThroughBlock(idToDisconnect)
            self:internalFindRamInterfaces(idToDisconnect)
            self:internalFindRamInterfaces(id)
            self:fixBlockInputData(id)
            self:internalAddBlockToUpdate(idToDisconnect)
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
            local pathId = self.runnableBlockPathIds[inputId]
            if (
                (pathId ~= 7 and pathId ~= 9 and pathId ~= 14 and pathId ~= 27 and pathId ~= 26) and
                self.blockStates[inputId]
            ) then
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
            for k,_ in pairs(self.multiBlockData[id]) do
                self:internalRemoveBlock(k)
            end
        end
        -- change to timer
        self:revertBlockType(id)
        -- change time
        self:clearTimerData(id)
        self.timerLengths[id] = time + 1
        self:updateLongestTimer()
        self:shouldBeThroughBlock(id)
        self:internalFindRamInterfaces(id)
        self:internalAddBlockToUpdate(id)
    end
end

function FastLogicRunner.internalChangeBlockType(self, id, path)
    if type(path) == "string" then
        path = self.pathIndexs[path]
    end
    if (self.runnableBlockPathIds[id] ~= path and self.altBlockData[id] == nil) or (self.altBlockData[id] ~= path and self.altBlockData[id] ~= nil) then
        local isMemeory = self.runnableBlockPathIds[id] == 12 or self.runnableBlockPathIds[id] == 27
        if not isMemeory then
            -- remove from multi blocks
            if self.multiBlockData[id] ~= false then
                for k,_ in pairs(self.multiBlockData[id]) do
                    self:internalRemoveBlock(k)
                end
            end
        end
        self.altBlockData[id] = false
        local oldPath = self.runnableBlockPathIds[id]
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
        if isMemeory then
            -- remove from multi blocks
            if self.multiBlockData[id] ~= false then
                for k,_ in pairs(self.multiBlockData[id]) do
                    self:internalRemoveBlock(k)
                end
            end
        end

        self:shouldBeThroughBlock(id)
        self:internalFindRamInterfaces(id)
        self:fixBlockInputData(id)
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
        self:fixBlockInputData(id)
    end
end

function FastLogicRunner.revertBlockType(self, id)
    if self.altBlockData[id] ~= false then
        -- sm.MTUtil.Profiler.Time.on("revertBlockType"..tostring(self.creationId))
        -- remove from multi blocks
        if self.multiBlockData[id] ~= false then
            for k,_ in pairs(self.multiBlockData[id]) do
                self:internalRemoveBlock(k)
            end
        else
            local blockType = self.altBlockData[id]
            self.altBlockData[id] = false
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
                self:fixBlockInputData(id)
            end
        end
        -- sm.MTUtil.Profiler.Time.off("revertBlockType"..tostring(self.creationId))
        -- sm.MTUtil.Profiler.Count.increment("revertBlockType"..tostring(self.creationId))
    end
end

local canBeThroughtBlock = {
    false, -- 1      EndTickButtons
    false, -- 2      lightBlocks
    false, -- 3      throughBlocks
    false, -- 4      norThroughBlocks
    true,  -- 5      timerBlocks
    true,  -- 6      andBlocks
    false, -- 7      Address
    true,  -- 8      orBlocks
    false, -- 9      DataIn
    true,  -- 10     xorBlocks
    true,  -- 11     nandBlocks
    false, -- 12     DataOut
    true,  -- 13     norBlocks
    false, -- 14     WriteData
    true,  -- 15     xnorBlocks
    false, -- 16     multiBlocks
    false, -- 17     throughMultiBlockInput
    false, -- 18     norThroughMultiBlockInput
    false, -- 19     andMultiBlockInput
    false, -- 20     orMultiBlockInput
    false, -- 21     xorMultiBlockInput
    false, -- 22     nandMultiBlockInput
    false, -- 23     norMultiBlockInput
    false, -- 24     xnorMultiBlockInput
    false, -- 25     stateSetterBlocks
    false, -- 26     BlockMemory
    false, -- 27     interfaceMultiBlockInpu
}

function FastLogicRunner.shouldBeThroughBlock(self, id)
    local pathId = self.runnableBlockPathIds[id]
    if self.numberOfBlockInputs[id] + self.numberOfOtherInputs[id] <= 1 then
        if canBeThroughtBlock[pathId] then
            if pathId >= 11 then    -- nand nor xnor
                self:makeBlockAlt(id, 4)
            elseif pathId >= 6 then -- and or xor
                self:makeBlockAlt(id, 3)
            elseif pathId == 5 then -- timer
                if self.timerLengths[id] == 1 then
                    self:makeBlockAlt(id, 3)
                end
            end
        end
    elseif pathId == 3 or pathId == 4 then
        self:revertBlockType(id)
    end
end

function FastLogicRunner.getUpdatedIds(self)
    local changed = {}
    local blockStates = self.blockStates
    local lastBlockStates = self.lastBlockStates
    for i = 1, #blockStates do
        if lastBlockStates[i] ~= blockStates[i] then
            lastBlockStates[i] = blockStates[i]
            changed[#changed + 1] = i
        end
    end
    return changed
end


function FastLogicRunner.internalAddNonFastOutput(self, interId, id)
    local nonFastBlock = self.nonFastBlocks[interId]
    if nonFastBlock[3][id] == nil then
        nonFastBlock[2][#nonFastBlock[2]+1] = id
        nonFastBlock[3][id] = true
        self:revertBlockType(id)
        self.numberOfOtherInputs[id] = self.numberOfOtherInputs[id] + 1
        if nonFastBlock[1] then
            self.countOfOnOtherInputs[id] = self.countOfOnOtherInputs[id] + 1
        end
        self:shouldBeThroughBlock(id)
        self:internalFindRamInterfaces(id)
        self:internalAddBlockToUpdate(id)
    end
end

function FastLogicRunner.internalRemoveNonFastOutput(self, interId, id)
    local nonFastBlock = self.nonFastBlocks[interId]
    if nonFastBlock[3][id] ~= nil then
        if #nonFastBlock[2] == 1 then -- if it is the last connection remove the nonFastBlock
            -- remove block
            self.nonFastBlocks[interId] = nil
        else
            -- remove data
            table.removeValue(nonFastBlock[2], id)
            nonFastBlock[3][id] = nil
        end
        if self.numberOfOtherInputs[id] ~= false then
            -- remove connction
            self:revertBlockType(id)
            self.numberOfOtherInputs[id] = self.numberOfOtherInputs[id] - 1
            if nonFastBlock[1] then -- update state
                self.countOfOnOtherInputs[id] = self.countOfOnOtherInputs[id] - 1
            end
            self:shouldBeThroughBlock(id)
            self:internalFindRamInterfaces(id)
            self:internalAddBlockToUpdate(id)
        end
    end
end

function FastLogicRunner.internalSetBlockState(self, id, state)
    self:internalSetBlockStates({{id, state}})
end


--------------------------------------------------------

function FastLogicRunner.externalAddBlock(self, block, skipChecksAndUpdates)
    if self.hashedLookUp[block.uuid] == nil then
        table.addToConstantKeysOnlyHash(self.hashData, block.uuid)
        self:internalAddBlock(block.type, self.hashedLookUp[block.uuid], block.state, block.timerLength, skipChecksAndUpdates)
    end
end

function FastLogicRunner.externalRemoveBlock(self, uuid)
    local id = self.hashedLookUp[uuid]
    if id ~= nil then
        self:internalRemoveBlock(id)
    end
end

function FastLogicRunner.externalAddInput(self, uuid, uuidToConnect, skipChecksAndUpdates)
    local id = self.hashedLookUp[uuid]
    local idToConnect = self.hashedLookUp[uuidToConnect]
    if id ~= nil and idToConnect ~= nil then
        self:internalAddOutput(idToConnect, id, skipChecksAndUpdates)
    end
end

function FastLogicRunner.externalRemoveInput(self, uuid, uuidToDisconnect, skipChecksAndUpdates)
    local id = self.hashedLookUp[uuid]
    local idToDisconnect = self.hashedLookUp[uuidToDisconnect]
    if id ~= nil and idToDisconnect ~= nil then
        self:internalRemoveOutput(idToDisconnect, id, skipChecksAndUpdates)
    end
end

function FastLogicRunner.externalAddOutput(self, uuid, uuidToConnect, skipChecksAndUpdates)
    local id = self.hashedLookUp[uuid]
    local idToConnect = self.hashedLookUp[uuidToConnect]
    if id ~= nil and idToConnect ~= nil then
        self:internalAddOutput(id, idToConnect, skipChecksAndUpdates)
    end
end

function FastLogicRunner.externalRemoveOutput(self, uuid, uuidToDisconnect, skipChecksAndUpdates)
    local id = self.hashedLookUp[uuid]
    local idToDisconnect = self.hashedLookUp[uuidToDisconnect]
    if id ~= nil and idToDisconnect ~= nil then
        self:internalRemoveOutput(id, idToDisconnect, skipChecksAndUpdates)
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

function FastLogicRunner.externalShouldBeThroughBlock(self, uuid)
    if self.hashedLookUp[uuid] ~= nil then
        self:shouldBeThroughBlock(self.hashedLookUp[uuid])
    end
end

-- some NonFast fuctions dont need internals because they are not called internaly
-- also it the code assumes that there are not erroes in the data that is being set to it

function FastLogicRunner.externalAddNonFastBlock(self, interId, state, interactible)
    local nonFastBlock = self.nonFastBlocks[interId]
    if nonFastBlock == nil then
        self.nonFastBlocks[interId] = {
            state or false, -- there might not be a state given
            {}, -- outputs
            {}, -- outputs hash
            interactible -- not read just stored for other classes to read
        }
    elseif state ~= nil then
        self:externalSetNonFastBlockState(interId, state)
    end
end

function FastLogicRunner.externalRemoveNonFastBlock(self, interId)
    local nonFastBlock = self.nonFastBlocks[interId]
    if nonFastBlock ~= nil then
        local outputs = nonFastBlock[2]
        local state = nonFastBlock[1]
        for i = 1, #outputs do
            local outputId = outputs[i]
            if self.numberOfOtherInputs[outputId] ~= false then
                self:revertBlockType(outputId)
                self.numberOfOtherInputs[outputId] = self.numberOfOtherInputs[outputId] - 1
                if state then
                    self.countOfOnOtherInputs[outputId] = self.countOfOnOtherInputs[outputId] - 1
                end
                self:shouldBeThroughBlock(outputId)
                self:internalFindRamInterfaces(id)
                self:internalAddBlockToUpdate(outputId)
            end
        end
        self.nonFastBlocks[interId] = nil
    end
end

function FastLogicRunner.externalAddNonFastOutput(self, interId, uuid)
    local id = self.hashedLookUp[uuid]
    if id ~= nil then
        self:internalAddNonFastOutput(interId, id)
    end
end

function FastLogicRunner.externalRemoveNonFastOutput(self, interId, uuid)
    local id = self.hashedLookUp[uuid]
    if id ~= nil then
        self:internalRemoveNonFastOutput(interId, id)
    end
end

function FastLogicRunner.externalTurnNonFastBlockOn(self, interId)
    local nonFastBlock = self.nonFastBlocks[interId]
    if not nonFastBlock[1] then
        nonFastBlock[1] = true
        local outputs = nonFastBlock[2]
        local i = 1
        while i <= #outputs do
            local outputId = outputs[i]
            if self.countOfOnOtherInputs[outputId] ~= false then
                self.countOfOnOtherInputs[outputId] = self.countOfOnOtherInputs[outputId] + 1
                self:internalAddBlockToUpdate(outputId)
                i = i + 1
            else
                table.remove(outputs, i)
            end
        end
    end
end

function FastLogicRunner.externalTurnNonFastBlockOff(self, interId)
    local nonFastBlock = self.nonFastBlocks[interId]
    if nonFastBlock[1] then
        nonFastBlock[1] = false
        local outputs = nonFastBlock[2]
        local i = 1
        while i <= #outputs do
            local outputId = outputs[i]
            if self.countOfOnOtherInputs[outputId] ~= false then
                self.countOfOnOtherInputs[outputId] = self.countOfOnOtherInputs[outputId] - 1
                self:internalAddBlockToUpdate(outputId)
                i = i + 1
            else
                table.remove(outputs, i)
            end
        end
    end
end

function FastLogicRunner.externalSetNonFastBlockState(self, interId, state)
    local nonFastBlock = self.nonFastBlocks[interId]
    if nonFastBlock[1] ~= state then
        nonFastBlock[1] = state
        local stateNumber = state and 1 or -1
        local outputs = nonFastBlock[2]
        local i = 1
        while i <= #outputs do
            local outputId = outputs[i]
            if self.countOfOnOtherInputs[outputId] ~= false then
                self.countOfOnOtherInputs[outputId] = self.countOfOnOtherInputs[outputId] + stateNumber
                self:internalAddBlockToUpdate(outputId)
                i = i + 1
            else
                table.remove(outputs, i)
            end
        end
    end
end

function FastLogicRunner.externalUpdateNonFastOutput(self, interId, allOutputUuids)
    if #allOutputUuids == 0 then
        self:externalRemoveNonFastBlock(interId)
        return
    end
    local hashedLookUp = self.hashedLookUp
    local nonFastBlock = self.nonFastBlocks[interId]
    local outputs = nonFastBlock[2]
    local outputsHash = nonFastBlock[3]
    local allOutputIds = {}
    for i = 1, #allOutputUuids do
        local outputId = hashedLookUp[allOutputUuids[i]]
        if outputId ~= nil then
            if outputsHash[outputId] == nil then
                self:internalAddNonFastOutput(interId, outputId)
            end
            allOutputIds[outputId] = true
        end
    end
    for i = 1, #outputs do
        local outputId = outputs[i]
        if allOutputIds[outputId] == nil or self.countOfOnOtherInputs[outputId] == false then
            self:internalRemoveNonFastOutput(interId, outputId)
        end
    end
end

function FastLogicRunner.externalHasNonFastInputs(self, uuid)
    local id = self.hashedLookUp[uuid]
    return id ~= nil and self.numberOfOtherInputs[id] ~= false and self.numberOfOtherInputs[id] ~= 0
end

function FastLogicRunner.externalFindRamInterfaces(self, uuid)
    local id = self.hashedLookUp[uuid]
    if id ~= nil then
        self:internalFindRamInterfaces(id)
    end
end