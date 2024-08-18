dofile "../util/util.lua"
local string = string
local table = table
local type = type
local pairs = pairs
local sm = sm

local layers
local layerHash
local outputBlocks
local outputHash
local farthestOutput
local lowestLayer
local highestLayer
local inputLayerLimitHash
local FLR

local BalencedLogicFinder = {}

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.BalencedLogicFinder = BalencedLogicFinder

function BalencedLogicFinder.findBalencedLogic(FastLogicRunner, id)
    layers = {}
    layerHash = {}
    outputBlocks = {}
    outputHash = {}
    farthestOutput = {}
    lowestLayer = 0
    highestLayer = 0
    inputLayerLimitHash = {}
    FLR = FastLogicRunner

    BalencedLogicFinder.addIdToLayer(id, 0)

    BalencedLogicFinder.findLayers()

    local newLayers = {}
    local newLayerHash = {}
    for i = lowestLayer, highestLayer do
        local layer = layers[i]
        local newIndex = i-lowestLayer+1
        if layer == nil then
            newLayers[newIndex] = {}
        else
            newLayers[newIndex] = layer
            for j = 1, #layer do
                newLayerHash[layer[j]] = newIndex
            end
        end
    end
    print("limit", inputLayerLimitHash)
    return newLayers, newLayerHash, outputBlocks, outputHash, farthestOutput
end

function BalencedLogicFinder.findLayers()
    local steps = 0
    local other0 = false
    local i = 0
    ::inputs::
    steps = steps + 1
    if steps == 10000 then goto stop end
    if BalencedLogicFinder.addLayerInputs(i) == 0 then
        if i <= lowestLayer then
            i = lowestLayer
            if other0 then
                goto stop
            end
            other0 = true
            goto outputs
        end
        i = i - 1
        goto inputs
    else
        if i < lowestLayer then
            i = lowestLayer
            other0 = false
            goto outputs
        end
        other0 = false
        i = i - 1
        goto inputs
    end
    ::outputs::
    steps = steps + 1
    if steps == 10000 then goto stop end
    if BalencedLogicFinder.addLayerOutputs(i) == 0 then
        if i >= highestLayer then
            if other0 then
                goto stop
            end
            other0 = true
            goto inputs
        end
        i = i + 1
        goto outputs
    else
        other0 = false
        i = i + 1
        goto outputs
    end
    ::stop::
    print(table.length(layerHash))
    print("steps =", steps, ":", i, highestLayer, lowestLayer)
end

function BalencedLogicFinder.addLayerInputs(layerIndex)
    print("add in", layerIndex)
    local count = 0
    local layer = layers[layerIndex]
    if layer == nil then return end
    local i = 1
    while i <= #layer do
        local inputs = FLR.blockInputs[layer[i]]
        for j = 1, #inputs do
            local id = inputs[j]
            local inputLayer = layerIndex - BalencedLogicFinder.BL_getoutputLayer(id)
            local idLayerHash = layerHash[id]
            if idLayerHash == nil then
                if inputLayerLimit == nil or inputLayer > inputLayerLimit then
                    count = count + 1
                    layerHash[id] = inputLayer
                    if layers[inputLayer] == nil then
                        layers[inputLayer] = {}
                        if lowestLayer > inputLayer then
                            lowestLayer = inputLayer
                        end
                    end
                    layers[inputLayer][#layers[inputLayer]+1] = id
                end
            elseif idLayerHash ~= false and idLayerHash ~= inputLayer then
                if inputLayer < 0 and inputLayer > idLayerHash then
                    print("bad layer1", id, inputLayer, idLayerHash)
                    BalencedLogicFinder.setInputLayerLimit(inputLayer)
                elseif idLayerHash < 0 then
                    print("bad layer2", id, inputLayer, idLayerHash)
                    BalencedLogicFinder.setInputLayerLimit(idLayerHash)
                end
            end
        end
        i = i + 1
    end
    return count
end

function BalencedLogicFinder.addLayerOutputs(layerIndex)
    print("add out", layerIndex)
    local count = 0
    local layer = layers[layerIndex]
    if layer == nil then return 0 end
    local blocksToRemove = {}
    for i = 1, #layer do
        local outputs = FLR.blockOutputs[layer[i]]
        local outputLayer = layerIndex + BalencedLogicFinder.BL_getoutputLayer(layer[i])
        for j = 1, #outputs do
            local id = outputs[j]
            -- local inputs = FLR.blockInputs[id]
            local idLayerHash = layerHash[id]
            -- for k = 1, #inputs do
            --     local inputId = inputs[k]
            --     if (
            --         layerHash[inputId] ~= lowestLayer and
            --         (layerHash[inputId] == false or layerHash[inputId] ~= layerIndex)
            --     ) then
            --         if idLayerHash ~= nil then
            --             blocksToRemove[#blocksToRemove+1] = id
            --         end
            --         goto dontAddBlock
            --     end
            -- end
            if idLayerHash == nil then
                count = count + 1
                layerHash[id] = outputLayer
                if layers[outputLayer] == nil then
                    layers[outputLayer] = {}
                    if highestLayer < outputLayer then
                        highestLayer = outputLayer
                    end
                end
                layers[outputLayer][#layers[outputLayer]+1] = id
            elseif idLayerHash ~= false and idLayerHash ~= outputLayer and idLayerHash ~= lowestLayer then
                blocksToRemove[#blocksToRemove+1] = layer[i]
                break
            end
            ::dontAddBlock::
        end
    end
    for i = 1, #blocksToRemove do
        BalencedLogicFinder.removeBlockAndOutputsRec(blocksToRemove[i])
    end
    return count
end

function BalencedLogicFinder.addIdToLayer(id, layerIndex)
    if inputLayerLimit ~= nil and layerIndex <= inputLayerLimit then return end
    layerHash[id] = layerIndex
    if layers[layerIndex] == nil then
        layers[layerIndex] = {id}
        if highestLayer < layerIndex then
            highestLayer = layerIndex
        elseif lowestLayer > layerIndex then
            lowestLayer = layerIndex
        end
    else
        layers[layerIndex][#layers[layerIndex]+1] = id
    end
end

function BalencedLogicFinder.removeId(id)
    local idLayerHash = layerHash[id]
    if idLayerHash == false then return end
    layerHash[id] = false
    if #layers[idLayerHash] == 1 then
        layers[idLayerHash] = nil
        if lowestLayer == idLayerHash then
            for k = lowestLayer + 1, highestLayer, 1 do
                if layers[k] ~= nil then
                    lowestLayer = k
                    return
                end
            end
        elseif highestLayer == idLayerHash then
            for k = highestLayer - 1, lowestLayer, -1 do
                if layers[k] ~= nil then
                    highestLayer = k
                    return
                end
            end
        end
    else
        for k = 1, #layers[idLayerHash] do
            if layers[idLayerHash][k] == id then
                table.remove(layers[idLayerHash], k)
                return
            end
        end
    end
end

function BalencedLogicFinder.setInputLayerLimit(layerIndex)
    -- local count = 0
    -- if inputLayerLimit == nil or layerIndex > inputLayerLimit then
    --     inputLayerLimit = layerIndex
    -- end
    -- while lowestLayer <= inputLayerLimit do
    --     local layer = layers[lowestLayer]w 
    --     if layer ~= nil then
    --         for i = 1, #layer do
    --             layerHash[layer[i]] = false
    --             count = count + 1
    --         end
    --         layers[lowestLayer] = nil
    --     end
    --     lowestLayer = lowestLayer + 1
    -- end
end

function BalencedLogicFinder.removeBlockAndOutputsRec(id)
    local count = 0
    if layerHash[id] == false then return end
    local idsToDo = {{id, layerHash[id]}}
    BalencedLogicFinder.removeId(id)
    local i = 1
    while i <= #idsToDo do
        local outputs = FLR.blockOutputs[idsToDo[i][1]]
        local layerIndex = idsToDo[i][2]
        for k = 1, #outputs do
            local outputId = outputs[k]
            if layerHash[outputId] ~= nil and layerHash[outputId] ~= false and layerHash[outputId] >= layerIndex then
                idsToDo[#idsToDo+1] = {outputId, layerHash[outputId]}
                BalencedLogicFinder.removeId(outputId)
                count = count + 1
            end
        end
        i = i + 1
    end
    print("removeBlockAndOutputsRec", count)
end

function BalencedLogicFinder.BL_getoutputLayer(id)
    if FLR.runnableBlockPathIds[id] == 5 then
        return FLR.timerLengths[id]
    end
    return 1
end
