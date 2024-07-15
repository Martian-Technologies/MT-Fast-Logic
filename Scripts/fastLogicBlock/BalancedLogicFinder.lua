dofile "../util/util.lua"
local string = string
local table = table
local type = type
local pairs = pairs

function FastLogicRunner.findBalencedLogic(self, id)
    local layers = {{id}}
    local layerHash = {[id] = 1}
    local blocksToScan = {id}
    local blocksNotWanted = {}
    local i = 1
    while #blocksToScan >= i do
        self:BL_scanBlock(blocksToScan[i], layers, layerHash, blocksToScan, blocksNotWanted)
        if i >= 100000 then
            print("findBalencedLogic ran to long. Exiting")
            -- print(blocksToScan)
            print(layers)
            print(layerHash)
            print(blocksNotWanted)
            return {}
        end
        i = i + 1
    end
    local shiftNeeded = 0
    local maxLayer = 0
    for k, v in pairs(layers) do
        if #v == 0 then
            layers[k] = nil
        else
            if shiftNeeded < 1-k then
                shiftNeeded = 1-k
            end
            if maxLayer < k then
                maxLayer = k
            end
        end
    end
    local layersShifted = {}
    for i = 1, maxLayer + shiftNeeded do
        if layers[i - shiftNeeded] == nil then
            layersShifted[i] = {}
        else
            layersShifted[i] = layers[i - shiftNeeded]
        end
    end
    return layersShifted
end

function FastLogicRunner.BL_scanBlock(self, id, layers, layerHash, blocksToScan, blocksNotWanted)
    -- get layer indexs
    local layerIndex = layerHash[id]
    if layerIndex == nil then return false end
    -- if you dont want to scan this block
    if blocksNotWanted[id] ~= nil then
        table.removeValue(layers[layerIndex], id)
        layerHash[id] = nil
        return false
    end
    local inputs =  self.blockInputs[id]
    for i = 1, #inputs do
        local inputId = inputs[i]
        -- it does not connect to it self
        if inputId == id then
            blocksNotWanted[id] = true
            table.removeValue(layers[layerIndex], id)
            layerHash[id] = nil
            return true
        end
        -- -- it does not have a input going to a current layer that is not correct
        -- if layerHash[inputId] ~= nil then
        --     local layer = layerIndex - self:BL_getBlockTime(inputId)
        --     if layerHash[inputId] ~= layerIndex or blocksNotWanted[inputId] ~= nil then
        --         blocksToScan[#blocksToScan+1] = inputId
        --         self:BL_removeBlock(id, layers, layerHash, blocksToScan, blocksNotWanted, inputId)
        --         return true
        --     end
        -- end
    end
    -- find Inputs
    for i = 1, #inputs do
        local inputId = inputs[i]
        if layerHash[inputId] == nil and blocksNotWanted[inputId] == nil then
            local index = layerIndex - self:BL_getBlockTime(inputId)
            local layer = layers[index]
            if layer == nil then
                layers[index] = {inputId}
            else
                layer[#layer+1] = inputId
            end
            layerHash[inputId] = index
            blocksToScan[#blocksToScan+1] = inputId
        end
    end
    -- find Outputs
    local outputs =  self.blockOutputs[id]
    for i = 1, #outputs do
        local outputId = outputs[i]
        if layerHash[outputId] == nil and blocksNotWanted[outputId] == nil then
            local index = layerIndex + self:BL_getBlockTime(inputId)
            local layer = layers[index]
            if layer == nil then
                layers[index] = {outputId}
            else
                layer[#layer+1] = outputId
            end
            layerHash[outputId] = index
            blocksToScan[#blocksToScan+1] = outputId
        end
    end
    return false
end

function FastLogicRunner.BL_removeBlock(self, id, layers, layerHash, blocksToScan, blocksNotWanted, conflictId)
    -- if conflictId == id then
    --     return false
    -- end
    -- -- get layer index
    -- local layerIndex = layerHash[id]
    -- -- remove id
    -- table.removeValue(layers[layerIndex], id)
    -- layerHash[id] = nil
    -- -- get output layer index
    -- local outputLayerIndex = layerIndex + self:BL_getBlockTime(id)
    -- -- if the outputLayer is empty then we know that this block can not be part of this balenced circuit
    -- local outputLayer = layers[outputLayerIndex]
    -- if outputLayer == nil or #outputLayer == 0 then
    --     blocksNotWanted[id] = true
    --     return true
    -- end
    -- -- findOutputs
    -- local outputs = self.blockOutputs[id]
    -- for i = 1, #outputs do
    --     local outputId = outputs[i]
    --     if layerHash[outputId] ~= nil then
    --         if not self:BL_removeBlock(outputId, layers, layerHash, blocksToScan, blocksNotWanted, conflictId) then
    --             blocksNotWanted[id] = true
    --         end
    --     end
    -- end
    -- return true
end

function FastLogicRunner.BL_getBlockTime(self, id)
    if self.runnableBlockPathIds[id] == 5 then
        return self.timerLengths[id] - 1
    end
    return 1
end