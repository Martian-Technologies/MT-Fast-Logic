FastLogicRunner = FastLogicRunner or class()
print("loading FastLogicRunner")

dofile "../util/util.lua"
dofile "CreationLogicGetter.lua"
dofile "LogicStateDisplayer.lua"
dofile "BalancedLogicFinder.lua"

local numberOfUpdatesPerTick = 5000

local FastLogicRunner = FastLogicRunner
local table = table
local ipairs = ipairs
local pairs = pairs

function FastLogicRunner.server_onRefresh(self)
    self:refresh()
end

function FastLogicRunner.server_onCreate(self)
    self:refresh()
end

function FastLogicRunner.client_onInteract(self, character, state)
    if state then
        self.network:sendToServer("server_onInteract")
    end
end

function FastLogicRunner.server_onInteract(self, character, state)
    self.data = "new"
    self:refresh()
end

function FastLogicRunner.refresh(self)
    self.updateTicks = 0
    self.tickType = self.tickType or 1
    self.openDisplays = self.openDisplays or {}
    if (self.data == "new") then
        self:sendMessageToAll("Scanning Started")
        self:getBLockData(self.interactable:getBody())
    end
    self.network:sendToClients("client_refresh")
    print("reloaded")
end

function FastLogicRunner.server_onMelee(self)
    for k, v in pairs(self.blockStates) do
        self.blockStates[k] = false
    end
end

function FastLogicRunner.client_refresh(self)
    self.displayGUIs = self.displayGUIs or {}
end

function FastLogicRunner.sendMessageToAll(self, message)
    self.network:sendToClients("client_sendMessage", message)
end

function FastLogicRunner.client_sendMessage(self, message)
    sm.gui.chatMessage(message)
end

function FastLogicRunner.server_onFixedUpdate(self, timeStep)
    if (self.isScanning == true) then
        self.data = self:doScanning()
        if self.data ~= nil then
            self:prepData()
            self:sendMessageToAll("Scanning Done")
        end
    else
        if (self.data ~= nil) then
            self:doUpdates()
            self:updateDisplays()
        end
    end
end

function FastLogicRunner.prepData(self)
    self.blockStates = {}
    self.blockData = {}
    self.runnableBlockPaths = {}
    self.blockOutputs = {}
    self.numberOfBlockInputs = {}
    self.numberOfBlockOutputs = {}
    self.inputBlocks = {}
    self.countOfOnInputs = {}
    self.timerData = {}
    self.runnableBlockPathIds = {}
    local longestTimer = 0
    local toFixTimers = {}
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
    }
    self.pathIndexs ={}
    for index, path in pairs(self.pathNames) do
        self.pathIndexs[path] = index
    end
    local timerIndex = 0
    -- use this instead
    --{["inputBlocks"] = {}, ["lightBlocks"] = {}, ["throughBlocks"] = {}, ["norThroughBlocks"] = {}, ["timerBlocks"] = {},
    --["andBlocks"] = {}, ["orBlocks"] = {}, ["xorBlocks"] = {}, ["nandBlocks"] = {},  ["norBlocks"] = {},  ["xnorBlocks"] = {}}
    print("---")
    for id, block in pairs(self.data) do
        self.countOfOnInputs[id] = 0
        if (block.type == "vanilla input" and (#block.outputs > 0 or block.color == "420420")) then
            self.inputBlocks[id] = block.shape:getInteractable()
            self.blockOutputs[id] = block.outputs
            self.runnableBlockPaths[id] = "inputBlocks"
            self.blockStates[id] = false
        elseif (block.type == "vanilla light") then
            if (#block.inputs == 0) then
                self.blockStates[id] = true
            else
                self.blockData[id] = block.inputs[1]
                self.runnableBlockPaths[id] = "lightBlocks"
                self.blockStates[id] = false
            end
        elseif (block.type == "vanilla timer") then
            if (#block.inputs == 0) then
                self.blockStates[id] = false
            elseif (#block.outputs > 0 or block.color == "420420") then
                if block.ticks == 0 then
                    self.blockData[id] = block.inputs[1]
                    self.blockOutputs[id] = block.outputs
                    self.runnableBlockPaths[id] = "throughBlocks"
                    self.blockStates[id] = false
                elseif (block.ticks <= 1) then
                    self.blockData[id] = id + 1 / (block.ticks + 1)
                    self.blockOutputs[id] = block.outputs
                    self.runnableBlockPaths[id] = "throughBlocks"
                    self.blockStates[id] = false
                    for i = 1, block.ticks - 1, 1 do
                        self.blockData.throughBlocks[id + i / (block.ticks + 1)] = id + (i + 1) / (block.ticks + 1)
                        self.blockOutputs[id + i / (block.ticks + 1)] = {id + (i - 1) / (block.ticks + 1)}
                        self.runnableBlockPaths[id + i / (block.ticks + 1)] = "throughBlocks"
                        self.blockStates[id + i / (block.ticks + 1)] = false
                        self.countOfOnInputs[id + i / (block.ticks + 1)] = 0
                    end
                    self.blockData[id + block.ticks / (block.ticks + 1)] = block.inputs[1]
                    self.blockOutputs[id + block.ticks / (block.ticks + 1)] = {id + (block.ticks - 1) / (block.ticks + 1)}
                    self.runnableBlockPaths[id + block.ticks / (block.ticks + 1)] = "throughBlocks"
                    self.blockStates[id + block.ticks / (block.ticks + 1)] = false
                    self.countOfOnInputs[id + block.ticks / (block.ticks + 1)] = 0
                    toFixTimers[id] = block
                else
                    timerIndex = timerIndex + 1
                    self.blockData[id] = { block.inputs[1], timerIndex, block.ticks, block.ticks, false }
                    self.blockOutputs[id] = block.outputs
                    self.runnableBlockPaths[id] = "timerBlocks"
                    self.blockStates[id] = false
                    if block.ticks > longestTimer then
                        longestTimer = block.ticks
                    end
                end
            else
                for _, inputId in pairs(block.inputs) do
                    for k, outputId in pairs(self.data[inputId].outputs) do
                        if outputId == id then
                            table.remove(self.data[inputId].outputs, k)
                        end
                    end
                end
            end
        elseif (block.type == "vanilla logic") then
            if (#block.inputs == 0) then
                self.blockStates[id] = false
            elseif (#block.outputs > 0 or block.color == "420420") then
                if (#block.inputs == 1) then
                    if (block.mode >= 3) then
                        self.blockData[id] = block.inputs[1]
                        self.runnableBlockPaths[id] = "norThroughBlocks"
                    else
                        self.blockData[id] = block.inputs[1]
                        self.runnableBlockPaths[id] = "throughBlocks"
                    end
                else
                    if (block.mode == 0) then
                        self.blockData[id] = block.inputs
                        self.runnableBlockPaths[id] = "andBlocks"
                        self.numberOfBlockInputs[id] = #block.inputs
                    elseif (block.mode == 1) then
                        self.blockData[id] = block.inputs
                        self.runnableBlockPaths[id] = "orBlocks"
                    elseif (block.mode == 2) then
                        self.blockData[id] = block.inputs
                        self.runnableBlockPaths[id] = "xorBlocks"
                        --end
                    elseif (block.mode == 3) then
                        self.blockData[id] = block.inputs
                        self.runnableBlockPaths[id] = "nandBlocks"
                        self.numberOfBlockInputs[id] = #block.inputs
                    elseif (block.mode == 4) then
                        self.blockData[id] = block.inputs
                        self.runnableBlockPaths[id] = "norBlocks"
                    elseif (block.mode == 5) then
                        self.blockData[id] = block.inputs
                        self.runnableBlockPaths[id] = "xnorBlocks"
                    end
                end
                self.blockOutputs[id] = block.outputs
                self.blockStates[id] = false
            else
                for _, inputId in pairs(block.inputs) do
                    for k, outputId in pairs(self.data[inputId].outputs) do
                        if outputId == id then
                            table.remove(self.data[inputId].outputs, k)
                        end
                    end
                end
            end
        end
    end
    for id, block in pairs(toFixTimers) do
        local inputBlockOutputs = self.blockOutputs[block.inputs[1]]
        for i, inputBlockOutputId in pairs(inputBlockOutputs) do
            if inputBlockOutputId == id then
                inputBlockOutputs[i] = id + block.ticks / (block.ticks + 1)
            end
        end
    end
    for id, outputs in pairs(self.blockOutputs) do
        self.numberOfBlockOutputs[id] = #outputs
    end
    for i = 1, longestTimer + 1, 1 do
        self.timerData[i] = {}
    end
    self.nextRunningBlocks = {}
    self.runningBlocks = {}
    self.runningBlockLengths = {}
    for _, index in pairs(self.pathIndexs) do
        self.runningBlocks[index] = {}
        self.runningBlockLengths[index] = 0
    end
    for id, path in pairs(self.runnableBlockPaths) do
        self.runnableBlockPathIds[id] = self.pathIndexs[path]
    end
    for id, block in pairs(self.blockData) do
        local pathId = self.runnableBlockPathIds[id]
        self.runningBlockLengths[pathId] = self.runningBlockLengths[pathId] + 1
        self.runningBlocks[pathId][self.runningBlockLengths[pathId]] = id
    end
    self:doUpdate()
end

function FastLogicRunner.server_onProjectile(self)
    -- print("-----------------------------")
    -- local blockCounts = {}
    -- for k, v in pairs(self.runnableBlockPaths) do
    --     if blockCounts[v] == nil then
    --         blockCounts[v] = 0
    --     end
    --     blockCounts[v] = blockCounts[v] + 1
    -- end
    -- print(blockCounts)

    self:FindBalencedLogic()
end

function FastLogicRunner.doUpdates(self)
    self.updateTicks = self.updateTicks + numberOfUpdatesPerTick
    if self.updateTicks >= 1 then
        -- input
        for blockId, data in pairs(self.inputBlocks) do
            local lastState = self.blockStates[blockId]
            if sm.exists(data) and (data.active ~= lastState) then
                self.blockStates[blockId] = not lastState
                local stateNumber = lastState and -1 or 1
                for i = 1, self.numberOfBlockOutputs[blockId] do
                    local idToRunNext = self.blockOutputs[blockId][i]
                    self.countOfOnInputs[idToRunNext] = self.countOfOnInputs[idToRunNext] + stateNumber
                    if self.nextRunningBlocks[idToRunNext] == nil then
                        local pathId = self.runnableBlockPathIds[idToRunNext]
                        local tableLenght = self.runningBlockLengths[pathId]
                        self.runningBlocks[pathId][tableLenght + 1] = idToRunNext
                        self.runningBlockLengths[pathId] = tableLenght + 1
                        self.nextRunningBlocks[idToRunNext] = true
                    end
                end
            end
        end
        while self.updateTicks >= 1 do
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
    end
end

function FastLogicRunner.doUpdate(self)
    -- uncomment to see how many blocks are running
    --print(table.lengthSumOfContainedElements(self.runningBlocks))
    --print(table.length(self.blockData))
    --print(self.countOfOnInputs)
    -- if table.lengthSumOfContainedElements(self.runningBlocks) > 0 then
    --print(self.runningBlocks)
    -- end
    -- for k,v in pairs(self.runningBlocks) do
    --     print(k .. ": " .. #v)
    -- end
    local newBlockStates = {}
    local newBlockStatesLength = 0
    self.nextRunningBlocks = {}
    local runningBlocks = self.runningBlocks
    local nextRunningBlocks = self.nextRunningBlocks
    local runningBlockLengths = self.runningBlockLengths
    local countOfOnInputs = self.countOfOnInputs
    local runnableBlockPathIds = self.runnableBlockPathIds
    local numberOfBlockOutputs = self.numberOfBlockOutputs
    local numberOfBlockInputs = self.numberOfBlockInputs
    local blockStates = self.blockStates
    local blockOutputs = self.blockOutputs
    -- through
    local throughBlocks = runningBlocks[3]
    for k=1, runningBlockLengths[3] do
        local blockId = throughBlocks[k]
        if (countOfOnInputs[blockId] == 1) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    -- nor through
    local norThroughBlocks = runningBlocks[4]
    for k=1, runningBlockLengths[4] do
        local blockId = norThroughBlocks[k]
        if (countOfOnInputs[blockId] == 0) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    -- and
    local andBlocks = runningBlocks[6]
    for k=1, runningBlockLengths[6] do
        local blockId = andBlocks[k]
        if (countOfOnInputs[blockId] == numberOfBlockInputs[blockId]) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    -- or
    local orBlocks = runningBlocks[7]
    for k=1, runningBlockLengths[7] do
        local blockId = orBlocks[k]
        if (countOfOnInputs[blockId] > 0) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    -- xor
    local xorBlocks = runningBlocks[8]
    for k=1, runningBlockLengths[8] do
        local blockId = xorBlocks[k]
        if (countOfOnInputs[blockId] % 2 == 1) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    -- nand
    local nandBlocks = runningBlocks[9]
    for k=1, runningBlockLengths[9] do
        local blockId = nandBlocks[k]
        if (countOfOnInputs[blockId] ~=  numberOfBlockInputs[blockId]) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    -- nor
    local norBlocks = runningBlocks[10]
    for k=1, runningBlockLengths[10] do
        local blockId = norBlocks[k]
        if (countOfOnInputs[blockId] == 0) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    -- xnor
    local xnorBlocks = runningBlocks[11]
    for k=1, runningBlockLengths[11] do
        local blockId = xnorBlocks[k]
        if (countOfOnInputs[blockId] % 2 == 0) ~= blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
    end
    -- timer
    local timerReadRow = table.remove(self.timerData, 1)
    self.timerData[#self.timerData + 1] = {}
    local timerBlocks = runningBlocks[5]
    for k=1, runningBlockLengths[5] do
        local blockId = timerBlocks[k]
        local block = self.blockData[blockId]
        if (timerReadRow[block[2]]) ~= nil then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        if (countOfOnInputs[blockId] == 1) ~= block[5] then
            block[5] = not block[5]
            self.timerData[block[3]][block[2]] = true
            block[4] = block[3]
            nextRunningBlocks[blockId] = true
        elseif block[4] > 1 then
            block[4] = block[4] - 1
            nextRunningBlocks[blockId] = true
        end
    end
    -- light
    local lightBlocks = runningBlocks[2]
    for k=1, runningBlockLengths[2] do
        local blockId = lightBlocks[k]
        blockStates[blockId] = blockStates[self.blockData[blockId]]
    end
    -- create new list of runningBlockLengths
    runningBlockLengths = {
        [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0, [8] = 0, [9] = 0,  [10] = 0,  [11] = 0
    }
    self.runningBlockLengths = runningBlockLengths
    for id, _ in pairs(nextRunningBlocks) do
        local pathId = runnableBlockPathIds[id]
        runningBlockLengths[pathId] = runningBlockLengths[pathId] + 1
        runningBlocks[pathId][runningBlockLengths[pathId]] = id
    end
    for i = 1, newBlockStatesLength do
        local id = newBlockStates[i]
        blockStates[id] = not blockStates[id]
        local stateNumber = blockStates[id] and 1 or -1
        local outputs = blockOutputs[id]
        for k = 1, numberOfBlockOutputs[id] do
            local outputId = outputs[k]
            countOfOnInputs[outputId] = countOfOnInputs[outputId] + stateNumber
            if nextRunningBlocks[outputId] == nil then
                nextRunningBlocks[outputId] = true
                local pathId = runnableBlockPathIds[outputId]
                runningBlockLengths[pathId] = runningBlockLengths[pathId] + 1
                runningBlocks[pathId][runningBlockLengths[pathId]] = outputId
            end
        end
    end
end
