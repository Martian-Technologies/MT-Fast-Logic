dofile "../util/util.lua"
dofile "BaseFastLogicBlock.lua"

FastLogicBlockInterface = table.deepCopyTo(BaseFastLogicBlock, (FastLogicBlockInterface or class()))
FastLogicBlockInterface.maxParentCount = -1 -- infinite
FastLogicBlockInterface.maxChildCount = -1  -- infinite

function FastLogicBlockInterface.getData2(self)
    self.creation.FastLogicBlockInterfaces[self.data.uuid] = self
end

function FastLogicBlockInterface.server_onCreate2(self)
    self.type = "Interface"
end

function FastLogicBlockInterface.server_onDestroy2(self)
    self.creation.FastLogicBlockInterfaces[self.data.uuid] = nil
end

function FastLogicBlockInterface.client_updateTexture(self)
end