dofile "../util/util.lua"
local string = string
local table = table
local type = type
local pairs = pairs

function FastLogicRunner.findBalencedLogic(self, id)
    local layers = {{id}}
    local layerHash = {[id] = 1}
    local blocksToScan = {{id}}
    local layerIndexLimits = {1, 1}
    local blocksNotWanted = {}
    local i = 1
    local minLayerIndex = nil
    while true do
        local idToScan = nil
        for k = layerIndexLimits[1], layerIndexLimits[2] do
            if blocksToScan[k] ~= nil and #blocksToScan[k] > 0 then
                idToScan = blocksToScan[k][1]
                table.remove(blocksToScan[k], 1)
                break
            end
        end
        if idToScan == nil then break end
        local newMinLayerIndex = self:BL_scanBlock(idToScan, layers, layerHash, blocksToScan, blocksNotWanted, layerIndexLimits, minLayerIndex)
        if newMinLayerIndex ~= nil then
            minLayerIndex = newMinLayerIndex
            for k, v in pairs(layers) do
                if k < minLayerIndex then
                    for j = 1, #v do
                        layerHash[v[j]] = nil
                    end
                    layers[k] = nil
                end
            end
        end
        if i >= 1000000 then
            print("findBalencedLogic ran to long. Exiting")
            return {}
        end
        i = i + 1
    end
end
--     local shiftNeeded = 0
--     local maxLayer = 0
--     for k, v in pairs(layers) do
--         if #v == 0 then
--             layers[k] = nil
--         else
--             if shiftNeeded < 1-k then
--                 shiftNeeded = 1-k
--             end
--             if maxLayer < k then
--                 maxLayer = k
--             end
--         end
--     end
--     local layersShifted = {}
--     for i = 1, maxLayer + shiftNeeded do
--         if layers[i - shiftNeeded] == nil then
--             layersShifted[i] = {}
--         else
--             layersShifted[i] = layers[i - shiftNeeded]
--         end
--     end
--     return layersShifted
-- end

-- function FastLogicRunner.BL_scanBlock(self, id, layers, layerHash, blocksToScan, blocksNotWanted, layerIndexLimits, minLayerIndex)
--     print("scan: " .. tostring(id))
--     -- get layer index
--     local layerIndex = layerHash[id]
--     if layerIndex == nil then return end
--     if minLayerIndex ~= nil and minLayerIndex > layerIndex then
--         return
--     end
--     -- if you dont want to have this block
--     if blocksNotWanted[id] ~= nil then
--         table.removeValue(layers[layerIndex], id)
--         layerHash[id] = nil
--         return
--     end
--     local inputs =  self.blockInputs[id]
--     local dontDoDeletes = false
--     for i = 1, #inputs do
--         local inputId = inputs[i]
--         local inputLayerIndex = layerHash[inputId]
--         if inputLayerIndex ~= nil and inputLayerIndex == layerIndex - self:BL_getBlockTime(inputId) then
--             dontDoDeletes = true
--         end
--     end
--     for i = 1, #inputs do
--         local inputId = inputs[i]
--         local inputLayerIndex = layerHash[inputId]
--         if inputLayerIndex ~= nil then
--             -- it does not connect to it self
--             if inputId == id then
--                 blocksNotWanted[id] = true
--                 table.removeValue(layers[layerIndex], id)
--                 layerHash[id] = nil
--                 return
--             elseif dontDoDeletes and inputLayerIndex ~= layerIndex - self:BL_getBlockTime(inputId) then
--                 self:BL_deleteBlockAndOutputs(id, layers, layerHash, blocksToScan, blocksNotWanted)
--                 blocksToScan[inputLayerIndex][#blocksToScan[inputLayerIndex]+1] = inputId
--                 return
--             end
--         end
--     end
--     local outputs = self.blockOutputs[id]
--     -- for i = 1, #outputs do
--     --     local outputId = outputs[i]
--     --     local outputLayerIndex = layerHash[outputId]
--     --     if outputLayerIndex ~= nil then
--     --         if outputLayerIndex ~= layerIndex + self:BL_getBlockTime(id) then
--     --             self:BL_deleteBlockAndOutputs(id, layers, layerHash, blocksToScan, blocksNotWanted)
--     --             blocksToScan[outputLayerIndex][#blocksToScan[outputLayerIndex]+1] = outputId
--     --             return
--     --         end
--     --     end
--     -- end
--     -- find Inputs
--     local inputCount = 0
--     for i = 1, #inputs do
--         local inputId = inputs[i]
--         if blocksNotWanted[inputId] == nil then
--             if layerHash[inputId] == nil then
--                 -- it does not connect to it self
--                 local inputId2
--                 local inputs2 =  self.blockInputs[inputId]
--                 for i2 = 1, #inputs2 do
--                     inputId2 = inputs2[i2]
--                     if inputId2 == inputId then
--                         break
--                     end
--                 end
--                 if inputId2 ~= inputId then
--                     local index = layerIndex - self:BL_getBlockTime(inputId)
--                     if minLayerIndex == nil or index >= minLayerIndex then
--                         print("added input: " .. tostring(inputId))
--                         inputCount = inputCount + 1
--                         -- add block
--                         local layer = layers[index]
--                         if layer == nil then
--                             layers[index] = {inputId}
--                         else
--                             layer[#layer+1] = inputId
--                         end
--                         layerHash[inputId] = index
--                         if blocksToScan[index] == nil then
--                             blocksToScan[index] = {inputId}
--                             if layerIndexLimits[2] < index then
--                                 layerIndexLimits[2] = index
--                             elseif layerIndexLimits[1] > index then
--                                 layerIndexLimits[1] = index
--                             end
--                         else
--                             blocksToScan[index][#blocksToScan[index]+1] = inputId
--                         end
--                     end
--                 end
--             else
--                 inputCount = inputCount + 1
--             end
--         end
--     end
--     -- find Outputs
--     for i = 1, #outputs do
--         local outputId = outputs[i]
--         if layerHash[outputId] == nil and blocksNotWanted[outputId] == nil then
--             -- it does not connect to it self
--             local outputId2
--             local outputs2 =  self.blockOutputs[outputId]
--             for i2 = 1, #outputs2 do
--                 outputId2 = outputs2[i2]
--                 if outputId2 == outputId then
--                     break
--                 end
--             end
--             if outputId2 ~= outputId then
--                 local index = layerIndex + self:BL_getBlockTime(id)
--                 if minLayerIndex == nil or index >= minLayerIndex then
--                     print("added output: " .. tostring(outputId))
--                     -- add block
--                     local layer = layers[index]
--                     if layer == nil then
--                         layers[index] = {outputId}
--                     else
--                         layer[#layer+1] = outputId
--                     end
--                     layerHash[outputId] = index
--                     if blocksToScan[index] == nil then
--                         blocksToScan[index] = {outputId}
--                         if layerIndexLimits[2] < index then
--                             layerIndexLimits[2] = index
--                         elseif layerIndexLimits[1] > index then
--                             layerIndexLimits[1] = index
--                         end
--                     else
--                         blocksToScan[index][#blocksToScan[index]+1] = outputId
--                     end
--                 end
--             end
--         end
--     end
--     if inputCount == 0 then
--         return layerIndex
--     end
-- end

-- function FastLogicRunner.BL_deleteBlockAndOutputs(self, id, layers, layerHash, blocksToScan, blocksNotWanted)
--     print("remove: " .. tostring(id))
--     local layerIndex = layerHash[id]
--     layerHash[id] = nil
--     table.removeValue(layers[layerIndex], id)
--     table.removeValue(blocksToScan[layerIndex], id)
--     local outputCount = 0
--     local outputs = self.blockOutputs[id]
--     for i = 1, #outputs do
--         local outputId = outputs[i]
--         local outputLayerIndex = layerHash[outputId]
--         if outputLayerIndex ~= nil then
--             outputCount = outputCount + 1
--             if outputLayerIndex > layerIndex then
--                 self:BL_deleteBlockAndOutputs(outputId, layers, layerHash, blocksToScan, blocksNotWanted)
--             end
--         end
--     end
--     if outputCount == 0 then
--         print("nooo")
--         blocksNotWanted[id] = true
--     end
-- end

-- function FastLogicRunner.BL_getBlockTime(self, id)
--     if self.runnableBlockPathIds[id] == 5 then
--         return self.timerLengths[id]
--     end
--     return 1
-- end
