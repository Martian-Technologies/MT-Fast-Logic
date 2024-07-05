dofile "../util/util.lua"
local string = string
local table = table
local type = type
local pairs = pairs

FastLogicRunner = FastLogicRunner or {}

dofile "BlockMannager.lua"
dofile "BalancedLogicFinder.lua"
dofile "LogicOptimizer.lua"

-- locals for fast read
local table = table
local ipairs = ipairs
local pairs = pairs

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
local numberOfStateChanges = nil
local numberOfOptimizedInputs = nil
local optimizedBlockOutputs = nil
local optimizedBlockOutputsPosHash = nil
local nextTimerOutputWait = nil
local multiBlockData = nil
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

function FastLogicRunner.getNew(creationId)
    print("new logic runner")
    local new = table.deepCopy(FastLogicRunner)
    new.creationId = creationId
    new.getNew = nil
    return new
end

function FastLogicRunner.init(self)
    self.creation = sm.MTFastLogic.Creations[self.creationId]
    self.numberOfUpdatesPerTick = self.numberOfUpdatesPerTick or 1
    self.updateTicks = self.updateTicks or 0
    self.blocksOptimized = self.blocksOptimized or -100
    self.blocksToAddInputs = {}
    if self.hashData == nil then
        self:makeDataArrays()
    end
end

function FastLogicRunner.makeDataArrays(self)
    -- setUpHassStuff
    self.hashData = table.makeConstantKeysOnlyHash({})
    self.unhashedLookUp = self.hashData.unhashedLookUp
    self.hashedLookUp = self.hashData.hashedLookUp
    -- make arrays
    self.blocksRan = 0
    self.nextTimerOutputWait = 0
    self.blockStates = table.makeArrayForHash(self.hashData)
    self.blockInputs = table.makeArrayForHash(self.hashData)
    self.lastBlockStates = table.makeArrayForHash(self.hashData, 0)
    self.blockInputsHash = {}
    self.runnableBlockPaths = table.makeArrayForHash(self.hashData)
    self.blockOutputs = table.makeArrayForHash(self.hashData)
    self.blockOutputsHash = {}
    self.numberOfBlockInputs = table.makeArrayForHash(self.hashData)
    self.numberOfOtherInputs = table.makeArrayForHash(self.hashData)
    self.numberOfBlockOutputs = table.makeArrayForHash(self.hashData)
    self.countOfOnInputs = table.makeArrayForHash(self.hashData)
    self.countOfOnOtherInputs = table.makeArrayForHash(self.hashData)
    self.timerData = {}
    self.timerLengths = table.makeArrayForHash(self.hashData)
    self.timerInputStates = table.makeArrayForHash(self.hashData)
    self.runnableBlockPathIds = table.makeArrayForHash(self.hashData)
    self.longestTimer = 0
    self.numberOfStateChanges = table.makeArrayForHash(self.hashData)
    self.numberOfOptimizedInputs = table.makeArrayForHash(self.hashData)
    self.optimizedBlockOutputs = table.makeArrayForHash(self.hashData)
    self.optimizedBlockOutputsPosHash = table.makeArrayForHash(self.hashData)
    self.altBlockData = table.makeArrayForHash(self.hashData)
    self.multiBlockData = table.makeArrayForHash(self.hashData)
    self.pathNames = {
        "EndTickButtons",            -- 1
        "lightBlocks",               -- 2
        "throughBlocks",             -- 3
        "norThroughBlocks",          -- 4
        "timerBlocks",               -- 5
        "andBlocks",                 -- 6
        "and2Blocks",                -- 7
        "orBlocks",                  -- 8
        "or2Blocks",                 -- 9
        "xorBlocks",                 -- 10
        "nandBlocks",                -- 11
        "nand2Blocks",               -- 12
        "norBlocks",                 -- 13
        "nor2Blocks",                -- 14
        "xnorBlocks",                -- 15
        "multiBlocks",               -- 16
        "throughMultiBlockInput",    -- 17
        "norThroughMultiBlockInput", -- 18
        "andMultiBlockInput",        -- 19
        "orMultiBlockInput",         -- 20
        "xorMultiBlockInput",        -- 21
        "nandMultiBlockInput",       -- 22
        "norMultiBlockInput",        -- 23
        "xnorMultiBlockInput",       -- 24
        "blockStateSetterBlocks",    -- 25
    }
    self.pathIndexs = {}
    for index, path in pairs(self.pathNames) do
        self.pathIndexs[path] = index
    end
    self.nextRunningBlocks = table.makeArrayForHash(self.hashData, 0)
    self.nextRunningIndex = 1
    self.runningBlocks = {}
    self.runningBlockLengths = {}
    self.blocksSortedByPath = {}
    for _, pathId in pairs(self.pathIndexs) do
        self.runningBlocks[pathId] = {}
        self.runningBlockLengths[pathId] = 0
        self.blocksSortedByPath[pathId] = {}
    end
    self.toMultiBlockInput = {
        false, -- 1
        false, -- 2
        17,    -- 3
        18,    -- 4
        false, -- 5
        19,    -- 6
        19,    -- 7
        20,    -- 8
        20,    -- 9
        21,    -- 10
        22,    -- 11
        22,    -- 12
        23,    -- 13
        23,    -- 14
        24,    -- 15
        false, -- 16
        false, -- 17
        false, -- 18
        false, -- 19
        false, -- 20
        false, -- 21
        false, -- 22
        false, -- 23
        false, -- 24
        false, -- 25
    }
    self:updateLongestTimer()
end

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
    numberOfStateChanges = self.numberOfStateChanges
    numberOfOptimizedInputs = self.numberOfOptimizedInputs
    optimizedBlockOutputs = self.optimizedBlockOutputs
    optimizedBlockOutputsPosHash = self.optimizedBlockOutputsPosHash
    nextTimerOutputWait = self.nextTimerOutputWait
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
    end
end

function FastLogicRunner.getUpdatedIds(self)
    local changed = {}
    blockStates = self.blockStates
    local lastBlockStates = self.lastBlockStates
    for i = 1, #blockStates do
        if lastBlockStates[i] ~= blockStates[i] then
            lastBlockStates[i] = blockStates[i]
            changed[#changed + 1] = i
        end
    end
    return changed
end

function FastLogicRunner.doLastTickUpdates(self)
    local multiBlocks = self.blocksSortedByPath[16]
    blockOutputs = self.blockOutputs
    blockStates = self.blockStates
    multiBlockData = self.multiBlockData
    runnableBlockPathIds = self.runnableBlockPathIds
    for i = 1, #multiBlocks do
        local multiBlockId = multiBlocks[i]
        local data = self:internalGetLastMultiBlockInternalStates(multiBlockId)
        local idStatePairs = data[2]
        local lastIdStatePairs = data[1]
        if idStatePairs == nil then
            idStatePairs = self:internalGetMultiBlockInternalStates(multiBlockId)
        end
        local blocks = multiBlockData[multiBlockId][2]
        for j = 1, #lastIdStatePairs do
            local outputs = blockOutputs[lastIdStatePairs[j][1]]
            local state = lastIdStatePairs[j][2]
            for k = 1, #outputs do
                local id = outputs[k]
                if runnableBlockPathIds[id] == 2 then
                    blockStates[id] = state
                end
            end
        end
        self:internalSetBlockStates(idStatePairs, false)
    end
end

function FastLogicRunner.update(self)
    self:setFastReadData(true)
    for i = 1, #self.blocksToAddInputs do
        self:externalAddInput(self.blocksToAddInputs[i][1], self.blocksToAddInputs[i][2])
    end
    self.blocksToAddInputs = {}
    self:optimizeLogic()
    self.blocksRan = 0
    self.updateTicks = self.updateTicks + self.numberOfUpdatesPerTick
    if self.updateTicks >= 1 then
        --make sure all blocks are not broken
        for pathId = 1, #runningBlocks do
            local i = 1
            while i <= runningBlockLengths[pathId] do
                local id = runningBlocks[pathId][i]
                if countOfOnInputs[id] == false then
                    -- print("ountOfOnInputs[id] == false broke tell itchytrack (you might be fine still tell him)")
                    nextRunningBlocks[id] = false
                    table.remove(runningBlocks[pathId], i)
                    runningBlockLengths[pathId] = runningBlockLengths[pathId] - 1
                else
                    i = i + 1
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
        while self.updateTicks >= 2 do
            self:doUpdate()
            self.updateTicks = self.updateTicks - 1
            sum = 0
            for i = 1, #self.runningBlockLengths do
                sum = sum + self.runningBlockLengths[i]
            end
            if sum == 0 and self.nextTimerOutputWait > 10000000 then
                self.updateTicks = 1
            end
        end
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
    -- and2
    for k = 1, runningBlockLengths[7] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks7[k]
        local numberOfOptimized = numberOfOptimizedInputs[blockId]
        if numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId] == 0 then -- no inputs
            if blockStates[blockId] then
                newBlockStatesLength = newBlockStatesLength + 1
                newBlockStates[newBlockStatesLength] = blockId
            end
        elseif countOfOnInputs[blockId] == numberOfBlockInputs[blockId] then --  all inputs on
            if (countOfOnOtherInputs[blockId] == numberOfOtherInputs[blockId]) ~= blockStates[blockId] then
                newBlockStatesLength = newBlockStatesLength + 1
                newBlockStates[newBlockStatesLength] = blockId
            end
        elseif countOfOnInputs[blockId] == numberOfOptimized then -- all optimizedInputs on
            numberOfOptimized = numberOfOptimized + 1
            local inputId = blockInputs[blockId][numberOfOptimized]
            optimizedBlockOutputs[inputId][optimizedBlockOutputsPosHash[inputId][blockId]] = blockId
            -- optimizedBlockOutputsPosHash[inputId][blockId] = #optimizedBlockOutputs[inputId]
            while blockStates[blockInputs[blockId][numberOfOptimized]] do        -- while the top optimizedInput on
                countOfOnInputs[blockId] = countOfOnInputs[blockId] + 1
                if countOfOnInputs[blockId] == numberOfBlockInputs[blockId] then -- if that was the last input to turn on
                    if (countOfOnOtherInputs[blockId] == numberOfOtherInputs[blockId]) ~= blockStates[blockId] then
                        newBlockStatesLength = newBlockStatesLength + 1
                        newBlockStates[newBlockStatesLength] = blockId
                    end
                    break
                else
                    numberOfOptimized = numberOfOptimized + 1 -- if it was not the last input adds 1 to the # of inputs
                    inputId = blockInputs[blockId][numberOfOptimized]
                    optimizedBlockOutputs[inputId][optimizedBlockOutputsPosHash[inputId][blockId]] = blockId
                    -- optimizedBlockOutputsPosHash[inputId][blockId] = #optimizedBlockOutputs[inputId]
                end
            end
        else -- some optimizedInputs are off
            ::AND::
            local inputId = blockInputs[blockId][numberOfOptimized]
            if blockStates[inputId] then -- the top optimizedInput on
                countOfOnInputs[blockId] = countOfOnInputs[blockId] - 1
                numberOfOptimized = numberOfOptimized - 1

                -- remove from optimizedBlockOutputs
                optimizedBlockOutputs[inputId][optimizedBlockOutputsPosHash[inputId][blockId]] = -1
                goto AND
            elseif countOfOnInputs[blockId] + 1 < numberOfOptimized then -- the top optimizedInput off
                numberOfOptimized = numberOfOptimized - 1

                -- remove from optimizedBlockOutputs
                optimizedBlockOutputs[inputId][optimizedBlockOutputsPosHash[inputId][blockId]] = -1
                goto AND
            end

            if blockStates[blockId] then -- block is on but should be off
                newBlockStatesLength = newBlockStatesLength + 1
                newBlockStates[newBlockStatesLength] = blockId
            end
        end
        numberOfOptimizedInputs[blockId] = numberOfOptimized
    end
    runningBlockLengths[7] = 0
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
    -- or2
    for k = 1, runningBlockLengths[9] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks9[k]
        local numberOfOptimized = numberOfOptimizedInputs[blockId]
        if numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId] == 0 then -- no inputs
            if blockStates[blockId] then
                newBlockStatesLength = newBlockStatesLength + 1
                newBlockStates[newBlockStatesLength] = blockId
            end
        elseif numberOfOptimized == numberOfBlockInputs[blockId] and countOfOnInputs[blockId] == 0 then -- all inputs off
            if (countOfOnOtherInputs[blockId] == 0) == blockStates[blockId] then
                newBlockStatesLength = newBlockStatesLength + 1
                newBlockStates[newBlockStatesLength] = blockId
            end
        elseif countOfOnInputs[blockId] == 0 then -- all optimizedInputs off
            numberOfOptimized = numberOfOptimized + 1
            local inputId = blockInputs[blockId][numberOfOptimized]
            optimizedBlockOutputs[inputId][optimizedBlockOutputsPosHash[inputId][blockId]] = blockId
            -- optimizedBlockOutputsPosHash[inputId][blockId] = #optimizedBlockOutputs[inputId]
            while not blockStates[blockInputs[blockId][numberOfOptimized]] do -- while the top optimizedInput off
                if numberOfOptimized == numberOfBlockInputs[blockId] then     -- if that was the last input to turn off
                    if (countOfOnOtherInputs[blockId] == 0) == blockStates[blockId] then
                        newBlockStatesLength = newBlockStatesLength + 1
                        newBlockStates[newBlockStatesLength] = blockId
                    end
                    break
                else
                    numberOfOptimized = numberOfOptimized + 1 -- if it was not the last input adds 1 to the # of inputs
                    inputId = blockInputs[blockId][numberOfOptimized]
                    optimizedBlockOutputs[inputId][optimizedBlockOutputsPosHash[inputId][blockId]] = blockId
                    -- optimizedBlockOutputsPosHash[inputId][blockId] = #optimizedBlockOutputs[inputId]
                end
            end
            if blockStates[blockInputs[blockId][numberOfOptimized]] then
                countOfOnInputs[blockId] = 1
            end
        else -- some optimizedInputs are on
            ::OR::
            local inputId = blockInputs[blockId][numberOfOptimized]
            if not blockStates[inputId] then -- the top optimizedInput off
                numberOfOptimized = numberOfOptimized - 1

                -- remove from optimizedBlockOutputs
                optimizedBlockOutputs[inputId][optimizedBlockOutputsPosHash[inputId][blockId]] = -1
                goto OR
            elseif countOfOnInputs[blockId] > 1 then -- the top optimizedInput on
                countOfOnInputs[blockId] = countOfOnInputs[blockId] - 1
                numberOfOptimized = numberOfOptimized - 1

                -- remove from optimizedBlockOutputs
                optimizedBlockOutputs[inputId][optimizedBlockOutputsPosHash[inputId][blockId]] = -1
                goto OR
            end

            if not blockStates[blockId] then -- block is off but should be no
                newBlockStatesLength = newBlockStatesLength + 1
                newBlockStates[newBlockStatesLength] = blockId
            end
        end
        numberOfOptimizedInputs[blockId] = numberOfOptimized
    end
    runningBlockLengths[9] = 0
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
    -- nand2
    for k = 1, runningBlockLengths[12] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks12[k]
        local numberOfOptimized = numberOfOptimizedInputs[blockId]
        if numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId] == 0 then -- no inputs
            if blockStates[blockId] then
                newBlockStatesLength = newBlockStatesLength + 1
                newBlockStates[newBlockStatesLength] = blockId
            end
        elseif countOfOnInputs[blockId] == numberOfBlockInputs[blockId] then --  all inputs on
            if (countOfOnOtherInputs[blockId] == numberOfOtherInputs[blockId]) == blockStates[blockId] then
                newBlockStatesLength = newBlockStatesLength + 1
                newBlockStates[newBlockStatesLength] = blockId
            end
        elseif countOfOnInputs[blockId] == numberOfOptimized then -- all optimizedInputs on
            numberOfOptimized = numberOfOptimized + 1
            local inputId = blockInputs[blockId][numberOfOptimized]
            optimizedBlockOutputs[inputId][optimizedBlockOutputsPosHash[inputId][blockId]] = blockId
            -- optimizedBlockOutputsPosHash[inputId][blockId] = #optimizedBlockOutputs[inputId]
            while blockStates[blockInputs[blockId][numberOfOptimized]] do        -- while the top optimizedInput on
                countOfOnInputs[blockId] = countOfOnInputs[blockId] + 1
                if countOfOnInputs[blockId] == numberOfBlockInputs[blockId] then -- if that was the last input to turn off
                    if (countOfOnOtherInputs[blockId] == numberOfOtherInputs[blockId]) == blockStates[blockId] then
                        newBlockStatesLength = newBlockStatesLength + 1
                        newBlockStates[newBlockStatesLength] = blockId
                    end
                    break
                else
                    numberOfOptimized = numberOfOptimized + 1 -- if it was not the last input adds 1 to the # of inputs
                    inputId = blockInputs[blockId][numberOfOptimized]
                    optimizedBlockOutputs[inputId][optimizedBlockOutputsPosHash[inputId][blockId]] = blockId
                    -- optimizedBlockOutputsPosHash[inputId][blockId] = #optimizedBlockOutputs[inputId]
                end
            end
        else -- some optimizedInputs are off
            ::NAND::
            local inputId = blockInputs[blockId][numberOfOptimized]
            if blockStates[inputId] then -- the top optimizedInput on
                countOfOnInputs[blockId] = countOfOnInputs[blockId] - 1
                numberOfOptimized = numberOfOptimized - 1

                -- remove from optimizedBlockOutputs
                optimizedBlockOutputs[inputId][optimizedBlockOutputsPosHash[inputId][blockId]] = -1
                goto NAND
            elseif countOfOnInputs[blockId] + 1 < numberOfOptimized then -- the top optimizedInput off
                numberOfOptimized = numberOfOptimized - 1

                -- remove from optimizedBlockOutputs
                optimizedBlockOutputs[inputId][optimizedBlockOutputsPosHash[inputId][blockId]] = -1
                goto NAND
            end

            if not blockStates[blockId] then -- block is off but should be no
                newBlockStatesLength = newBlockStatesLength + 1
                newBlockStates[newBlockStatesLength] = blockId
            end
        end
        numberOfOptimizedInputs[blockId] = numberOfOptimized
    end
    runningBlockLengths[12] = 0
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
    -- nor2
    for k = 1, runningBlockLengths[14] do
        self.blocksRan = self.blocksRan + 1
        local blockId = runningBlocks14[k]
        local numberOfOptimized = numberOfOptimizedInputs[blockId]
        if numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId] == 0 then -- no inputs
            if blockStates[blockId] then
                newBlockStatesLength = newBlockStatesLength + 1
                newBlockStates[newBlockStatesLength] = blockId
            end
        elseif numberOfOptimized == numberOfBlockInputs[blockId] and countOfOnInputs[blockId] == 0 then --  all inputs off
            if (countOfOnOtherInputs[blockId] == 0) ~= blockStates[blockId] then
                newBlockStatesLength = newBlockStatesLength + 1
                newBlockStates[newBlockStatesLength] = blockId
            end
        elseif countOfOnInputs[blockId] == 0 then -- all optimizedInputs off
            numberOfOptimized = numberOfOptimized + 1
            local inputId = blockInputs[blockId][numberOfOptimized]
            optimizedBlockOutputs[inputId][optimizedBlockOutputsPosHash[inputId][blockId]] = blockId
            -- optimizedBlockOutputsPosHash[inputId][blockId] = #optimizedBlockOutputs[inputId]
            while not blockStates[blockInputs[blockId][numberOfOptimized]] do -- while the top optimizedInput off
                if numberOfOptimized == numberOfBlockInputs[blockId] then     -- if that was the last input to turn off
                    if (countOfOnOtherInputs[blockId] == 0) ~= blockStates[blockId] then
                        newBlockStatesLength = newBlockStatesLength + 1
                        newBlockStates[newBlockStatesLength] = blockId
                    end
                    break
                else
                    numberOfOptimized = numberOfOptimized + 1 -- if it was not the last input adds 1 to the # of inputs
                    inputId = blockInputs[blockId][numberOfOptimized]
                    optimizedBlockOutputs[inputId][optimizedBlockOutputsPosHash[inputId][blockId]] = blockId
                    -- optimizedBlockOutputsPosHash[inputId][blockId] = #optimizedBlockOutputs[inputId]
                end
            end
            if blockStates[blockInputs[blockId][numberOfOptimized]] then
                countOfOnInputs[blockId] = 1
            end
        else -- some optimizedInputs are on
            ::NOR::
            local inputId = blockInputs[blockId][numberOfOptimized]
            if not blockStates[inputId] then -- the top optimizedInput off
                numberOfOptimized = numberOfOptimized - 1

                optimizedBlockOutputs[inputId][optimizedBlockOutputsPosHash[inputId][blockId]] = -1 -- new
                goto NOR
            elseif countOfOnInputs[blockId] > 1 then                                                -- the top optimizedInput on
                countOfOnInputs[blockId] = countOfOnInputs[blockId] - 1
                numberOfOptimized = numberOfOptimized - 1

                -- remove from optimizedBlockOutputs
                optimizedBlockOutputs[inputId][optimizedBlockOutputsPosHash[inputId][blockId]] = -1
                goto NOR
            end

            if blockStates[blockId] then -- block is on but should be off
                newBlockStatesLength = newBlockStatesLength + 1
                newBlockStates[newBlockStatesLength] = blockId
            end
        end
        numberOfOptimizedInputs[blockId] = numberOfOptimized
    end
    runningBlockLengths[14] = 0
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
            nextTimerOutputWait = timerLengths[blockId] <= nextTimerOutputWait and timerLengths[blockId] + 1 or nextTimerOutputWait
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
    if nextTimerOutputWait <= 1 then
        nextTimerOutputWait = 100000000
    end
    self.nextTimerOutputWait = nextTimerOutputWait - 1
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
            local outputs = optimizedBlockOutputs[id]
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
            nextTimerOutputWait = multiData[7] <= nextTimerOutputWait and multiData[7] + 1 or nextTimerOutputWait
        elseif multiData[1] == 2 then
            local outputId = multiData[4][1]
            timerData[multiData[7]][#timerData[multiData[7]] + 1] = {not blockStates[multiData[3][1]], multiData[4][1]}
            nextTimerOutputWait = multiData[7] <= nextTimerOutputWait and multiData[7] + 1 or nextTimerOutputWait
        else
            print("no runner for multi block with id: " .. tostring(multiData[1]))
            didNotRunInternal = true
        end

        if didNotRunInternal then -- run blocks
            for i = 1, #multiData[3] do
                local outputs = optimizedBlockOutputs[multiData[3][i]]
                for j = 1, #outputs do
                    local outputId = outputs[j]
                    if outputId ~= -1 then
                        if nextRunningBlocks[outputId] ~= nextRunningIndex then
                            nextRunningBlocks[outputId] = nextRunningIndex
                            local pathId = runnableBlockPathIds[outputId]
                            runningBlockLengths[pathId] = runningBlockLengths[pathId] + 1
                            runningBlocks[pathId][runningBlockLengths[pathId]] = outputId
                        end
                    end
                end
            end
        end
        multiBlockData[blockId][5] = {}
    end
    runningBlockLengths[16] = 0

    for k = 1, newBlockStatesLength do
        local id = newBlockStates[k]
        numberOfStateChanges[id] = numberOfStateChanges[id] + 1
        blockStates[id] = not blockStates[id]
        local stateNumber = blockStates[id] and 1 or -1
        local outputs = optimizedBlockOutputs[id]
        for k = 1, #outputs do
            local outputId = outputs[k]
            if outputId ~= -1 then
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
end

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
                id = data[i][1]
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