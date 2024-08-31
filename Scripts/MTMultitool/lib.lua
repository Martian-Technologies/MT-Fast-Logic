MTMultitoolLib = {
    voxelMapHash = {}
}

function MTMultitoolLib.getLocalCenter(shape)
    if shape == nil then
        return sm.vec3.new(0, 0, 0)
    end
    if not sm.exists(shape) then
        return sm.vec3.new(0, 0, 0)
    end
    return shape:getLocalPosition() + shape.xAxis * 0.5 + shape.yAxis * 0.5 + shape.zAxis * 0.5
end

function MTMultitoolLib.findSequeceOfGates(start, final)
    if not start or not final then
        return {}
    end
    local startBody = start:getBody()
    local finalBody = final:getBody()
    if not startBody or not finalBody then
        return {}
    end
    if startBody ~= finalBody then
        return {}
    end
    local getLocalCenter = MTMultitoolLib.getLocalCenter
    local voxelMap = MTMultitoolLib.getVoxelMap(startBody)
    local halfBlock = sm.vec3.new(0.125, 0.125, 0.125)
    local startPos = getLocalCenter(start) / 4 - halfBlock
    local finalPos = getLocalCenter(final) / 4 - halfBlock
    local xDelta = (finalPos.x - startPos.x) * 4
    local yDelta = (finalPos.y - startPos.y) * 4
    local zDelta = (finalPos.z - startPos.z) * 4
    if xDelta == 0 and yDelta == 0 and zDelta == 0 then
        return { start, final }
    end
    local gcd = MathUtil.gcd(math.abs(xDelta), MathUtil.gcd(math.abs(yDelta), math.abs(zDelta)))
    local xStep = xDelta / gcd / 4
    local yStep = yDelta / gcd / 4
    local zStep = zDelta / gcd / 4
    local sequence = {}
    -- fill the sequence with 0
    for i = 1, gcd do
        table.insert(sequence, 0)
    end
    for i = 0, gcd do
        local pos = startPos + sm.vec3.new(xStep * i, yStep * i, zStep * i)
        local indexString = pos.x .. ";" .. pos.y .. ";" .. pos.z
        local shape = voxelMap[indexString]
        if shape ~= nil then
            sequence[i] = shape
        end
    end
    -- table.insert(sequence, final)
    local seq = {}
    for i, v in pairs(sequence) do
        if v ~= 0 then
            table.insert(seq, v)
        end
    end
    return seq
end

function MTMultitoolLib.findSequeceOfGatesOLD(start, final)
    -- check their position delta, and find gcd of x,y,z deltas to find the direction one step in the sequence
    -- start and final are shapes
    if not start or not final then
        return {}
    end
    local startBody = start:getBody()
    local finalBody = final:getBody()
    if not startBody or not finalBody then
        return {}
    end
    if startBody ~= finalBody then
        return {}
    end
    local getLocalCenter = MTMultitoolLib.getLocalCenter
    -- local shapes = startBody:getShapes()
    local startPos = getLocalCenter(start)
    local finalPos = getLocalCenter(final)
    local xDelta = finalPos.x - startPos.x
    local yDelta = finalPos.y - startPos.y
    local zDelta = finalPos.z - startPos.z
    if xDelta == 0 and yDelta == 0 and zDelta == 0 then
        return { start, final }
    end
    local gcd = MathUtil.gcd(math.abs(xDelta), MathUtil.gcd(math.abs(yDelta), math.abs(zDelta)))
    local xStep = xDelta / gcd
    local yStep = yDelta / gcd
    local zStep = zDelta / gcd
    local sequence = {}
    -- fill the sequence with nils
    for i = 1, gcd do
        table.insert(sequence, 0)
    end
    table.insert(sequence, final)
    -- check every gate on the body and check if it falls on the sequence, if it does, add it to the sequence
    if xStep == 0 and yStep == 0 and zStep == 0 then
        return { start, final }
    end
    local shapesUnfiltered = startBody:getShapes()
    local shapes = {}
    for i, shape in pairs(shapesUnfiltered) do
        -- if shape is not an interactable gate, skip it
        if shape:getInteractable() ~= nil then
            table.insert(shapes, shape)
        end
    end
    if xStep == 0 and yStep == 0 then
        for i, shape in pairs(shapes) do
            local shapePos = getLocalCenter(shape)
            local zSteps = (shapePos.z - startPos.z) / zStep
            if zSteps == math.floor(zSteps) and (shapePos.x == startPos.x) and (shapePos.y == startPos.y) and zSteps >= 0 and zSteps <= gcd then
                sequence[zSteps + 1] = shape
            end
        end
    elseif xStep == 0 and zStep == 0 then
        for i, shape in pairs(shapes) do
            local shapePos = getLocalCenter(shape)
            local ySteps = (shapePos.y - startPos.y) / yStep
            if ySteps == math.floor(ySteps) and (shapePos.x == startPos.x) and (shapePos.z == startPos.z) and ySteps >= 0 and ySteps <= gcd then
                sequence[ySteps + 1] = shape
            end
        end
    elseif yStep == 0 and zStep == 0 then
        for i, shape in pairs(shapes) do
            local shapePos = getLocalCenter(shape)
            local xSteps = (shapePos.x - startPos.x) / xStep
            if xSteps == math.floor(xSteps) and (shapePos.y == startPos.y) and (shapePos.z == startPos.z) and xSteps >= 0 and xSteps <= gcd then
                sequence[xSteps + 1] = shape
            end
        end
    elseif xStep == 0 then
        for i, shape in pairs(shapes) do
            local shapePos = getLocalCenter(shape)
            local ySteps = (shapePos.y - startPos.y) / yStep
            local zSteps = (shapePos.z - startPos.z) / zStep
            if ySteps == zSteps and ySteps == math.floor(ySteps) and zSteps == math.floor(zSteps) and (shapePos.x == startPos.x) and ySteps >= 0 and ySteps <= gcd then
                sequence[ySteps + 1] = shape
            end
        end
    elseif yStep == 0 then
        for i, shape in pairs(shapes) do
            local shapePos = getLocalCenter(shape)
            local xSteps = (shapePos.x - startPos.x) / xStep
            local zSteps = (shapePos.z - startPos.z) / zStep
            if xSteps == zSteps and xSteps == math.floor(xSteps) and zSteps == math.floor(zSteps) and (shapePos.y == startPos.y) and xSteps >= 0 and xSteps <= gcd then
                sequence[xSteps + 1] = shape
            end
        end
    elseif zStep == 0 then
        for i, shape in pairs(shapes) do
            local shapePos = getLocalCenter(shape)
            local xSteps = (shapePos.x - startPos.x) / xStep
            local ySteps = (shapePos.y - startPos.y) / yStep
            if xSteps == ySteps and xSteps == math.floor(xSteps) and ySteps == math.floor(ySteps) and (shapePos.z == startPos.z) and xSteps >= 0 and xSteps <= gcd then
                sequence[xSteps + 1] = shape
            end
        end
    else
        for i, shape in pairs(shapes) do
            local shapePos = getLocalCenter(shape)
            local xSteps = (shapePos.x - startPos.x) / xStep
            local ySteps = (shapePos.y - startPos.y) / yStep
            local zSteps = (shapePos.z - startPos.z) / zStep
            if xSteps == ySteps and xSteps == zSteps and xSteps == math.floor(xSteps) and ySteps == math.floor(ySteps) and zSteps == math.floor(zSteps) and xSteps >= 0 and xSteps <= gcd then
                sequence[xSteps + 1] = shape
            end
        end
    end
    local seq = {}
    for i, v in pairs(sequence) do
        if v ~= 0 then
            table.insert(seq, v)
        end
    end
    return seq
end

function MTMultitoolLib.getShapeAt(body, position)
    local shapes = body:getShapes()
    for i, shape in pairs(shapes) do
        if MTMultitoolLib.getLocalCenter(shape) == position then
            return shape
        end
    end
    return nil
end

function MTMultitoolLib.createVoxelGrid(body)
    local shapes = body:getShapes()
    local min = nil
    local max = nil
    for i, shape in pairs(shapes) do
        local pos = MTMultitoolLib.getLocalCenter(shape)
        if not min then
            min = pos
            max = pos
        else
            min = sm.vec3.min(min, pos)
            max = sm.vec3.max(max, pos)
        end
    end
    local xSize = max.x - min.x + 1
    local ySize = max.y - min.y + 1
    local zSize = max.z - min.z + 1
    local offset = -min
    local grid = {} -- 1d array of shapes (x + y * xSize + z * xSize * ySize)
    for i, shape in pairs(shapes) do
        local pos = MTMultitoolLib.getLocalCenter(shape) + offset
        local index = pos.x + pos.y * xSize + pos.z * xSize * ySize + 1
        grid[index] = shape
    end
    return {
        grid = grid,
        size = sm.vec3.new(xSize, ySize, zSize),
        offset = offset,
        tabletype="linear"
    }
end

function MTMultitoolLib.createVoxelGridFromCreationBodies(bodies)
    local shapes = {}
    for i, body in pairs(bodies) do
        for j, shape in pairs(body:getShapes()) do
            table.insert(shapes, shape)
        end
    end
    local grid = {}
    for i, shape in pairs(shapes) do
        local pos = shape:getWorldPosition()
        grid[math.floor(pos.x*4)..";"..math.floor(pos.y*4)..";"..math.floor(pos.z*4)] = shape
    end
    return {
        grid = grid,
        tabletype="hash"
    }
end

function MTMultitoolLib.createVoxelGridFromPositionTable(positions)
    local min = nil
    local max = nil
    for i, pos in pairs(positions) do
        if not min then
            min = pos
            max = pos
        else
            min = sm.vec3.min(min, pos)
            max = sm.vec3.max(max, pos)
        end
    end
    local xSize = max.x - min.x + 1
    local ySize = max.y - min.y + 1
    local zSize = max.z - min.z + 1
    local offset = -min
    local grid = {} -- 1d array of shapes (x + y * xSize + z * xSize * ySize)
    for i, pos in pairs(positions) do
        local index = pos.x + pos.y * xSize + pos.z * xSize * ySize + 1
        grid[index] = pos
    end
    return {
        grid = grid,
        size = sm.vec3.new(xSize, ySize, zSize),
        offset = offset,
        tabletype="linear"
    }
end

function MTMultitoolLib.getShapeAtVoxelGrid(grid, position)
    if grid.tabletype == "linear" then
        local x = position.x + grid.offset.x
        local y = position.y + grid.offset.y
        local z = position.z + grid.offset.z
        if x < 0 or y < 0 or z < 0 then
            return nil
        end
        if x >= grid.size.x or y >= grid.size.y or z >= grid.size.z then
            return nil
        end
        local index = x + y * grid.size.x + z * grid.size.x * grid.size.y
        return grid.grid[index + 1]
    elseif grid.tabletype == "hash" then
        local pos = math.floor(position.x*4) .. ";" .. math.floor(position.y*4) .. ";" .. math.floor(position.z*4)
        return grid.grid[pos]
    end
end

function MTMultitoolLib.formatOrdinal(n)
    local suffix = "th"
    if n % 10 == 1 and n % 100 ~= 11 then
        suffix = "st"
    elseif n % 10 == 2 and n % 100 ~= 12 then
        suffix = "nd"
    elseif n % 10 == 3 and n % 100 ~= 13 then
        suffix = "rd"
    end
    return n .. suffix
end

function MTMultitoolLib.getVoxelMap(body, override_cache)
    if MTMultitoolLib.voxelMapHash[body:getId()] and not override_cache then
        local hashValue = MTMultitoolLib.voxelMapHash[body:getId()]
        if not body:hasChanged(hashValue.tick) then
            return hashValue.voxelMap
        end
    end

    local interactables = body:getInteractables()
    local voxelMap = {}
    -- print("__________________________________________________________")
    local halfBlock = sm.vec3.new(0.125, 0.125, 0.125)
    for _, interactable in pairs(interactables) do
        local position = MTMultitoolLib.getLocalCenter(interactable:getShape()) / 4 - halfBlock
        local indexString = position.x .. ";" .. position.y .. ";" .. position.z
        voxelMap[indexString] = interactable:getShape()
    end

    MTMultitoolLib.voxelMapHash[body:getId()] = {
        voxelMap = voxelMap,
        tick = sm.game.getCurrentTick()
    }

    -- print(voxelMap)

    return voxelMap
end

function MTMultitoolLib.getVoxelMapShapes(body, override_cache)
    if MTMultitoolLib.voxelMapHash[body:getId().."shapes"] and not override_cache then
        local hashValue = MTMultitoolLib.voxelMapHash[body:getId()]
        if not body:hasChanged(hashValue.tick) then
            return hashValue.voxelMap
        end
    end

    local shapes = body:getShapes()
    local voxelMap = {}
    -- print("__________________________________________________________")
    local halfBlock = sm.vec3.new(0.125, 0.125, 0.125)
    for _, shape in pairs(shapes) do
        local position = MTMultitoolLib.getLocalCenter(shape) / 4 - halfBlock
        local indexString = position.x .. ";" .. position.y .. ";" .. position.z
        voxelMap[indexString] = shape
    end

    MTMultitoolLib.voxelMapHash[body:getId()] = {
        voxelMap = voxelMap,
        tick = sm.game.getCurrentTick()
    }

    -- print(voxelMap)

    return voxelMap
end

function MTMultitoolLib.getVoxelMapShapesGW(body, override_cache)
    if MTMultitoolLib.voxelMapHash[body:getId().."shapesGW"] and not override_cache then
        local hashValue = MTMultitoolLib.voxelMapHash[body:getId()]
        if not body:hasChanged(hashValue.tick) then
            return hashValue.voxelMap
        end
    end

    local shapes = body:getShapes()
    local voxelMap = {}
    -- print("__________________________________________________________")
    local halfBlock = sm.vec3.new(0.125, 0.125, 0.125)
    for _, shape in pairs(shapes) do
        local position = MTMultitoolLib.getLocalCenter(shape) / 4 - halfBlock
        local indexString = position.x .. ";" .. position.y .. ";" .. position.z
        if voxelMap[indexString] == nil then
            voxelMap[indexString] = {}
        end
        table.insert(voxelMap[indexString], shape)
    end

    MTMultitoolLib.voxelMapHash[body:getId()] = {
        voxelMap = voxelMap,
        tick = sm.game.getCurrentTick()
    }

    -- print(voxelMap)

    return voxelMap
end


function MTMultitoolLib.getOccupiedBlocks(shape)
    local positions = {}
    local bb = shape:getBoundingBox()
    -- Returns:
    -- - [ Vec3 ]: The bounding box.
    local origin = shape:getLocalPosition()
    local xSize = bb.x * 4
    local ySize = bb.y * 4
    local zSize = bb.z * 4
    local xAxis = shape:getXAxis()
    local yAxis = shape:getYAxis()
    local zAxis = shape:getZAxis()
    if xSize == 1 and ySize == 1 and zSize == 1 then
        return {origin + xAxis * 0.5 + yAxis * 0.5 + zAxis * 0.5}
    end
    for x = 0, xSize - 1 do
        for y = 0, ySize - 1 do
            for z = 0, zSize - 1 do
                -- print(x)
                -- print(y)
                -- print(z)
                -- print('-------------------')
                local pos = origin + xAxis * (x+0.5) + yAxis * (y+0.5) + zAxis * (z+0.5)
                table.insert(positions, pos)
            end
        end
    end
    -- print(xAxis)
    -- print(yAxis)
    -- print(zAxis)
    -- print("xSize: " .. xSize)
    -- print("ySize: " .. ySize)
    -- print("zSize: " .. zSize)
    -- for i, pos in pairs(positions) do
    --     print(pos)
    -- end
    -- print('-------------------')
    return positions
end

function MTMultitoolLib.getVoxelMapMultidotblocks(body)
    local interactables = nil
    local gotInteractables = false
    if MTMultitoolLib.voxelMapHash[body:getId() .. "multidotblocks"] then
        local hashValue = MTMultitoolLib.voxelMapHash[body:getId() .. "multidotblocks"]
        if not body:hasChanged(hashValue.tick) then
            return hashValue.voxelMap
        end
        interactables = body:getInteractables()
        -- if #interactables == hashValue.numInts then
        --     hashValue.tick = sm.game.getCurrentTick()
        --     return hashValue.voxelMap
        -- end
        gotInteractables = true
    end

    if not gotInteractables then
        interactables = body:getInteractables()
    end

    local voxelMap = {}
    -- print("__________________________________________________________")
    local halfBlock = sm.vec3.new(0.125, 0.125, 0.125)
    for _, interactable in pairs(interactables) do
        local shape = interactable:getShape()
        -- local position = MTMultitoolLib.getLocalCenter(interactable:getShape()) / 4 - halfBlock
        -- local indexString = position.x .. ";" .. position.y .. ";" .. position.z
        -- voxelMap[indexString] = interactable:getShape()
        local positions = MTMultitoolLib.getOccupiedBlocks(interactable:getShape())
        for i, p in pairs(positions) do
            local pos = p / 4 - halfBlock
            voxelMap[pos.x .. ";" .. pos.y .. ";" .. pos.z] = shape
        end
    end

    MTMultitoolLib.voxelMapHash[body:getId() .. "multidotblocks"] = {
        voxelMap = voxelMap,
        tick = sm.game.getCurrentTick(),
        numInts = #interactables
    }

    return voxelMap
end

function MTMultitoolLib.getVoxelMapInteractableIds(body)
    if MTMultitoolLib.voxelMapHash[body:getId() .. "intIds"] then
        local hashValue = MTMultitoolLib.voxelMapHash[body:getId() .. "intIds"]
        if not body:hasChanged(hashValue.tick) then
            return hashValue.voxelMap
        end
    end

    local interactables = body:getInteractables()
    local voxelMap = {}
    -- print("__________________________________________________________")
    local halfBlock = sm.vec3.new(0.125, 0.125, 0.125)
    for _, interactable in pairs(interactables) do
        -- local position = MTMultitoolLib.getLocalCenter(interactable:getShape()) / 4 - halfBlock
        -- local indexString = position.x .. ";" .. position.y .. ";" .. position.z
        -- voxelMap[indexString] = interactable:getShape()
        local positions = MTMultitoolLib.getOccupiedBlocks(interactable:getShape())
        for i, p in pairs(positions) do
            local pos = p / 4 - halfBlock
            local indexString = pos.x .. ";" .. pos.y .. ";" .. pos.z
            voxelMap[indexString] = interactable:getId()
        end
    end

    MTMultitoolLib.voxelMapHash[body:getId() .. "intIds"] = {
        voxelMap = voxelMap,
        tick = sm.game.getCurrentTick()
    }

    return voxelMap
end

RangeOffset = {}
RangeOffset.rangeOffset = sm.vec3.new(0, 0, 0)
function RangeOffset.inject(multitool)
    table.insert(multitool.subscriptions.client_onUpdate, function()
        RangeOffset.rangeOffset = sm.camera.getUp() * (0.00000011597 * (sm.camera.getFov() ^ 2.60339) + 0.005688879)
    end)
end

function MTMultitoolLib.colorToHexNoAlpha(color)
    return color:getHexStr():sub(1, -3)
end