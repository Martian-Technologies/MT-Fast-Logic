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
            -- print(id)
            id = id + 1
            if blockInputs[id] ~= false and blockInputs[id] ~= nil then
                local blockType = self.runnableBlockPathIds[id]
                -- "andBlocks",        -- 6
                -- "and2Blocks",       -- 7
                -- "orBlocks",         -- 8
                -- "or2Blocks",        -- 9
                -- "nandBlocks",       -- 11
                -- "nand2Blocks",      -- 12
                -- "norBlocks",        -- 13
                -- "nor2Blocks",       -- 14
                -- ordering inputs
                -- print(blockType)
                if blockType == 6 or blockType == 7 or blockType == 8 or blockType == 9 or blockType == 11 or blockType == 12 or blockType == 13 or blockType == 14 then
                    local numberOfInputUpdates = {}
                    for i = 1, #blockInputs[id] do
                        numberOfInputUpdates[blockInputs[id][i]] = numberOfStateChanges[blockInputs[id][i]] + i
                    end
                    local newBLockInputs = table.getKeysSortedByValue(numberOfInputUpdates, function(a, b) return a < b end)
                    local bottom = 0
                    for i = 1, math.ceil(#newBLockInputs/3) do
                        bottom = bottom + newBLockInputs[i]
                    end
                    bottom = bottom / math.ceil(#newBLockInputs/3)
                    local top = 0
                    for i = #newBLockInputs - math.floor(#newBLockInputs/3), #newBLockInputs do
                        if newBLockInputs[i] == nil then
                            goto skipModeChange
                        end
                        top = top + newBLockInputs[i]
                    end
                    top = top / (math.floor(#newBLockInputs/3) + 1)
                    if top/bottom > 1.2 then
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
            end
        end
    end
    if id == #blockInputs then
        for i = 1, #numberOfStateChanges do
            if numberOfStateChanges[i] ~= false then
                numberOfStateChanges[i] = numberOfStateChanges[i] * 0.4
            end
        end
        id = -#blockInputs
    end

    self.blocksOptimized = id
end