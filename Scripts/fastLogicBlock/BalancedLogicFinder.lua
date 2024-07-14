dofile "../util/util.lua"
local string = string
local table = table
local type = type
local pairs = pairs

function FastLogicRunner.findBalencedLogic(self, id)
    local layers = {{id}}
    local layerHash = {[id] = 1}
    local blocksToScan = {id}
    local i = 1
    while #blocksToScan >= i do
        self:scanBlock(blocksToScan[i], layers, layerHash, blocksToScan)
        i = i + 1
    end
    local shiftNeeded = 0
    for k, v in pairs(layers) do
        if #v == 0 then
            layers[k] = nil
        else
            if shiftNeeded < 1-k then
                shiftNeeded = 1-k
            end
        end
    end
    local layersShifted = {}
    if shiftNeeded == 0 then
        layersShifted = layers
    else
        for i = 1, table.length(layers) do
            layersShifted[i] = layers[i - shiftNeeded]
        end
    end
    return layersShifted
end

function FastLogicRunner.scanBlock(self, id, layers, layerHash, blocksToScan)
    -- get layer indexs
    local layerIndex = layerHash[id]
    local inputLayerIndex = layerIndex - 1
    local outputLayerIndex = layerIndex + 1
    -- add layers
    local inputLayer = layers[inputLayerIndex]
    if inputLayer == nil then
        inputLayer = {}
        layers[inputLayerIndex] = inputLayer
    end
    local outputLayer = layers[outputLayerIndex]
    if outputLayer == nil then
        outputLayer = {}
        layers[outputLayerIndex] = outputLayer
    end
    -- makeSure it does not connect to its self
    local inputs =  self.blockInputs[id]
    for i = 1, #inputs do
        local inputId = inputs[i]
        if inputId == id then
            table.removeValue(layers[layerIndex], id)
            layerHash[id] = nil
            return false
        end
    end
    -- findInputs
    for i = 1, #inputs do
        local inputId = inputs[i]
        if layerHash[inputId] == nil then
            layerHash[inputId] = inputLayerIndex
            inputLayer[#inputLayer+1] = inputId
            blocksToScan[#blocksToScan+1] = inputId
        end
    end
    -- findOutputs
    local outputs =  self.blockOutputs[id]
    for i = 1, #outputs do
        local outputId = outputs[i]
        if layerHash[outputId] == nil then
            layerHash[outputId] = outputLayerIndex
            outputLayer[#outputLayer+1] = outputId
            blocksToScan[#blocksToScan+1] = outputId
        end
    end
    return true
end
