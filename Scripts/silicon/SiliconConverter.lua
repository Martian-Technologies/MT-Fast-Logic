dofile "../util/util.lua"
dofile "../util/backupEngine.lua"
dofile "SiliconSizes.lua"
local string = string
local table = table
local type = type
local pairs = pairs
local sm = sm

SiliconConverter = SiliconConverter or {}

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.DataForSiliconBlocks = sm.MTFastLogic.DataForSiliconBlocks or {}

local rotations = {
    yzx = { xAxis = sm.vec3.new(0, 0, 1), zAxis = sm.vec3.new(0, 1, 0) },
    zxy = { xAxis = sm.vec3.new(0, 1, 0), zAxis = sm.vec3.new(1, 0, 0) },
    zyx = { xAxis = sm.vec3.new(0, 0, -1), zAxis = sm.vec3.new(1, 0, 0) },
    xyz = { xAxis = sm.vec3.new(1, 0, 0), zAxis = sm.vec3.new(0, 0, 1) },
    xzy = { xAxis = sm.vec3.new(-1, 0, 0), zAxis = sm.vec3.new(0, 1, 0) },
    yxz = { xAxis = sm.vec3.new(0, 1, 0), zAxis = sm.vec3.new(0, 0, 1) },
}

function SiliconConverter.convertToSilicon(creationId, blockUuids) -- only for FastLogicGates
    local creation = sm.MTFastLogic.Creations[creationId]
    local blocks = creation.blocks
    local blocksPosHash = {}
    for _, uuid in ipairs(blockUuids) do
        local block = blocks[uuid]
        if not block.isSilicon then
            if (
                creation.AllFastBlocks[uuid].type ~= "LogicGate" or
                creation.FastLogicRunner:externalHasNonFastInputs(uuid) or
                #creation.AllFastBlocks[uuid].shape:getJoints() > 0
            ) then
                goto continue
            end
            for k, v in pairs(sm.MTFastLogic.FastLogicBlockLookUp[uuid].interactable:getChildren()) do
                if v ~= nil and creation.uuids[v.id] == nil then
                    goto continue
                end
            end
            local pos = string.vecToString(block.pos)
            if blocksPosHash[pos] == nil then
                blocksPosHash[pos] = {}
            end
            blocksPosHash[pos][#blocksPosHash[pos]+1] = uuid
            ::continue::
        end
    end
    if table.length(blocksPosHash) == 0 then return end
    local siliconBlocksToMake = SiliconConverter.getAreas(blocksPosHash)
    for i = 1, #siliconBlocksToMake do
        local newShape = creation.AllFastBlocks[siliconBlocksToMake[i].uuids[1]].shape:getBody():createPart(
            sm.uuid.new(siliconBlocksToMake[i].uuid),
            siliconBlocksToMake[i].pos - sm.MTUtil.getOffset(siliconBlocksToMake[i].bestRot),
            siliconBlocksToMake[i].bestRot.zAxis,
            siliconBlocksToMake[i].bestRot.xAxis,
            true
        )
        sm.MTFastLogic.DataForSiliconBlocks[newShape:getInteractable():getId()] = siliconBlocksToMake[i].uuids
        for ii = 1, #siliconBlocksToMake[i].uuids do
            local uuid = siliconBlocksToMake[i].uuids[ii]
            creation.blocks[uuid].isSilicon = true
            creation.blocks[uuid].siliconBlockId = newShape:getInteractable():getId()
            creation.AllFastBlocks[uuid]:remove(false)
        end
    end
end

function SiliconConverter.getAreas(posHash)
    local cornerPos = nil
    for k, _ in pairs(posHash) do
        local pos = string.stringToVec(k)
        if cornerPos == nil or pos.x < cornerPos.x or (
                pos.x == cornerPos.x and (pos.y < cornerPos.y or
                    (pos.y == cornerPos.y and pos.z < cornerPos.z)
                )
            ) then
            cornerPos = pos
        end
    end
    local x = cornerPos.x
    while posHash[string.vecToString(sm.vec3.new(x + 1, cornerPos.y, cornerPos.z))] ~= nil do
        x = x + 1
        if x > 1000 then break end
    end
    local y = cornerPos.y
    while posHash[string.vecToString(sm.vec3.new(x, y + 1, cornerPos.z))] ~= nil do
        for x1 = cornerPos.x, x do
            if posHash[string.vecToString(sm.vec3.new(x1, y + 1, cornerPos.z))] == nil then
                goto skipY
            end
        end
        y = y + 1
        if y > 1000 then break end
    end
    ::skipY::
    local z = cornerPos.z
    while posHash[string.vecToString(sm.vec3.new(x, y, z + 1))] ~= nil do
        for x1 = cornerPos.x, x do
            for y1 = cornerPos.y, y do
                if posHash[string.vecToString(sm.vec3.new(x1, y1, z + 1))] == nil then
                    goto skipZ
                end
            end
        end
        z = z + 1
        if z > 1000 then break end
    end
    ::skipZ::

    local rotations = {
        yzx = { xAxis = sm.vec3.new(0, 0, 1), zAxis = sm.vec3.new(0, 1, 0) },
        zxy = { xAxis = sm.vec3.new(0, 1, 0), zAxis = sm.vec3.new(1, 0, 0) },
        zyx = { xAxis = sm.vec3.new(0, 0, -1), zAxis = sm.vec3.new(1, 0, 0) },
        xyz = { xAxis = sm.vec3.new(1, 0, 0), zAxis = sm.vec3.new(0, 0, 1) },
        xzy = { xAxis = sm.vec3.new(-1, 0, 0), zAxis = sm.vec3.new(0, 1, 0) },
        yxz = { xAxis = sm.vec3.new(0, -1, 0), zAxis = sm.vec3.new(0, 0, 1) },
    }

    local bestArea = nil
    local bestScore = nil
    local bestUuid = nil
    local bestRot = nil
    local xSize = x - cornerPos.x + 1
    local ySize = y - cornerPos.y + 1
    local zSize = z - cornerPos.z + 1
    for name, uuid in pairs(sm.MTFastLogic.SiliconBlocksShapeDB.sizeToUuid) do
        local vec = string.stringToVec(name, "x")
        vec = { x = vec.x, y = vec.y, z = vec.z }
        local score = vec.x * vec.y * vec.z
        for k, rot in pairs(rotations) do
            if vec[string.sub(k, 1, 1)] <= x - cornerPos.x + 1 and vec[string.sub(k, 2, 2)] <= y - cornerPos.y + 1 and vec[string.sub(k, 3, 3)] <= z - cornerPos.z + 1 then
                if bestScore == nil or score > bestScore then
                    bestArea = { vec[string.sub(k, 1, 1)], vec[string.sub(k, 2, 2)], vec[string.sub(k, 3, 3)] }
                    bestScore = score
                    bestUuid = uuid
                    bestRot = rot
                end
            end
        end
    end
    if bestArea == nil then
        return {}
    end

    x = bestArea[1] + cornerPos.x - 1
    y = bestArea[2] + cornerPos.y - 1
    z = bestArea[3] + cornerPos.z - 1

    local offset = sm.vec3.new(0, 0, 0)
    if bestRot.xAxis.x == -1 then
        offset.x = offset.x + bestArea[1] - 1
    elseif bestRot.xAxis.y == -1 then
        offset.y = offset.y + bestArea[2] - 1
    elseif bestRot.xAxis.z == -1 then
        offset.z = offset.z + bestArea[3] - 1
    end

    if bestRot.zAxis.x == -1 then
        offset.x = offset.x + bestArea[1] - 1
    elseif bestRot.zAxis.y == -1 then
        offset.y = offset.y + bestArea[2] - 1
    elseif bestRot.zAxis.z == -1 then
        offset.z = offset.z + bestArea[3] - 1
    end

    local areas = { {
        uuids = {},
        uuid = bestUuid,
        pos = cornerPos + offset,
        bestRot = bestRot
    } }

    for x1 = cornerPos.x, x do
        for y1 = cornerPos.y, y do
            for z1 = cornerPos.z, z do
                local pos = string.vecToString(sm.vec3.new(x1, y1, z1))
                for i = 1, #posHash[pos] do
                    areas[1].uuids[#areas[1].uuids + 1] = posHash[pos][i]
                end
                posHash[pos] = nil
            end
        end
    end
    if table.length(posHash) > 0 then
        local areas2 = SiliconConverter.getAreas(posHash)
        for i = 1, #areas2 do
            areas[#areas + 1] = areas2[i]
        end
    end
    return areas
end

function SiliconConverter.convertFromSilicon(creationId, blockUuids) -- only for FastLogicGates
    local creation = sm.MTFastLogic.Creations[creationId]
    local allBlockManager = creation.FastLogicAllBlockManager
    local blocks = creation.blocks
    local siliconBlocks = {}
    for _, uuid in ipairs(blockUuids) do
        if blocks[uuid].isSilicon and #creation.SiliconBlocks[blocks[uuid].siliconBlockId].shape:getJoints() == 0 then
            siliconBlocks[#siliconBlocks + 1] = creation.SiliconBlocks[blocks[uuid].siliconBlockId]
        end
    end

    for _, siliconBlock in pairs(siliconBlocks) do
        for i = 1, #siliconBlock.data.blocks do
            local siliconData = siliconBlock.data.blocks[i]
            local block = blocks[siliconData.uuid]
            if block ~= nil and block.isSilicon then
                block.isSilicon = false
                creation.FastLogicRealBlockManager:createPartWithData(block, siliconBlock.shape.body)
            end
        end
        siliconBlock:remove(false)
    end
end
