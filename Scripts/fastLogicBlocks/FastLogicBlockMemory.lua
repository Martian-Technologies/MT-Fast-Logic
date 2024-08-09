dofile "../util/util.lua"
dofile "../util/compressionUtil/compressionUtil.lua"

dofile "BaseFastLogicBlock.lua"

FastLogicBlockMemory = table.deepCopyTo(BaseFastLogicBlock, (FastLogicBlockMemory or class()))
FastLogicBlockMemory.colorNormal = sm.color.new(0xf00000ff)
FastLogicBlockMemory.colorHighlight = sm.color.new(0xf53d00ff)
FastLogicBlockMemory.maxParentCount = -1 -- infinite
FastLogicBlockMemory.maxChildCount = -1  -- infinite

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

function FastLogicBlockMemory.client_updateTexture(self)
end

function FastLogicBlockMemory.server_saveMemory(self, memory)
    self.memory = memory
    self.data.memory = sm.MTFastLogic.CompressionUtil.hashToString(memory)
    self.storage:save(self.data)
end
