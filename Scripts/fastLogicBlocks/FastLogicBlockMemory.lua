dofile "../util/util.lua"
dofile "../util/compressionUtil/compressionUtil.lua"

dofile "BaseFastLogicBlock.lua"

FastLogicBlockMemory = table.deepCopyTo(BaseFastLogicBlock, (FastLogicBlockMemory or class()))
FastLogicBlockMemory.maxParentCount = -1 -- infinite
FastLogicBlockMemory.maxChildCount = -1  -- infinite

function FastLogicBlockMemory.getData2(self)
    self.creation.FastLogicBlockMemorys[self.data.uuid] = self
end

function FastLogicBlockMemory.server_onCreate2(self)
    self.type = "BlockMemory"
    if self.storage:load() ~= nil then
        local data = self.storage:load()
        self.data.memory = data.memory
        self.memory = sm.MTUtil.compressionUtil.stringToHash(data.memory)
    else
        self.data.memory = ""
        self.memory = {}
    end
    self.storage:save(self.data)
end

function FastLogicBlockMemory.server_onDestroy2(self)
    self.creation.FastLogicBlockMemorys[self.data.uuid] = nil
end

function FastLogicBlockMemory.client_updateTexture(self)
end

function FastLogicBlockMemory.server_saveMemory(self, memory)
    self.memory = memory
    self.data.memory = sm.MTUtil.compressionUtil.hashToString(memory)
    self.storage:save(self.data)
end
