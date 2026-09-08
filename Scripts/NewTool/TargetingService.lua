-- Camera targeting queries. Creation geometry and body indexing are delegated
-- to CreationSpatialIndex so other selection modes can reuse the same index.

TargetingService = {}

local defaultMaxDistance = 128
local defaultConnectionRadius = 0.1

local function containsBody(bodies, body)
    if bodies == nil then return true end
    for _, allowedBody in ipairs(bodies) do
        if allowedBody == body then return true end
    end
    return false
end

function TargetingService.init(tool, spatialIndex)
    tool.TargetingService = {}
    local self = tool.TargetingService
    local index = spatialIndex

    local function raycastBody(maxDistance)
        local origin = sm.camera.getPosition()
        local direction = sm.camera.getDirection()
        return sm.physics.raycast(
            origin,
            origin + direction * maxDistance,
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

    local function raycastBlock(options)
        local didHit, result = raycastBody(options.maxDistance)
        if not didHit or result.type ~= "body" then return false, result end

        local shape = result:getShape()
        if shape == nil or shape:getInteractable() == nil then return false, result end
        if not containsBody(options.bodyConstraint, shape:getBody()) then return false, nil end
        return true, result
    end

    local function raycastConnection(options)
        local didHit, result = raycastBody(options.maxDistance)
        if not didHit then return false, result end

        local body = getHitBody(result)
        if body == nil or not containsBody(options.bodyConstraint, body) then return false, nil end

        local origin = sm.camera.getPosition()
        local direction = sm.camera.getDirection()
        local nearestShape = nil
        local nearestDistance = nil
        local radius2 = options.connectionRadius * options.connectionRadius

        for _, interactable in ipairs(body:getInteractables()) do
            local shape = interactable:getShape()
            if shape ~= nil and sm.exists(shape) then
                local offset = shape:getWorldPosition() - origin
                local distance = offset:dot(direction)
                local lateral = offset - direction * distance
                if distance >= 0 and distance <= options.maxDistance and lateral:length2() <= radius2 and
                    (nearestDistance == nil or distance < nearestDistance) then
                    nearestShape = shape
                    nearestDistance = distance
                end
            end
        end

        if nearestShape == nil then return false, nil end
        return true, makeResult(body, nearestShape, nearestShape:getWorldPosition(), nil)
    end

    local function raycastDda(options)
        local didHit, result = raycastBody(options.maxDistance)
        if not didHit then return false, result end

        local body = getHitBody(result)
        if body == nil or not containsBody(options.bodyConstraint, body) then return false, nil end

        local localAabbMin, localAabbMax = body:getLocalAabb()
        localAabbMin = localAabbMin / 4
        localAabbMax = localAabbMax / 4

        local rayPosition = result.pointLocal
        local rayDirection = sm.quat.inverse(body.worldRotation) * sm.camera.getDirection()
        rayDirection = rayDirection:safeNormalize(sm.vec3.new(1, 0, 0))
        local bodyIndex = index.get(body)
        if bodyIndex == nil then return false, nil end
        local radius = options.connectionRadius * 4
        local distanceTravelled = (result.pointWorld - sm.camera.getPosition()):length()

        for _ = 1, 2048 do
            if distanceTravelled > options.maxDistance then break end

            local voxelPosition = sm.vec3.new(
                math.floor(rayPosition.x * 4),
                math.floor(rayPosition.y * 4),
                math.floor(rayPosition.z * 4)
            ) / 4
            local shape = index.lookupInteractableVoxel(bodyIndex, voxelPosition)

            if shape ~= nil and sm.exists(shape) then
                local center = index.getShapeCenterLocal(shape)
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

            local advance = nextDistance + 0.0001
            rayPosition = rayPosition + rayDirection * advance
            distanceTravelled = distanceTravelled + advance
            if rayPosition.x < localAabbMin.x or rayPosition.x > localAabbMax.x or
                rayPosition.y < localAabbMin.y or rayPosition.y > localAabbMax.y or
                rayPosition.z < localAabbMin.z or rayPosition.z > localAabbMax.z then
                break
            end
        end

        return false, nil
    end

    function self.queryBlock(queryOptions)
        queryOptions = queryOptions or {}
        local options = {
            raycastMode = queryOptions.raycastMode or "DDA",
            bodyConstraint = queryOptions.bodyConstraint,
            maxDistance = queryOptions.maxDistance or defaultMaxDistance,
            connectionRadius = queryOptions.connectionRadius or defaultConnectionRadius
        }

        if options.raycastMode == "blockRaycast" then
            return raycastBlock(options)
        elseif options.raycastMode == "connectionRaycast" then
            return raycastConnection(options)
        elseif options.raycastMode == "DDA" then
            return raycastDda(options)
        end

        error("Unknown targeting raycast mode: " .. tostring(options.raycastMode))
    end
end
