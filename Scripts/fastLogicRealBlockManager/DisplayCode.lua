dofile "../util/util.lua"
local string = string
local table = table

function FastLogicRealBlockManager.updateTimerDisplay(self)
    local runner = self.FastLogicRunner
    local timers = self.creation.FastTimers
    if next(timers) == nil then
        return
    end

    local frames = runner.timerUvFrames
    local needsUpdate = runner.didLogicalUpdate or runner.timerUvNeedsUpdate
    if not needsUpdate then
        for uuid, _ in pairs(timers) do
            local id = runner.hashedLookUp[uuid]
            if id ~= nil and frames[id] == nil then
                needsUpdate = true
                break
            end
        end
    end
    if needsUpdate then
        frames = runner:computeTimerUvFrames()
    end

    local displayedTimerUvs = self.displayedTimerUvs
    local changedTimerUvs = sm.MTFastLogic.FastLogicRunnerRunner.changedTimerUvsArray
    for uuid, timer in pairs(timers) do
        local id = runner.hashedLookUp[uuid]
        if id ~= nil then
            local uv = frames[id]
            if uv == nil then
                uv = runner.blockStates[id] and 1023 or 0
                frames[id] = uv
            end
            if displayedTimerUvs[uuid] ~= uv then
                displayedTimerUvs[uuid] = uv
                changedTimerUvs[#changedTimerUvs + 1] = timer.id * 1024 + uv
            end
        end
    end
end

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
