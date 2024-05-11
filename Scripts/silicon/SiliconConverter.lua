dofile "../util/util.lua"
local string = string
local table = table

SiliconConverter = SiliconConverter or {}

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.WillBeSiliconBlocks = sm.MTFastLogic.WillBeSiliconBlocks or { {}, {} }

local blockUuids = {
    ["1x1x1"] = "3706ba55-bd11-4053-b437-bbf2aff823b4",
    ["2x1x1"] = "f0e1640f-7776-4232-b1d9-8c1a41b53958",
    ["3x1x1"] = "f0e2828f-7776-4232-b1d9-8a3c45b63898",
    ["4x1x1"] = "f0e1640f-7406-1984-b1d9-8c1a41b53958",
    ["8x1x1"] = "f0e1640f-7406-4232-b1d9-8c1a41b53958",
    ["12x1x1"] = "f3e2828f-1212-1111-b1d4-8d3c45b63000",
    ["2x2x1"] = "f590d9d1-179d-49ff-86ab-7f74a730e243",
    ["4x4x1"] = "d576a4c9-e6bc-46c0-9230-f92967cc39b6",
    ["8x8x1"] = "195aa046-017a-4f0b-809c-98ed141955fb",
    ["16x16x1"] = "f0e2828f-1234-4321-b1d9-8a3c45b63898",
    ["12x4x1"] = "f3e2828f-1241-1412-b1f2-8d3c45b63000",
    ["2x2x2"] = "e6011dc4-8842-4d94-a196-0c7386065ab6",
    ["8x8x4"] = "f0e2828f-8888-4444-b1d9-8a3c45b63898",
}
local rotations = {
    yzx = { xAxis = sm.vec3.new(1, 0, 0), zAxis = sm.vec3.new(0, 1, 0) },
    zxy = { xAxis = sm.vec3.new(0, 1, 0), zAxis = sm.vec3.new(1, 0, 0) },
    zyx = { xAxis = sm.vec3.new(0, 0, 1), zAxis = sm.vec3.new(-1, 0, 0) },
    xyz = { xAxis = sm.vec3.new(1, 0, 0), zAxis = sm.vec3.new(0, 0, 1) },
    xzy = { xAxis = sm.vec3.new(0, 0, 1), zAxis = sm.vec3.new(0, 1, 0) },
    yxz = { xAxis = sm.vec3.new(0, 1, 0), zAxis = sm.vec3.new(0, 0, -1) },
}

function SiliconConverter.convertToSilicon(creationId, blockUuids) -- only for FastLogicGates
    local creation = sm.MTFastLogic.Creations[creationId]
    local blocks = creation.blocks
    local blocksPosHash = {}
    for _, uuid in ipairs(blockUuids) do
        local block = blocks[uuid]
        if not block.isSilicon then
            for k, v in pairs(sm.MTFastLogic.FastLogicBlockLookUp[uuid].interactable:getChildren()) do
                if v ~= nil and creation.uuids[v.id] == nil then
                    goto continue
                end
            end
            if creation.AllFastBlocks[uuid].type == "LogicGate" and table.length(creation.AllFastBlocks[uuid].activeInputs) == 0 then
                blocksPosHash[string.vecToString(block.pos)] = uuid
            end
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
        sm.MTFastLogic.WillBeSiliconBlocks[2][#sm.MTFastLogic.WillBeSiliconBlocks[2] + 1] = {
            interactable = newShape:getInteractable(),
            uuids = siliconBlocksToMake[i].uuids
        }
        for ii = 1, #siliconBlocksToMake[i].uuids do
            creation.blocks[siliconBlocksToMake[i].uuids[ii]].isSilicon = true
            creation.blocks[siliconBlocksToMake[i].uuids[ii]].siliconBlockId = newShape:getInteractable():getId()
            creation.AllFastBlocks[siliconBlocksToMake[i].uuids[ii]]:remove(false)
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
        zyx = { xAxis = sm.vec3.new(0, 0, 1), zAxis = sm.vec3.new(-1, 0, 0) },
        xyz = { xAxis = sm.vec3.new(1, 0, 0), zAxis = sm.vec3.new(0, 0, 1) },
        xzy = { xAxis = sm.vec3.new(1, 0, 0), zAxis = sm.vec3.new(0, -1, 0) },
        yxz = { xAxis = sm.vec3.new(0, 1, 0), zAxis = sm.vec3.new(0, 0, -1) },
    }

    local bestArea = nil
    local bestScore = nil
    local bestUuid = nil
    local bestRot = nil
    local xSize = x - cornerPos.x + 1
    local ySize = y - cornerPos.y + 1
    local zSize = z - cornerPos.z + 1
    for name, uuid in pairs(blockUuids) do
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

    local areas = { {
        uuids = {},
        uuid = bestUuid,
        pos = cornerPos,
        bestRot = bestRot
    } }

    for x1 = cornerPos.x, x do
        for y1 = cornerPos.y, y do
            for z1 = cornerPos.z, z do
                areas[1].uuids[#areas[1].uuids + 1] = posHash[string.vecToString(sm.vec3.new(x1, y1, z1))]
                posHash[string.vecToString(sm.vec3.new(x1, y1, z1))] = nil
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
    local allBlockMannager = creation.FastLogicAllBlockMannager
    local blocks = creation.blocks
    local siliconBlocks = {}
    for _, uuid in ipairs(blockUuids) do
        if blocks[uuid].isSilicon then
            siliconBlocks[#siliconBlocks + 1] = creation.SiliconBlocks[blocks[uuid].siliconBlockId]
        end
    end

    for _, siliconBlock in pairs(siliconBlocks) do
        for i = 1, #siliconBlock.data.blocks do
            local siliconData = siliconBlock.data.blocks[i]
            local block = blocks[siliconData.uuid]
            if block ~= nil and block.isSilicon then
                block.isSilicon = false
                creation.FastLogicRealBlockMannager:createPartWithData(block, siliconBlock.shape.body)
            end
        end
        siliconBlock:remove(false)
    end
end
