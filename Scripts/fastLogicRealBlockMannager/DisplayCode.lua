dofile "../util/util.lua"
local string = string
local table = table

function FastLogicRealBlockMannager.updateDisplay(self, blockToUpdate)
    local numberOfChanges = 0
    local blocks = self.creation.blocks
    local displayedStates = self.displayedBlockStates
    local fastBlocks = self.creation.AllFastBlocks
    local changedUuidsArray = sm.MTFastLogic.FastLogicRunnerRunner.changedUuidsArray
    local changedUuids = {}
    for i = 1, #blockToUpdate do
        local uuid = blockToUpdate[i]
        local block = fastBlocks[uuid]
        if block ~= nil then
            local state = blocks[uuid].state
            if displayedStates[uuid] ~= state then
                displayedStates[uuid] = state
                if block.interactable.active ~= state or block.state ~= state then
                    print("yes")
                    block.interactable.active = state
                    block.state = state
                    if state then
                        block.interactable.power = 1
                    else
                        block.interactable.power = 0
                    end
                    numberOfChanges = numberOfChanges + 1
                    changedUuids[numberOfChanges] = uuid
                end
            end
        end
        if numberOfChanges > 1000 then
            print("WHAT")
            changedUuidsArray[#changedUuidsArray + 1] = changedUuids
            changedUuids = {}
            numberOfChanges = 0
        end
       
    end
    if numberOfChanges > 0 then
        print(changedUuids)
        changedUuidsArray[#changedUuidsArray + 1] = changedUuids
    end
    self.creation.lastBodyUpdate = sm.game.getCurrentTick()
end
