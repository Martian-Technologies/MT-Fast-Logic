dofile "../util/util.lua"


function FastLogicRunner.optimizeLogic(self)
    local blockInputs = self.blockInputs
    local numberOfBlockInputs = self.numberOfBlockInputs
    local numberOfStateChanges = self.numberOfStateChanges
    local id = self.blocksOptimized
    local target = math.min(id + math.ceil(#blockInputs / 80), #blockInputs)
    if target < 1 then
        id = target
    else
        while id < target do
            id = id + 1
            if blockInputs[id] ~= false and type(blockInputs[id]) == "table" then
                local numberOfInputUpdates = {}
                for i = 1, #blockInputs[id] do
                    numberOfInputUpdates[blockInputs[id][i]] = numberOfStateChanges[blockInputs[id][i]] + i
                end
                local newBLockInputs = table.getKeysSortedByValue(numberOfInputUpdates, function(a, b) return a < b end)
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
