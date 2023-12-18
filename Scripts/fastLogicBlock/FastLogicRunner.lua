FastLogicRunner = FastLogicRunner or class()

print("loading FastLogicRunner")

dofile "../util/util.lua"
dofile "CreationLogicGetter.lua"
dofile "LogicStateDisplayer.lua"

local numberOfUpdatesPerTick = 1

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
    self.runnableBlocks = {}
    self.runnableBlockPaths = {}
    self.inputBlocks = {}
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
    print("---")
    for id, block in pairs(self.data) do
        if (block.type == "vanilla input" and (#block.outputs > 0 or block.color == "420420")) then
            self.inputBlocks[id] = { block.outputs, block.shape:getInteractable() }
            self.runnableBlockPaths[id] = "inputBlocks"
            self.blockStates[id] = false
        elseif (block.type == "vanilla light") then
            if (#block.inputs == 0) then
                self.blockStates[id] = true
            else
                self.runnableBlocks[id] = block.inputs[1]
                self.runnableBlockPaths[id] = "lightBlocks"
                self.blockStates[id] = false
            end
        elseif (block.type == "vanilla timer") then
            if (#block.inputs == 0) then
                self.blockStates[id] = false
            elseif (#block.outputs > 0 or block.color == "420420") then
                --if (block.ticks <= 1) then
                --self.runnableBlocks.throughBlocks[id + (block.ticks) / (block.ticks + 1)] = block.inputs[1]
                --self.runnableBlockPaths[id] = "throughBlocks"
                --for i = 0, block.ticks - 1, 1 do
                --self.runnableBlocks.throughBlocks[id + i / (block.ticks + 1)] = id + (i + 1) / (block.ticks + 1)
                --self.runnableBlockPaths[id + i / (block.ticks + 1)] = "throughBlocks"
                --end
                if block.ticks == 0 then
                    self.runnableBlocks[id] = { block.inputs[1], block.outputs }
                    self.runnableBlockPaths[id] = "throughBlocks"
                    self.blockStates[id] = false
                else
                    self.runnableBlocks[id] = { block.inputs[1], block.outputs, {}, block.ticks, block.ticks}
                    self.runnableBlockPaths[id] = "timerBlocks"
                    for i = 1, block.ticks, 1 do
                        self.runnableBlocks[id][3][i] = false
                    end
                    self.blockStates[id] = false
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
                        self.runnableBlocks[id] = { block.inputs[1], block.outputs }
                        self.runnableBlockPaths[id] = "norThroughBlocks"
                    else
                        self.runnableBlocks[id] = { block.inputs[1], block.outputs }
                        self.runnableBlockPaths[id] = "throughBlocks"
                    end
                else
                    if (block.mode == 0) then
                        self.runnableBlocks[id] = { block.inputs, block.outputs }
                        self.runnableBlockPaths[id] = "andBlocks"
                    elseif (block.mode == 1) then
                        self.runnableBlocks[id] = { block.inputs, block.outputs }
                        self.runnableBlockPaths[id] = "orBlocks"
                    elseif (block.mode == 2) then
                        self.runnableBlocks[id] = { block.inputs, block.outputs }
                        self.runnableBlockPaths[id] = "xorBlocks"
                        --end
                    elseif (block.mode == 3) then
                        self.runnableBlocks[id] = { block.inputs, block.outputs }
                        self.runnableBlockPaths[id] = "nandBlocks"
                    elseif (block.mode == 4) then
                        self.runnableBlocks[id] = { block.inputs, block.outputs }
                        self.runnableBlockPaths[id] = "norBlocks"
                    elseif (block.mode == 5) then
                        self.runnableBlocks[id] = { block.inputs, block.outputs }
                        self.runnableBlockPaths[id] = "xnorBlocks"
                    end
                end
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
    self.runningBlocks = {}
    for _, path in pairs(self.pathNames) do
        self.runningBlocks[path] = {}
    end
    for id, path in pairs(self.runnableBlockPaths) do
        self.runningBlocks[path][id] = true
    end
end

function FastLogicRunner.getOutputLengths(self, tbl)
    local lengths = {}
    for id, _ in pairs(tbl) do
        local outLength
        if self.data[id] == nil then
            outLength = "NIL"
        else
            outLength = #self.data[id].outputs
        end
        if (lengths[outLength] == nil) then
            lengths[outLength] = 0
        end
        lengths[outLength] = lengths[outLength] + 1
    end
    local otherName = "["
    local otherCount = 0
    for length, count in pairs(lengths) do
        if (count < table.length(tbl) / 20) then
            otherCount = otherCount + count
            if otherName ~= "[" then
                otherName = otherName .. ", "
            end
            otherName = otherName .. length
            lengths[length] = nil
        end
    end
    if otherCount > 0 then
        lengths[otherName .. "]"] = otherCount
    end
    return lengths
end

function FastLogicRunner.getInputLengths(self, tbl)
    local lengths = {}
    for _, data in pairs(tbl) do
        if (lengths[#data[1]] == nil) then
            lengths[#data[1]] = 0
        end
        lengths[#data[1]] = lengths[#data[1]] + 1
    end
    local otherName = "["
    local otherCount = 0
    for length, count in pairs(lengths) do
        if (count < table.length(tbl) / 20) then
            otherCount = otherCount + count
            if otherName ~= "[" then
                otherName = otherName .. ", "
            end
            otherName = otherName .. length
            lengths[length] = nil
        end
    end
    if otherCount > 0 then
        lengths[otherName .. "]"] = otherCount
    end
    return lengths
end

function FastLogicRunner.server_onProjectile(self)
    print("-----------------------------")
    local blockCounts = {}
    for k, v in pairs(self.runnableBlockPaths) do
        if blockCounts[v] == nil then
            blockCounts[v] = 0
        end
        blockCounts[v] = blockCounts[v] + 1
    end
    print(blockCounts)
    -- print("inputBlocks")
    -- print("count:", table.length(self.runnableBlocks.inputBlocks))
    -- print("outputs:", self:getOutputLengths(self.runnableBlocks.inputBlocks))
    -- print("throughBlocks")
    -- print("count:", table.length(self.runnableBlocks.throughBlocks))
    -- print("outputs:", self:getOutputLengths(self.runnableBlocks.throughBlocks))
    -- print("norThroughBlocks")
    -- print("count:", table.length(self.runnableBlocks.norThroughBlocks))
    -- print("outputs:", self:getOutputLengths(self.runnableBlocks.norThroughBlocks))
    -- print("andBlocks")
    -- print("count:", table.length(self.runnableBlocks.andBlocks))
    -- print("inputs", self:getInputLengths(self.runnableBlocks.andBlocks))
    -- print("outputs:", self:getOutputLengths(self.runnableBlocks.andBlocks))
    -- print("orBlocks")
    -- print("count:", table.length(self.runnableBlocks.orBlocks))
    -- print("inputs", self:getInputLengths(self.runnableBlocks.orBlocks))
    -- print("outputs:", self:getOutputLengths(self.runnableBlocks.orBlocks))
    -- print("xorBlocks")
    -- print("count:", table.length(self.runnableBlocks.xorBlocks))
    -- print("inputs", self:getInputLengths(self.runnableBlocks.xorBlocks))
    -- print("outputs:", self:getOutputLengths(self.runnableBlocks.xorBlocks))
    -- print("sxorBlocks")
    -- print("count:", table.length(self.runnableBlocks.sxorBlocks))
    -- print("inputs", self:getInputLengths(self.runnableBlocks.sxorBlocks))
    -- print("outputs:", self:getOutputLengths(self.runnableBlocks.sxorBlocks))
    -- print("nandBlocks")
    -- print("count:", table.length(self.runnableBlocks.nandBlocks))
    -- print("inputs", self:getInputLengths(self.runnableBlocks.nandBlocks))
    -- print("outputs:", self:getOutputLengths(self.runnableBlocks.nandBlocks))
    -- print("norBlocks")
    -- print("count:", table.length(self.runnableBlocks.norBlocks))
    -- print("inputs", self:getInputLengths(self.runnableBlocks.norBlocks))
    -- print("outputs:", self:getOutputLengths(self.runnableBlocks.norBlocks))
    -- print("xnorBlocks")
    -- print("count:", table.length(self.runnableBlocks.xnorBlocks))
    -- print("inputs", self:getInputLengths(self.runnableBlocks.xnorBlocks))
    -- print("outputs:", self:getOutputLengths(self.runnableBlocks.xnorBlocks))
    -- print("timerBlocks")
    -- print("count:", table.length(self.runnableBlocks.timerBlocks))
    -- print("outputs:", self:getOutputLengths(self.runnableBlocks.timerBlocks))
    -- print("lightBlocks")
    -- print("count:", table.length(self.runnableBlocks.lightBlocks))
    -- print("-----------------------------")
end

function FastLogicRunner.doUpdates(self)
    self.updateTicks = self.updateTicks + numberOfUpdatesPerTick
    if self.updateTicks >= 1 then
        -- input
        for blockId, data in pairs(self.inputBlocks) do
            if sm.exists(data[2]) then
                self.blockStates[blockId] = data[2].active
            end
            for i = 1, #data[1], 1 do
                self.runningBlocks[self.runnableBlockPaths[data[1][i]]][data[1][i]] = true
            end
        end
        while self.updateTicks >= 1 do
            self:doUpdate()
            self.updateTicks = self.updateTicks - 1
        end
    end
end

function FastLogicRunner.doUpdate(self)
    -- uncomment to see how many blocks are running
    --print(table.lengthSumOfContainedElements(self.runningBlocks))
    --print(table.length(self.runnableBlocks))
    local lastBlockStates = {}
    for k, v in pairs(self.blockStates) do
        lastBlockStates[k] = v
    end
    local nextRunningBlocks = {}
    for _, path in pairs(self.pathNames) do
        nextRunningBlocks[path] = {}
    end
    -- through
    for blockId, _ in pairs(self.runningBlocks.throughBlocks) do
        self.blockStates[blockId] = lastBlockStates[self.runnableBlocks[blockId][1]]
        if self.blockStates[blockId] ~= lastBlockStates[blockId] then
            local outputs = self.runnableBlocks[blockId][2]
            for i = 1, #outputs, 1 do
                nextRunningBlocks[self.runnableBlockPaths[outputs[i]]][outputs[i]] = true
            end
        end
    end
    -- nor through
    for blockId, _ in pairs(self.runningBlocks.norThroughBlocks) do
        self.blockStates[blockId] = not lastBlockStates[self.runnableBlocks[blockId][1]]
        if self.blockStates[blockId] ~= lastBlockStates[blockId] then
            local outputs = self.runnableBlocks[blockId][2]
            for i = 1, #outputs, 1 do
                nextRunningBlocks[self.runnableBlockPaths[outputs[i]]][outputs[i]] = true
            end
        end
    end
    -- and
    for blockId, _ in pairs(self.runningBlocks.andBlocks) do
        local block = self.runnableBlocks[blockId]
        for i = 1, #block[1], 1 do
            if (not lastBlockStates[block[1][i]]) then
                self.blockStates[blockId] = false
                goto andend
            end
        end
        self.blockStates[blockId] = true
        ::andend::
        if self.blockStates[blockId] ~= lastBlockStates[blockId] then
            for i = 1, #block[2], 1 do
                nextRunningBlocks[self.runnableBlockPaths[block[2][i]]][block[2][i]] = true
            end
        end
    end
    -- or
    for blockId, _ in pairs(self.runningBlocks.orBlocks) do
        local block = self.runnableBlocks[blockId]
        for i = 1, #block[1], 1 do
            if (lastBlockStates[block[1][i]]) then
                self.blockStates[blockId] = true
                goto orend
            end
        end
        self.blockStates[blockId] = false
        ::orend::
        if self.blockStates[blockId] ~= lastBlockStates[blockId] then
            for i = 1, #block[2], 1 do
                nextRunningBlocks[self.runnableBlockPaths[block[2][i]]][block[2][i]] = true
            end
        end
    end
    -- xor
    for blockId, _ in pairs(self.runningBlocks.xorBlocks) do
        local count = 0
        local block = self.runnableBlocks[blockId]
        for i = 1, #block[1], 1 do
            if (lastBlockStates[block[1][i]]) then
                count = count + 1
            end
        end
        self.blockStates[blockId] = count % 2 == 1
        if self.blockStates[blockId] ~= lastBlockStates[blockId] then
            for i = 1, #block[2], 1 do
                nextRunningBlocks[self.runnableBlockPaths[block[2][i]]][block[2][i]] = true
            end
        end
    end
    -- nand
    for blockId, _ in pairs(self.runningBlocks.nandBlocks) do
        local block = self.runnableBlocks[blockId]
        for i = 1, #block[1], 1 do
            if (not lastBlockStates[block[1][i]]) then
                self.blockStates[blockId] = true
                goto nandend
            end
        end
        self.blockStates[blockId] = false
        ::nandend::
        if self.blockStates[blockId] ~= lastBlockStates[blockId] then
            for i = 1, #block[2], 1 do
                nextRunningBlocks[self.runnableBlockPaths[block[2][i]]][block[2][i]] = true
            end
        end
    end
    -- nor
    for blockId, _ in pairs(self.runningBlocks.norBlocks) do
        local block = self.runnableBlocks[blockId]
        for i = 1, #block[1], 1 do
            if (lastBlockStates[block[1][i]]) then
                self.blockStates[blockId] = false
                goto norend
            end
        end
        self.blockStates[blockId] = true
        ::norend::
        if self.blockStates[blockId] ~= lastBlockStates[blockId] then
            for i = 1, #block[2], 1 do
                nextRunningBlocks[self.runnableBlockPaths[block[2][i]]][block[2][i]] = true
            end
        end
    end
    -- xnor
    for blockId, _ in pairs(self.runningBlocks.xnorBlocks) do
        local count = 0
        local block = self.runnableBlocks[blockId]
        for i = 1, #block[1], 1 do
            if (lastBlockStates[block[1][i]]) then
                count = count + 1
            end
        end
        self.blockStates[blockId] = count % 2 == 0
        if self.blockStates[blockId] ~= lastBlockStates[blockId] then
            for i = 1, #block[2], 1 do
                nextRunningBlocks[self.runnableBlockPaths[block[2][i]]][block[2][i]] = true
            end
        end
    end
    -- timer
    for blockId, _ in pairs(self.runningBlocks.timerBlocks) do
        local block = self.runnableBlocks[blockId]
        self.blockStates[blockId] = table.remove(block[3], 1)
        block[3][block[4]] = lastBlockStates[block[1]]
        if self.blockStates[blockId] ~= lastBlockStates[blockId] then
            for i = 1, #block[2], 1 do
                nextRunningBlocks[self.runnableBlockPaths[block[2][i]]][block[2][i]] = true
            end
        end
        if block[3][block[4]-1] ~= lastBlockStates[block[1]] then
            block[5] = block[4] - 1
            nextRunningBlocks.timerBlocks[blockId] = true
        elseif block[5] > 0 then
            block[5] = block[5] - 1
            nextRunningBlocks.timerBlocks[blockId] = true
        end
    end
    -- light
    for blockId, _ in pairs(self.runningBlocks.lightBlocks) do
        self.blockStates[blockId] = lastBlockStates[self.runnableBlocks[blockId]]
    end
    self.runningBlocks = nextRunningBlocks
end
