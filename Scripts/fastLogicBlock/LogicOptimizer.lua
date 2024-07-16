dofile "../util/util.lua"
local string = string
local table = table
local type = type
local pairs = pairs


function FastLogicRunner.optimizeLogic(self)
    local blockInputs = self.blockInputs
    local numberOfBlockInputs = self.numberOfBlockInputs
    local id = self.blocksOptimized
    local target = math.min(id + math.ceil(#blockInputs / 160), #blockInputs)
    if target < 1 then
        id = target
    else
        while id < target do
            id = id + 1
            if blockInputs[id] ~= false and blockInputs[id] ~= nil then
                -- multi blocks
                -- self:findMultiBlocks(id)
                print(id)
            end
        end
    end

    self.blocksOptimized = id
end

function FastLogicRunner.findMultiBlocks(self, id)
    local blockInputs = self.blockInputs
    local blockOutputs = self.blockOutputs
    -- line, id = 1 -- not line, id = 2
    if self.runnableBlockPathIds[id] == 3 and self.multiBlockData[id] == false then
        local blocks = { id }
        local needsEndOfTick
        ::checkInputAgain::
        if self.numberOfBlockInputs[blocks[1]] == 1 and self.numberOfOtherInputs[blocks[1]] == 0 then
            local blockToCheck = blockInputs[blocks[1]][1]
            if not table.contains(blocks, blockToCheck) then
                local lightCount = 0
                for i=1, self.numberOfBlockOutputs[blockToCheck] do
                    if self.runnableBlockPathIds[blockOutputs[blockToCheck][i]] == 2 then
                        lightCount = lightCount + 1
                    end
                end
                if (
                    self.multiBlockData[blockToCheck] == false and
                    self.runnableBlockPathIds[blockToCheck] >= 3 and self.runnableBlockPathIds[blockToCheck] <= 15 and self.runnableBlockPathIds[blockToCheck] ~= 5 and
                    self.numberOfBlockOutputs[blockToCheck] == lightCount + 1
                ) then
                    blocks = table.appendTable({blockToCheck}, blocks)
                    goto checkInputAgain
                end
            end
        end
        ::checkOutputAgain::
        local lightCount = 0
        local blockToCheck = nil
        for i=1, self.numberOfBlockOutputs[blocks[#blocks]] do
            if self.runnableBlockPathIds[blockOutputs[blocks[#blocks]][i]] == 2 then
                lightCount = lightCount + 1
            else
                blockToCheck = blockOutputs[blocks[#blocks]][i]
            end
        end
        if self.numberOfBlockOutputs[blocks[#blocks]] == lightCount + 1 then
            -- local blockToCheck = blockOutputs[blocks[#blocks]][1]
            if not table.contains(blocks, blockToCheck) then
                if (
                    self.multiBlockData[blockToCheck] == false and
                    self.runnableBlockPathIds[blockToCheck] >= 3 and self.runnableBlockPathIds[blockToCheck] <= 4
                ) then
                    blocks[#blocks + 1] = blockToCheck
                    goto checkOutputAgain
                end
            end
        end
        ::checkCanBeInputAgain::
        if #blocks ~= 1 and self.runnableBlockPathIds[blocks[1]] == 5 then
            table.remove(blocks, 1)
            goto checkCanBeInputAgain
        end
        if #blocks >= 4 then
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

            print("line block: " .. tostring(length))
        end
    end
end
