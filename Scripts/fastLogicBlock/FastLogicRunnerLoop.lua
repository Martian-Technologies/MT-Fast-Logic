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
local timerLengths = nil
local timerInputStates = nil
local blockOutputs = nil
local lastTimerOutputWait = nil
local multiBlockData = nil
local numberOfTimesRun = nil
local runningBlocks1 = nil
local runningBlocks3 = nil
local runningBlocks4 = nil
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
local runningBlocks5 = nil
local runningBlocks17 = nil
local runningBlocks18 = nil
local runningBlocks19 = nil
local runningBlocks20 = nil
local runningBlocks21 = nil
local runningBlocks22 = nil
local runningBlocks23 = nil
local runningBlocks24 = nil
local runningBlocks16 = nil

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
    timerData = self.timerData
    timerLengths = self.timerLengths
    timerInputStates = self.timerInputStates
    blockOutputs = self.blockOutputs
    lastTimerOutputWait = self.lastTimerOutputWait
    multiBlockData = self.multiBlockData
    if needsRunningBlocks == true then
        runningBlocks = self.runningBlocks
        runningBlocks1 = runningBlocks[1]
        runningBlocks3 = runningBlocks[3]
        runningBlocks4 = runningBlocks[4]
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
        runningBlocks5 = runningBlocks[5]
        runningBlocks17 = runningBlocks[17]
        runningBlocks18 = runningBlocks[18]
        runningBlocks19 = runningBlocks[19]
        runningBlocks20 = runningBlocks[20]
        runningBlocks21 = runningBlocks[21]
        runningBlocks22 = runningBlocks[22]
        runningBlocks23 = runningBlocks[23]
        runningBlocks24 = runningBlocks[24]
        runningBlocks16 = runningBlocks[16]
        numberOfTimesRun = self.numberOfTimesRun
    end
end

function FastLogicRunner.update(self)
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
        --make sure all blocks are not broken
        for pathId = 1, #runningBlocks do
            if self.pathNames[pathId] ~= "none" then
                local i = 1
                while i <= runningBlockLengths[pathId] do
                    local id = runningBlocks[pathId][i]
                    if countOfOnInputs[id] == false then
                        -- pri nt("ountOfOnInputs[id] == false broke tell itchytrack (you might be fine still tell him)")
                        nextRunningBlocks[id] = false
                        table.remove(runningBlocks[pathId], i)
                        runningBlockLengths[pathId] = runningBlockLengths[pathId] - 1
                    else
                        i = i + 1
                    end
                end
            end
        end
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
            sum = 0
            for i = 1, #self.runningBlockLengths do
                if self.pathNames[i] ~= "none" then
                    sum = sum + self.runningBlockLengths[i]
                end
            end
            if sum == 0 and self.lastTimerOutputWait <= -1 then
                self.updateTicks = 1
            end
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
    timerData[#timerData + 1] = {}
    for k = 1, runningBlockLengths[5] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks5[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] == 1) ~= timerInputStates[blockId] then
            timerInputStates[blockId] = not timerInputStates[blockId]
            timerData[timerLengths[blockId]][#timerData[timerLengths[blockId]] + 1] = blockId
            lastTimerOutputWait = timerLengths[blockId] > lastTimerOutputWait and timerLengths[blockId] + 1 or lastTimerOutputWait
        end
    end
    runningBlockLengths[5] = 0
    local timerReadRow = table.remove(timerData, 1)
    for k = 1, #timerReadRow do
        local item = timerReadRow[k]
        if type(item) == "number" then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = timerReadRow[k]
        elseif type(item[1]) == "boolean" then
            if countOfOnInputs[item[2]] ~= false and item[1] ~= blockStates[item[2]] then
                newBlockStatesLength = newBlockStatesLength + 1
                newBlockStates[newBlockStatesLength] = item[2]
            end
        else

        end
    end
    if lastTimerOutputWait >= 0 then
        self.lastTimerOutputWait = lastTimerOutputWait - 1
    end
    --------------- multi block stuff ---------------
    local runningMultiBlockLengths = runningBlockLengths[16]
    -- through multi block input
    for k = 1, runningBlockLengths[17] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks17[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] == 1) ~= blockStates[blockId] then
            local multiBlockId = multiBlockData[blockId]
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[16][runningMultiBlockLengths] = multiBlockId
                nextRunningBlocks[multiBlockId] = lastRunningIndex
                multiBlockData[multiBlockId][5][#multiBlockData[multiBlockId][5]+1] = blockId
            end
        end
    end
    runningBlockLengths[17] = 0
    -- nor through multi block input
    for k = 1, runningBlockLengths[18] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks18[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] == numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId]) == blockStates[blockId] then
            local multiBlockId = multiBlockData[blockId]
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[16][runningMultiBlockLengths] = multiBlockId
                nextRunningBlocks[multiBlockId] = lastRunningIndex
                multiBlockData[multiBlockId][5][#multiBlockData[multiBlockId][5]+1] = blockId
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
            local multiBlockId = multiBlockData[blockId]
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[16][runningMultiBlockLengths] = multiBlockId
                nextRunningBlocks[multiBlockId] = lastRunningIndex
                multiBlockData[multiBlockId][5][#multiBlockData[multiBlockId][5]+1] = blockId
            end
        end
    end
    runningBlockLengths[19] = 0
    -- or multi block input
    for k = 1, runningBlockLengths[20] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks20[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] > 0) ~= blockStates[blockId] then
            local multiBlockId = multiBlockData[blockId]
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[16][runningMultiBlockLengths] = multiBlockId
                nextRunningBlocks[multiBlockId] = lastRunningIndex
                multiBlockData[multiBlockId][5][#multiBlockData[multiBlockId][5]+1] = blockId
            end
        end
        k = k + 1
    end
    runningBlockLengths[20] = 0
    -- xor multi block input
    for k = 1, runningBlockLengths[21] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks21[k]
        if ((countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]) % 2 == 1) ~= blockStates[blockId] then
            local multiBlockId = multiBlockData[blockId]
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[16][runningMultiBlockLengths] = multiBlockId
                nextRunningBlocks[multiBlockId] = lastRunningIndex
                multiBlockData[multiBlockId][5][#multiBlockData[multiBlockId][5]+1] = blockId
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
            local multiBlockId = multiBlockData[blockId]
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[16][runningMultiBlockLengths] = multiBlockId
                nextRunningBlocks[multiBlockId] = lastRunningIndex
                multiBlockData[multiBlockId][5][#multiBlockData[multiBlockId][5]+1] = blockId
            end
        end
    end
    runningBlockLengths[22] = 0
    -- nor multi block input
    for k = 1, runningBlockLengths[23] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks23[k]
        if (countOfOnInputs[blockId] == 0 and countOfOnOtherInputs[blockId] == 0 and numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId] > 0) ~= blockStates[blockId] then
            local multiBlockId = multiBlockData[blockId]
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[16][runningMultiBlockLengths] = multiBlockId
                nextRunningBlocks[multiBlockId] = lastRunningIndex
                multiBlockData[multiBlockId][5][#multiBlockData[multiBlockId][5]+1] = blockId
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
            local multiBlockId = multiBlockData[blockId]
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[16][runningMultiBlockLengths] = multiBlockId
                nextRunningBlocks[multiBlockId] = lastRunningIndex
                multiBlockData[multiBlockId][5][#multiBlockData[multiBlockId][5]+1] = blockId
            end
        end
    end
    runningBlockLengths[24] = 0
    -- multi blocks
    for k = 1, runningMultiBlockLengths do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks16[k]
        local multiData = multiBlockData[blockId]
        for i = 1, #multiData[5] do
            local id = multiData[5][i]
            blockStates[id] = not blockStates[id]
            local stateNumber = blockStates[id] and 1 or -1
            local outputs = blockOutputs[id]
            for j = 1, #outputs do
                local outputId = outputs[j]
                if outputId ~= -1 then
                    countOfOnInputs[outputId] = countOfOnInputs[outputId] + stateNumber
                end
            end
        end
        local didNotRunInternal = false
        -- run internal
        if multiData[1] == 1 then
            local outputId = multiData[4][1]
            timerData[multiData[7]][#timerData[multiData[7]] + 1] = {blockStates[multiData[3][1]], multiData[4][1]}
            lastTimerOutputWait = multiData[7] > lastTimerOutputWait and multiData[7] + 1 or lastTimerOutputWait
        elseif multiData[1] == 2 then
            local outputId = multiData[4][1]
            timerData[multiData[7]][#timerData[multiData[7]] + 1] = {not blockStates[multiData[3][1]], multiData[4][1]}
            lastTimerOutputWait = multiData[7] > lastTimerOutputWait and multiData[7] + 1 or lastTimerOutputWait
        else
            print("no runner for multi block with id: " .. tostring(multiData[1]))
            didNotRunInternal = true
        end

        if didNotRunInternal then -- run blocks
            for i = 1, #multiData[3] do
                local outputs = blockOutputs[multiData[3][i]]
                for j = 1, #outputs do
                    local outputId = outputs[j]
                    -- if outputId ~= -1 then
                        if nextRunningBlocks[outputId] ~= nextRunningIndex then
                            nextRunningBlocks[outputId] = nextRunningIndex
                            local pathId = runnableBlockPathIds[outputId]
                            runningBlockLengths[pathId] = runningBlockLengths[pathId] + 1
                            runningBlocks[pathId][runningBlockLengths[pathId]] = outputId
                        end
                    -- end
                end
            end
        end
        multiBlockData[blockId][5] = {}
    end
    runningBlockLengths[16] = 0
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



-- assumes that the blocks are all make up a balenced circuit
function FastLogicRunner.simulatedManyBalencedUpdates(self, blockIdsToInclude, listOfNumberOfTicksToRun, listOfInputStates)
    -- setup vars
    self:setFastReadData()
    local blockIdsToIncludeHash = {}
    local allToUpdate = {}
    local allToUpdateHash = {}
    local allStates = {}
    local allTimerData = {}
    local allTimerDataHash = {}
    local usingPathIds = {}
    local maxTimerLenght = 0
    for k = 1, #blockIdsToInclude do
        local id = blockIdsToInclude[k]
        blockIdsToIncludeHash[id] = true
        if altBlockData[id] ~= nil then
            usingPathIds[id] = altBlockData[id]
        else
            usingPathIds[id] = runnableBlockPathIds[id]
        end
        if runnableBlockPathIds[id] == 5 and maxTimerLenght < timerLengths[id] then
            maxTimerLenght = timerLengths[id]
        end
    end

    for j = 1, #listOfNumberOfTicksToRun do
        local numberOfTicksToRun = listOfNumberOfTicksToRun[j]
        local inputStates = listOfInputStates[j]
        -- run
        while #timerData < maxTimerLenght do
            timerData[#timerData + 1 ] = {}
        end
        local states = {}
        local toUpdateHash = {}
        local toUpdate = {}
        local simTimerData = {}

        -- setup inputs
        for i = 1, #blockIdsToInclude do
            local id = blockIdsToInclude[i]
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
        local timerReadRow = table.remove(simTimerData, 1)
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
            local timerReadRow = table.remove(simTimerData, 1)
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
        -- end run
        for k = 1, #blockIdsToInclude do
            local id = blockIdsToInclude[k]
            if states[id] ~= nil then
                allStates[id] = states[id]
            end
        end
        for k = 1, #simTimerData do
            local data = simTimerData[k]
            local timerHash = allTimerDataHash[k]
            local timer = allTimerData[k]
            for i = 1, #data do
                local id = data[i][1]
                if timerHash[id] == nil then
                    timer[#timer + 1] = data[i]
                    timerHash[id] = #timer
                else
                    timer[timerHash[id]][2] = data[i][2]
                end
            end
        end
        for k = 1, #toUpdate do
            local id = toUpdate[k]
            if allToUpdateHash[id] == nil then
                allToUpdate[#allToUpdate + 1] = id
                allToUpdateHash[id] = true
            end
        end
    end
    return {allStates, allTimerData, allToUpdate}
end

function FastLogicRunner.simulatedBalencedUpdates(self, blockIdsToInclude, numberOfTicksToRun, inputStates)
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
        if altBlockData[id] ~= nil then
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
    local timerReadRow = table.remove(simTimerData, 1)
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
        local timerReadRow = table.remove(simTimerData, 1)
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