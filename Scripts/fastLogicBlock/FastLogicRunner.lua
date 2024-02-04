FastLogicRunner = FastLogicRunner or class()
print("loading FastLogicRunner")

dofile "../util/util.lua"
dofile "CreationLogicGetter.lua"
dofile "LogicStateDisplayer.lua"
dofile "BalancedLogicFinder.lua"

local numberOfUpdatesPerTick = 8192

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
    self.pathIndexs = {}
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
                        self.blockOutputs[id + i / (block.ticks + 1)] = { id + (i - 1) / (block.ticks + 1) }
                        self.runnableBlockPaths[id + i / (block.ticks + 1)] = "throughBlocks"
                        self.blockStates[id + i / (block.ticks + 1)] = false
                        self.countOfOnInputs[id + i / (block.ticks + 1)] = 0
                    end
                    self.blockData[id + block.ticks / (block.ticks + 1)] = block.inputs[1]
                    self.blockOutputs[id + block.ticks / (block.ticks + 1)] = { id +
                    (block.ticks - 1) / (block.ticks + 1) }
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
    for id, path in pairs(self.runnableBlockPaths) do
        self.runnableBlockPathIds[id] = self.pathIndexs[path]
    end
    self.newBlockStates = {}
    self.newBlockStatesLength = 0
    for id, _ in pairs(self.blockStates) do
        self.newBlockStatesLength = self.newBlockStatesLength + 1
        self.newBlockStates[self.newBlockStatesLength] = id
    end
    -- for id, state in pairs(self.blockStates) do
    --     self.blockStates[id] = not state
    -- end
    self.blocksToRun = {}
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
                self.newBlockStatesLength = self.newBlockStatesLength + 1
                self.newBlockStates[self.newBlockStatesLength] = blockId
                -- self.blockStates[blockId] = not lastState
                -- local stateNumber = lastState and -1 or 1
                -- for i = 1, self.numberOfBlockOutputs[blockId] do
                --     local idToRunNext = self.blockOutputs[blockId][i]
                --     self.countOfOnInputs[idToRunNext] = self.countOfOnInputs[idToRunNext] + stateNumber
                --     if self.nextRunningBlocks[idToRunNext] == nil then
                --         local pathId = self.runnableBlockPathIds[idToRunNext]
                --         local tableLenght = self.runningBlockLengths[pathId]
                --         self.runningBlocks[pathId][tableLenght + 1] = idToRunNext
                --         self.runningBlockLengths[pathId] = tableLenght + 1
                --         self.nextRunningBlocks[idToRunNext] = true
                --     end
                -- end
            end
        end
        -- everything else
        while self.updateTicks >= 1 do
            self:doUpdate()
            self.updateTicks = self.updateTicks - 1
            -- local sum = 0
            -- for k, v in pairs(self.runningBlockLengths) do
            --     sum = sum + v
            -- end
            -- if sum == 0 then
            --     self.updateTicks = 0
            -- end
        end
    end
end

local allBlockFuncs =
{
    -- through
    [3] = function(self, blockId, newBlockStatesLength, newBlockStates)
        if (self.countOfOnInputs[blockId] == 1) ~= self.blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        return newBlockStatesLength
        -- nor through
    end,
    [4] = function(self, blockId, newBlockStatesLength, newBlockStates)
        if (self.countOfOnInputs[blockId] == 0) ~= self.blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        return newBlockStatesLength
        -- and
    end,
    [6] = function(self, blockId, newBlockStatesLength, newBlockStates)
        if (self.countOfOnInputs[blockId] == self.numberOfBlockInputs[blockId]) ~= self.blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        return newBlockStatesLength
        -- or
    end,
    [7] = function(self, blockId, newBlockStatesLength, newBlockStates)
        if (self.countOfOnInputs[blockId] > 0) ~= self.blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        return newBlockStatesLength
        -- xor
    end,
    [8] = function(self, blockId, newBlockStatesLength, newBlockStates)
        if (self.countOfOnInputs[blockId] % 2 == 1) ~= self.blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        return newBlockStatesLength
        -- nand
    end,
    [9] = function(self, blockId, newBlockStatesLength, newBlockStates)
        if (self.countOfOnInputs[blockId] ~= self.numberOfBlockInputs[blockId]) ~= self.blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        return newBlockStatesLength
        -- nor
    end,
    [10] = function(self, blockId, newBlockStatesLength, newBlockStates)
        if (self.countOfOnInputs[blockId] == 0) ~= self.blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        return newBlockStatesLength
        -- xnor
    end,
    [11] = function(self, blockId, newBlockStatesLength, newBlockStates)
        if (self.countOfOnInputs[blockId] % 2 == 0) ~= self.blockStates[blockId] then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        return newBlockStatesLength
        -- timer
    end,
    [5] = function(self, blockId, newBlockStatesLength, newBlockStates)
        local block = self.blockData[blockId]
        if (self.timerReadRow[block[2]]) ~= nil then
            newBlockStatesLength = newBlockStatesLength + 1
            newBlockStates[newBlockStatesLength] = blockId
        end
        if (self.countOfOnInputs[blockId] == 1) ~= block[5] then
            block[5] = not block[5]
            self.timerData[block[3]][block[2]] = true
            block[4] = block[3]
            self.nextRunningBlocks[blockId] = true
        elseif block[4] > 1 then
            block[4] = block[4] - 1
            self.nextRunningBlocks[blockId] = true
        end
        return newBlockStatesLength
        -- light
    end,
    [2] = function(self, blockId, newBlockStatesLength, newBlockStates)
        self.blockStates[blockId] = self.blockStates[self.blockData[blockId]]
        return newBlockStatesLength
    end
}

function FastLogicRunner.doUpdate(self)
    -- uncomment to see how many blocks are running
    -- print(table.lengthSumOfContainedElements(self.runningBlocks))
    -- print(table.length(self.blockData))
    -- print(self.countOfOnInputs)
    -- print(self.newBlockStates)
    -- print(self.blockStates)
    -- if table.lengthSumOfContainedElements(self.runningBlocks) > 0 then
    -- print(self.runningBlocks)
    -- end
    -- for k,v in pairs(self.runningBlocks) do
    --     print(k .. ": " .. #v)
    -- end
    local newBlockStates = {}
    local newBlockStatesLength = 0
    local runningBlocks = self.nextRunningBlocks
    self.nextRunningBlocks = {}
    local countOfOnInputs = self.countOfOnInputs
    local runnableBlockPathIds = self.runnableBlockPathIds
    local numberOfBlockOutputs = self.numberOfBlockOutputs
    local numberOfBlockInputs = self.numberOfBlockInputs
    local blockStates = self.blockStates
    local blockOutputs = self.blockOutputs
    local blocksToRun = self.blocksToRun
    local blocksToRunLength = 0


    -- all timer data shift
    self.timerReadRow = table.remove(self.timerData, 1)
    self.timerData[#self.timerData + 1] = {}

    for blockId, _ in pairs(runningBlocks) do
        blocksToRunLength = blocksToRunLength + 1
        blocksToRun[blocksToRunLength] = blockId
    end
    --     -- ========================== RUN BLOCKS ==========================
    --     -- right now this is the only block that could run
    --     local block = self.blockData[blockId]
    --     if (timerReadRow[block[2]]) ~= nil then
    --         newBlockStatesLength = newBlockStatesLength + 1
    --         newBlockStates[newBlockStatesLength] = blockId
    --     end
    --     if (countOfOnInputs[blockId] == 1) ~= block[5] then
    --         block[5] = not block[5]
    --         self.timerData[block[3]][block[2]] = true
    --         block[4] = block[3]
    --         self.nextRunningBlocks[blockId] = true
    --     elseif block[4] > 1 then
    --         block[4] = block[4] - 1
    --         self.nextRunningBlocks[blockId] = true
    --     end
    --     -- ========================== END RUN BLOCKS ==========================
    -- end
    for i = 1, self.newBlockStatesLength do
        local id = self.newBlockStates[i]
        blockStates[id] = not blockStates[id]
        local stateNumber = blockStates[id] and 1 or -1
        local outputs = blockOutputs[id]
        for k = 1, numberOfBlockOutputs[id] do
            local blockId = outputs[k]
            countOfOnInputs[blockId] = countOfOnInputs[blockId] + stateNumber
            if runningBlocks[blockId] == nil then
                runningBlocks[blockId] = true
                blocksToRunLength = blocksToRunLength + 1
                blocksToRun[blocksToRunLength] = blockId
            end
        end
    end
    for i = 1, blocksToRunLength do
        local blockId = blocksToRun[i]
        -- ========================== RUN BLOCKS ==========================
        -- local pathId = runnableBlockPathIds[blockId]
        newBlockStatesLength = allBlockFuncs[runnableBlockPathIds[blockId]](self, blockId, newBlockStatesLength, newBlockStates)
        -- ========================== END RUN BLOCKS ==========================
    end
    self.newBlockStatesLength = newBlockStatesLength
    self.newBlockStates = newBlockStates
end
