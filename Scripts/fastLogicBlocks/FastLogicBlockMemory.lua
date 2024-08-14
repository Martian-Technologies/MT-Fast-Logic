dofile "../util/util.lua"
dofile "../util/compressionUtil/compressionUtil.lua"

dofile "BaseFastLogicBlock.lua"

sm.interactable.connectionType.fastLogicInterface = math.pow(2, 27)

FastLogicBlockMemory = table.deepCopyTo(BaseFastLogicBlock, (FastLogicBlockMemory or class()))
FastLogicBlockMemory.colorNormal = sm.color.new(0xf00000ff)
FastLogicBlockMemory.colorHighlight = sm.color.new(0xf53d00ff)
FastLogicBlockMemory.connectionInput = sm.interactable.connectionType.logic
FastLogicBlockMemory.connectionOutput = sm.interactable.connectionType.fastLogicInterface

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
    -- compress mem
    self.data.memory = sm.MTFastLogic.CompressionUtil.hashToString(memory)
    self.storage:save(self.data)
end

function FastLogicBlockMemory.server_saveHeldMemory(self)
    self.data.memory = sm.MTFastLogic.CompressionUtil.hashToString(self.memory)
    self.storage:save(self.data)
end

function FastLogicBlockMemory.server_onProjectile(self, position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid)
    print(self.memory)
end

function FastLogicBlockMemory.client_onInteract(self, character, state)
    if state then
        if not sm.json.fileExists("$CONTENT_DATA/memoryBlockData/data.json") then
            sm.gui.chatMessage("Can't find file at $CONTENT_DATA/memoryBlockData/data.json")
            return
        end
        local allData = sm.json.open("$CONTENT_DATA/memoryBlockData/data.json")
        local data = allData[string.sub(self.shape:getColor():getHexStr(), 0, 6)]
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
        for k,v in pairs(data) do
            if type(v) == "string" then
                v = tonumber(v)
            end
            if type(k) == "string" then
                k = tonumber(k)
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