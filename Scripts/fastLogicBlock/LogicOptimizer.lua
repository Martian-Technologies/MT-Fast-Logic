dofile "../util/util.lua"
local string = string
local table = table
local type = type
local pairs = pairs


function FastLogicRunner.optimizeLogic(self)
    local blockInputs = self.blockInputs
    local numberOfBlockInputs = self.numberOfBlockInputs
    local numberOfStateChanges = self.numberOfStateChanges
    local id = self.blocksOptimized
    local target = math.min(id + math.ceil(#blockInputs / 160), #blockInputs)
    if target < 1 then
        id = target
    else
        while id < target do
            id = id + 1
            if blockInputs[id] ~= false and blockInputs[id] ~= nil then
                local blockType = self.runnableBlockPathIds[id]
                -- ordering inputs
                if blockType == 6 or blockType == 7 or blockType == 8 or blockType == 9 or blockType == 11 or blockType == 12 or blockType == 13 or blockType == 14 then
                    local numberOfInputUpdates = {}
                    for i = 1, #blockInputs[id] do
                        numberOfInputUpdates[blockInputs[id][i]] = numberOfStateChanges[blockInputs[id][i]] + i
                    end
                    local newBLockInputs = table.getKeysSortedByValue(numberOfInputUpdates, function(a, b) return a < b end)
                    local bottom = 0
                    for i = 1, math.ceil(#newBLockInputs / 3) do
                        bottom = bottom + newBLockInputs[i]
                    end
                    bottom = bottom / math.ceil(#newBLockInputs / 3)
                    local top = 0
                    for i = #newBLockInputs - math.floor(#newBLockInputs / 3), #newBLockInputs do
                        if newBLockInputs[i] == nil then
                            goto skipModeChange
                        end
                        top = top + newBLockInputs[i]
                    end
                    top = top / (math.floor(#newBLockInputs / 3) + 1)
                    if top / bottom > 1.2 then
                        -- print(blockType)

                        if (blockType == 6 or blockType == 8 or blockType == 11 or blockType == 13) then
                            self:makeBlockAlt(id, blockType + 1)
                        end
                    elseif (blockType == 7 or blockType == 9 or blockType == 12 or blockType == 14) then
                        self:makeBlockAlt(id, blockType - 1)
                    end
                    ::skipModeChange::
                    for i = 1, numberOfBlockInputs[id] do
                        if blockInputs[id][i] ~= newBLockInputs[i] then
                            blockInputs[id] = newBLockInputs
                            self:fixBlockInputData(id)
                            break
                        end
                    end
                end

                -- multi blocks
                -- self:findMultiBlocks(id)
            end
        end
    end
    if id == #blockInputs then
        for i = 1, #numberOfStateChanges do
            if numberOfStateChanges[i] ~= false then
                numberOfStateChanges[i] = numberOfStateChanges[i] * 0.4
            end
        end
        id = - #blockInputs
    end

    self.blocksOptimized = id
end

function FastLogicRunner.findMultiBlocks(self, id)
    local blockInputs = self.blockInputs
    local blockOutputs = self.blockOutputs
    -- line, id = 1 -- not line, id = 2
    if self.runnableBlockPathIds[id] == 3 and self.multiBlockData[id] == false then
        local blocks = { id }
        ::checkInputAgain::
        if self.numberOfBlockInputs[blocks[1]] == 1 then
            local blockToCheck = blockInputs[blocks[1]][1]
            if not table.contains(blocks, blockToCheck) then
                if (
                    (not table.contains(blocks, blockToCheck)) and
                    self.multiBlockData[blockToCheck] == false and
                    self.runnableBlockPathIds[blockToCheck] >= 3 and self.runnableBlockPathIds[blockToCheck] <= 15 and
                    self.numberOfBlockOutputs[blockToCheck] + self.numberOfOtherInputs[blockToCheck] == 1
                ) then
                    blocks = table.appendTable({blockToCheck}, blocks)
                    goto checkInputAgain
                end
            end
        end
        ::checkOutputAgain::
        if self.numberOfBlockOutputs[blocks[#blocks]] == 1 then
            local blockToCheck = blockOutputs[blocks[#blocks]][1]
            if (
                (not table.contains(blocks, blockToCheck)) and
                self.multiBlockData[blockToCheck] == false and
                self.runnableBlockPathIds[blockToCheck] >= 3 and self.runnableBlockPathIds[blockToCheck] <= 5
            ) then
                blocks[#blocks + 1] = blockToCheck
                goto checkOutputAgain
            end
        end
        ::checkCanBeInputAgain::
        if #blocks ~= 1 and self.runnableBlockPathIds[blocks[1]] == 5 then
            table.remove(blocks, 1)
            goto checkCanBeInputAgain
        end
        if #blocks >= 3 then
            local length = -1
            local isNot = false
            for i = 1, #blocks do
                if self.runnableBlockPathIds[blocks[i]] == 5 then
                    length = length + self.timerLengths[blocks[i]]
                else
                    if self.runnableBlockPathIds[blocks[i]] == 4 and i ~= 1 then
                        isNot = not isNot
                    end
                    length = length + 1
                end
            end

            local multiBlockId = self:internalAddMultiBlock(isNot and 2 or 1)

            self:makeBlockAlt(blocks[1], self.toMultiBlockInput[self.runnableBlockPathIds[blocks[1]]])
            
            self:internalAddBlockToMultiBlock(blocks[1], multiBlockId, true, false)
            self.multiBlockData[multiBlockId][7] = length
            for i = 2, #blocks-1 do
                self:internalAddBlockToMultiBlock(blocks[i], multiBlockId, false, false)
            end
            self:internalAddBlockToMultiBlock(blocks[#blocks], multiBlockId, false, true)

            self:updateLongestTimerToLength(length)
            -- print(isNot)
            -- print(length)
            -- print(blocks)
        end
    end
end
