-- BlockSelector owns looking-at-block queries and their line-only preview.
-- It deliberately has no tool/workflow knowledge: a workflow enables it, reads
-- getTarget(), and may constrain which bodies can be selected.

NewToolBlockSelector = {}

local defaultMaxDistance = 128
local defaultConnectionRadius = 0.1
local defaultPreviewThickness = 0.01
local defaultPreviewPadding = 0.006

local function containsBody(bodies, body)
    if bodies == nil then return true end
    for _, allowedBody in ipairs(bodies) do
        if allowedBody == body then return true end
    end
    return false
end

local function getShapeCenterLocal(shape)
    local bounds = shape:getBoundingBox()
    return shape:getLocalPosition() / 4 +
        shape:getXAxis() * (bounds.x / 2) +
        shape:getYAxis() * (bounds.y / 2) +
        shape:getZAxis() * (bounds.z / 2)
end

local function getOccupiedPositions(shape)
    local bounds = shape:getBoundingBox()
    local origin = shape:getLocalPosition()
    local xSize = math.max(math.floor(bounds.x * 4 + 0.5), 1)
    local ySize = math.max(math.floor(bounds.y * 4 + 0.5), 1)
    local zSize = math.max(math.floor(bounds.z * 4 + 0.5), 1)
    local xAxis = shape:getXAxis()
    local yAxis = shape:getYAxis()
    local zAxis = shape:getZAxis()
    local positions = {}

    for x = 0, xSize - 1 do
        for y = 0, ySize - 1 do
            for z = 0, zSize - 1 do
                positions[#positions + 1] = origin +
                    xAxis * (x + 0.5) +
                    yAxis * (y + 0.5) +
                    zAxis * (z + 0.5)
            end
        end
    end

    return positions
end

local function voxelKey(position)
    return position.x .. ";" .. position.y .. ";" .. position.z
end

function NewToolBlockSelector.init(tool)
    tool.BlockSelector = {}
    local self = tool.BlockSelector
    local voxelMaps = {}

    self.enabled = true
    self.raycastMode = "DDA" -- DDA, blockRaycast, or connectionRaycast
    self.bodyConstraint = nil
    self.raycastLookingAt = nil
    self.hit = nil
    self.maxDistance = defaultMaxDistance
    self.connectionRadius = defaultConnectionRadius
    self.previewThickness = defaultPreviewThickness
    self.previewPadding = defaultPreviewPadding
    self.previewColor = nil

    local function resetCrosshair()
        tool.tool:setDispersionFraction(0)
        tool.tool:setCrossHairAlpha(0.3)
    end

    local function getVoxelMap(body)
        local id = body:getId()
        local cached = voxelMaps[id]
        if cached ~= nil and not body:hasChanged(cached.tick) then
            return cached.map
        end

        local map = {}
        for _, interactable in ipairs(body:getInteractables()) do
            local shape = interactable:getShape()
            if shape ~= nil and sm.exists(shape) then
                for _, position in ipairs(getOccupiedPositions(shape)) do
                    local voxelPosition = position / 4 - sm.vec3.new(0.125, 0.125, 0.125)
                    map[voxelKey(voxelPosition)] = shape
                end
            end
        end

        voxelMaps[id] = {
            map = map,
            tick = sm.game.getCurrentTick()
        }
        return map
    end

    local function raycastBody()
        local origin = sm.camera.getPosition()
        local direction = sm.camera.getDirection()
        return sm.physics.raycast(
            origin,
            origin + direction * self.maxDistance,
            sm.localPlayer.getPlayer().character
        )
    end

    local function makeResult(body, shape, pointWorld, pointLocal)
        return {
            type = "body",
            pointWorld = pointWorld,
            pointLocal = pointLocal,
            getBody = function() return body end,
            getShape = function() return shape end
        }
    end

    local function getHitBody(result)
        if result == nil or result.type ~= "body" then return nil end
        local shape = result:getShape()
        if shape == nil then return nil end
        return shape:getBody()
    end

    local function raycastBlock()
        local didHit, result = raycastBody()
        if not didHit or result.type ~= "body" then return false, result end

        local shape = result:getShape()
        if shape == nil or shape:getInteractable() == nil then return false, result end
        if not containsBody(self.bodyConstraint, shape:getBody()) then return false, nil end
        return true, result
    end

    local function raycastConnection()
        local didHit, result = raycastBody()
        if not didHit then return false, result end

        local body = getHitBody(result)
        if body == nil or not containsBody(self.bodyConstraint, body) then return false, nil end

        local origin = sm.camera.getPosition()
        local direction = sm.camera.getDirection()
        local nearestShape = nil
        local nearestDistance = nil
        local radius2 = self.connectionRadius * self.connectionRadius

        for _, interactable in ipairs(body:getInteractables()) do
            local shape = interactable:getShape()
            if shape ~= nil and sm.exists(shape) then
                local offset = shape:getWorldPosition() - origin
                local distance = offset:dot(direction)
                local lateral = offset - direction * distance
                if distance >= 0 and distance <= self.maxDistance and lateral:length2() <= radius2 and
                    (nearestDistance == nil or distance < nearestDistance) then
                    nearestShape = shape
                    nearestDistance = distance
                end
            end
        end

        if nearestShape == nil then return false, nil end
        return true, makeResult(body, nearestShape, nearestShape:getWorldPosition(), nil)
    end

    local function raycastDda()
        local didHit, result = raycastBody()
        if not didHit then return false, result end

        local body = getHitBody(result)
        if body == nil or not containsBody(self.bodyConstraint, body) then return false, nil end

        local localAabbMin, localAabbMax = body:getLocalAabb()
        localAabbMin = localAabbMin / 4
        localAabbMax = localAabbMax / 4

        local rayPosition = result.pointLocal
        local rayDirection = sm.quat.inverse(body.worldRotation) * sm.camera.getDirection()
        rayDirection = rayDirection:safeNormalize(sm.vec3.new(1, 0, 0))
        local voxelMap = getVoxelMap(body)
        local radius = self.connectionRadius * 4

        for _ = 1, 2048 do
            local voxelPosition = sm.vec3.new(
                math.floor(rayPosition.x * 4),
                math.floor(rayPosition.y * 4),
                math.floor(rayPosition.z * 4)
            ) / 4
            local shape = voxelMap[voxelKey(voxelPosition)]

            if shape ~= nil and sm.exists(shape) then
                local center = getShapeCenterLocal(shape)
                local centerOffset = (center - rayPosition) * 4
                local forwardDistance = centerOffset:dot(rayDirection)
                local perpendicularDistance2 = centerOffset:length2() - forwardDistance * forwardDistance
                local bounds = shape:getBoundingBox()
                local shapeRadius = math.max(math.min(bounds.x, bounds.y, bounds.z) * 2 - 0.1, 0.001)
                local effectiveRadius = math.min(radius, shapeRadius)

                if forwardDistance >= 0 and perpendicularDistance2 <= effectiveRadius * effectiveRadius then
                    return true, makeResult(body, shape, body:transformPoint(center), center)
                end
            end

            local stepX = rayDirection.x < 0 and -1 or 1
            local stepY = rayDirection.y < 0 and -1 or 1
            local stepZ = rayDirection.z < 0 and -1 or 1
            local nextDistance = nil

            local function considerAxis(coordinate, direction, step)
                if direction == 0 then return end
                local boundary
                if step > 0 then
                    boundary = (math.floor(coordinate * 4) + 1) / 4
                else
                    boundary = math.floor(coordinate * 4) / 4
                end
                local distance = (boundary - coordinate) / direction
                if distance >= 0 and (nextDistance == nil or distance < nextDistance) then
                    nextDistance = distance
                end
            end

            considerAxis(rayPosition.x, rayDirection.x, stepX)
            considerAxis(rayPosition.y, rayDirection.y, stepY)
            considerAxis(rayPosition.z, rayDirection.z, stepZ)
            if nextDistance == nil then break end

            rayPosition = rayPosition + rayDirection * (nextDistance + 0.0001)
            if rayPosition.x < localAabbMin.x or rayPosition.x > localAabbMax.x or
                rayPosition.y < localAabbMin.y or rayPosition.y > localAabbMax.y or
                rayPosition.z < localAabbMin.z or rayPosition.z > localAabbMax.z then
                break
            end
        end

        return false, nil
    end

    local function raycast()
        if self.raycastMode == "blockRaycast" then
            return raycastBlock()
        elseif self.raycastMode == "connectionRaycast" then
            return raycastConnection()
        end
        return raycastDda()
    end

    local function getPreviewColor(shape)
        if self.previewColor ~= nil then return self.previewColor end
        local shapeColor = shape:getColor()
        return sm.color.new(1 - shapeColor.r, 1 - shapeColor.g, 1 - shapeColor.b, 1)
    end

    local function renderPreview(shape)
        local bounds = shape:getBoundingBox()
        local position = shape:getWorldPosition()
        local rotation = shape:getWorldRotation()
        local padding = self.previewPadding
        local at = rotation * sm.vec3.new(1, 0, 0)
        local right = rotation * sm.vec3.new(0, 1, 0)
        local up = rotation * sm.vec3.new(0, 0, 1)
        local halfAt = at * (bounds.x / 2 + padding)
        local halfRight = right * (bounds.y / 2 + padding)
        local halfUp = up * (bounds.z / 2 + padding)
        local color = getPreviewColor(shape)
        local options = { color = color, thickness = self.previewThickness }

        local corners = {
            position - halfAt - halfRight - halfUp,
            position - halfAt - halfRight + halfUp,
            position - halfAt + halfRight - halfUp,
            position - halfAt + halfRight + halfUp,
            position + halfAt - halfRight - halfUp,
            position + halfAt - halfRight + halfUp,
            position + halfAt + halfRight - halfUp,
            position + halfAt + halfRight + halfUp
        }
        local edges = {
            { 1, 2 }, { 1, 3 }, { 1, 5 },
            { 2, 4 }, { 2, 6 }, { 3, 4 },
            { 3, 7 }, { 4, 8 }, { 5, 6 },
            { 5, 7 }, { 6, 8 }, { 7, 8 }
        }

        for _, edge in ipairs(edges) do
            tool.LineRend.draw(corners[edge[1]], corners[edge[2]], options)
        end
    end

    function self.enable(options)
        self.enabled = true
        options = options or {}
        if options.raycastMode ~= nil then self.setRaycastMode(options.raycastMode) end
        if options.bodyConstraint ~= nil then self.bodyConstraint = options.bodyConstraint end
        if options.maxDistance ~= nil then self.maxDistance = options.maxDistance end
        if options.connectionRadius ~= nil then self.connectionRadius = options.connectionRadius end
        if options.previewThickness ~= nil then self.previewThickness = options.previewThickness end
        if options.previewPadding ~= nil then self.previewPadding = options.previewPadding end
        if options.previewColor ~= nil then self.previewColor = options.previewColor end
    end

    function self.disable()
        self.enabled = false
        self.raycastLookingAt = nil
        self.hit = nil
        resetCrosshair()
    end

    function self.setRaycastMode(mode)
        if mode == "DDA" or mode == "blockRaycast" or mode == "connectionRaycast" then
            self.raycastMode = mode
            return true
        end
        error("Unknown BlockSelector raycast mode: " .. tostring(mode))
    end

    function self.setBodyConstraint(bodies)
        self.bodyConstraint = bodies
    end

    function self.getTarget()
        return self.raycastLookingAt
    end

    function self.getHit()
        return self.hit
    end

    function self.reset()
        self.bodyConstraint = nil
        self.raycastLookingAt = nil
        self.hit = nil
        resetCrosshair()
    end

    -- Called after LineRend.beginFrame(), once per equipped-tool update.
    function self.client_onEquippedUpdate()
        if not self.enabled or not tool.tool:isEquipped() then
            self.raycastLookingAt = nil
            self.hit = nil
            resetCrosshair()
            return
        end

        local didHit, result = raycast()
        if not didHit or result == nil then
            self.raycastLookingAt = nil
            self.hit = nil
            resetCrosshair()
            return
        end

        local shape = result:getShape()
        if shape == nil or not sm.exists(shape) then
            self.raycastLookingAt = nil
            self.hit = nil
            resetCrosshair()
            return
        end

        self.raycastLookingAt = shape
        self.hit = result
        local hitPosition = result.pointWorld or shape:getWorldPosition()
        local distance = math.max((hitPosition - sm.camera.getPosition()):length(), 0.01)
        tool.tool:setDispersionFraction(0.45 / distance)
        tool.tool:setCrossHairAlpha(1)
        renderPreview(shape)
    end

    function self.client_onUnequip()
        self.raycastLookingAt = nil
        self.hit = nil
        resetCrosshair()
    end
end
