local remove = table.remove

-- for fast read
local runningBlocks = nil
local nextRunningBlocks = nil
local runningBlockLengths = nil
local countOfOnInputs = nil
local countOfOnOtherInputs = nil
local runnableBlockPathIds = nil
local numberOfBlockOutputs = nil
local blockInputs = nil
local numberOfBlockInputs = nil
local numberOfOtherInputs = nil
local blockStates = nil
local timerData = nil
local otherTimeData = nil
local timerLengths = nil
local timerInputStates = nil
local blockOutputs = nil
local multiBlockData = nil
local numberOfTimesRun = nil
local ramBlockData = nil
local ramBlockOtherData = nil
local unhashedLookUp = nil
local FastLogicBlockMemorys = nil
local multiBlockInputMultiBlockId = nil
local runningBlocks1 = nil
local runningBlocks3 = nil
local runningBlocks4 = nil
local runningBlocks5 = nil
local runningBlocks6 = nil
local runningBlocks7 = nil
local runningBlocks8 = nil
local runningBlocks9 = nil
local runningBlocks10 = nil
local runningBlocks11 = nil
local runningBlocks12 = nil
local runningBlocks13 = nil
local runningBlocks14 = nil
local runningBlocks15 = nil
local runningBlocks16 = nil
local runningBlocks17 = nil
local runningBlocks18 = nil
local runningBlocks19 = nil
local runningBlocks20 = nil
local runningBlocks21 = nil
local runningBlocks22 = nil
local runningBlocks23 = nil
local runningBlocks24 = nil
local runningBlocks26 = nil
local runningBlocks27 = nil

function FastLogicRunner.setFastReadData(self, needsRunningBlocks)
    nextRunningBlocks = self.nextRunningBlocks
    runningBlockLengths = self.runningBlockLengths
    countOfOnInputs = self.countOfOnInputs
    countOfOnOtherInputs = self.countOfOnOtherInputs
    runnableBlockPathIds = self.runnableBlockPathIds
    numberOfBlockOutputs = self.numberOfBlockOutputs
    blockInputs = self.blockInputs
    numberOfBlockInputs = self.numberOfBlockInputs
    numberOfOtherInputs = self.numberOfOtherInputs
    blockStates = self.blockStates
    timerData = self.timeData[1]
    timerLengths = self.timerLengths
    timerInputStates = self.timerInputStates
    blockOutputs = self.blockOutputs
    if needsRunningBlocks == true then
        otherTimeData = self.timeData[2]
        multiBlockInputMultiBlockId = self.multiBlockInputMultiBlockId
        FastLogicBlockMemorys = self.creation.FastLogicBlockMemorys
        unhashedLookUp = self.unhashedLookUp
        multiBlockData = self.multiBlockData
        ramBlockData = self.ramBlockData
        ramBlockOtherData = self.ramBlockOtherData
        runningBlocks = self.runningBlocks
        runningBlocks1 = runningBlocks[1]
        runningBlocks3 = runningBlocks[3]
        runningBlocks4 = runningBlocks[4]
        runningBlocks5 = runningBlocks[5]
        runningBlocks6 = runningBlocks[6]
        runningBlocks7 = runningBlocks[7]
        runningBlocks8 = runningBlocks[8]
        runningBlocks9 = runningBlocks[9]
        runningBlocks10 = runningBlocks[10]
        runningBlocks11 = runningBlocks[11]
        runningBlocks12 = runningBlocks[12]
        runningBlocks13 = runningBlocks[13]
        runningBlocks14 = runningBlocks[14]
        runningBlocks15 = runningBlocks[15]
        runningBlocks16 = runningBlocks[16]
        runningBlocks17 = runningBlocks[17]
        runningBlocks18 = runningBlocks[18]
        runningBlocks19 = runningBlocks[19]
        runningBlocks20 = runningBlocks[20]
        runningBlocks21 = runningBlocks[21]
        runningBlocks22 = runningBlocks[22]
        runningBlocks23 = runningBlocks[23]
        runningBlocks24 = runningBlocks[24]
        runningBlocks26 = runningBlocks[26]
        runningBlocks27 = runningBlocks[27]
        numberOfTimesRun = self.numberOfTimesRun
    end
end

function FastLogicRunner.update(self)
    -- fPrint(self, {depth=2, maxTableLength=1000, ignoreTypes={"function"}})
    
    if self.isNew ~= nil then
        if self.isNew > 1 then
            self.isNew = self.isNew - 1
            return
        end
        self.isNew = nil
    end
    self:setFastReadData(true)
    self:optimizeLogic()
    self.blocksRan = 0
    if self.numberOfUpdatesPerTick == -1 then
        self.numberOfUpdatesPerTick = 0
        self.updateTicks = 1
    else
        self.updateTicks = self.updateTicks + self.numberOfUpdatesPerTick
    end
    if self.updateTicks >= 1 then
        -- sm.MTUtil.Profiler.Time.on("doPreUpdate")
        -- make sure all blocks are not broken
        -- fPrint(runningBlockLengths)
        for pathId = 1, #runningBlocks do
            if self.pathNames[pathId] ~= "none" then
                local i = 1
                while i <= runningBlockLengths[pathId] do
                    local id = runningBlocks[pathId][i]
                    if countOfOnInputs[id] == false then
                        -- print("ountOfOnInputs[id] == false broke tell itchytrack (you might be fine still tell him)")
                        nextRunningBlocks[id] = false
                        remove(runningBlocks[pathId], i)
                        runningBlockLengths[pathId] = runningBlockLengths[pathId] - 1
                    else
                        i = i + 1
                    end
                end
            end
        end
        -- sm.MTUtil.Profiler.Time.off("doPreUpdate")
        -- sm.MTUtil.Profiler.Count.increment("doPreUpdate")
        -- local timeTotal = sm.MTUtil.Profiler.Time.get("doPreUpdate")
        -- local countTotal = sm.MTUtil.Profiler.Count.get("doPreUpdate")
        -- print("doPreUpdate: " .. timeTotal / countTotal)
        -- EndTickButtons
        local EndTickButtons = self.blocksSortedByPath[self.pathIndexs["EndTickButtons"]]
        for k = 1, #EndTickButtons do
            local blockId = EndTickButtons[k]
            if countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] > 0 then
                blockStates[blockId] = true
                if self.updateTicks > 1 then
                    self.updateTicks = 1
                end
                runningBlockLengths[1] = 0
            else
                blockStates[blockId] = false
            end
        end
        local sum = 0
        -- other
        -- sm.MTUtil.Profiler.Time.on("doUpdateFullLoop")
        while self.updateTicks >= 2 do
            -- sm.MTUtil.Profiler.Time.on("doUpdate")
            self:doUpdate()
            -- sm.MTUtil.Profiler.Time.off("doUpdate")
            self.updateTicks = self.updateTicks - 1
            -- sm.MTUtil.Profiler.Count.increment("doUpdate")
        end
        -- sm.MTUtil.Profiler.Time.off("doUpdateFullLoop")
        -- light
        local lightBlocks = self.blocksSortedByPath[self.pathIndexs["lightBlocks"]]
        for k = 1, #lightBlocks do
            local blockId = lightBlocks[k]
            blockStates[blockId] = countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] > 0 or
                numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId] == 0
        end
        -- lastTick
        if self.updateTicks >= 1 then
            self:doUpdate()
            self.updateTicks = self.updateTicks - 1
        end
        self:doLastTickUpdates()
    end
    -- print(self.blocksRan)
end

function FastLogicRunner.doUpdate(self)
    local newBlockStatesLength = 0
    local newBlockStates = {}
    local lastRunningIndex = self.nextRunningIndex
    local nextRunningIndex = lastRunningIndex + 1
    self.nextRunningIndex = nextRunningIndex
    local length = #timerData + 1
    timerData[length] = {}
    otherTimeData[length] = {}
    -- EndTickButton
    for k = 1, runningBlockLengths[1] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks1[k]
        if countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] > 0 then
            blockStates[blockId] = true
            if self.updateTicks > 1 then
                self.updateTicks = 2
                self.nextRunningIndex = lastRunningIndex
                runningBlockLengths[1] = 0
                return
            end
        else
            blockStates[blockId] = false
        end
    end
    runningBlockLengths[1] = 0
    -- through
    for k = 1, runningBlockLengths[3] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks3[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] == 1) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    runningBlockLengths[3] = 0
    -- nor through
    for k = 1, runningBlockLengths[4] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks4[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] == numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId]) == blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    runningBlockLengths[4] = 0
    -- and
    for k = 1, runningBlockLengths[6] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks6[k]
        local sumCountOfOnInputs = countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]
        if (sumCountOfOnInputs > 0 and sumCountOfOnInputs == numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId]) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    runningBlockLengths[6] = 0
    -- or
    for k = 1, runningBlockLengths[8] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks8[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] > 0) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    runningBlockLengths[8] = 0
    -- xor
    for k = 1, runningBlockLengths[10] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks10[k]
        if ((countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]) % 2 == 1) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    runningBlockLengths[10] = 0
    -- nand
    local k = 1
    for k = 1, runningBlockLengths[11] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks11[k]
        local sumCountOfOnInputs = countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]
        if (sumCountOfOnInputs > 0 and sumCountOfOnInputs == numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId]) == blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    runningBlockLengths[11] = 0
    -- nor
    for k = 1, runningBlockLengths[13] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks13[k]
        if (countOfOnInputs[blockId] == 0 and countOfOnOtherInputs[blockId] == 0 and numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId] > 0) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        k = k + 1
    end
    runningBlockLengths[12] = 0
    runningBlockLengths[13] = 0
    -- xnor
    for k = 1, runningBlockLengths[15] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks15[k]
        if (
                numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId] > 0 and
                (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]) % 2 == 0
            ) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    runningBlockLengths[15] = 0
    -- timer
    for k = 1, runningBlockLengths[5] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks5[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] == 1) ~= timerInputStates[blockId] then
            timerInputStates[blockId] = not timerInputStates[blockId]
            local row = timerData[timerLengths[blockId]]
            row[#row + 1] = blockId
        end
    end
    runningBlockLengths[5] = 0
    --------------- multi block stuff ---------------
    local runningMultiBlockLengths = runningBlockLengths[16]
    -- through multi block input
    for k = 1, runningBlockLengths[17] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks17[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] == 1) ~= blockStates[blockId] then
            local multiBlockId = multiBlockInputMultiBlockId[blockId]
            local mutliBlockNextRunningBlocks = multiBlockData[multiBlockId][5]
            mutliBlockNextRunningBlocks[#mutliBlockNextRunningBlocks+1] = blockId
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[16][runningMultiBlockLengths] = multiBlockId
                nextRunningBlocks[multiBlockId] = lastRunningIndex
            end
        end
    end
    runningBlockLengths[17] = 0
    -- nor through multi block input
    for k = 1, runningBlockLengths[18] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks18[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] == numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId]) == blockStates[blockId] then
            local multiBlockId = multiBlockInputMultiBlockId[blockId]
            local mutliBlockNextRunningBlocks = multiBlockData[multiBlockId][5]
            mutliBlockNextRunningBlocks[#mutliBlockNextRunningBlocks+1] = blockId
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[16][runningMultiBlockLengths] = multiBlockId
                nextRunningBlocks[multiBlockId] = lastRunningIndex
            end
        end
    end
    runningBlockLengths[18] = 0
    -- and multi block input
    for k = 1, runningBlockLengths[19] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks19[k]
        local sumCountOfOnInputs = countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]
        if (sumCountOfOnInputs > 0 and sumCountOfOnInputs == numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId]) ~= blockStates[blockId] then
            local multiBlockId = multiBlockInputMultiBlockId[blockId]
            local mutliBlockNextRunningBlocks = multiBlockData[multiBlockId][5]
            mutliBlockNextRunningBlocks[#mutliBlockNextRunningBlocks+1] = blockId
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[16][runningMultiBlockLengths] = multiBlockId
                nextRunningBlocks[multiBlockId] = lastRunningIndex
            end
        end
    end
    runningBlockLengths[19] = 0
    -- or multi block input
    for k = 1, runningBlockLengths[20] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks20[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] > 0) ~= blockStates[blockId] then
            local multiBlockId = multiBlockInputMultiBlockId[blockId]
            local mutliBlockNextRunningBlocks = multiBlockData[multiBlockId][5]
            mutliBlockNextRunningBlocks[#mutliBlockNextRunningBlocks+1] = blockId
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[16][runningMultiBlockLengths] = multiBlockId
                nextRunningBlocks[multiBlockId] = lastRunningIndex
            end
        end
    end
    runningBlockLengths[20] = 0
    -- xor multi block input
    for k = 1, runningBlockLengths[21] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks21[k]
        if ((countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]) % 2 == 1) ~= blockStates[blockId] then
            local multiBlockId = multiBlockInputMultiBlockId[blockId]
            local mutliBlockNextRunningBlocks = multiBlockData[multiBlockId][5]
            mutliBlockNextRunningBlocks[#mutliBlockNextRunningBlocks+1] = blockId
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[16][runningMultiBlockLengths] = multiBlockId
                nextRunningBlocks[multiBlockId] = lastRunningIndex
            end
        end
    end
    runningBlockLengths[21] = 0
    -- nand multi block input
    for k = 1, runningBlockLengths[22] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks22[k]
        local sumCountOfOnInputs = countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]
        if (sumCountOfOnInputs > 0 and sumCountOfOnInputs == numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId]) == blockStates[blockId] then
            local multiBlockId = multiBlockInputMultiBlockId[blockId]
            local mutliBlockNextRunningBlocks = multiBlockData[multiBlockId][5]
            mutliBlockNextRunningBlocks[#mutliBlockNextRunningBlocks+1] = blockId
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[16][runningMultiBlockLengths] = multiBlockId
                nextRunningBlocks[multiBlockId] = lastRunningIndex
            end
        end
    end
    runningBlockLengths[22] = 0
    -- nor multi block input
    for k = 1, runningBlockLengths[23] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks23[k]
        if (countOfOnInputs[blockId] == 0 and countOfOnOtherInputs[blockId] == 0 and numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId] > 0) ~= blockStates[blockId] then
            local multiBlockId = multiBlockInputMultiBlockId[blockId]
            local mutliBlockNextRunningBlocks = multiBlockData[multiBlockId][5]
            mutliBlockNextRunningBlocks[#mutliBlockNextRunningBlocks+1] = blockId
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[16][runningMultiBlockLengths] = multiBlockId
                nextRunningBlocks[multiBlockId] = lastRunningIndex
            end
        end
    end
    runningBlockLengths[23] = 0
    -- xnor multi block input
    for k = 1, runningBlockLengths[24] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks24[k]
        if (
                numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId] > 0 and
                (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]) % 2 == 0
            ) ~= blockStates[blockId] then
            local multiBlockId = multiBlockInputMultiBlockId[blockId]
            local mutliBlockNextRunningBlocks = multiBlockData[multiBlockId][5]
            mutliBlockNextRunningBlocks[#mutliBlockNextRunningBlocks+1] = blockId
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[16][runningMultiBlockLengths] = multiBlockId
                nextRunningBlocks[multiBlockId] = lastRunningIndex
            end
        end
    end
    runningBlockLengths[24] = 0
    -- interface multi block input
    for k = 1, runningBlockLengths[27] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks27[k]
        local multiBlockId = multiBlockInputMultiBlockId[blockId]
        if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
            runningMultiBlockLengths = runningMultiBlockLengths + 1
            runningBlocks[16][runningMultiBlockLengths] = multiBlockId
            nextRunningBlocks[multiBlockId] = lastRunningIndex
        end
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] > 0) ~= blockStates[blockId] then
            local mutliBlockNextRunningBlocks = multiBlockData[multiBlockId][5]
            mutliBlockNextRunningBlocks[#mutliBlockNextRunningBlocks+1] = blockId
        end
    end
    runningBlockLengths[27] = 0
    -- multi blocks
    local ramOutputMultiBlocks = {}
    local ramOutputMultiBlocksLength = 0
    local ramOutputMultiBlocksHash = {}
    for k = 1, runningMultiBlockLengths do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks16[k]
        local multiData = multiBlockData[blockId]
        local multiBlockType = multiData[1]
        if multiBlockType == 1 then -- line
            local firstBlock = multiData[3][1]
            local secondBlockId = blockOutputs[firstBlock][1]
            local state = not blockStates[firstBlock]
            blockStates[firstBlock] = state
            if state then
                countOfOnInputs[secondBlockId] = countOfOnInputs[secondBlockId] + 1
            else
                countOfOnInputs[secondBlockId] = countOfOnInputs[secondBlockId] - 1
            end
            local row = otherTimeData[multiData[6]]
            row[#row + 1] = {1, multiData[4][1], state}
        elseif multiBlockType == 2 then -- not line
            local firstBlock = multiData[3][1]
            local secondBlockId = blockOutputs[firstBlock][1]
            local notState = blockStates[firstBlock]
            blockStates[firstBlock] = not notState
            if notState then
                countOfOnInputs[secondBlockId] = countOfOnInputs[secondBlockId] - 1
            else
                countOfOnInputs[secondBlockId] = countOfOnInputs[secondBlockId] + 1
            end
            local row = otherTimeData[multiData[6]]
            row[#row + 1] = {1, multiData[4][1], state}
        elseif multiBlockType == 3 then -- ram block input
            local blocksToUpdate = multiData[5]
            for i = 1, #blocksToUpdate do
                local id = blocksToUpdate[i]
                blockStates[id] = not blockStates[id]
            end
            local ramBlockId = multiData[7]
            if blockStates[multiData[10]] and not blockStates[ramBlockId] then
                local address = 1
                local addressBlocks = multiData[8]
                for i = 1, #addressBlocks do
                    local id = addressBlocks[i]
                    if blockStates[id] then
                        address = address + math.pow(2, i-1)
                    end
                end
                local data = 0
                local dataBlocks = multiData[9]
                for i = 1, #dataBlocks do
                    local id = dataBlocks[i]
                    if blockStates[id] then
                        data = data + math.pow(2, i - 1)
                    end
                end
                if data == 0 then data = nil end
                if ramBlockData[ramBlockId][address] ~= data then
                    ramBlockOtherData[ramBlockId][2] = 1 -- writing happened
                    ramBlockData[ramBlockId][address] = data
                elseif ramBlockOtherData[ramBlockId][2] == 1 then
                    ramBlockOtherData[ramBlockId][2] = 2 -- writing happend and is now done
                end
                local outputInterfaces = ramBlockOtherData[ramBlockId][1]
                local j = 1
                while j <= #outputInterfaces do
                    local outputInterfaceId = outputInterfaces[j]
                    if multiBlockData[outputInterfaceId] == false then
                        remove(outputInterfaces, j)
                    else
                        j = j + 1
                        if ramOutputMultiBlocksHash[outputInterfaceId] == nil then
                            ramOutputMultiBlocksHash[outputInterfaceId] = true
                            ramOutputMultiBlocksLength = ramOutputMultiBlocksLength + 1
                            ramOutputMultiBlocks[ramOutputMultiBlocksLength] = outputInterfaceId
                        end
                    end
                end
            elseif ramBlockOtherData[ramBlockId][2] == 1 then
                ramBlockOtherData[ramBlockId][2] = 2 -- writing happend and is now done
            end
        elseif multiBlockType == 4 then -- ram block output
            local blocksToUpdate = multiData[5]
            for i = 1, #blocksToUpdate do
                local id = blocksToUpdate[i]
                blockStates[id] = not blockStates[id]
            end
            if ramOutputMultiBlocksHash[blockId] == nil then
                ramOutputMultiBlocksHash[blockId] = true
                ramOutputMultiBlocksLength = ramOutputMultiBlocksLength + 1
                ramOutputMultiBlocks[ramOutputMultiBlocksLength] = blockId
            end
        elseif multiBlockType == 5 then -- balanced hash
            local blocksToUpdate = multiData[5]
            local inputData = multiData[10]
            local inputsIndexPow2 = multiData[11]
            for i = 1, #blocksToUpdate do
                local id = blocksToUpdate[i]
                blockStates[id] = not blockStates[id]
                local stateNumber = blockStates[id] and 1 or -1
                inputData = inputData + inputsIndexPow2[id] * stateNumber
                local outputs = blockOutputs[id]
                for j = 1, #outputs do
                    local outputId = outputs[j]
                    countOfOnInputs[outputId] = countOfOnInputs[outputId] + stateNumber
                end
            end
            multiData[10] = inputData
            local data = multiData[7][inputData]
            local outputTimes = multiData[9]
            local outputs = multiData[4]
            local farthestOutput = multiData[8]
            if data == nil then -- not hashed
                local newData = {}
                for i = 1, #outputs do
                    local id = outputs[i]
                    local outputTime = outputTimes[i]
                    local row = otherTimeData[outputTime]
                    if id == farthestOutput then
                        row[#row + 1] = {3, id, i, newData, inputData, multiData}
                    else
                        row[#row + 1] = {2, id, i, newData}
                    end
                    if outputTime > 2 then
                        row = otherTimeData[outputTime-2]
                        row[#row + 1] = {4, id}
                    end
                end
                -- run internals
                local inputs = multiData[3]
                for i = 1, #inputs do
                    local id = inputs[i]
                    if runnableBlockPathIds[id] ~= 27 then
                        local outputs = blockOutputs[id]
                        for j = 1, #outputs do
                            local outputId = outputs[j]
                            if nextRunningBlocks[outputId] ~= nextRunningIndex then
                                nextRunningBlocks[outputId] = nextRunningIndex
                                local pathId = runnableBlockPathIds[outputId]
                                runningBlockLengths[pathId] = runningBlockLengths[pathId] + 1
                                runningBlocks[pathId][runningBlockLengths[pathId]] = outputId
                            end
                        end
                    end
                end
            else
                for i = 1, #outputs do
                    local id = outputs[i]
                    local row = otherTimeData[outputTimes[i] - 1]
                    if id == farthestOutput then
                        row[#row + 1] = {5, id, data[i], inputData, multiData}
                    else
                        row[#row + 1] = {1, id, data[i]}
                    end
                end
            end
        else
            print("no runner for multi block with id: " .. tostring(multiData[1]))
        end
        -- code for updating inputs
        -- local blocksToUpdate = multiData[5]
        -- for i = 1, #blocksToUpdate do
        --     local id = blocksToUpdate[i]
        --     blockStates[id] = not blockStates[id]
        --     local stateNumber = blockStates[id] and 1 or -1
        --     local outputs = blockOutputs[id]
        --     for j = 1, #outputs do
        --         local outputId = outputs[j]
        --         countOfOnInputs[outputId] = countOfOnInputs[outputId] + stateNumber
        --     end
        -- end

        -- code for passing values through 
        -- local inputs = multiData[3]
        -- for i = 1, #inputs do
        --     local id = inputs[i]
        --     local outputs = blockOutputs[id]
        --     for j = 1, #outputs do
        --         local outputId = outputs[j]
        --         if nextRunningBlocks[outputId] ~= nextRunningIndex then
        --             nextRunningBlocks[outputId] = nextRunningIndex
        --             local pathId = runnableBlockPathIds[outputId]
        --             runningBlockLengths[pathId] = runningBlockLengths[pathId] + 1
        --             runningBlocks[pathId][runningBlockLengths[pathId]] = outputId
        --         end
        --     end
        -- end
        multiBlockData[blockId][5] = {}
    end
    runningBlockLengths[16] = 0
    -- ram block reset
    for k = 1, runningBlockLengths[26] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks26[k]
        local state = blockStates[blockId]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] > 0) ~= state then
            blockStates[blockId] = not state
            if state == false then
                local newData = {}
                ramBlockData[blockId] = newData
                FastLogicBlockMemorys[unhashedLookUp[blockId]].memory = newData
                local outputInterfaces = ramBlockOtherData[blockId][1]
                ramBlockOtherData[blockId][2] = 2 -- need to save
                local j = 1
                while j <= #outputInterfaces do
                    local outputInterfaceId = outputInterfaces[j]
                    if multiBlockData[outputInterfaceId] == false then
                        remove(outputInterfaces, j)
                    else
                        j = j + 1
                        if ramOutputMultiBlocksHash[outputInterfaceId] == nil then
                            ramOutputMultiBlocksHash[outputInterfaceId] = true
                            ramOutputMultiBlocksLength = ramOutputMultiBlocksLength + 1
                            ramOutputMultiBlocks[ramOutputMultiBlocksLength] = outputInterfaceId
                        end
                    end
                end
            end
        end
    end
    runningBlockLengths[26] = 0
    -- ram outputs
    for k = 1, ramOutputMultiBlocksLength do
        local multiData = multiBlockData[ramOutputMultiBlocks[k]]
        local data = 0
        if multiData[10] == nil or blockStates[multiData[10]] then
            local addressBlocks = multiData[8]
            local address = 1
            for i = 1, #addressBlocks do
                local id = addressBlocks[i]
                if blockStates[id] then
                    address = address + math.pow(2, i-1)
                end
            end
            data = ramBlockData[multiData[7]][address] or 0
        end
        local dataBlocks = multiData[9]
        for i = 1, #dataBlocks do
            local id = dataBlocks[i]
            if (data%2 >= 1) ~= blockStates[id] then
                newBlockStatesLength = newBlockStatesLength + 1
                newBlockStates[newBlockStatesLength] = id
            end
            data = data / 2
        end
    end
    -- run time stuff
    local timerReadRow = remove(timerData, 1)
    for k = 1, #timerReadRow do
        newBlockStatesLength = newBlockStatesLength + 1
        newBlockStates[newBlockStatesLength] = timerReadRow[k]
    end
    local otherReadRow = remove(otherTimeData, 1)
    for k = 1, #otherReadRow do
        local item = otherReadRow[k]
        local item1 = item[1]
        if item1 == 1 then
            local id = item[2]
            if item[3] ~= blockStates[id] then
                newBlockStatesLength = newBlockStatesLength + 1
                newBlockStates[newBlockStatesLength] = id
            end
        elseif item1 == 2 then
            local index = item[3]
            local hashArray = item[4]
            hashArray[index] = blockStates[item[2]]
        elseif item1 == 3 then
            local index = item[3]
            local hashArray = item[4]
            hashArray[index] = blockStates[item[2]]
            local multiData = item[6]
            multiData[7][item[5]] = hashArray
            multiData[12] = nil
        elseif item1 == 4 then
            local id = item[2]
            if nextRunningBlocks[id] ~= nextRunningIndex then
                nextRunningBlocks[id] = nextRunningIndex
                local pathId = runnableBlockPathIds[id]
                if pathId ~= 2 then
                    runningBlockLengths[pathId] = runningBlockLengths[pathId] + 1
                    runningBlocks[pathId][runningBlockLengths[pathId]] = id
                end
            end
        elseif item1 == 5 then
            local id = item[2]
            item[5][12] = item[4]
            if item[3] ~= blockStates[id] then
                newBlockStatesLength = newBlockStatesLength + 1
                newBlockStates[newBlockStatesLength] = id
            end
        end
    end
    -- update all
    for k = 1, newBlockStatesLength do
        local id = newBlockStates[k]
        local state = not blockStates[id]
        local stateNumber = state and 1 or -1
        blockStates[id] = state
        local outputs = blockOutputs[id]
        numberOfTimesRun[id] = numberOfTimesRun[id] + 1
        for k = 1, #outputs do
            local outputId = outputs[k]
            countOfOnInputs[outputId] = countOfOnInputs[outputId] + stateNumber
            if nextRunningBlocks[outputId] ~= nextRunningIndex then
                nextRunningBlocks[outputId] = nextRunningIndex
                local pathId = runnableBlockPathIds[outputId]
                if pathId ~= 2 then
                    runningBlockLengths[pathId] = runningBlockLengths[pathId] + 1
                    runningBlocks[pathId][runningBlockLengths[pathId]] = outputId
                end
            end
        end
    end
end



----------------------------- below is not part of the main loop!!! -----------------------------



-- assumes that included blocks are part of a balanced circuit
function FastLogicRunner.simulatedManyBalancedUpdates(
    self,
    blockIdsToInclude,
    numberOfTicksToRun,
    inputStatesOverTime
)
    -- setup vars
    self:setFastReadData()
    local altBlockData = self.altBlockData
    local blockIdsToIncludeHash = {}
    local usingPathIds = {}
    local maxTimerLenght = 0
    local toUpdate = {}
    local toUpdateHash = {}

    for k = 1, #blockIdsToInclude do
        local id = blockIdsToInclude[k]
        blockIdsToIncludeHash[id] = true
        if altBlockData[id] ~= false then
            usingPathIds[id] = altBlockData[id]
        else
            usingPathIds[id] = runnableBlockPathIds[id]
        end
        if usingPathIds[id] == 5 and maxTimerLenght < timerLengths[id] then
            maxTimerLenght = timerLengths[id]
        end
    end

    local states = {}
    local simTimerData = {}

    while #simTimerData < maxTimerLenght do
        simTimerData[#simTimerData + 1 ] = {}
    end

    local blocksThatUpdated = {}
    -- run ticks
    for tick = 1, numberOfTicksToRun do
        -- set inputs
        local inputStates = inputStatesOverTime[tick]
        if inputStates ~= nil then
            for id,state in pairs(inputStates) do
                states[id] = state
                local outputs = blockOutputs[id]
                for k = 1, #outputs do
                    local outputId = outputs[k]
                    if toUpdateHash[outputId] == nil then
                        toUpdateHash[outputId] = true
                        toUpdate[#toUpdate+1] = outputId
                    end
                end
            end
        end
        blocksThatUpdated[#blocksThatUpdated+1] = toUpdated
        -- do tick
        toUpdateHash = {}
        local newStates = {}
        local toUpdate2 = {}
        for k = 1, #toUpdate do
            local id = toUpdate[k]
            if blockIdsToIncludeHash[id] == true then
                local path = usingPathIds[id]
                if path == 5 then -- timer
                    simTimerData[timerLengths[id]][#simTimerData[timerLengths[id]] + 1] = {
                        id,
                        states[blockInputs[id][1]]
                    }
                else
                    if path == 6 then -- and
                        local state = true
                        local inputs = blockInputs[id]
                        for i = 1, numberOfBlockInputs[id] do
                            if not states[inputs[i]] then
                                state = false
                                goto endAndLoop
                            end
                        end
                        ::endAndLoop::
                        newStates[id] = state
                    elseif path == 8 then -- or
                        local state = false
                        local inputs = blockInputs[id]
                        for i = 1, numberOfBlockInputs[id] do
                            if states[inputs[i]] then
                                state = true
                                goto endOrLoop
                            end
                        end
                        ::endOrLoop::
                        newStates[id] = state
                    elseif path == 10 then -- xor
                        local state = false
                        local inputs = blockInputs[id]
                        for i = 1, numberOfBlockInputs[id] do
                            if states[inputs[i]] then
                                state = not state
                            end
                        end
                        newStates[id] = state
                    elseif path == 11 then -- nand
                        local state = false
                        local inputs = blockInputs[id]
                        for i = 1, numberOfBlockInputs[id] do
                            if not states[inputs[i]] then
                                state = true
                                goto endNandLoop
                            end
                        end
                        ::endNandLoop::
                        newStates[id] = state
                    elseif path == 13 then -- nor
                        local state = true
                        local inputs = blockInputs[id]
                        for i = 1, numberOfBlockInputs[id] do
                            if states[inputs[i]] then
                                state = false
                                goto endNorLoop
                            end
                        end
                        ::endNorLoop::
                        newStates[id] = state
                    elseif path == 15 then -- xnor
                        local state = true
                        local inputs = blockInputs[id]
                        for i = 1, numberOfBlockInputs[id] do
                            if states[inputs[i]] then
                                state = not state
                            end
                        end
                        newStates[id] = state
                    end
                    -- tell outputs to update
                    local outputs = blockOutputs[id]
                    for i = 1, numberOfBlockOutputs[id] do
                        local outputId = outputs[i]
                        if toUpdateHash[outputId] == nil then
                            toUpdateHash[outputId] = true
                            toUpdate2[#toUpdate2+1] = outputId
                        end
                    end
                end
            end
        end
        -- copy over new states
        for k = 1, #toUpdate do
            local id = toUpdate[k]
            if newStates[id] ~= nil then
                states[id] = newStates[id]
            end
        end
        -- step timer data
        if #simTimerData ~= 0 then
            local timerReadRow = remove(simTimerData, 1)
            simTimerData[#simTimerData+1] = {}
            for i = 1, #timerReadRow do
                local item = timerReadRow[i]
                local id = item[1]
                states[id] = item[2]
                -- tell outputs to update
                local outputs = blockOutputs[id]
                for k = 1, #outputs do
                    local outputId = outputs[k]
                    if toUpdateHash[outputId] == nil then
                        toUpdateHash[outputId] = true
                        toUpdate2[#toUpdate2+1] = outputId
                    end
                end
            end
        end
        toUpdate = toUpdate2
    end
    -- end run
    local idsToUpdate = {}
    local idsToUpdateHash = {}
    local perTimerData = {}
    for i = 1, #blocksThatUpdated do
        for j = 1, #blocksThatUpdated[i] do
            local id = blocksThatUpdated[i][j]
            if idsToUpdateHash[id] == nil then
                idsToUpdate[#idsToUpdate+1] = id
                idsToUpdateHash[id] = true
                if usingPathIds[id] == 5 then
                    perTimerData[id] = {states[id], {}}
                end
            end
        end
    end
    for id,state in pairs(states) do
        if idsToUpdateHash[id] == nil then
            idsToUpdate[#idsToUpdate+1] = id
            idsToUpdateHash[id] = true
            if usingPathIds[id] == 5 then
                perTimerData[id] = {state, {}}
            end
        end
    end
    for k = #simTimerData, 1, -1 do
        local row = simTimerData[k]
        for i = 1, #row do
            local id = row[i][1]
            if idsToUpdateHash[id] then
                local state = row[i][2]
                local timer = perTimerData[id]
                if timer[1] ~= state then
                    timer[1] = state
                    local timerTimeData = timer[2]
                    timerTimeData[#timerTimeData+1] = k
                end
            end
        end
    end
    return idsToUpdate, states, perTimerData
end

--- unused. If it doesn't work, don't be surprised 
--- no it will not work
function FastLogicRunner.simulatedBalancedUpdates(self, blockIdsToInclude, numberOfTicksToRun, inputStates)
    self:setFastReadData()
    local usingPathIds = {}
    local states = {}
    local toUpdateHash = {}
    local toUpdate = {}
    local simTimerData = {}

    -- setup inputs
    for i = 1, #blockIdsToInclude do
        local id = blockIdsToInclude[i]
        blockIdsToIncludeHash[id] = true
        if altBlockData[id] ~= false then
            usingPathIds[id] = altBlockData[id]
        else
            usingPathIds[id] = runnableBlockPathIds[id]
        end
        if usingPathIds[id] == 5 then
            while #simTimerData < timerLengths[id] do
                simTimerData[#simTimerData + 1 ] = {}
            end
        end
        if inputStates[id] ~= nil then
            states[id] = inputStates[id]
            local outputs = blockOutputs[id]
            for k = 1, #numberOfBlockOutputs[id] do
                local outputId = outputs[k]
                if outputId ~= -1 then
                    if toUpdateHash[outputId] == nil then
                        toUpdateHash[outputId] = true
                        toUpdate[#toUpdate] = outputId
                    end
                end
            end
        end
    end
    local timerReadRow = remove(simTimerData, 1)
    for i = 1, #timerReadRow do
        local item = timerReadRow[i]
        local id = item[1]
        states[id] = item[2]
        -- tell outputs to update
        local outputs = blockOutputs[id]
        for i = 1, #numberOfBlockOutputs[id] do
            local outputId = outputs[i]
            if outputId ~= -1 then
                if toUpdateHash[outputId] == nil then
                    toUpdateHash[outputId] = true
                    toUpdate[#toUpdate] = outputId
                end
            end
        end
    end

    -- run ticks
    local toUpdate2 = {}
    for tick = 1, numberOfTicksToRun do
        toUpdateHash = {}
        for k = 1, #toUpdate do
            local id = toUpdate[k]
            if blockIdsToIncludeHash[id] == false then
                local path = usingPathIds[id]
                if path == 5 then -- timer
                    simTimerData[timerLengths[id]][#simTimerData[timerLengths[id]]] = {id, states[blockInputs[id][1]]}
                else
                    if path == 6 or path == 7 then -- and
                    local state = true
                    local inputs = blockInputs[id]
                    for i = 1, numberOfBlockInputs[id] do
                        if not states[inputs[i]] then
                            state = false
                            goto endAndLoop
                        end
                    end
                    ::endAndLoop::
                    states[id] = state
                    elseif path == 8 or path == 9 then -- or
                        local state = false
                        local inputs = blockInputs[id]
                        for i = 1, numberOfBlockInputs[id] do
                            if states[inputs[i]] then
                                state = true
                                goto endOrLoop
                            end
                        end
                        ::endOrLoop::
                        states[id] = state
                    elseif path == 10 then -- xor
                        local state = false
                        local inputs = blockInputs[id]
                        for i = 1, numberOfBlockInputs[id] do
                            if states[inputs[i]] then
                                state = not state
                            end
                        end
                        states[id] = state
                    elseif path == 11 or path == 12 then -- nand
                        local state = false
                        local inputs = blockInputs[id]
                        for i = 1, numberOfBlockInputs[id] do
                            if not states[inputs[i]] then
                                state = true
                                goto endNandLoop
                            end
                        end
                        ::endNandLoop::
                        states[id] = state
                    elseif path == 13 or path == 14 then -- nor
                        local state = true
                        local inputs = blockInputs[id]
                        for i = 1, numberOfBlockInputs[id] do
                            if states[inputs[i]] then
                                state = false
                                goto endNorLoop
                            end
                        end
                        ::endNorLoop::
                        states[id] = state
                    elseif path == 15 then -- xnor
                        local state = true
                        local inputs = blockInputs[id]
                        for i = 1, numberOfBlockInputs[id] do
                            if states[inputs[i]] then
                                state = not state
                            end
                        end
                        states[id] = state
                    end
                    -- tell outputs to update
                    local outputs = blockOutputs[id]
                    for i = 1, #numberOfBlockOutputs[id] do
                        local outputId = outputs[i]
                        if outputId ~= -1 then
                            if toUpdateHash[outputId] == nil then
                                toUpdateHash[outputId] = true
                                toUpdate2[#toUpdate] = outputId
                            end
                        end
                    end
                end
            end
        end
        local timerReadRow = remove(simTimerData, 1)
        for i = 1, #timerReadRow do
            local item = timerReadRow[i]
            local id = item[1]
            states[id] = item[2]
            -- tell outputs to update
            local outputs = blockOutputs[id]
            for i = 1, #numberOfBlockOutputs[id] do
                local outputId = outputs[i]
                if outputId ~= -1 then
                    if toUpdateHash[outputId] == nil then
                        toUpdateHash[outputId] = true
                        toUpdate2[#toUpdate] = outputId
                    end
                end
            end
        end
        toUpdate = toUpdate2
        toUpdate2 = {}
    end

    return {states, simTimerData, toUpdate}
end
