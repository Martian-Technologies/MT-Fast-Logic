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
    self.blocksOptimized = self.blocksOptimized or 0
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
    self.pathNames = {
        "EndTickButtons",   -- 1
        "lightBlocks",      -- 2
        "throughBlocks",    -- 3
        "norThroughBlocks", -- 4
        "timerBlocks",      -- 5
        "andBlocks",        -- 6
        "and2Blocks",       -- 7
        "orBlocks",         -- 8
        "or2Blocks",        -- 9
        "xorBlocks",        -- 10
        "nandBlocks",       -- 11
        "nand2Blocks",      -- 12
        "norBlocks",        -- 13
        "nor2Blocks",       -- 14
        "xnorBlocks",       -- 15
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
    self.nextRunningIndex = self.nextRunningIndex + 1
    local nextRunningIndex = self.nextRunningIndex
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
    -- EndTickButton
    local EndTickButtons = runningBlocks[1]
    for k = 1, runningBlockLengths[1] do
        self.blocksRan = self.blocksRan + 1
        local blockId = EndTickButtons[k]
        if countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] > 0 then
            blockStates[blockId] = true
            if self.updateTicks >= 2 then
                self.nextRunningIndex = self.nextRunningIndex - 1
                runningBlockLengths[1] = 0
                self.updateTicks = 1
                return
            end
        else
            blockStates[blockId] = false
        end
    end
    -- through
    local throughBlocks = runningBlocks[3]
    for k = 1, runningBlockLengths[3] do
        self.blocksRan = self.blocksRan + 1
        local blockId = throughBlocks[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] == 1) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    -- nor through
    local norThroughBlocks = runningBlocks[4]
    for k = 1, runningBlockLengths[4] do
        self.blocksRan = self.blocksRan + 1
        local blockId = norThroughBlocks[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] == numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId]) == blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    -- and
    local andBlocks = runningBlocks[6]
    local k = 1
    while k <= runningBlockLengths[6] do
        self.blocksRan = self.blocksRan + 1
        local blockId = andBlocks[k]
        local sumCountOfOnInputs = countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]
        if (sumCountOfOnInputs > 0 and sumCountOfOnInputs == numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId]) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        k = k + 1
    end
    -- and2
    local and2Blocks = runningBlocks[7]
    local k = 1
    while k <= runningBlockLengths[7] do
        self.blocksRan = self.blocksRan + 1
        local blockId = and2Blocks[k]
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
        k = k + 1
    end
    -- or
    local orBlocks = runningBlocks[8]
    local k = 1
    while k <= runningBlockLengths[8] do
        self.blocksRan = self.blocksRan + 1
        local blockId = orBlocks[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] > 0) ~= blockStates[blockId]then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        k = k + 1
    end
    -- or2
    local or2Blocks = runningBlocks[9]
    k = 1
    while k <= runningBlockLengths[9] do
        self.blocksRan = self.blocksRan + 1
        local blockId = or2Blocks[k]
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
        k = k + 1
    end
    -- xor
    local xorBlocks = runningBlocks[10]
    for k = 1, runningBlockLengths[10] do
        self.blocksRan = self.blocksRan + 1
        local blockId = xorBlocks[k]
        if ((countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]) % 2 == 1) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        k = k + 1
    end
    -- nand
    local nandBlocks = runningBlocks[11]
    local k = 1
    while k <= runningBlockLengths[11] do
        self.blocksRan = self.blocksRan + 1
        local blockId = nandBlocks[k]
        local sumCountOfOnInputs = countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]
        if (sumCountOfOnInputs > 0 and sumCountOfOnInputs == numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId]) == blockStates[blockId]then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        k = k + 1
    end
    -- nand2
    local nand2Blocks = runningBlocks[12]
    k = 1
    while k <= runningBlockLengths[12] do
        self.blocksRan = self.blocksRan + 1
        local blockId = nand2Blocks[k]
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
        k = k + 1
    end
    -- nor
    local norBlocks = runningBlocks[13]
    local k = 1
    while k <= runningBlockLengths[13] do
        self.blocksRan = self.blocksRan + 1
        local blockId = norBlocks[k]
        if (countOfOnInputs[blockId] == 0 and countOfOnOtherInputs[blockId] == 0 and numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId] > 0) ~= blockStates[blockId]then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        k = k + 1
    end
    -- nor2
    local nor2Blocks = runningBlocks[14]
    k = 1
    while k <= runningBlockLengths[14] do
        self.blocksRan = self.blocksRan + 1
        local blockId = nor2Blocks[k]
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
        k = k + 1
    end
    -- xnor
    local xnorBlocks = runningBlocks[15]
    for k = 1, runningBlockLengths[15] do
        self.blocksRan = self.blocksRan + 1
        local blockId = xnorBlocks[k]
        if (
                numberOfBlockInputs[blockId] + numberOfOtherInputs[blockId] > 0 and
                (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId]) % 2 == 0
            ) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    -- timer
    timerData[#timerData + 1] = {}
    local timerBlocks = runningBlocks[5]
    for k = 1, runningBlockLengths[5] do
        self.blocksRan = self.blocksRan + 1
        local blockId = timerBlocks[k]
        if (countOfOnInputs[blockId] + countOfOnOtherInputs[blockId] == 1) ~= timerInputStates[blockId] then
            timerInputStates[blockId] = not timerInputStates[blockId]
            timerData[timerLengths[blockId]][#timerData[timerLengths[blockId]] + 1] = blockId
            nextTimerOutputWait = timerLengths[blockId] <= nextTimerOutputWait and timerLengths[blockId] + 1 or nextTimerOutputWait
        end
    end
    local timerReadRow = table.remove(timerData, 1)
    for k = 1, #timerReadRow do
        -- if numberOfBlockOutputs[timerReadRow[k]] ~= false then
        newBlockStatesLength = newBlockStatesLength + 1
        newBlockStates[newBlockStatesLength] = timerReadRow[k]
        -- end
    end
    if nextTimerOutputWait <= 1 then
        nextTimerOutputWait = 100000000
    end
    self.nextTimerOutputWait = nextTimerOutputWait - 1
    -- create new list of runningBlockLengths
    local runningBlockLengthsOld = runningBlockLengths
    runningBlockLengths = {
        [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0, [8] = 0, [9] = 0, [10] = 0, [11] = 0, [12] = 0, [13] = 0, [14] = 0, [15] = 0
    }
    self.runningBlockLengths = runningBlockLengths
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
