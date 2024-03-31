print("loading FastLogicRunner")

FastLogicRunner = FastLogicRunner or {}

dofile "../util/util.lua"
dofile "CreationLogicGetter.lua"
dofile "BlockMannager.lua"
dofile "BalancedLogicFinder.lua"
-- dofile "LogicOptimizer.lua"

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
    self.blockStates = table.makeArrayForHash(self.hashData)
    self.blockInputs = table.makeArrayForHash(self.hashData)
    self.lastBlockStates = table.makeArrayForHash(self.hashData, 0)
    self.blockInputsHash = {}
    self.runnableBlockPaths = table.makeArrayForHash(self.hashData)
    self.blockOutputs = table.makeArrayForHash(self.hashData)
    self.blockOutputsHash = {}
    self.numberOfBlockInputs = table.makeArrayForHash(self.hashData)
    self.numberOfBlockOutputs = table.makeArrayForHash(self.hashData)
    self.countOfOnInputs = table.makeArrayForHash(self.hashData)
    self.timerData = {}
    self.timerLengths = table.makeArrayForHash(self.hashData)
    self.timerInputStates = table.makeArrayForHash(self.hashData)
    self.runnableBlockPathIds = table.makeArrayForHash(self.hashData)
    self.longestTimer = 0
    self.pathNames = {
        "EndTickButtons",
        "lightBlocks",
        "throughBlocks",
        "norThroughBlocks",
        "timerBlocks",
        "andBlocks",
        "orBlocks",
        "xorBlocks",
        "nandBlocks",
        "norBlocks",
        "xnorBlocks",
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
            if countOfOnInputs[blockId] > 0 then
                blockStates[blockId] = true
                if self.updateTicks >= 2 then
                    runningBlockLengths[1] = 0
                    self.updateTicks = 1
                end
            else
                blockStates[blockId] = false
            end
        end
        -- other
        while self.updateTicks >= 2 do
            self.updateTicks = self.updateTicks - 1
            self:doUpdate()
            local sum = 0
            for k, v in pairs(runningBlockLengths) do
                sum = sum + v
            end
            if sum == 0 then
                self.updateTicks = 0
            end
        end
        -- light
        local numberOfBlockInputs = self.numberOfBlockInputs
        local lightBlocks = self.blocksSortedByPath[self.pathIndexs["lightBlocks"]]
        for k = 1, #lightBlocks do
            local blockId = lightBlocks[k]
            blockStates[blockId] = countOfOnInputs[blockId] > 0 or numberOfBlockInputs[blockId] == -1
        end
        -- lastTick
        if self.updateTicks >= 1 then
            self:doUpdate()
            self.updateTicks = self.updateTicks - 1
        end
    end
end

function FastLogicRunner.getUpdatedIds(self)
    local changed = {}
    local blockStates = self.blockStates
    local lastBlockStates = self.lastBlockStates
    for i = 1, #blockStates do
        if lastBlockStates[i] ~= blockStates[i] then
            lastBlockStates[i] = blockStates[i]
            changed[#changed+1] = i
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
    local runnableBlockPathIds = self.runnableBlockPathIds
    local numberOfBlockOutputs = self.numberOfBlockOutputs
    local blockInputs = self.blockInputs
    local numberOfBlockInputs = self.numberOfBlockInputs
    local blockStates = self.blockStates
    local timerData = self.timerData
    local timerLengths = self.timerLengths
    local timerInputStates = self.timerInputStates
    local blockOutputs = self.blockOutputs
    local instantGateOutputs = self.instantGateOutputs

    -- EndTickButton
    local EndTickButtons = runningBlocks[1]
    for k = 1, runningBlockLengths[1] do
        local blockId = EndTickButtons[k]
        if countOfOnInputs[blockId] > 0 then
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
        -- self.blocksRan = self.blocksRan + 1
        local blockId = throughBlocks[k]
        if (countOfOnInputs[blockId] == 1) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    -- nor through
    local norThroughBlocks = runningBlocks[4]
    for k = 1, runningBlockLengths[4] do
        -- self.blocksRan = self.blocksRan + 1
        local blockId = norThroughBlocks[k]
        if (countOfOnInputs[blockId] == 0) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    -- and
    local andBlocks = runningBlocks[6]
    local k = 1
    while k <= runningBlockLengths[6] do
        -- self.blocksRan = self.blocksRan + 1
        local blockId = andBlocks[k]
        if (countOfOnInputs[blockId] == numberOfBlockInputs[blockId]) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        k = k + 1
    end
    -- or
    local orBlocks = runningBlocks[7]
    k = 1
    while k <= runningBlockLengths[7] do
        -- self.blocksRan = self.blocksRan + 1
        local blockId = orBlocks[k]
        if (countOfOnInputs[blockId] > 0) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        k = k + 1
    end
    -- xor
    local xorBlocks = runningBlocks[8]
    for k = 1, runningBlockLengths[8] do
        -- self.blocksRan = self.blocksRan + 1
        local blockId = xorBlocks[k]
        if (countOfOnInputs[blockId] % 2 == 1) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        k = k + 1
    end
    -- nand
    local nandBlocks = runningBlocks[9]
    k = 1
    while k <= runningBlockLengths[9] do
        -- self.blocksRan = self.blocksRan + 1
        local blockId = nandBlocks[k]
        if (numberOfBlockInputs[blockId] > 0 and countOfOnInputs[blockId] ~= numberOfBlockInputs[blockId]) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        k = k + 1
    end
    -- nor
    local norBlocks = runningBlocks[10]
    k = 1
    while k <= runningBlockLengths[10] do
        -- self.blocksRan = self.blocksRan + 1
        local blockId = norBlocks[k]
        if (numberOfBlockInputs[blockId] > 0 and countOfOnInputs[blockId] == 0) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        k = k + 1
    end
    -- xnor
    local xnorBlocks = runningBlocks[11]
    for k = 1, runningBlockLengths[11] do
        -- self.blocksRan = self.blocksRan + 1
        local blockId = xnorBlocks[k]
        if (numberOfBlockInputs[blockId] > 0 and countOfOnInputs[blockId] % 2 == 0) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        k = k + 1
    end
    -- timer
    timerData[#timerData + 1] = {}
    local timerBlocks = runningBlocks[5]
    for k = 1, runningBlockLengths[5] do
        -- self.blocksRan = self.blocksRan + 1
        local blockId = timerBlocks[k]
        if (countOfOnInputs[blockId] == 1) ~= timerInputStates[blockId] then
            timerInputStates[blockId] = not timerInputStates[blockId]
            timerData[timerLengths[blockId]][#timerData[timerLengths[blockId]] + 1] = blockId
        end
    end
    local timerReadRow = table.remove(timerData, 1)
    for k = 1, #timerReadRow do
        if numberOfBlockOutputs[timerReadRow[k]] ~= false then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = timerReadRow[k]
        end
    end
    -- create new list of runningBlockLengths
    local runningBlockLengthsOld = runningBlockLengths
    runningBlockLengths = {
        [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0, [8] = 0, [9] = 0, [10] = 0, [11] = 0
    }
    self.runningBlockLengths = runningBlockLengths
    for k = 1, newBlockStatesLength do
        local id = newBlockStates[k]
        blockStates[id] = not blockStates[id]
        local stateNumber = blockStates[id] and 1 or -1
        local outputs = blockOutputs[id]
        for k = 1, numberOfBlockOutputs[id] do
            local outputId = outputs[k]
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
