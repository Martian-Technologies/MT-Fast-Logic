dofile "../util/util.lua"
local string = string
local table = table
local type = type
local pairs = pairs
local sm = sm
local BalencedLogicFinder = sm.MTFastLogic.BalencedLogicFinder


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
                self:findMultiBlocks(id)
            end
        end
    end

    if id == #blockInputs then
        id = -100 * #blockInputs
    end
    self.blocksOptimized = id
end

function FastLogicRunner.findMultiBlocks(self, id)
    local blockInputs = self.blockInputs
    local blockOutputs = self.blockOutputs
    local blockStates = self.blockStates
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
            local length = 0
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

            self:internalAddBlockToMultiBlock(blocks[1], multiBlockId, true, false)
            self.multiBlockData[multiBlockId][6] = length
            for i = 2, #blocks-1 do
                self:internalAddBlockToMultiBlock(blocks[i], multiBlockId, false, false)
            end
            self:internalAddBlockToMultiBlock(blocks[#blocks], multiBlockId, false, true)

            self:updateLongestTimeToLength(length)
            return
        end
    end
    if false and self.multiBlockData[id] == false and (sm.noise.randomRange( 0, 20 ) < 1) then
        local layers,
              layerHash,
              outputBlocks,
              outputHash,
              farthestOutput = BalencedLogicFinder.findBalencedLogic(self, id)
        if layers ~= nil then
            local outputBlockTimes = {}
            for i = 1, #outputBlocks do
                local outputId = outputBlocks[i]
                -- prob dont need, still we have it
                if layerHash[outputId] == 1 then
                    print("cant have input block be output")
                    goto notBalanced
                end
                outputBlockTimes[i] = layerHash[outputId] + 1
            end
            local multiBlockId = self:internalAddMultiBlock(5)
            local inputs = layers[1]
            local inputData = 0
            local inputsIndexPow2 = {}
            for i = 1, #inputs do
                local intputId = inputs[i]
                self:internalAddBlockToMultiBlock(intputId, multiBlockId, true, false)
                local pow = math.pow(2, i-1)
                inputsIndexPow2[intputId] = pow
                if blockStates[intputId] then
                    inputData = inputData + pow
                end
            end
            for i = 2, #layers do
                local layer = layers[i]
                for j = 1, #layer do
                    local blockId = layer[j]
                    if outputHash[blockId] == nil then
                        self:internalAddBlockToMultiBlock(blockId, multiBlockId, false, false)
                    else
                        self:internalAddBlockToMultiBlock(blockId, multiBlockId, false, true)
                    end
                end
            end
            local length = layerHash[farthestOutput] + 1
            self.multiBlockData[multiBlockId][6] = length
            self.multiBlockData[multiBlockId][7] = {}
            self.multiBlockData[multiBlockId][8] = farthestOutput
            self.multiBlockData[multiBlockId][9] = outputBlockTimes
            self.multiBlockData[multiBlockId][10] = inputData
            self.multiBlockData[multiBlockId][11] = inputsIndexPow2
            self:updateLongestTimeToLength(length)
        end
    end
    ::notBalanced::
end
