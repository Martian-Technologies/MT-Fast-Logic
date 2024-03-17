print("loading FastLogicRunner")

FastLogicRunner = FastLogicRunner or {}

dofile "../util/util.lua"
dofile "CreationLogicGetter.lua"
dofile "BlockMannager.lua"
dofile "LogicStateDisplayer.lua"
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

function FastLogicRunner.rescan(self)
    self.data = "new"
    self:refresh()
end

function FastLogicRunner.refresh(self)
    self.scanNext = self.scanNext or {}
    self.blockCount = self.blockCount or 0
    self.isEmpty = self.isEmpty or false
    self.creation = sm.MTFastLogic.Creations[self.creationId]
    self.numberOfUpdatesPerTick = self.numberOfUpdatesPerTick or 1
    self.updateTicks = self.updateTicks or 0
    self.tickType = self.tickType or 1
    self.displayedBlockStates = self.displayedBlockStates or {}
    if self.hashData == nil then
        self:makeDataArrays()
    end
    if (self.data == "new") then
        print("Scanning Started")
        -- self:sendMessageToAll("Scanning Started")
        for id, block in pairs(self.creation.FastLogicGates) do
            self:getBLockData(block.interactable:getBody())
            goto gotData
        end
        for id, block in pairs(self.creation.FastTimers) do
            self:getBLockData(block.interactable:getBody())
            goto gotData
        end
        ::gotData::
    end
    print("reloaded")
end

function FastLogicRunner.sendMessageToAll(self, message)
    sm.MTFastLogic.FastLogicRunnerRunner.network:sendToClients("client_sendMessage", message)
end

function FastLogicRunner.addAllNewBlocks(self)
    for i = 1, #self.creation.BlocksToScan do
        local block = self.creation.BlocksToScan[i]
        table.addToConstantKeysOnlyHash(self.hashData, block.id)
        local id = self.hashedLookUp[block.id]
        local inputs = table.hashArrayValues(self.hashData, block:getParentIds())
        local outputs = table.hashArrayValues(self.hashData, block:getChildIds())
        if block.type == "LogicGate" then
            if (block.data.mode == 0) then
                self:AddBlock("andBlocks", id, inputs, outputs, block.interactable.active)
            elseif (block.data.mode == 1) then
                self:AddBlock("orBlocks", id, inputs, outputs, block.interactable.active)
            elseif (block.data.mode == 2) then
                self:AddBlock("xorBlocks", id, inputs, outputs, block.interactable.active)
            elseif (block.data.mode == 3) then
                self:AddBlock("nandBlocks", id, inputs, outputs, block.interactable.active)
            elseif (block.data.mode == 4) then
                self:AddBlock("norBlocks", id, inputs, outputs, block.interactable.active)
            elseif (block.data.mode == 5) then
                self:AddBlock("xnorBlocks", id, inputs, outputs, block.interactable.active)
            end
        elseif block.type == "Timer" then
            self:AddBlock("timerBlocks", id, inputs, outputs, block.interactable.active, block.data.time)
        elseif block.type == "Light" then
            self:AddBlock("lightBlocks", id, inputs, outputs, block.interactable.active)
        end
    end
end

function FastLogicRunner.update(self)
    self:addAllNewBlocks()
    self.creation.BlocksToScan = {}
    if not sm.exists(self.creation.body) or self.creation.body:hasChanged(self.creation.lastBodyUpdate) then
        print("body updated")
        self.creation.lastBodyUpdate = sm.game.getCurrentTick()
        for _, v in pairs(self.creation.AllFastBlocks) do
            v:PreUpdate()
        end
    else
        for id, rId in pairs(self.scanNext) do
            self.creation.AllFastBlocks[rId]:PreUpdate()
        end
    end
    self.scanNext = {}
    for id, data in pairs(self.creation.AllNonFastBlocks) do
        if sm.exists(data.interactable) then
            if data.currentState ~= data.interactable.active then
                data.currentState = not data.currentState
                local stateNumber = data.currentState and 1 or -1
                for _, outputId in ipairs(data.outputs) do
                    if type(self.countOfOnInputs[outputId]) == "number" then
                        self.countOfOnInputs[outputId] = self.countOfOnInputs[outputId] + stateNumber
                        if self.countOfOnInputs[outputId] < 0 then
                            self.countOfOnInputs[outputId] = 0
                        end
                        self:AddBlockToUpdate(outputId)
                    else
                        if table.contains(self.creation.AllNonFastBlocks[id].outputs, outputId) then
                            if #self.creation.AllNonFastBlocks[id].outputs == 1 then
                                self.creation.AllNonFastBlocks[id] = nil
                            else
                                table.removeValue(self.creation.AllNonFastBlocks[id].outputs, outputId)
                            end
                        end
                    end
                end
            end
        end
    end
    self:doUpdates()
    if self.isEmpty then
        sm.MTFastLogic.Creations[self.creationId] = nil
    end
    local changed = false
    local numberofc = 0
    -- print(self.displayedBlockStates)
    -- print(self.blockStates)
    for i = 1, #self.blockStates do
        if self.displayedBlockStates[i] ~= self.blockStates[i] then
            if (self.creation.AllFastBlocks[self.unhashedLookUp[i]] ~= nil) then
                self.displayedBlockStates[i] = self.blockStates[i]
                if self.creation.AllFastBlocks[self.unhashedLookUp[i]]:UpdateState(self.blockStates[i]) then
                    numberofc = numberofc + 1
                    changed = true
                end
            end
        end
        if numberofc > 10000 then
            break
        end
    end
    if changed then
        self.creation.lastBodyUpdate = sm.game.getCurrentTick()
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
    self.blockInputsHash = {}
    self.runnableBlockPaths = table.makeArrayForHash(self.hashData)
    self.blockOutputs = table.makeArrayForHash(self.hashData)
    self.blockOutputsHash = {}
    self.numberOfBlockInputs = table.makeArrayForHash(self.hashData)
    self.numberOfBlockOutputs = table.makeArrayForHash(self.hashData)
    self.inputBlocks = {} -- is hash
    self.countOfOnInputs = table.makeArrayForHash(self.hashData)
    self.timerData = {}
    self.timerLengths = table.makeArrayForHash(self.hashData)
    self.timerInputStates = table.makeArrayForHash(self.hashData)
    self.runnableBlockPathIds = table.makeArrayForHash(self.hashData)
    self.longestTimer = 0
    self.pathNames = {
        "inputBlocks",
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
        ["vanilla input"] = "vanilla input"
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
    self:UpdateLongestTimer()
end

function FastLogicRunner.doUpdates(self)
    self.blocksRan = 0
    self.blocksForNextTick = 0
    self.blocksKilled = 0
    self.updateTicks = self.updateTicks + self.numberOfUpdatesPerTick
    if self.updateTicks >= 1 then
        if self.blockCount > 0 then
            -- other
            while self.updateTicks >= 2 do
                self:doUpdate()
                self.updateTicks = self.updateTicks - 1
                local sum = 0
                for k, v in pairs(self.runningBlockLengths) do
                    sum = sum + v
                end
                if sum == 0 then
                    self.updateTicks = 0
                end
            end
            -- light
            local countOfOnInputs = self.countOfOnInputs
            local numberOfBlockInputs = self.numberOfBlockInputs
            local blockStates = self.blockStates
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
end

function FastLogicRunner.doUpdate(self)
    -- print(self.blockOutputs)
    -- print(self.numberOfBlockInputs)
    -- print(self.countOfOnInputs)
    -- print(self.blockStates)
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
        newBlockStatesLength = newBlockStatesLength + 1
        newBlockStates[newBlockStatesLength] = timerReadRow[k]
    end
    -- create new list of runningBlockLengths
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
