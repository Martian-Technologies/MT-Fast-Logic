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
local lowestLayer
local highestLayer
local lowerLimit
local FLR

local maxInputLayerSize = 28

sm.MTFastLogic = sm.MTFastLogic or {}

local BalencedLogicFinder = sm.MTFastLogic.BalencedLogicFinder or {}
sm.MTFastLogic.BalencedLogicFinder = BalencedLogicFinder

function BalencedLogicFinder.findBalencedLogic(FastLogicRunner, id)
    FLR = FastLogicRunner

    -- can't be timer (idk why it is not working and I don't have time to fix it)
    if FLR.runnableBlockPathIds[id] == 5 or FLR.multiBlockData[id] ~= false then
        return nil
    end

    -- cant be selfwired
    local inputs = FLR.blockInputs[id]
    for j = 1, #inputs do
        if inputs[j] == id then
            return nil
        end
    end

    lowerLimit = nil
    local lastLowerLimit = nil
    local lowerLimitSameCount = 0
    local loops = 0
    local keepGoing = true
    while keepGoing do
        layers = {}
        layerHash = {}
        outputBlocks = {}
        outputHash = {}
        lowestLayer = 0
        highestLayer = 0
        BalencedLogicFinder.stage1_findInputLayers(id, 1)
        BalencedLogicFinder.stage2_makeInputLayer()
        BalencedLogicFinder.stage3_findOutputs()
        local loops2 = 0
        local doremoveBlocksWithBadOutputsUp = true
        while doremoveBlocksWithBadOutputsUp do
            doremoveBlocksWithBadOutputsUp = BalencedLogicFinder.removeBlocksWithBadOutputsUp(id)
            BalencedLogicFinder.layersStartAtOne()
            loops2 = loops2 + 1
            if loops2 > 20 then
                print("error: inf loop2", loops2)
                return nil
            end
        end
        if layerHash[id] == nil then
            return nil
        end

        lowerLimit = 1-layerHash[id]
        if lastLowerLimit == lowerLimit and lastLowerLimit ~= nil then
            if lowerLimitSameCount > 2 then
                break
            end
            lowerLimitSameCount = lowerLimitSameCount + 1
        else
            lastLowerLimit = lowerLimit
            lowerLimitSameCount = 0
        end

        loops = loops + 1
        if loops > 20 then
            print("error: inf loop", loops)
            return nil
        end
    end

    if layers == nil then
        return nil
    end

    local connectionCount = 0
    local farthestOutput = nil
    for i = 1, #layers do
        local layer = layers[i]
        for j = 1, #layer do
            local blockId = layer[j]
            local outputs = FLR.blockOutputs[blockId]
            if #outputs > 0 then
                local outputId = outputs[1]
                if layerHash[outputId] == nil or layerHash[outputId] == 1 then
                    outputBlocks[#outputBlocks+1] = blockId
                    outputHash[blockId] = layerHash[blockId]
                    if farthestOutput == nil or layerHash[farthestOutput] < layerHash[blockId] then
                        farthestOutput = blockId
                    end
                else
                    connectionCount = connectionCount + #outputs
                end
            elseif FLR.creation.blocks[FLR.unhashedLookUp[blockId]].numberOfOtherOutputs > 0 then
                outputBlocks[#outputBlocks+1] = blockId
                outputHash[blockId] = layerHash[blockId]
                if farthestOutput == nil or layerHash[farthestOutput] < layerHash[blockId] then
                    farthestOutput = blockId
                end
            end
        end
    end

    if farthestOutput == nil then
        -- print("no output, makes caching cheep!")
        -- this could be used to remove large portions of the graph but its nit worth it prob
        return nil
    end
    
    local score = connectionCount/#layers[1] + connectionCount/#outputBlocks
    if score < 50 then
        -- print("score not good")
        return nil
    end

    print(score)

    return layers, layerHash, outputBlocks, outputHash, farthestOutput
end

function BalencedLogicFinder.stage1_findInputLayers(startId, startLayerIndex)
    local steps = 0
    local blocksToAdd = {{startId, startLayerIndex}}
    local blocksToAddIndex = 1
    local limit = #blocksToAdd -- so we dont start scanning new elements of blocksToAdd
    while blocksToAddIndex <= #blocksToAdd do
        local id = blocksToAdd[blocksToAddIndex][1]
        local idOutputLayerIndex = blocksToAdd[blocksToAddIndex][2]
        local idLayerIndex = idOutputLayerIndex - BalencedLogicFinder.getBlockTime(id)
        local idLayerHash = layerHash[id]
        if idLayerHash ~= nil then
            if (idLayerHash ~= idLayerIndex) then
                lowestLayer = idOutputLayerIndex
                BalencedLogicFinder.removeLayer(lowestLayer)
                lowerLimit = lowestLayer
                break
            end
        elseif (
            (lowerLimit ~= nil and lowerLimit > idLayerIndex) or
            FLR.multiBlockData[id] ~= false
        ) then
            lowerLimit = idOutputLayerIndex
            break
        elseif idLayerIndex ~= lowestLayer then
            -- is not time for block
            blocksToAdd[#blocksToAdd+1] = {id, idOutputLayerIndex}
        else
            local inputs = FLR.blockInputs[id]
            for j = 1, #inputs do
                if inputs[j] == id then
                    lowerLimit = idLayerIndex + 1
                    goto dontAdd
                end
            end
            -- add block
            BalencedLogicFinder.addIdToLayer(id, idLayerIndex)
            -- add inputs
            if lowerLimit == nil or lowerLimit < idLayerIndex then
                if FLR.creation.blocks[FLR.unhashedLookUp[id]].numberOfOtherOutputs == 0 then
                    -- tell it to add next layer next cycle
                    for j = 1, #inputs do
                        local inputId = inputs[j]
                        blocksToAdd[#blocksToAdd+1] = {inputId, idLayerIndex}
                    end
                else
                    lowerLimit = idLayerIndex
                end
            end
            ::dontAdd::
        end
        if blocksToAddIndex >= limit then
            lowestLayer = lowestLayer - 1
            limit = #blocksToAdd
        end
        blocksToAddIndex = blocksToAddIndex + 1
        if steps > 10000 then break end
        steps = steps + 1
    end
    if blocksToAddIndex > #blocksToAdd then
        lowerLimit = lowestLayer
    end

    -- print("stage 1: steps =", steps, ":", lowestLayer, highestLayer, lowerLimit)
end

function BalencedLogicFinder.stage2_makeInputLayer()
    -- find lowest limit
    local layer = layers[lowestLayer]
    while layer == nil or #layer == 0 do
        layers[lowestLayer] = nil
        lowestLayer = lowestLayer + 1
        layer = layers[lowestLayer]
    end
    while layer == nil or #layer > maxInputLayerSize do
        BalencedLogicFinder.removeLayer(lowestLayer)
        layers[lowestLayer] = nil
        lowestLayer = lowestLayer + 1
        layer = layers[lowestLayer]
        
    end
    lowerLimit = lowestLayer
    -- make layers start at 1
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
    layers = newLayers
    layerHash = newLayerHash
    highestLayer = highestLayer - lowestLayer
    lowestLayer = 1

    -- print("stage 2:" ,lowestLayer, highestLayer, #layers[lowestLayer])
end

function BalencedLogicFinder.stage3_findOutputs()
    local blocksToAdd = {}
    local blocksToAddHash = {}
    local inputLayerSize = #layers[1]
    -- add outputs on current gates to blocksToAdd
    for id,layerIndex in pairs(layerHash) do
        if FLR.creation.blocks[FLR.unhashedLookUp[id]].numberOfOtherOutputs == 0 then
            local outputs = FLR.blockOutputs[id]
            local outputLayerIndex = layerIndex + BalencedLogicFinder.getBlockTime(id)
            for i = 1, #outputs do
                local outputId = outputs[i]
                if (
                    FLR.numberOfOtherInputs[outputId] == 0 and
                    layerHash[outputId] == nil and
                    FLR.multiBlockData[outputId] == false
                ) then
                    local outputsOutputs = FLR.blockOutputs[outputId]
                    local outputsOutputLayerIndex = outputLayerIndex + BalencedLogicFinder.getBlockTime(outputId)
                    for k = 1, #outputsOutputs do
                        if layerHash[outputsOutputs[k]] ~= nil and layerHash[outputsOutputs[k]] ~= outputsOutputLayerIndex then
                            goto skipAdd
                        end
                    end
                    inputLayerSize = BalencedLogicFinder.checkIfShouldDoAdd(
                        outputId,
                        outputLayerIndex,
                        blocksToAdd,
                        blocksToAddHash,
                        inputLayerSize
                    )
                    ::skipAdd::
                end
            end
        end
    end
    local steps = 1
    while steps <= #blocksToAdd do
        local id = blocksToAdd[steps][1]
        local layerIndex = blocksToAdd[steps][2]
        BalencedLogicFinder.addIdToLayer(id, layerIndex)
        if FLR.creation.blocks[FLR.unhashedLookUp[id]].numberOfOtherOutputs == 0 then
            local outputs = FLR.blockOutputs[id]
            local outputLayerIndex = layerIndex + BalencedLogicFinder.getBlockTime(id)
            for i = 1, #outputs do
                local outputId = outputs[i]
                if (
                    blocksToAddHash[outputId] == nil and
                    FLR.numberOfOtherInputs[outputId] == 0 and
                    FLR.multiBlockData[outputId] == false and
                    layerHash[outputId] == nil
                ) then
                    local outputsOutputs = FLR.blockOutputs[outputId]
                    local outputsOutputLayerIndex = outputLayerIndex + BalencedLogicFinder.getBlockTime(outputId)
                    for k = 1, #outputsOutputs do
                        if layerHash[outputsOutputs[k]] ~= nil and layerHash[outputsOutputs[k]] ~= outputsOutputLayerIndex then
                            goto skipAdd
                        end
                    end
                    inputLayerSize = BalencedLogicFinder.checkIfShouldDoAdd(
                        outputId,
                        outputLayerIndex,
                        blocksToAdd,
                        blocksToAddHash,
                        inputLayerSize
                    )
                    ::skipAdd::
                end
            end
        end
        steps = steps + 1
        if steps > 10000 then
            break
        end
    end
    -- print("stage 3: steps =", steps, #layers[1])
end

function BalencedLogicFinder.checkIfShouldDoAdd(
    topId,
    topLayer,
    blocksToAdd,
    blocksToAddHash,
    inputLayerSize
)
    local blocksToScan = {{topId, topLayer}}
    local blocksToScanHash = {[topId] = true}
    local steps = 1
    local layerOneSizeIncrease = 0
    while steps <= #blocksToScan do
        local id = blocksToScan[steps][1]
        local layerIndex = blocksToScan[steps][2]
        if layerIndex > 1 then
            local inputs = FLR.blockInputs[id]
            for i = 1, #inputs do
                local inputId = inputs[i]
                if (
                    FLR.multiBlockData[inputId] ~= false or
                    blocksToAddHash[inputId] == false or
                    FLR.creation.blocks[FLR.unhashedLookUp[inputId]].numberOfOtherOutputs ~= 0
                ) then
                    goto topNotGood
                end
                for j = 1, #inputs do
                    if inputs[j] == id then
                        goto topNotGood
                    end
                end
                if (
                    blocksToScanHash[inputId] == nil and
                    blocksToAddHash[inputId] == nil
                ) then
                    local inputlayerIndex = layerIndex - BalencedLogicFinder.getBlockTime(inputId)
                    if layerHash[inputId] == nil and inputlayerIndex >= 1 then
                        blocksToScanHash[inputId] = true
                        blocksToScan[#blocksToScan+1] = {inputId, inputlayerIndex}
                    elseif layerHash[inputId] ~= inputlayerIndex then
                        goto topNotGood
                    end
                end
            end
        else
            layerOneSizeIncrease = layerOneSizeIncrease + 1
        end
        steps = steps + 1
    end
    if inputLayerSize + layerOneSizeIncrease <= maxInputLayerSize then
        -- if the input size is fine then add all those blocks
        for i = 1, #blocksToScan do
            blocksToAdd[#blocksToAdd+1] = blocksToScan[i]
            blocksToAddHash[blocksToScan[i][1]] = true
        end
        return inputLayerSize + layerOneSizeIncrease
    end
    -- if the input size is not fine then tell the top block it can not be added
    ::topNotGood::
    blocksToAddHash[topId] = false
    return inputLayerSize
end

function BalencedLogicFinder.addIdToLayer(id, layerIndex)
    if layerHash[id] ~= nil then return end
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

function BalencedLogicFinder.removeLayer(layerIndex)
    local layer = layers[layerIndex]
    if layer == nil then return end
    for i = 1, #layer do
        layerHash[layer[i]] = nil
    end
    layers[layerIndex] = nil
    if layerIndex == lowestLayer then
        for k = lowestLayer + 1, highestLayer, 1 do
            if layers[k] ~= nil then
                if #layers[k] == 0 then
                    layers[k] = nil
                else
                    lowestLayer = k
                    return
                end
            end
        end
        lowestLayer = highestLayer
    end
end

function BalencedLogicFinder.removeId(id)
    local idLayerHash = layerHash[id]
    layerHash[id] = nil
    if idLayerHash == nil then return end
    if #layers[idLayerHash] == 1 then
        layers[idLayerHash] = nil
        if lowestLayer == idLayerHash then
            for k = lowestLayer + 1, highestLayer, 1 do
                if layers[k] ~= nil then
                    if #layers[k] == 0 then
                        layers[k] = nil
                    else
                        lowestLayer = k
                        return
                    end
                end
            end
        elseif highestLayer == idLayerHash then
            for k = highestLayer - 1, lowestLayer, -1 do
                if layers[k] ~= nil then
                    if #layers[k] == 0 then
                        layers[k] = nil
                    else
                        highestLayer = k
                        return
                    end
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

function BalencedLogicFinder.getBlockTime(id)
    if FLR.runnableBlockPathIds[id] == 5 then
        return FLR.timerLengths[id]
    end
    return 1
end

function BalencedLogicFinder.removeBlocksWithBadOutputsUp(startId)
    local startLayer = layerHash[startId]
    if startLayer == nil then return false end
    local kills = 0
    for layerIndex = #layers, 1, -1 do
        local layer = layers[layerIndex]
        if layer ~= nil then
            for i = 1, #layer do
                local id = layer[i]
                if layerHash[id] ~= nil then
                    local outputs = FLR.blockOutputs[id]
                    local outputType
                    for j = 1, #outputs do
                        local outputId = outputs[j]
                        if layerHash[outputId] == nil then
                            if outputType == nil then
                                outputType = false
                            elseif outputType then
                                outputType = "kill"
                                break
                            end
                        else
                            if outputType == nil then
                                outputType = true
                            elseif not outputType then
                                outputType = "kill"
                                break
                            end
                        end
                    end
                    if outputType == "kill" then
                        if layerIndex < startLayer then
                            kills = kills + 1
                            for k = 1, layerIndex do
                                BalencedLogicFinder.removeLayer(k)
                            end
                            return true
                        else
                            for k = 1, #outputs do
                                if layerHash[outputs[k]] ~= nil then
                                    kills = kills + 1
                                    BalencedLogicFinder.removeBlockAndOutputsRec(outputs[k])
                                end
                            end
                        end
                        
                    end
                end
            end
        end
    end
    return kills > 0
end

function BalencedLogicFinder.removeBlockAndOutputsRec(id)
    if layerHash[id] == nil then return end
    local idsToRemove = {id}
    local idsToRemoveHash = {[id] = true}
    local i = 1
    while i <= #idsToRemove do
        local idToRemove = idsToRemove[i]
        local layerIndex = layerHash[idToRemove]
        BalencedLogicFinder.removeId(idToRemove)
        local outputs = FLR.blockOutputs[idToRemove]
        for k = 1, #outputs do
            local outputId = outputs[k]
            if (
                layerHash[outputId] ~= nil and
                layerHash[outputId] >= layerIndex and
                idsToRemoveHash[outputId] == nil
            ) then
                idsToRemove[#idsToRemove+1] = outputId
                idsToRemoveHash[outputId] = true
            end
        end
        i = i + 1
    end
end

function BalencedLogicFinder.layersStartAtOne()
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
    layers = newLayers
    layerHash = newLayerHash
    highestLayer = highestLayer - lowestLayer
    lowestLayer = 1
end