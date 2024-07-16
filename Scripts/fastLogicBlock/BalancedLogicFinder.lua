dofile "../util/util.lua"
local string = string
local table = table
local type = type
local pairs = pairs

function FastLogicRunner.findBalencedLogic(self, id)
    local outputs = self.blockOutputs[id]
    for i = 1, #outputs do
        if outputs[i] == id then
            return {}
        end
    end
    local layers = {{id}}
    local layerHash = {[id] = 1}
    local blocksToScan = {id}
    local blockSources = {[id]={}}
    local layerIndexLimit = {1}
    local i = 1
    while true do
        if #blocksToScan == 0 then break end
        self:BL_scanBlock(
            table.remove(blocksToScan, 1),
            layers, layerHash,
            blocksToScan,
            layerIndexLimit,
            blockSources
        )
        if i >= 100000 then
            print("findBalencedLogic ran to long. Exiting")
            return {}
        end
        i = i + 1
    end
    for i = 1, layerIndexLimit[1] do
        if layers[i] == nil then
            layers[i] = {}
        end
    end
    return layers
end

function FastLogicRunner.BL_scanBlock(self, id, layers, layerHash, blocksToScan, layerIndexLimits, blockSources)
    print("scan: " .. tostring(id))
    -- get layer index
    local layerIndex = layerHash[id]
    if layerIndex == nil then return end
    -- find outputs
    local outputsToAdd = {}
    local outputs =  self.blockOutputs[id]
    for i = 1, #outputs do
        local outputId = outputs[i]
        -- it does not connect to it self
        local outputId2 
        local outputs2 = self.blockOutputs[outputId]
        for i2 = 1, #outputs2 do
            outputId2 = outputs2[i2]
            if outputId2 == outputId then
                break
            end
        end
        if outputId2 ~= outputId then
            if layerHash[outputId] == nil then
                -- add block
                outputsToAdd[#outputsToAdd+1] = outputId
            else
                -- check for bad output
                local outputLayerIndex = layerHash[outputId]
                if outputLayerIndex ~= 1 then
                    local wantedOutputLayerIndex = layerIndex + self:BL_getBlockTime(id)
                    -- 
                    if outputLayerIndex == 1 then
                        outputsToAdd = {}
                        break
                    elseif wantedOutputLayerIndex ~= outputLayerIndex then
                        if wantedOutputLayerIndex > outputLayerIndex then
                            if blockSources[id][outputId] == nil then
                                print({layerIndex, outputLayerIndex, id, outputId})
                                print("a1")
                                self:BL_deleteBlockAndOutputs(outputId, layers, layerHash, blocksToScan, blockSources)
                                if layerHash[id] == nil then return end
                            else
                                print({layerIndex, outputLayerIndex, id, outputId})
                                print("b1")
                                self:BL_deleteBlockAndInputs(id, layers, layerHash, blocksToScan, blockSources, outputLayerIndex)
                                return
                            end

                        elseif wantedOutputLayerIndex < outputLayerIndex then
                            print({layerIndex, outputLayerIndex, id, outputId})
                            print("here")
                        end
                    end
                end
            end
        end
    end
    -- find inputs
    if layerIndex ~= 1 then
        local inputsToAdd = {}
        local inputs = self.blockInputs[id]
        for i = 1, #inputs do
            local inputsId = inputs[i]
            -- it does not connect to it self
            local inputsId2
            local inputs2 = self.blockInputs[inputsId]
            for i2 = 1, #inputs2 do
                inputsId2 = inputs2[i2]
                if inputsId2 == inputsId then
                    break
                end
            end
            if inputsId2 ~= inputsId then
                if layerHash[inputsId] == nil then
                    -- add block
                    inputsToAdd[#inputsToAdd+1] = inputsId
                else
                    -- check for bad input
                    local intputLayerIndex = layerHash[inputsId]
                    local wantedIntputLayerIndex = layerIndex - self:BL_getBlockTime(inputsId)
                    -- print({layerIndex, intputLayerIndex})
                    if intputLayerIndex == 0 then
                        inputsToAdd = {}
                        break
                    elseif wantedIntputLayerIndex ~= intputLayerIndex then
                        if wantedIntputLayerIndex > intputLayerIndex then
                            if blockSources[id][inputsId] == nil then
                                print({layerIndex, intputLayerIndex, id, inputsId})
                                print("a")
                                -- print(id)
                                -- print(inputsId)
                                -- print(blockSources)
                                self:BL_deleteBlockAndOutputs(id, layers, layerHash, blocksToScan, blockSources)
                                return
                            else
                                print({layerIndex, intputLayerIndex, id, inputsId})
                                print("b")
                                self:BL_deleteBlockAndOutputs(id, layers, layerHash, blocksToScan, blockSources)
                                return
                            end
                        elseif wantedIntputLayerIndex < intputLayerIndex then
                            print({layerIndex, intputLayerIndex, id, inputsId})
                            print("c")
                            self:BL_deleteBlockAndOutputs(id, layers, layerHash, blocksToScan, blockSources)
                            return
                        end
                    end
                end
            end
        end
        -- add inputs
        for i = 1, #inputsToAdd do
            local inputsId = inputsToAdd[i]
            local index = layerIndex - self:BL_getBlockTime(inputsId)
            if index >= 1 then
                print("added in: " .. tostring(inputsId))
                local layer = layers[index]
                if layer == nil then
                    layers[index] = {inputsId}
                    if layerIndexLimits[1] < index then
                        layerIndexLimits[1] = index
                    end
                else
                    layer[#layer+1] = inputsId
                end
                layerHash[inputsId] = index
                blocksToScan[#blocksToScan+1] = inputsId
                if blockSources[id] == nil then
                    print(id)
                    print(outputId)
                    print(blockSources[id])
                    print("BAD_BAD_BAD_BAD_BAD_BAD_BAD_BAD_BAD")
                end
                local sources = table.copy(blockSources[id])
                sources[id] = true
                blockSources[inputsId] = sources
            end
        end
    end
    -- add outputs
    for i = 1, #outputsToAdd do
        local outputId = outputsToAdd[i]
        print("added out: " .. tostring(outputId))
        local index = layerIndex + self:BL_getBlockTime(id)
        local layer = layers[index]
        if layer == nil then
            layers[index] = {outputId}
            if layerIndexLimits[1] < index then
                layerIndexLimits[1] = index
            end
        else
            layer[#layer+1] = outputId
        end
        layerHash[outputId] = index
        blocksToScan[#blocksToScan+1] = outputId
        if blockSources[id] == nil then
            print(id)
            print(outputId)
            print(blockSources[id])
            print("BAD_BAD_BAD_BAD_BAD_BAD_BAD_BAD_BAD")
        end
        local sources = table.copy(blockSources[id])
        sources[id] = true
        blockSources[outputId] = sources
    end
    
end

function FastLogicRunner.BL_deleteBlockAndInputs(self, id, layers, layerHash, blocksToScan, blockSources, count)
    -- remove block
    local layerIndex = layerHash[id]
    print("remove in: " .. tostring(id) .. " Count: " .. tostring(count))
    if layerIndex == 1 then return end
    layerHash[id] = nil
    table.removeValue(layers[layerIndex], id)
    table.removeValue(blocksToScan, id)
    blockSources[id] = nil
    -- check to remove inputs
    if count ~= nil then
        count = count - self:BL_getBlockTime(id)
        if count <= 1 then return end
    end
    -- remove inputs (need this for blocksToScan)
    local outputs = self.blockOutputs[id]
    for i = 1, #outputs do
        table.removeValue(blocksToScan, outputs[i])
    end
    -- remove inputs
    local inputs = self.blockInputs[id]
    for i = 1, #inputs do
        local inputId = inputs[i]
        table.removeValue(blocksToScan, inputId)
        if layerHash[inputId] ~= nil then
            self:BL_deleteBlockAndInputs(inputId, layers, layerHash, blocksToScan, blockSources, count)
        end
    end
end

function FastLogicRunner.BL_deleteBlockAndOutputs(self, id, layers, layerHash, blocksToScan, blockSources, count)
    -- remove block
    local layerIndex = layerHash[id]
    if layerIndex == 1 then return end
    print("remove out: " .. tostring(id) .. " Count: " .. tostring(count))
    layerHash[id] = nil
    table.removeValue(layers[layerIndex], id)
    table.removeValue(blocksToScan, id)
    blockSources[id] = nil
    -- check to remove inputs
    if count ~= nil then
        count = count - self:BL_getBlockTime(id)
        if count <= 1 then return end
    end
    -- remove outputs (need this for blocksToScan)
    local inputs = self.blockInputs[id]
    for i = 1, #inputs do
        table.removeValue(blocksToScan, inputs[i])
    end
    -- remove inputs
    local outputs = self.blockOutputs[id]
    for i = 1, #outputs do
        local outputId = outputs[i]
        table.removeValue(blocksToScan, outputId)
        if layerHash[outputId] ~= nil then
            self:BL_deleteBlockAndOutputs(outputId, layers, layerHash, blocksToScan, blockSources, count)
        end
    end
end

function FastLogicRunner.BL_getBlockTime(self, id)
    if self.runnableBlockPathIds[id] == 5 then
        return self.timerLengths[id]
    end
    return 1
end
