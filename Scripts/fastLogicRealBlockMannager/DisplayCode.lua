dofile "../util/util.lua"


function FastLogicRealBlockMannager.updateDisplay(self, blockToUpdate)
    local numberOfChanges = 0
    local blocks = self.creation.blocks
    local displayedStates = self.displayedBlockStates
    local fastBlocks = self.creation.AllFastBlocks
    local changedIdsArray = sm.MTFastLogic.FastLogicRunnerRunner.changedIdsArray
    local changedIds = {}
    for i = 1, #blockToUpdate do
        local id = blockToUpdate[i]
        local block = fastBlocks[id]
        if block ~= nil then
            local state = blocks[id].state
            if displayedStates[id] ~= state then
                displayedStates[id] = state
                if block.interactable.active ~= state or block.state ~= state then
                    block.interactable.active = state
                    block.state = state
                    if state then
                        block.interactable.power = 1
                    else
                        block.interactable.power = 0
                    end
                    numberOfChanges = numberOfChanges + 1
                    changedIds[numberOfChanges] = id
                end
            end
        end
        if numberOfChanges > 5000 then
            changedIdsArray[#changedIdsArray + 1] = changedIds
            changedIds = {}
            numberOfChanges = 0
        end
    end
    if numberOfChanges > 0 then
        changedIdsArray[#changedIdsArray + 1] = changedIds
        self.creation.lastBodyUpdate = sm.game.getCurrentTick()
    end
end
