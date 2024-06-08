dofile "../util/util.lua"
local string = string
local table = table
local type = type
local pairs = pairs

FastLogicRunner = FastLogicRunner or {}

dofile "BlockMannager.lua"
dofile "BalancedLogicFinder.lua"
dofile "LogicOptimizer.lua"

local table = table
local ipairs = ipairs
local pairs = pairs

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
    self.blocksForNextTick = 0
    self.blocksKilled = 0
    self.newIdIndex = 0
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

function FastLogicRunner.update(self)
    for i = 1, #self.blocksToAddInputs do
        self:externalAddInput(self.blocksToAddInputs[i][1], self.blocksToAddInputs[i][2])
    end
    self.blocksToAddInputs = {}
    self:optimizeLogic()
    self.blocksRan = 0
    self.blocksForNextTick = 0
    self.blocksKilled = 0
    self.updateTicks = self.updateTicks + self.numberOfUpdatesPerTick
    if self.updateTicks >= 1 then
        local countOfOnInputs = self.countOfOnInputs
        local blockStates = self.blockStates
        local runningBlocks = self.runningBlocks
        local runningBlockLengths = self.runningBlockLengths
        local nextRunningBlocks = self.nextRunningBlocks
        local countOfOnOtherInputs = self.countOfOnOtherInputs
        --make sure all blocks are not broken
        for pathId = 1, #runningBlocks do
            local i = 1
            while i <= runningBlockLengths[pathId] do
                local id = runningBlocks[pathId][i]
                if countOfOnInputs[id] == false then
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
                if self.updateTicks >= 2 then
                    runningBlockLengths[1] = 0
                    self.updateTicks = 1
                end
            else
                blockStates[blockId] = false
            end
        end
        local sum = 0
        -- other
        while self.updateTicks >= 2 do
            self.updateTicks = self.updateTicks - 1
            self:doUpdate()
            sum = 0
            for i = 1, #self.runningBlockLengths do
                sum = sum + self.runningBlockLengths[i]
            end
            if sum == 0 and self.nextTimerOutputWait > 10000000 then
                self.updateTicks = 0
            end
        end
        -- light
        local numberOfBlockInputs = self.numberOfBlockInputs
        local numberOfOtherInputs = self.numberOfOtherInputs
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
    end
    -- print(self.blocksRan)
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

function FastLogicRunner.doUpdate(self)
    local newBlockStatesLength = 0
    local newBlockStates = {}
    local runningBlocks = self.runningBlocks
    local lastRunningIndex = self.nextRunningIndex
    local nextRunningIndex = lastRunningIndex + 1
    self.nextRunningIndex = nextRunningIndex 
    local nextRunningBlocks = self.nextRunningBlocks
    local runningBlockLengths = self.runningBlockLengths
    local countOfOnInputs = self.countOfOnInputs
    local countOfOnOtherInputs = self.countOfOnOtherInputs
    local runnableBlockPathIds = self.runnableBlockPathIds
    local numberOfBlockOutputs = self.numberOfBlockOutputs
    local blockInputs = self.blockInputs
    local numberOfBlockInputs = self.numberOfBlockInputs
    local numberOfOtherInputs = self.numberOfOtherInputs
    local blockStates = self.blockStates
    local timerData = self.timerData
    local timerLengths = self.timerLengths
    local timerInputStates = self.timerInputStates
    local blockOutputs = self.blockOutputs
    local numberOfStateChanges = self.numberOfStateChanges
    local numberOfOptimizedInputs = self.numberOfOptimizedInputs
    local optimizedBlockOutputs = self.optimizedBlockOutputs
    local optimizedBlockOutputsPosHash = self.optimizedBlockOutputsPosHash
    local nextTimerOutputWait = self.nextTimerOutputWait
    local multiBlockData = self.multiBlockData
    -- EndTickButton
    local someRunningBlocks = runningBlocks[1]
    for k = 1, runningBlockLengths[1] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
        if countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] > 0 then
            blockStates[blockId] = true
            if self.updateTicks >= 2 then
                self.nextRunningIndex = lastRunningIndex
                runningBlockLengths[1] = 0
                self.updateTicks = 1
                return
            end
        else
            blockStates[blockId] = false
        end
    end
    runningBlockLengths[1] = 0
    -- through
    someRunningBlocks = runningBlocks[3]
    for k = 1, runningBlockLengths[3] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] == 1) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    runningBlockLengths[3] = 0
    -- nor through
    someRunningBlocks = runningBlocks[4]
    for k = 1, runningBlockLengths[4] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] == numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId]) == blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    runningBlockLengths[4] = 0
    -- and
    someRunningBlocks = runningBlocks[6]
    for k = 1, runningBlockLengths[6] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
        local sumCountOfOnInputs = countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]
        if (sumCountOfOnInputs > 0 and sumCountOfOnInputs == numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId]) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    runningBlockLengths[6] = 0
    -- and2
    someRunningBlocks = runningBlocks[7]
    for k = 1, runningBlockLengths[7] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
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
    someRunningBlocks = runningBlocks[8]
    for k = 1, runningBlockLengths[8] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] > 0) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    runningBlockLengths[8] = 0
    -- or2
    someRunningBlocks = runningBlocks[9]
    for k = 1, runningBlockLengths[9] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
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
    someRunningBlocks = runningBlocks[10]
    for k = 1, runningBlockLengths[10] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
        if ((countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]) % 2 == 1) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    runningBlockLengths[10] = 0
    -- nand
    someRunningBlocks = runningBlocks[11]
    local k = 1
    for k = 1, runningBlockLengths[11] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
        local sumCountOfOnInputs = countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]
        if (sumCountOfOnInputs > 0 and sumCountOfOnInputs == numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId]) == blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    runningBlockLengths[11] = 0
    -- nand2
    someRunningBlocks = runningBlocks[12]
    for k = 1, runningBlockLengths[12] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
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
    someRunningBlocks = runningBlocks[13]
    for k = 1, runningBlockLengths[13] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
        if (countOfOnInputs[blockId] == 0 and countOfOnOtherInputs[blockId] == 0 and numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId] > 0) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        k = k + 1
    end
    runningBlockLengths[13] = 0
    -- nor2
    someRunningBlocks = runningBlocks[14]
    for k = 1, runningBlockLengths[14] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
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
    someRunningBlocks = runningBlocks[15]
    for k = 1, runningBlockLengths[15] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
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
    someRunningBlocks = runningBlocks[5]
    for k = 1, runningBlockLengths[5] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
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
            if item[1] ~= blockStates[item[2]] then
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
    someRunningBlocks = runningBlocks[17]
    for k = 1, runningBlockLengths[17] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] == 1) ~= blockStates[blockId] then
            local multiBlockId = multiBlockData[blockId]
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[16][runningMultiBlockLengths] = multiBlockId
                multiBlockData[multiBlockId][5][#multiBlockData[multiBlockId][5]+1] = blockId
            end
        end
    end
    runningBlockLengths[17] = 0
    -- nor through multi block input
    someRunningBlocks = runningBlocks[18]
    for k = 1, runningBlockLengths[18] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] == numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId]) == blockStates[blockId] then
            local multiBlockId = multiBlockData[blockId]
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[runningMultiBlockLengths] = multiBlockId
                multiBlockData[multiBlockId][5][#multiBlockData[multiBlockId][5]+1] = blockId
            end
        end
    end
    runningBlockLengths[18] = 0
    -- and multi block input
    someRunningBlocks = runningBlocks[19]
    for k = 1, runningBlockLengths[19] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
        local sumCountOfOnInputs = countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]
        if (sumCountOfOnInputs > 0 and sumCountOfOnInputs == numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId]) ~= blockStates[blockId] then
            local multiBlockId = multiBlockData[blockId]
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[runningMultiBlockLengths] = multiBlockId
                multiBlockData[multiBlockId][5][#multiBlockData[multiBlockId][5]+1] = blockId
            end
        end
    end
    runningBlockLengths[19] = 0
    -- or multi block input
    someRunningBlocks = runningBlocks[20]
    for k = 1, runningBlockLengths[20] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] > 0) ~= blockStates[blockId] then
            local multiBlockId = multiBlockData[blockId]
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[runningMultiBlockLengths] = multiBlockId
                multiBlockData[multiBlockId][5][#multiBlockData[multiBlockId][5]+1] = blockId
            end
        end
        k = k + 1
    end
    runningBlockLengths[20] = 0
    -- xor multi block input
    someRunningBlocks = runningBlocks[21]
    for k = 1, runningBlockLengths[21] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
        if ((countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]) % 2 == 1) ~= blockStates[blockId] then
            local multiBlockId = multiBlockData[blockId]
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[runningMultiBlockLengths] = multiBlockId
                multiBlockData[multiBlockId][5][#multiBlockData[multiBlockId][5]+1] = blockId
            end
        end
    end
    runningBlockLengths[21] = 0
    -- nand multi block input
    someRunningBlocks = runningBlocks[22]
    for k = 1, runningBlockLengths[22] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
        local sumCountOfOnInputs = countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]
        if (sumCountOfOnInputs > 0 and sumCountOfOnInputs == numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId]) == blockStates[blockId] then
            local multiBlockId = multiBlockData[blockId]
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[runningMultiBlockLengths] = multiBlockId
                multiBlockData[multiBlockId][5][#multiBlockData[multiBlockId][5]+1] = blockId
            end
        end
    end
    runningBlockLengths[22] = 0
    -- nor multi block input
    someRunningBlocks = runningBlocks[23]
    for k = 1, runningBlockLengths[23] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
        if (countOfOnInputs[blockId] == 0 and countOfOnOtherInputs[blockId] == 0 and numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId] > 0) ~= blockStates[blockId] then
            local multiBlockId = multiBlockData[blockId]
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[runningMultiBlockLengths] = multiBlockId
                multiBlockData[multiBlockId][5][#multiBlockData[multiBlockId][5]+1] = blockId
            end
        end
    end
    runningBlockLengths[23] = 0
    -- xnor multi block input
    someRunningBlocks = runningBlocks[24]
    for k = 1, runningBlockLengths[24] do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
        if (
                numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId] > 0 and
                (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]) % 2 == 0
            ) ~= blockStates[blockId] then
            local multiBlockId = multiBlockData[blockId]
            if nextRunningBlocks[multiBlockId] ~= lastRunningIndex then
                runningMultiBlockLengths = runningMultiBlockLengths + 1
                runningBlocks[runningMultiBlockLengths] = multiBlockId
                multiBlockData[multiBlockId][5][#multiBlockData[multiBlockId][5]+1] = blockId
            end
        end
    end
    runningBlockLengths[24] = 0
    -- multi blocks
    someRunningBlocks = runningBlocks[16]
    for k = 1, runningMultiBlockLengths do
        self.blocksRan = self.blocksRan + 1
        local blockId = someRunningBlocks[k]
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
            timerData[multiData[6]][#timerData[multiData[6]] + 1] = {blockStates[multiData[3][1]], multiData[4][1]}
            nextTimerOutputWait = multiData[6] <= nextTimerOutputWait and multiData[6] + 1 or nextTimerOutputWait
        else
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
                    -- self.blocksForNextTick = self.blocksForNextTick + 1
                    nextRunningBlocks[outputId] = nextRunningIndex
                    local pathId = runnableBlockPathIds[outputId]
                    runningBlockLengths[pathId] = runningBlockLengths[pathId] + 1
                    runningBlocks[pathId][runningBlockLengths[pathId]] = outputId
                end
            end
        end
    end
end
