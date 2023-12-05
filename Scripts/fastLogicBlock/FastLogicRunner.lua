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
        self.data = self:getBLockData(self.interactable:getBody())
        self:prepData()
    end
    self.network:sendToClients("client_refresh")
    print("reloaded")
end

function FastLogicRunner.client_refresh(self)
    self.displayGUIs = self.displayGUIs or {}
end

function FastLogicRunner.server_onFixedUpdate(self, timeStep)
    if (self.data ~= nil) then
        self:doUpdates()
        self:updateDisplays()
    end
end

function FastLogicRunner.prepData(self)
    self.blockStates = {}
    self.throughBlocks = {}
    self.norThroughBlocks = {}
    self.andBlocks = {}
    self.orBlocks = {}
    self.xorBlocks = {}
    self.nandBlocks = {}
    self.norBlocks = {}
    self.xnorBlocks = {}
    self.timerBlocks = {}
    self.inputBlocks = {}
    self.lightBlocks = {}
    print("---")
    for id, block in pairs(self.data) do
        if (block.type == "vanilla input" and (#block.outputs > 0 or block.color == "420420")) then
            self.inputBlocks[id] = block.shape:getInteractable()
            self.blockStates[id] = false
        elseif (block.type == "vanilla light") then
            if (#block.inputs == 0) then
                self.blockStates[id] = true
            else
                self.lightBlocks[id] = block.inputs[1]
                self.blockStates[id] = false
            end
        elseif (block.type == "vanilla timer") then
            if (#block.inputs == 0) then
                self.blockStates[id] = false
            elseif (#block.outputs > 0 or block.color == "420420") then
                if (block.ticks <= 1) then
                    self.throughBlocks[id + (block.ticks) / (block.ticks + 1)] = block.inputs[1]
                    for i = 0, block.ticks - 1, 1 do
                        self.throughBlocks[id + i / (block.ticks + 1)] = id + (i + 1) / (block.ticks + 1)
                    end
                else
                    self.timerBlocks[id] = { input = block.inputs[1], data = deque.new() }
                    for i = 1, block.ticks, 1 do
                        deque.push_back(self.timerBlocks[id].data, false)
                    end
                    self.blockStates[id] = false
                end
            end
        elseif (block.type == "vanilla logic") then
            if (#block.inputs == 0) then
                self.blockStates[id] = false
            elseif (#block.outputs > 0 or block.color == "420420") then
                if (#block.inputs == 1) then
                    if (block.mode >= 3) then
                        self.norThroughBlocks[id] = block.inputs[1]
                    else
                        self.throughBlocks[id] = block.inputs[1]
                    end
                else
                    if (block.mode == 0) then
                        self.andBlocks[id] = block.inputs
                    elseif (block.mode == 1) then
                        self.orBlocks[id] = block.inputs
                    elseif (block.mode == 2) then
                        self.xorBlocks[id] = block.inputs
                    elseif (block.mode == 3) then
                        self.nandBlocks[id] = block.inputs
                    elseif (block.mode == 4) then
                        self.norBlocks[id] = block.inputs
                    elseif (block.mode == 5) then
                        self.xnorBlocks[id] = block.inputs
                    end
                end
                self.blockStates[id] = false
            end
        end
    end
    -- print("-----------------------------")
    -- print("inputBlocks")
    -- print(self.inputBlocks)
    -- print("throughBlocks")
    -- print(self.throughBlocks)
    -- print("norThroughBlocks")
    -- print(self.norThroughBlocks)
    -- print("timerBlocks")
    -- print(self.timerBlocks)
    -- print("lightBlocks")
    -- print(self.lightBlocks)
end

function FastLogicRunner.doUpdates(self)
    self.updateTicks = self.updateTicks + numberOfUpdatesPerTick
    if self.updateTicks >= 1 then
        -- input
        for blockId, input in pairs(self.inputBlocks) do
            if sm.exists(input) then
                self.blockStates[blockId] = input.active
            end
        end
        while self.updateTicks >= 1 do
            self:doUpdate()
            self.updateTicks = self.updateTicks - 1
        end
    end
end

function FastLogicRunner.doUpdate(self)
    local lastBlockStates = {}
    for k, v in pairs(self.blockStates) do
        lastBlockStates[k] = v
    end
    -- through
    for blockId, input in pairs(self.throughBlocks) do
        self.blockStates[blockId] = lastBlockStates[input]
    end
    -- nor through
    for blockId, input in pairs(self.norThroughBlocks) do
        self.blockStates[blockId] = not lastBlockStates[input]
    end
    -- and
    for blockId, inputs in pairs(self.andBlocks) do
        for _, id in ipairs(inputs) do
            if (not lastBlockStates[id]) then
                self.blockStates[blockId] = false
                goto andend
            end
        end
        self.blockStates[blockId] = true
        ::andend::
    end
    -- or
    for blockId, inputs in pairs(self.orBlocks) do
        for _, id in ipairs(inputs) do
            if (lastBlockStates[id]) then
                self.blockStates[blockId] = true
                goto orend
            end
        end
        self.blockStates[blockId] = false
        ::orend::
    end
    -- xor
    for blockId, inputs in pairs(self.xorBlocks) do
        local count = 0
        for _, id in ipairs(inputs) do
            if (lastBlockStates[id]) then
                count = count + 1
            end
        end
        self.blockStates[blockId] = count % 2 == 1
    end
    -- nand
    for blockId, inputs in pairs(self.nandBlocks) do
        for _, id in ipairs(inputs) do
            if (not lastBlockStates[id]) then
                self.blockStates[blockId] = true
                goto nandend
            end
        end
        self.blockStates[blockId] = false
        ::nandend::
    end
    -- nor
    for blockId, inputs in pairs(self.norBlocks) do
        for _, id in ipairs(inputs) do
            if (lastBlockStates[id]) then
                self.blockStates[blockId] = false
                goto norend
            end
        end
        self.blockStates[blockId] = true
        ::norend::
    end
    -- xnor
    for blockId, inputs in pairs(self.xnorBlocks) do
        local count = 0
        for _, id in ipairs(inputs) do
            if (lastBlockStates[id]) then
                count = count + 1
            end
        end
        self.blockStates[blockId] = count % 2 == 0
    end
    -- timer
    for blockId, block in pairs(self.timerBlocks) do
        local dequeObject = block.data
        -- push back
        dequeObject.back = dequeObject.back + 1
        block.data[dequeObject.back] = lastBlockStates[block.input]
        -- pop front
        self.blockStates[blockId] = dequeObject[dequeObject.front]
        dequeObject[dequeObject.front] = nil
        dequeObject.front = dequeObject.front + 1

        -- old
        -- deque.push_back(block.data, lastBlockStates[block.input])
        -- self.blockStates[blockId] = deque.pop_front(block.data)
    end
    -- light
    for blockId, input in pairs(self.lightBlocks) do
        self.blockStates[blockId] = lastBlockStates[input]
    end
end
