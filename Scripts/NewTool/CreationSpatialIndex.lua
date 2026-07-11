-- Shared creation geometry and revision-aware spatial indexes.
-- Targeting and selection code should use this module rather than maintaining
-- their own coordinate conversion, voxel maps, or row-finding implementations.

CreationSpatialIndex = {}

local function round(value)
    if value >= 0 then return math.floor(value + 0.5) end
    return math.ceil(value - 0.5)
end

local function gcd(a, b)
    a = math.abs(round(a))
    b = math.abs(round(b))
    while b ~= 0 do
        a, b = b, a % b
    end
    return a
end

local function voxelKey(position)
    return position.x .. ";" .. position.y .. ";" .. position.z
end

local function centerKey(position)
    return round(position.x * 4000) .. ";" ..
        round(position.y * 4000) .. ";" ..
        round(position.z * 4000)
end

local function getShapeCenterLocal(shape)
    local bounds = shape:getBoundingBox()
    return shape:getLocalPosition() / 4 +
        shape:getXAxis() * (bounds.x / 2) +
        shape:getYAxis() * (bounds.y / 2) +
        shape:getZAxis() * (bounds.z / 2)
end

local function indexOccupiedVoxels(voxelMap, shape)
    local bounds = shape:getBoundingBox()
    local origin = shape:getLocalPosition()
    local xSize = math.max(round(bounds.x * 4), 1)
    local ySize = math.max(round(bounds.y * 4), 1)
    local zSize = math.max(round(bounds.z * 4), 1)
    local xAxis = shape:getXAxis()
    local yAxis = shape:getYAxis()
    local zAxis = shape:getZAxis()

    for x = 0, xSize - 1 do
        for y = 0, ySize - 1 do
            for z = 0, zSize - 1 do
                local gridCenter = origin +
                    xAxis * (x + 0.5) +
                    yAxis * (y + 0.5) +
                    zAxis * (z + 0.5)
                local voxelPosition = gridCenter / 4 - sm.vec3.new(0.125, 0.125, 0.125)
                voxelMap[voxelKey(voxelPosition)] = shape
            end
        end
    end
end

function CreationSpatialIndex.init(tool)
    tool.CreationSpatialIndex = {}
    local self = tool.CreationSpatialIndex
    local bodyCaches = {}

    local function buildIndex(body)
        local index = {
            body = body,
            revision = sm.game.getCurrentTick(),
            interactableVoxelMap = {},
            interactableCenterMap = {}
        }

        for _, interactable in ipairs(body:getInteractables()) do
            local shape = interactable:getShape()
            if shape ~= nil and sm.exists(shape) then
                index.interactableCenterMap[centerKey(getShapeCenterLocal(shape))] = shape
                indexOccupiedVoxels(index.interactableVoxelMap, shape)
            end
        end
        return index
    end

    local function ensureShapeIndex(index)
        if index == nil or index.shapeVoxelMap ~= nil then return end

        index.shapeVoxelMap = {}
        index.shapeCenterMap = {}
        for _, shape in ipairs(index.body:getShapes()) do
            if shape ~= nil and sm.exists(shape) then
                index.shapeCenterMap[centerKey(getShapeCenterLocal(shape))] = shape
                indexOccupiedVoxels(index.shapeVoxelMap, shape)
            end
        end
    end

    function self.get(body)
        if body == nil or not sm.exists(body) then return nil end

        local id = body:getId()
        local cached = bodyCaches[id]
        if cached ~= nil and cached.body == body and not body:hasChanged(cached.revision) then
            return cached
        end

        cached = buildIndex(body)
        bodyCaches[id] = cached
        return cached
    end

    function self.invalidate(body)
        if body ~= nil then bodyCaches[body:getId()] = nil end
    end

    function self.getShapeCenterLocal(shape)
        return getShapeCenterLocal(shape)
    end

    function self.getShapeAtVoxel(body, position)
        local index = self.get(body)
        ensureShapeIndex(index)
        return index and index.shapeVoxelMap[voxelKey(position)] or nil
    end

    function self.lookupShapeVoxel(bodyIndex, position)
        ensureShapeIndex(bodyIndex)
        return bodyIndex and bodyIndex.shapeVoxelMap[voxelKey(position)] or nil
    end

    function self.lookupInteractableVoxel(bodyIndex, position)
        return bodyIndex and bodyIndex.interactableVoxelMap[voxelKey(position)] or nil
    end

    function self.findStraightRow(startShape, endShape)
        if startShape == nil or endShape == nil or
            not sm.exists(startShape) or not sm.exists(endShape) then
            return {}, nil
        end

        local body = startShape:getBody()
        if body == nil or body ~= endShape:getBody() then return {}, nil end

        local index = self.get(body)
        if index == nil then return {}, nil end

        local startPosition = getShapeCenterLocal(startShape)
        local endPosition = getShapeCenterLocal(endShape)
        local deltaInBlocks = (endPosition - startPosition) * 4
        local steps = gcd(deltaInBlocks.x, gcd(deltaInBlocks.y, deltaInBlocks.z))
        if steps == 0 then return { startShape }, index.revision end

        local row = {}
        local step = (endPosition - startPosition) / steps
        for stepIndex = 0, steps do
            local shape = index.interactableCenterMap[centerKey(startPosition + step * stepIndex)]
            if shape ~= nil and sm.exists(shape) then row[#row + 1] = shape end
        end
        return row, index.revision
    end
end
