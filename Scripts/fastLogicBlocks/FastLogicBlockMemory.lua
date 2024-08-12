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
    table.copyTo(self.memory, memory)
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