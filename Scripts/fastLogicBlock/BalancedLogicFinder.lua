dofile "../util/util.lua"

function FastLogicRunner.FindBalencedLogic(self)
    for id, block in ipairs(self.data) do
        local layerIndex = 1
        local layers = { { id } }
        local blockLayerLookup = {[id] = 1}
        while self:GetParentLayer(layers, blockLayerLookup, layerIndex) do
            layerIndex = layerIndex + 1
        end
        layerIndex = layerIndex - 1
    end
end

function FastLogicRunner.BalencedLogicChecker()
    
end

function FastLogicRunner.GetParentLayer(self, layers, blockLayerLookup, layerIndex)
    local layer = layers[layerIndex]
    if layers[layerIndex + 1] == nil then
        layers[layerIndex + 1] = {}
    end
    local parentLayer = layers[layerIndex + 1]
    local callGetChild = false
    for i = 1, #layer do
        local inputs = self.data[layer[i]].inputs
        for j = 1, #inputs do
            local input = inputs[j]
            if blockLayerLookup[input] == nil then
                parentLayer[#parentLayer + 1] = input
                blockLayerLookup[input] = layerIndex + 1
                callGetChild = true
            elseif blockLayerLookup[input] ~= layerIndex + 1 then
                return false
            end
        end
    end
    if callGetChild then
        self:GetChildLayer(layers, blockLayerLookup, layerIndex + 1)
    end
    return true
end

function FastLogicRunner.GetChildLayer(self, layers, blockLayerLookup, layerIndex)
    if layerIndex <= 1 then return end
    local layer = layers[layerIndex]
    local childLayer = layers[layerIndex - 1]
    local callRec = false
    for i = 1, #layer do
        local outputs = self.data[layer[i]].outputs
        for j = 1, #outputs do
            local output = outputs[j]
            if blockLayerLookup[output] == nil then
                childLayer[#childLayer + 1] = output
                blockLayerLookup[output] = layerIndex - 1
                callRec = true
            elseif blockLayerLookup[output] ~= layerIndex - 1 then
                return false
            end
        end
    end
    if (callRec) then
        self:GetChildLayer(layers, blockLayerLookup, layerIndex - 1)
        self:GetParentLayer(layers, blockLayerLookup, layerIndex - 1)
    end
end
