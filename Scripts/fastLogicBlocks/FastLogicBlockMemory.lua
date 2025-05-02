dofile "../util/util.lua"
dofile "../util/compressionUtil/compressionUtil.lua"

dofile "BaseFastLogicBlock.lua"

local sm = sm
local string = string
local tostring = tostring

sm.interactable.connectionType.fastLogicInterface = math.pow(2, 27)
sm.interactable.connectionType.composite = math.pow(2, 15)

FastLogicBlockMemory = table.deepCopyTo(BaseFastLogicBlock, (FastLogicBlockMemory or class()))
FastLogicBlockMemory.colorNormal = sm.color.new(0xf00000ff)
FastLogicBlockMemory.colorHighlight = sm.color.new(0xf53d00ff)
FastLogicBlockMemory.connectionInput = sm.interactable.connectionType.logic
FastLogicBlockMemory.connectionOutput = sm.interactable.connectionType.fastLogicInterface + sm.interactable.connectionType.composite

--needed for SComputers
FastLogicBlockMemory.componentType = "MTFastMemory"

function FastLogicBlockMemory.removeSelfFromCreation(self)
	self.creation.FastLogicBlockMemorys[self.data.uuid] = nil
end

function FastLogicBlockMemory.getData2(self)
    self.creation.FastLogicBlockMemorys[self.data.uuid] = self
end

local function divideBy2(numStr)
    local quotient = {}  -- will store quotient digits as strings
    local remainder = 0

    for i = 1, #numStr do
      local digitChar = numStr:sub(i, i)
      local digit = digitChar:byte() - string.byte("0")  -- convert char to number
      local value = remainder * 10 + digit
      local qDigit = math.floor(value / 2)  -- quotient digit
      remainder = value % 2               -- update remainder
      -- Avoid leading zeros in the quotient
      if #quotient > 0 or qDigit ~= 0 then
        table.insert(quotient, tostring(qDigit))
      end
    end

    if #quotient == 0 then
      return "0", remainder
    end

    return table.concat(quotient), remainder
end

local function decimalToBinary(num)
    local s = tostring(num)
    local integerStr = s:match("^%d+")
    if not integerStr then
        return "0"
    end

    integerStr = integerStr:gsub("^0+", "")
    if integerStr == "" then
      integerStr = "0"
    end

    if integerStr == "0" then
      return "0"
    end

    local bits = {}
    local remainder

    while integerStr ~= "0" do
      integerStr, remainder = divideBy2(integerStr)
      table.insert(bits, remainder)
    end

    local binaryDigits = {}
    for i = #bits, 1, -1 do
      table.insert(binaryDigits, tostring(bits[i]))
    end

    -- trim leading zeros
    while #binaryDigits > 1 and binaryDigits[1] == "0" do
        table.remove(binaryDigits, 1)
    end
    return table.concat(binaryDigits)
end

local hexToBin = {
    ["0"] = "0000",
    ["1"] = "0001",
    ["2"] = "0010",
    ["3"] = "0011",
    ["4"] = "0100",
    ["5"] = "0101",
    ["6"] = "0110",
    ["7"] = "0111",
    ["8"] = "1000",
    ["9"] = "1001",
    ["a"] = "1010",
    ["b"] = "1011",
    ["c"] = "1100",
    ["d"] = "1101",
    ["e"] = "1110",
    ["f"] = "1111"
}

local function parseStrAsBin(txt)
    if type(txt) == "number" then
        return decimalToBinary(txt)
    end
    if string.sub(txt, 1, 2) == "0b" then
        local output = ""
        for i = 3, #txt do
            local char = txt:sub(i, i)
            if char == "1" or char == "0" then
                output = output .. char
            end
        end
        return output
    elseif string.sub(txt, 1, 2) == "0x" then
        local output = ""
        for i = 3, #txt do
            local char = txt:sub(i, i)
            if char:match("[0-9a-fA-F]") then
                output = output .. hexToBin[char:lower()]
            end
        end
        return output
    else
        return decimalToBinary(txt)
    end
end

local function parseBinstrAsNum(txt)
    -- this expects string input consisting of only 1s and 0s
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
end

local function isPureBinary(value)
    if type(value) ~= "string" then
        return false
    end
    for i = 1, #value do
        local char = value:sub(i, i)
        if char ~= "1" and char ~= "0" then
            return false
        end
    end
    return true
end

function FastLogicBlockMemory.server_onCreate2(self)
    self.type = "BlockMemory"
    local data = self.storage:load()

    if data ~= nil then
        if data.memory == nil then
            self.data.memory = ""
            self.memory = {}
        else
            -- the first character will be used as an indicator to indicate version.
            self.data.memory = data.memory
            if string.sub(data.memory, 1, 1) == "q" then
                self.memory = sm.MTFastLogic.CompressionUtil.goofyToBinHash(sm.MTFastLogic.CompressionUtil.stringToHash(string.sub(data.memory, 2)))
            else
                self.memory = sm.MTFastLogic.CompressionUtil.stringToHash(data.memory)
            end
        end
    else
        self.data.memory = ""
        self.memory = {}
    end
    local newMemory = {}
    for k, v in pairs(self.memory) do
        -- check for pure binary
        local kPure = isPureBinary(k)
        local vPure = isPureBinary(v)
        if not kPure then
            k = decimalToBinary(tostring(k-1))
        end
        if not vPure then
            v = string.reverse(decimalToBinary(tostring(v)))
        end
        newMemory[k] = v
    end
    self.memory = newMemory
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
    -- print(self.memory)
    local memory = {}
    for k, v in pairs(self.memory) do
        local vReverse = string.reverse(v)
        memory[parseBinstrAsNum(k)] = parseBinstrAsNum(vReverse)
        -- print(parseBinstrAsNum(k), parseBinstrAsNum(vReverse))
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
    self.data.memory = "q" ..
    sm.MTFastLogic.CompressionUtil.hashToString(sm.MTFastLogic.CompressionUtil.binHashToGoofy(self.memory))
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
        -- check the type of data, and take note if it's a dictionary or a list
        local isDict = false
        for k, v in pairs(data) do
            if type(k) == "string" then
                isDict = true
                break
            end
        end
        for k, v in pairs(data) do
            v = parseStrAsBin(v)
            if isDict then
                k = parseStrAsBin(k)
            else
                k = parseStrAsBin(k-1)
            end
            v = string.reverse(v)
            if isPureBinary(v) and isPureBinary(k) then
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