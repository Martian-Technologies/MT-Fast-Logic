dofile "../util/util.lua"
local string = string
local table = table
local type = type
local pairs = pairs

function FastLogicRunner.optimizeLogic(self)
    -- prin t(self.numberOfBlockInputs)
    -- prin t(self.numberOfOtherInputs)
    -- prin t(self.blockInputs)
    -- prin t(self.blockOutputs)
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
                self:findMultiBlocks(id)
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
    -- line, id = 1
    if self.runnableBlockPathIds[id] == 3 and self.multiBlockData[id] == false then
        local lineStart = id
        local lineEnd = id
        local blocks = { id }
        local length = 0
        if self.runnableBlockPathIds[id] == 5 then
            length = length + self.timerLengths[id]
        else
            length = length + 1
        end
        while self.numberOfBlockInputs[lineStart] == 1 and self.multiBlockData[blockInputs[lineStart][1]] == false and
            (not table.contains(blocks, blockInputs[lineStart][1])) and (not table.contains(blockInputs[blockInputs[lineStart][1]], blockInputs[lineStart][1])) and
            (self.runnableBlockPathIds[blockInputs[lineStart][1]] == 5 or self.runnableBlockPathIds[blockInputs[lineStart][1]] == 3) do
            lineStart = blockInputs[lineStart][1]
            blocks[#blocks + 1] = lineStart
            if self.runnableBlockPathIds[lineStart] == 5 then
                length = length + self.timerLengths[lineStart]
            else
                length = length + 1
            end
        end
        while self.numberOfBlockOutputs[lineEnd] == 1 and self.multiBlockData[blockOutputs[lineEnd][1]] == false and
            (not table.contains(blocks, blockOutputs[lineEnd][1])) and (not table.contains(blockInputs[blockOutputs[lineEnd][1]], blockOutputs[lineEnd][1])) and
            (self.runnableBlockPathIds[blockOutputs[lineEnd][1]] == 5 or self.runnableBlockPathIds[blockOutputs[lineEnd][1]] == 3) do
            lineEnd = blockOutputs[lineEnd][1]
            blocks[#blocks + 1] = lineEnd
            if self.runnableBlockPathIds[lineEnd] == 5 then
                length = length + self.timerLengths[lineEnd]
            else
                length = length + 1
            end
        end
        local inputBlockId = lineStart
        if self.numberOfBlockInputs[lineStart] == 1 and self.multiBlockData[blockInputs[lineStart][1]] == false and
            (not table.contains(blocks, blockInputs[lineStart][1])) and (not table.contains(blockInputs[blockInputs[lineStart][1]], blockInputs[lineStart][1])) and
            self.runnableBlockPathIds[blockInputs[lineStart][1]] >= 6 and self.runnableBlockPathIds[blockInputs[lineStart][1]] <= 15 then
            inputBlockId = blockInputs[lineStart][1]
        else
            if self.runnableBlockPathIds[lineStart] == 5 then
                length = length - self.timerLengths[lineStart]
            else
                length = length - 1
            end
            while self.runnableBlockPathIds[blockOutputs[lineStart][1]] == 5 do
                table.removeValue(blocks, lineStart)
                lineStart = blockOutputs[lineStart][1]
                if self.runnableBlockPathIds[lineStart] == 5 then
                    length = length - self.timerLengths[lineStart]
                else
                    length = length - 1
                end
            end
        end

        if #blocks > 4 then
            local outputBlockId = lineEnd
            if self.runnableBlockPathIds[lineEnd] == 5 then
                length = length - self.timerLengths[lineEnd]
            else
                length = length - 1
            end
            length = length + 1
            table.removeValue(blocks, lineEnd)
            lineEnd = blockInputs[lineEnd][1]

            local multiBlockId = self:internalAddMultiBlock(1)

            self:makeBlockAlt(inputBlockId, self.toMultiBlockInput[self.runnableBlockPathIds[inputBlockId]])
            
            self:internalAddBlockToMultiBlock(inputBlockId, multiBlockId, true, false)
            self:internalAddBlockToMultiBlock(outputBlockId, multiBlockId, false, true)
            self.multiBlockData[multiBlockId][6] = length

            for i = 1, #blocks do
                self:internalAddBlockToMultiBlock(blocks[i], multiBlockId, false, false)
            end

            self:updateLongestTimerToLength(length)

            print(length)
            print(lineStart)
            print(lineEnd)
            print(blocks)
        end
    end
end
