function FastLogicRunner.internalFakeAddBlock(self, path, state, timerLength)
    local newBlockId = table.addBlankToConstantKeysOnlyHash(self.hashData)
    self:internalAddBlock(path, newBlockId, state, timerLength)
    return newBlockId
end

function FastLogicRunner.internalAddMultiBlock(self, multiBlockType)
    local multiBlockId = self:internalFakeAddBlock(16, false, nil) -- 16 is the multiBlocks id
    self.multiBlockData[multiBlockId][1] = multiBlockType
    return multiBlockId
end

function FastLogicRunner.internalAddBlockToMultiBlock(self, id, multiBlockId, isInput, isOutput)
    local multiBlockData = self.multiBlockData
    local multiData = multiBlockData[multiBlockId]
    if multiBlockData[id] == false then
        multiBlockData[id] = {[multiBlockId]=true}
    else
        multiBlockData[id][multiBlockId] = true
    end
    multiData[2][#multiData[2]+1] = id
    if isInput then
        local multiBlockInputType = self.toMultiBlockInput[self.runnableBlockPathIds[id]]
        if multiBlockInputType ~= false then
            self:makeBlockAlt(id, multiBlockInputType)
        end
        self:externalAddBlockToUpdate(id)
        multiData[3][#multiData[3]+1] = id
        self.multiBlockInputMultiBlockId[id] = multiBlockId
    end
    if isOutput then
        multiData[4][#multiData[4]+1] = id
    end
end

function FastLogicRunner.internalCollapseMultiBlock(self, multiBlockId)
    -- multiData = [id, all blocks, inputs, outputs, to update, max time, otherdata (different per multiBlock) ...]
    local multiBlockData = self.multiBlockData
    local multiData = multiBlockData[multiBlockId]
    local idStatePairs = {} -- fill with states to set/update
    local idTimePairs = {} -- fill with data for timers
    local multiBlockType = multiData[1]
    if multiBlockType == nil then
    elseif multiBlockType == 1 or multiBlockType == 2 then
        local blockStates = self.blockStates
        local blockOutputs = self.blockOutputs
        local timerLengths = self.timerLengths
        local timerInputStates = self.timerInputStates
        local timerData = self.timeData[1]
        local otherTimeData = self.timeData[2]
        local timerDataHash = {}
        local otherTimeDataHash = {}
        for i = 1, #timerData do
            local timerDataAtTime = timerData[i]
            local hashAtTime = {}
            for k = 1, #timerDataAtTime do
                hashAtTime[timerDataAtTime[k]] = k
            end
            timerDataHash[i] = hashAtTime
        end
        for i = 1, #otherTimeData do
            local timeDataAtTime = otherTimeData[i]
            local hashAtTime = {}
            for k = 1, #timeDataAtTime do
                local item = timeDataAtTime[k]
                if item ~= nil then
                    hashAtTime[item[2]] = k
                end
            end
            otherTimeDataHash[i] = hashAtTime
        end
        local runnableBlockPathIds = self.runnableBlockPathIds
        -- prep stuff above
        local blocksToFixInputData = {}
        local state = blockStates[multiData[3][1]]
        -- update first block
        local firstBlock = multiData[3][1]
        blockStates[firstBlock] = state
        blocksToFixInputData[firstBlock] = true
        for k = 1, #blockOutputs[firstBlock] do
            blocksToFixInputData[blockOutputs[firstBlock][k]] = true
        end
        -- update the rest of the blocks
        local endBlockId = multiData[4][1]
        local index = 2
        local time = multiData[6]-1
        local timerSkipCount = 0
        local id = multiData[2][2]
        while time > 1 do
            if timerSkipCount > 1 then
                timerSkipCount = timerSkipCount - 1
                if timerDataHash[timerSkipCount][id] ~= nil then
                    break
                end
                if otherTimeDataHash[time][endBlockId] ~= nil then
                    state = not state
                    timerData[timerSkipCount][#timerData[timerSkipCount]+1] = id
                end
                if timerSkipCount == 1 then
                    blockStates[id] = state
                    blocksToFixInputData[id] = true
                    for k = 1, #blockOutputs[id] do
                        blocksToFixInputData[blockOutputs[id][k]] = true
                    end
                end
            else
                id = multiData[2][index]
                local multiBlockIds = multiBlockData[id]
                if multiBlockIds ~= false then
                    for k,_ in pairs(multiBlockIds) do
                        if multiBlockData[k].isDead ~= true then
                            self:internalRemoveBlock(k)
                        end
                    end
                end
                if self.nextRunningBlocks[id] >= self.nextRunningIndex - 1 then
                    break
                end
                if runnableBlockPathIds[id] == 5 then
                    timerInputStates[id] = state
                    timerSkipCount = timerLengths[id]
                    if timerDataHash[timerSkipCount][id] ~= nil then
                        break
                    end
                    if otherTimeDataHash[time][endBlockId] ~= nil then
                        state = not state
                        timerData[timerSkipCount][#timerData[timerSkipCount]+1] = id
                    end
                else
                    if otherTimeDataHash[time][endBlockId] ~= nil then
                        state = not state
                    end
                    if runnableBlockPathIds[id] == 4 then
                        state = not state
                    end
                    blockStates[id] = state
                    blocksToFixInputData[id] = true
                    for k = 1, #blockOutputs[id] do
                        blocksToFixInputData[blockOutputs[id][k]] = true
                    end
                end
                index = index + 1
            end
            time = time - 1
        end
        for id, _ in pairs(blocksToFixInputData) do
            self:fixBlockInputData(id)
        end
    elseif multiBlockType == 3 or multiBlockType == 4 then
        local blocksToFixInputData = {}
        local blockStates = self.blockStates
        local blockOutputs = self.blockOutputs
        for i = 1, #multiData[2] do
            local id = multiData[2][i]
            -- we know that interface gates cant be part of other multiBlocks
            -- local multiBlockIds = multiBlockData[id]
            -- if multiBlockIds ~= false then
            --     for k,_ in pairs(multiBlockIds) do
            --         if multiBlockData[k].isDead ~= true then
            --             self:internalRemoveBlock(k)
            --         end
            --     end
            -- end
            local interfaceBlock = self.creation.FastLogicBlockInterfaces[self.unhashedLookUp[id]]
            if interfaceBlock ~= nil then
                interfaceBlock.error = "none"
            end
            blockStates[id] = false
            blocksToFixInputData[id] = true
            for k = 1, #blockOutputs[id] do
                blocksToFixInputData[blockOutputs[id][k]] = true
            end
        end
        for id, _ in pairs(blocksToFixInputData) do
            self:fixBlockInputData(id)
        end
    elseif multiBlockType == 5 then
        local blockOutputs = self.blockOutputs
        local blockStates = self.blockStates
        local farthestOutput = multiData[8]
        local otherTimeData = self.timeData[2]
        local inputsIndexPow2 = multiData[11]
        local length = multiData[6]
        local inputs = multiData[3]
        local numberOfTicksToRun = 0
        local inputStatesOverTime = {}
        for i = 1, length-2 do
            local timeDataAtTime = otherTimeData[i]
            for k = 1, #timeDataAtTime do
                local item = timeDataAtTime[k]
                if item ~= nil and item[2] == farthestOutput then
                    local inputStates = {}
                    inputStatesOverTime[i+1] = inputStates
                    if length - i - 2 > numberOfTicksToRun then
                        numberOfTicksToRun = length - i - 2
                    end
                    local inputData
                    if item[1] == 3 then
                        inputData = item[5]
                    elseif item[1] == 5 then
                        inputData = item[4]
                    elseif item[1] == 4 then
                        goto continue
                    end
                    for j = #inputs, 1, -1 do
                        local inputId = inputs[j]
                        local pow2 = inputsIndexPow2[inputId]
                        if inputData >= pow2 then
                            inputData = inputData - pow2
                            inputStates[inputId] = true
                        else
                            inputStates[inputId] = false
                        end
                    end
                end
                ::continue::
            end
        end
        local farthestInputData = multiData[12]
        if farthestInputData ~= nil then
            numberOfTicksToRun = length - 2
            inputStatesOverTime[1] = {}
            for j = #inputs, 1, -1 do
                local inputId = inputs[j]
                local pow2 = inputsIndexPow2[inputId]
                if farthestInputData >= pow2 then
                    farthestInputData = farthestInputData - pow2
                    inputStatesOverTime[1][inputId] = true
                else
                    inputStatesOverTime[1][inputId] = false
                end
            end
        end

        local idsToUpdate, states, perTimerData = self:simulatedManyBalancedUpdates(
            multiData[2],
            numberOfTicksToRun,
            inputStatesOverTime
        )

        local blocksToFixInputData = {}

        for i = 1, #idsToUpdate do
            local id = idsToUpdate[i]
            blockStates[id] = states[id]
            blocksToFixInputData[id] = true
            for k = 1, #blockOutputs[id] do
                blocksToFixInputData[blockOutputs[id][k]] = true
            end
        end

        for id, _ in pairs(blocksToFixInputData) do
            self:fixBlockInputData(id)
        end

        local timerData = self.timeData[1]
        local timerDataHash = {}
        for i = 1, #timerData do
            local timerDataAtTime = timerData[i]
            local hashAtTime = {}
            for k = 1, #timerDataAtTime do
                hashAtTime[timerDataAtTime[k]] = k
            end
            timerDataHash[i] = hashAtTime
        end
        local timerInputStates = self.timerInputStates
        for id, data in pairs(perTimerData) do
            timerInputStates[id] = data[1]
            local timeData = data[2]
            for i = 1, #timeData do
                local time = timeData[i]
                if timerDataHash[time][id] == nil then
                    timerData[time][#timerData[time]+1] = id
                end
            end
        end
    end
end

------------------------------- per block code -------------------------------

------------- ram -------------

function FastLogicRunner.makeAllRamInterfaces(self)
    for j = 1, #self.interfacesToMake do
        local blockId = self.interfacesToMake[j]
        local outputs = self.blockOutputs[blockId]
        if outputs ~= false then
            for i = 1, #outputs do
                local outputId = outputs[i]
                if self.runnableBlockPaths[outputId] == "Address" then
                    self:internalMakeRamInterface(outputId, blockId)
                end
            end
        end
    end
    self.interfacesToMake = {}
    self.interfacesToMakeHash = {}
end

function FastLogicRunner.internalFindRamInterfaces(self, blockId, pastCheckHash)
    if blockId == nil then return end
    if pastCheckHash == nil then
        pastCheckHash = {[blockId] = true}
    elseif pastCheckHash[blockId] == nil then
        pastCheckHash[blockId] = true
    else
        return
    end
    local runnableBlockPaths = self.runnableBlockPaths
    local path = runnableBlockPaths[blockId]
    if path == "BlockMemory" then
        if self.interfacesToMakeHash[blockId] == nil then
            self.interfacesToMake[#self.interfacesToMake+1] = blockId
            self.interfacesToMakeHash[blockId] = true
            local outputs = self.blockOutputs[blockId]
            for i = 1, #outputs do
                local outputId = outputs[i]
                if runnableBlockPaths[outputId] == "interfaceMultiBlockInput" then
                    self:revertBlockType(outputId)
                end
            end
        end
    elseif (
        path == "Address" or
        path == "DataIn" or
        path == "DataOut" or
        path == "WriteData" or
        path == "interfaceMultiBlockInput"
        ) then
        local inputs = self.blockInputs[blockId]
        for i = 1, #inputs do
            self:internalFindRamInterfaces(inputs[i], pastCheckHash)
        end
    end
end

function FastLogicRunner.internalMakeRamInterface(self, rootInterfaceId, memoryBlockId)
    local runnableBlockPaths = self.runnableBlockPaths
    local blockOutputs = self.blockOutputs
    local blockStates = self.blockStates
    local numberOfBlockOutputs = self.numberOfBlockOutputs
    local numberOfBlockInputs = self.numberOfBlockInputs
    local numberOfOtherInputs = self.numberOfOtherInputs
    local idToCheckNext = rootInterfaceId
    local allBlockFound = {rootInterfaceId}
    local addressBlocks = {rootInterfaceId}
    local dataBlocks = {}
    local writeBlock = nil
    local searchStage = 1 -- 1 address, 2 data out, 3 data in, 4 write data
    local done = false
    local count = 0
    if (
        numberOfBlockOutputs[rootInterfaceId] > 1 or
        self.blocks[self.unhashedLookUp[rootInterfaceId]].numberOfOtherOutputs > 0
    ) then
        local interfaceBlock = self.creation.FastLogicBlockInterfaces[self.unhashedLookUp[rootInterfaceId]]
        if interfaceBlock ~= nil then
            interfaceBlock.error = {1, searchStage}
        end
        self:internalSetBlockState(rootInterfaceId, false)
        return
    end
    while not done do
        local outputs = blockOutputs[idToCheckNext]
        local inputs = self.blockInputs[idToCheckNext]
        for i = 1, #inputs do
            local inputId = inputs[i]
            local path = runnableBlockPaths[inputId]
            if path == "BlockMemory" and rootInterfaceId ~= idToCheckNext then
                if searchStage == 2 then
                    done = true
                    goto continue
                else
                    for j = 1, #allBlockFound do
                        local interfaceBlock = self.creation.FastLogicBlockInterfaces[self.unhashedLookUp[allBlockFound[j]]]
                        if interfaceBlock ~= nil then
                            interfaceBlock.error = {9, searchStage}
                        end
                        self:internalSetBlockState(allBlockFound[j], false)
                    end
                    return
                end
            end
        end
        if numberOfBlockOutputs[idToCheckNext] == 0 then
            done = true
        else
            for i = 1, numberOfBlockOutputs[idToCheckNext] do
                local outputId = outputs[i]
                local path = runnableBlockPaths[outputId]
                if path == "Address" then
                    if (
                        numberOfBlockOutputs[outputId] > 1 or
                        self.blocks[self.unhashedLookUp[outputId]].numberOfOtherOutputs > 0
                    ) then
                        allBlockFound[#allBlockFound+1] = outputId
                        for j = 1, #allBlockFound do
                            local interfaceBlock = self.creation.FastLogicBlockInterfaces[self.unhashedLookUp[allBlockFound[j]]]
                            if interfaceBlock ~= nil then
                                interfaceBlock.error = {1, searchStage}
                            end
                            self:internalSetBlockState(allBlockFound[j], false)
                        end
                        return
                    end
                    if searchStage == 1 then
                        addressBlocks[#addressBlocks+1] = outputId
                        allBlockFound[#allBlockFound+1] = outputId
                        idToCheckNext = outputId
                        goto continue
                    elseif searchStage == 2 then
                        -- nothing keep checking outputs
                    else
                        allBlockFound[#allBlockFound+1] = outputId
                        for j = 1, #allBlockFound do
                            local interfaceBlock = self.creation.FastLogicBlockInterfaces[self.unhashedLookUp[allBlockFound[j]]]
                            if interfaceBlock ~= nil then
                                interfaceBlock.error = {2, searchStage}
                            end
                            self:internalSetBlockState(allBlockFound[j], false)
                        end
                        return
                    end
                elseif path == "DataIn" then
                    if (
                        numberOfBlockOutputs[outputId] > 1 or
                        self.blocks[self.unhashedLookUp[outputId]].numberOfOtherOutputs > 0
                    ) then
                        allBlockFound[#allBlockFound+1] = outputId
                        for j = 1, #allBlockFound do
                            local interfaceBlock = self.creation.FastLogicBlockInterfaces[self.unhashedLookUp[allBlockFound[j]]]
                            if interfaceBlock ~= nil then
                                interfaceBlock.error = {3, searchStage}
                            end
                            self:internalSetBlockState(allBlockFound[j], false)
                        end
                        return
                    end
                    if searchStage == 1 then
                        dataBlocks[#dataBlocks+1] = outputId
                        allBlockFound[#allBlockFound+1] = outputId
                        searchStage = 3
                        idToCheckNext = outputId
                        goto continue
                    elseif searchStage == 2 then
                        -- nothing keep checking outputs
                    elseif searchStage == 3 then
                        dataBlocks[#dataBlocks+1] = outputId
                        allBlockFound[#allBlockFound+1] = outputId
                        idToCheckNext = outputId
                        goto continue
                    elseif searchStage == 4 then
                        dataBlocks[#dataBlocks+1] = outputId
                        allBlockFound[#allBlockFound+1] = outputId
                        searchStage = 3
                        idToCheckNext = outputId
                        goto continue
                    end
                elseif path == "DataOut" then
                    if (
                        numberOfBlockInputs[outputId] > 1 or
                        numberOfOtherInputs[outputId] > 0
                    ) then
                        allBlockFound[#allBlockFound+1] = outputId
                        for j = 1, #allBlockFound do
                            local interfaceBlock = self.creation.FastLogicBlockInterfaces[self.unhashedLookUp[allBlockFound[j]]]
                            if interfaceBlock ~= nil then
                                interfaceBlock.error = {12, searchStage}
                            end
                            self:internalSetBlockState(allBlockFound[j], false)
                        end
                        return
                    end
                    if searchStage == 1 then
                        dataBlocks[#dataBlocks+1] = outputId
                        allBlockFound[#allBlockFound+1] = outputId
                        searchStage = 2
                        idToCheckNext = outputId
                        goto continue
                    elseif searchStage == 2 then
                        dataBlocks[#dataBlocks+1] = outputId
                        allBlockFound[#allBlockFound+1] = outputId
                        idToCheckNext = outputId
                        goto continue
                    elseif searchStage == 4 then
                        dataBlocks[#dataBlocks+1] = outputId
                        allBlockFound[#allBlockFound+1] = outputId
                        searchStage = 2
                        idToCheckNext = outputId
                        goto continue
                    else
                        allBlockFound[#allBlockFound+1] = outputId
                        for j = 1, #allBlockFound do
                            local interfaceBlock = self.creation.FastLogicBlockInterfaces[self.unhashedLookUp[allBlockFound[j]]]
                            if interfaceBlock ~= nil then
                                interfaceBlock.error = {4, searchStage}
                            end
                            self:internalSetBlockState(allBlockFound[j], false)
                        end
                        return
                    end
                elseif path == "WriteData" then
                    if (
                        numberOfBlockOutputs[outputId] > 1 or
                        self.blocks[self.unhashedLookUp[outputId]].numberOfOtherOutputs > 0
                    ) then
                        allBlockFound[#allBlockFound+1] = outputId
                        for j = 1, #allBlockFound do
                            local interfaceBlock = self.creation.FastLogicBlockInterfaces[self.unhashedLookUp[allBlockFound[j]]]
                            if interfaceBlock ~= nil then
                                interfaceBlock.error = {5, searchStage}
                            end
                            self:internalSetBlockState(allBlockFound[j], false)
                        end
                        return
                    end
                    if searchStage == 1 then
                        writeBlock = outputId
                        allBlockFound[#allBlockFound+1] = outputId
                        idToCheckNext = outputId
                        searchStage = 4
                        goto continue
                    elseif searchStage == 2 then
                        -- nothing keep checking outputs
                    elseif searchStage == 3 then
                        writeBlock = outputId
                        allBlockFound[#allBlockFound+1] = outputId
                        searchStage = 4
                        done = true
                        idToCheckNext = outputId
                        goto continue
                    else
                        allBlockFound[#allBlockFound+1] = outputId
                        for j = 1, #allBlockFound do
                            local interfaceBlock = self.creation.FastLogicBlockInterfaces[self.unhashedLookUp[allBlockFound[j]]]
                            if interfaceBlock ~= nil then
                                interfaceBlock.error = {6, searchStage}
                            end
                            self:internalSetBlockState(allBlockFound[j], false)
                        end
                        return
                    end
                end
            end
        end
        done = true
        ::continue::
        count = count + 1
        if count >= 200 then
            allBlockFound[#allBlockFound+1] = outputId
            for j = 1, #allBlockFound do
                local interfaceBlock = self.creation.FastLogicBlockInterfaces[self.unhashedLookUp[allBlockFound[j]]]
                if interfaceBlock ~= nil then
                    interfaceBlock.error = {7, searchStage}
                end
                self:internalSetBlockState(allBlockFound[j], false)
            end
            return
        end
    end
    if searchStage == 1 or (searchStage == 3 and writeBlock == nil) or (searchStage == 4 and #dataBlocks == 0) then
        for j = 1, #allBlockFound do
            local interfaceBlock = self.creation.FastLogicBlockInterfaces[self.unhashedLookUp[allBlockFound[j]]]
            if interfaceBlock ~= nil then
                interfaceBlock.error = {(searchStage == 3) and 10 or ((searchStage == 4) and 11 or 8), searchStage}
            end
        end
        return
    end
    for j = 1, #allBlockFound do
        local interfaceBlock = self.creation.FastLogicBlockInterfaces[self.unhashedLookUp[allBlockFound[j]]]
        if interfaceBlock ~= nil then
            interfaceBlock.error = nil
        end
    end

    local multiBlockId = self:internalAddMultiBlock((searchStage == 2) and 4 or 3)
    self.multiBlockData[multiBlockId][7] = memoryBlockId
    self.multiBlockData[multiBlockId][8] = addressBlocks
    self.multiBlockData[multiBlockId][9] = dataBlocks
    for i = 1, #addressBlocks do
        local id = addressBlocks[i]
        self:internalAddBlockToMultiBlock(id, multiBlockId, true)
        self:internalAddBlockToUpdate(id)
    end
    if searchStage == 2 then
        for i = 1, #dataBlocks do
            local id = dataBlocks[i]
            self:internalAddBlockToMultiBlock(id, multiBlockId, false, true)
        end
        if writeBlock ~= nil then
            self:internalAddBlockToMultiBlock(writeBlock, multiBlockId, true)
            self:internalAddBlockToUpdate(writeBlock)
            self.multiBlockData[multiBlockId][10] = writeBlock
        end
        self.ramBlockOtherData[memoryBlockId][1][#self.ramBlockOtherData[memoryBlockId][1]+1] = multiBlockId
    else
        for i = 1, #dataBlocks do
            local id = dataBlocks[i]
            self:internalAddBlockToMultiBlock(id, multiBlockId, true)
            self:internalAddBlockToUpdate(id)
        end
        self:internalAddBlockToMultiBlock(writeBlock, multiBlockId, true)
        self:internalAddBlockToUpdate(writeBlock)
        self.multiBlockData[multiBlockId][10] = writeBlock
    end
end

function FastLogicRunner.internalUpdateRamInterfaces(self, id)
    local multiBlockData = self.multiBlockData
    local outputInterfaces = self.ramBlockOtherData[id][1]
    local j = 1
    while j <= #outputInterfaces do
        local outputInterfaceId = outputInterfaces[j]
        if multiBlockData[outputInterfaceId] == false then
            table.remove(outputInterfaces, j)
        else
            self:internalAddBlockToUpdate(multiBlockData[outputInterfaceId][3][1])
            j = j + 1
        end
    end
end

function FastLogicRunner.externalUpdateRamInterfaces(self, uuid)
    local id = self.hashedLookUp[uuid]
    if id ~= nil then
        self:internalUpdateRamInterfaces(id)
    end
end

------------- ram -------------
