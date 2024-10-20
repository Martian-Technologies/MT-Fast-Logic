dofile "../util/util.lua"
dofile "../util/compressionUtil/compressionUtil.lua"

dofile "BaseFastLogicBlock.lua"

sm.interactable.connectionType.fastLogicInterface = math.pow(2, 27)
sm.interactable.connectionType.composite = math.pow(2, 15)

FastLogicBlockMemory = table.deepCopyTo(BaseFastLogicBlock, (FastLogicBlockMemory or class()))
FastLogicBlockMemory.colorNormal = sm.color.new(0xf00000ff)
FastLogicBlockMemory.colorHighlight = sm.color.new(0xf53d00ff)
FastLogicBlockMemory.connectionInput = sm.interactable.connectionType.logic
FastLogicBlockMemory.connectionOutput = sm.interactable.connectionType.fastLogicInterface + sm.interactable.connectionType.composite

--needed for SComputers
FastLogicBlockMemory.componentType = "MTFastMemory"

function FastLogicBlockMemory.getData2(self)
    self.creation.FastLogicBlockMemorys[self.data.uuid] = self
end

function FastLogicBlockMemory.server_onCreate2(self)
    self.type = "BlockMemory"
    if self.storage:load() ~= nil then
        local data = self.storage:load()
        if data.memory == nil then
            self.data.memory = ""
            self.memory = {}
        else
            self.data.memory = data.memory
            self.memory = sm.MTFastLogic.CompressionUtil.stringToHash(data.memory)
        end
    else
        self.data.memory = ""
        self.memory = {}
    end
    self.storage:save(self.data)
    self.lastSavedMemory = os.clock()
    self.needToSaveMemory = false
    self.interactable.publicData = {
        sc_component = {
            type = FastLogicBlockMemory.componentType,
            api = {
                setValue = function(key, value)
                    FastLogicBlockMemory.server_setValue(self, key, value)
                end,
                getValue = function(key)
                    return self.memory[math.floor(key + 1)] or 0
                end,
                setValues = function(kvPairs)
                    FastLogicBlockMemory.server_setValues(self, kvPairs)
                end,
                getValues = function(keys)
                    return FastLogicBlockMemory.server_getValues(self, keys)
                end,
                clearMemory = function()
                    FastLogicBlockMemory.server_clearMemory(self)
                end,
                setMemory = function(memory)
                    FastLogicBlockMemory.server_saveMemoryIdxOffset(self, memory)
                end,
                getMemory = function()
                    return FastLogicBlockMemory.server_getMemoryIdxOffset(self)
                end,
            },
            docs = { -- not used yet, but I'll try to convince logic to support this
                setValue = {
                    "Sets the value of a key in the memory",
                    "key: number - The key to set",
                    "value: number - The value to set"
                },
                getValue = {
                    "Gets the value of a key in the memory",
                    "key: number - The key to get"
                },
                setValues = {
                    "Sets multiple values in the memory",
                    "kvPairs: table - A table with key-value pairs to set"
                },
                getValues = {
                    "Gets multiple values from the memory",
                    "keys: table - A table with keys to get"
                },
                clearMemory = {
                    "Clears the memory"
                },
                setMemory = {
                    "Sets the memory",
                    "memory: table - The memory to set"
                },
                getMemory = {
                    "Gets the memory"
                },
            }
        }
    }
end

function FastLogicBlockMemory.server_setValue(self, key, value)
    self.memory[math.floor(key + 1)] = math.floor(value)
    self.FastLogicRunner:externalUpdateRamInterfaces(self.data.uuid)
    FastLogicBlockMemory.server_requestSaveMemory(self)
end

function FastLogicBlockMemory.server_onFixedUpdate(self)
    if self.needToSaveMemory then
        if os.clock() - self.lastSavedMemory > 0.5 then
            FastLogicBlockMemory.server_saveHeldMemory(self)
        end
    end
end

function FastLogicBlockMemory.server_requestSaveMemory(self)
    self.needToSaveMemory = true
end

function FastLogicBlockMemory.server_setValues(self, kvPairs)
    for k, v in pairs(kvPairs) do
        self.memory[math.floor(k + 1)] = math.floor(v)
    end
    self.FastLogicRunner:externalUpdateRamInterfaces(self.data.uuid)
    FastLogicBlockMemory.server_requestSaveMemory(self)
end

function FastLogicBlockMemory.server_getValues(self, keys)
    local values = {}
    for _, k in pairs(keys) do
        values[k] = self.memory[math.floor(k + 1)] or 0
    end
    return values
end

function FastLogicBlockMemory.server_clearMemory(self)
    for k, _ in pairs(self.memory) do
        self.memory[k] = nil
    end
    self.FastLogicRunner:externalUpdateRamInterfaces(self.data.uuid)
    FastLogicBlockMemory.server_saveHeldMemory(self)
end

function FastLogicBlockMemory.server_saveMemoryIdxOffset(self, memory)
    -- clear mem
    for k,_ in pairs(self.memory) do
        self.memory[k] = nil
    end
    -- save mem
    for k,v in pairs(memory) do
        self.memory[math.floor(k + 1)] = math.floor(v)
    end
    -- update interfaces
    self.FastLogicRunner:externalUpdateRamInterfaces(self.data.uuid)
    FastLogicBlockMemory.server_saveHeldMemory(self)
end

function FastLogicBlockMemory.server_getMemoryIdxOffset(self)
    -- sm.MTUtil.Profiler.Count.increment("getMemoryIdxOffset")
    -- sm.MTUtil.Profiler.Time.on("getMemoryIdxOffset")
    local memory = {}
    for k, v in pairs(self.memory) do
        memory[k - 1] = v
    end
    -- sm.MTUtil.Profiler.Time.off("getMemoryIdxOffset")
    return memory
end

function FastLogicBlockMemory.server_onDestroy2(self)
    self.creation.FastLogicBlockMemorys[self.data.uuid] = nil
end

function FastLogicBlockMemory.client_updateTexture(self, state)
    if self.client_state ~= state then
        self.client_state = state
        if state then
            self.interactable:setUvFrameIndex(0)
        else
            self.interactable:setUvFrameIndex(6)
        end
    end
end

function FastLogicBlockMemory.server_saveMemory(self, memory)
    if type(memory) == "string" then
        memory = sm.MTFastLogic.CompressionUtil.stringToHash(memory)
    end
    -- clear mem
    for k,_ in pairs(self.memory) do
        self.memory[k] = nil
    end
    -- save mem
    table.copyTo(memory, self.memory)
    -- update interfaces
    self.FastLogicRunner:externalUpdateRamInterfaces(self.data.uuid)
    FastLogicBlockMemory.server_saveHeldMemory(self)
end

function FastLogicBlockMemory.server_saveHeldMemory(self)
    self.lastSavedMemory = os.clock()
    self.needToSaveMemory = false
    self.data.memory = sm.MTFastLogic.CompressionUtil.hashToString(self.memory)
    self.storage:save(self.data)
end

function FastLogicBlockMemory.server_onProjectile(self, position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid)
    print(self.memory)
    -- local averageTime = sm.MTUtil.Profiler.Time.get("getMemoryIdxOffset") /
    -- sm.MTUtil.Profiler.Count.get("getMemoryIdxOffset")
    -- print("Average time: " .. tostring(averageTime))
    -- print("Total time: " .. tostring(sm.MTUtil.Profiler.Time.get("getMemoryIdxOffset")))
    -- print("Total count: " .. tostring(sm.MTUtil.Profiler.Count.get("getMemoryIdxOffset")))
    -- sm.MTUtil.Profiler.Time.reset("getMemoryIdxOffset")
    -- sm.MTUtil.Profiler.Count.reset("getMemoryIdxOffset")
end

local function parseStrAsNum(txt)
    -- if txt starts with 0b, parse as binary
    if string.sub(txt, 1, 2) == "0b" then
        local outputNumber = 0
        for i = 1, #txt do
            local char = txt:sub(i, i)
            if char == "1" then
                outputNumber = outputNumber * 2 + 1
            elseif char == "0" then
                outputNumber = outputNumber * 2
            end
        end
        return outputNumber
    elseif string.sub(txt, 1, 2) == "0x" then
        return tonumber(txt, 16)
    else
        return tonumber(txt)
    end
end

function FastLogicBlockMemory.client_onInteract(self, character, state)
    if state then
        if not sm.json.fileExists("$CONTENT_DATA/memoryBlockData/data.json") then
            sm.gui.chatMessage("Can't find file at $CONTENT_DATA/memoryBlockData/data.json")
            return
        end
        local allData = sm.json.open("$CONTENT_DATA/memoryBlockData/data.json")
        local color = string.sub(self.shape:getColor():getHexStr(), 0, 6)
        -- local data = allData[string.sub(self.shape:getColor():getHexStr(), 0, 6)]
        local data = nil
        for k, v in pairs(allData) do
            -- lower case everything
            local kLower = string.lower(k)
            local colorLower = string.lower(color)
            if kLower == colorLower then
                data = v
                break
            end
        end
        if data == nil then
            data = allData.data
        end
        if data == nil then
            sm.gui.chatMessage(
                "Could not read data in memoryBlockData/data.json\nMake sure its formatted:" ..
                "\n{\n    \"data\": [],\n    \"color hex 1\": [],\n    \"color hex 2\": [],\n    ...\n}"
            )
            return
        end
        local memory = {}
        local validValues = 0
        local invalidValue = 0
        for k, v in pairs(data) do
            if type(v) == "string" then
                v = parseStrAsNum(v)
            end
            if type(k) == "string" then
                k = parseStrAsNum(k)
            end
            if type(k) == "number" and type(v) == "number" then
                memory[k] = v
                validValues = validValues + 1
            else
                invalidValue = invalidValue + 1
            end
        end
        sm.gui.chatMessage(
            "Imported: " ..
            tostring(validValues) ..
            " values.   Fail to import: " ..
            tostring(invalidValue) ..
            " values."
        )
        memory = sm.MTFastLogic.CompressionUtil.hashToString(memory)
        self.network:sendToServer("server_saveMemory", memory)
    end
end