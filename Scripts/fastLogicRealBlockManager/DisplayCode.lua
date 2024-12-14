dofile "../util/util.lua"
local string = string
local table = table

function FastLogicRealBlockManager.updateDisplay(self, blockToUpdate)
    local creation = self.creation
    local creationBlocks = creation.blocks
    local blocks = creation.blocks
    local displayedStates = self.displayedBlockStates
    local fastBlocks = creation.AllFastBlocks
    local changedUuids = sm.MTFastLogic.FastLogicRunnerRunner.changedUuidsArray
    for i = 1, #blockToUpdate do
        local uuid = blockToUpdate[i]
        local block = fastBlocks[uuid]
        if block ~= nil then
            local state = blocks[uuid].state
            if displayedStates[uuid] ~= state then
                displayedStates[uuid] = state
                if block.interactable.active ~= state or block.state ~= state then
                    block.state = state
                    if creationBlocks[uuid].numberOfOtherOutputs ~= 0 then
                        block.interactable.active = state
                        if state then
                            block.interactable.power = 1
                        else
                            block.interactable.power = 0
                        end
                    end
                    changedUuids[#changedUuids + 1] = uuid
                end
            end
        end
    end
end
