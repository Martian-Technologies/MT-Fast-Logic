ConnectionRaycaster = class()

function ConnectionRaycaster:configure(maxDistance, connectionDotRadius, multitool)
    self.maxDistance = maxDistance + 0.5
    self.connectionDotRadius = connectionDotRadius
    self.connectionDotRadius2 = connectionDotRadius * connectionDotRadius
    self.bodyCache = {}
    self.nametagUpdate = NametagManager.createController(multitool)
end

function ConnectionRaycaster:raycastToBlock(surface)
    -- shoot raycast to get the hit position
    local hit, res = sm.physics.raycast(sm.camera.getPosition(),
    sm.camera.getPosition() + sm.camera.getDirection() * 128, sm.localPlayer.getPlayer().character)
    -- print(hit)
    -- print(res.type)
    if hit and res.type == "body" then
        local localPosition = res.pointLocal
        -- print(localPosition)
        local norm = res.normalLocal
        -- print(norm)
        if surface then
            localPosition = localPosition + norm * 0.125
        else
            localPosition = localPosition - norm * 0.125
        end
        -- print(localPosition)
        localPosition = sm.vec3.new(math.floor(localPosition.x * 4) / 4, math.floor(localPosition.y * 4) / 4,
            math.floor(localPosition.z * 4) / 4)
        localPosition = localPosition + sm.vec3.new(0.125, 0.125, 0.125)
        local bodyhit = res:getBody()
        return localPosition, bodyhit
    end
    return nil, nil
end

function ConnectionRaycaster:raycastToConnection(rayDirection, rayOrigin, bodies, originInteractable)
    local allBodies = bodies

    -- now run the raycast
    local shortestDistance = nil
    local hitBlock = nil
    local sphereToRayOrigin = nil
    local tc = nil
    local d2 = nil
    local t1c = nil
    local distance = nil

    if originInteractable ~= nil then
        -- try intersecting the ray with the origin interactable first, if we hit it, then we can skip the rest
        sphereToRayOrigin = (originInteractable:getShape():getWorldPosition() - rayOrigin)*4
        tc = sphereToRayOrigin:dot(rayDirection)
        if tc > 0 then
            d2 = sphereToRayOrigin:length2() - tc * tc
            -- print(d2)
            if math.abs(d2) < self.connectionDotRadius2 then
                -- print('step 1')
                t1c = math.sqrt(self.connectionDotRadius * self.connectionDotRadius - d2)
                distance = tc - t1c
                hitBlock = originInteractable
                shortestDistance = distance
            end
        end
    end
    if hitBlock ~= nil then
        local res = {
            pointWorld = hitBlock:getShape():getWorldPosition(),
            originWorld = rayOrigin,
            type = "body",
            getShape = function()
                return hitBlock:getShape()
            end,
            getJoint = function()
                return hitBlock:getJoint()
            end
        }
        return true, res
    end
    local allInteractables, allInteractableLocations = self:getInteractablePositionsFromBodies(allBodies)
    for i = 1, #allInteractableLocations do
        -- print((allInteractableLocations[i] - rayOrigin):length2())
        if (allInteractableLocations[i] - rayOrigin*4):length2() > 1000 then
            goto continue
        end
        sphereToRayOrigin = allInteractableLocations[i] - rayOrigin * 4
        tc = sphereToRayOrigin:dot(rayDirection)
        if tc < 0 then
            goto continue
        end
        d2 = sphereToRayOrigin:length2() - tc * tc
        if math.abs(d2) > self.connectionDotRadius2 then
            goto continue
        end
        t1c = math.sqrt(self.connectionDotRadius * self.connectionDotRadius - d2)
        distance = tc - t1c
        if shortestDistance == nil or distance < shortestDistance then
            shortestDistance = distance
            hitBlock = allInteractables[i]
        end
        ::continue::
    end
    if hitBlock == nil then
        return false, nil
    end
    local res = {
        pointWorld = hitBlock:getShape():getWorldPosition(),
        originWorld = rayOrigin,
        type = "body",
        getShape = function()
            return hitBlock:getShape()
        end,
        getJoint = function()
            return hitBlock:getJoint()
        end
    }
    return true, res
end

function ConnectionRaycaster:cleanCache()
    -- remove all entries from the cache that are older than 1 second
    local currentTime = os.clock()
    for k, v in pairs(self.bodyCache) do
        if currentTime - v.time > 1 then
            self.bodyCache[k] = nil
        end
    end
end

function ConnectionRaycaster:getInteractablePositionsFromBody(body)
    local bodyID = body:getId()
    -- if the body is in the cache, return the cached interactables
    -- if self.bodyCache[bodyID] then
    --     local cachedData = self.bodyCache[bodyID]
    --     -- check the amount of time since the cache was last updated
    --     if os.clock() - cachedData.time < 1 then
    --         return cachedData.interactables, cachedData.interactablePositions
    --     end
    -- end
    -- print("cache miss")
    local bodyInteractables = body:getInteractables()
    -- local bodyJoints = body:getJoints()
    local allInteractables = {}
    for i = 1, #bodyInteractables do
        if bodyInteractables[i] ~= self.interactable and bodyInteractables[i] ~= self.connectFrom then
            allInteractables[#allInteractables + 1] = bodyInteractables[i]
        end
    end
    -- for i = 1, #bodyJoints do
    --     allInteractables[#allInteractables + 1] = bodyJoints[i]
    -- end
    local allInteractableLocations = {}
    local toRemove = {}
    local offset = 0
    for i = 1, #allInteractables do
        if allInteractables[i] == nil then
            toRemove[#toRemove + 1] = i
            offset = offset + 1
        -- elseif table.find(allInteractables[i], 'shape') == nil then
        --     toRemove[#toRemove + 1] = allInteractables[i]
        --     offset = offset + 1
        else
            allInteractableLocations[i - offset] = allInteractables[i]:getShape():getWorldPosition() * 4
        end
    end
    for i = 1, #toRemove do
        table.removeValue(allInteractables, toRemove[i])
    end
    -- self.bodyCache[bodyID] = {
    --     interactables = allInteractables,
    --     interactablePositions = allInteractableLocations,
    --     time = os.clock()
    -- }
    return allInteractables, allInteractableLocations
end

function ConnectionRaycaster:getInteractablePositionsFromBodies(bodies)
    self:cleanCache()
    local allInteractablePositions = {}
    local allInteractables = {}
    for i = 1, #bodies do
        local bodyInteractables, bodyInteractablePositions = self:getInteractablePositionsFromBody(bodies[i])
        for j = 1, #bodyInteractables do
            allInteractablePositions[#allInteractablePositions + 1] = bodyInteractablePositions[j]
            allInteractables[#allInteractables + 1] = bodyInteractables[j]
        end
    end
    return allInteractables, allInteractablePositions
end

function ConnectionRaycaster:raymarchToConnection(rayDirection, rayOrigin, bodies)
    local allBodies = bodies
    local allInteractables = self:getInteractablePositionsFromBodies(allBodies)

    local function getDistance(point1, point2)
        return (point1 - point2):length()
    end

    local rayPosition = rayOrigin * 4
    local hitBlock = nil
    local timesran = 0
    local distanceCovered = 0
    while true do
        timesran = 1 + timesran
        local closestPointIndex = -1
        local closestPointDistance = -1
        for i = 1, #allInteractableLocations do
            local distanceToRay = getDistance(rayPosition, allInteractableLocations[i])
            if closestPointDistance > distanceToRay or closestPointIndex == -1 then
                closestPointDistance = distanceToRay
                closestPointIndex = i
            end
        end

        if closestPointDistance < self.connectionDotRadius then -- if the ray hits a connection dot
            hitBlock = allInteractables[closestPointIndex]
            break
        elseif distanceCovered >= self.maxDistance then -- if the ray is at the end of its length
            break
        else
            rayPosition = rayPosition + rayDirection * closestPointDistance
            distanceCovered = distanceCovered + closestPointDistance
        end

        if timesran >= 400 then
            print("-----------  error  -----------")
            print("Connecter.lua raycast failed :(")
            break
        end
    end
    if (hitBlock == nil) then
        return false, nil
    end
    local res = {
        pointWorld = hitBlock:getShape():getWorldPosition(),
        originWorld = rayOrigin,
        type = "body",
        getShape = function()
            return hitBlock:getShape()
        end,
        getJoint = function()
            return hitBlock:getJoint()
        end
    }
    return true, res
end

local function splitString(str, sep)
    local sep, fields = sep or ":", {}
    local out = {}
    local line = ""
    for i = 1, #str do
        if str:sub(i, i) == sep then
            table.insert(out, line)
            line = ""
        else
            line = line .. str:sub(i, i)
        end
    end
    if line ~= "" then
        table.insert(out, line)
    end
    return out
end

local function parseTableAsNumbers(tbl)
    local out = {}
    for i = 1, #tbl do
        out[i] = tonumber(tbl[i])
    end
    return out
end

function ConnectionRaycaster:rayTraceDDA(rayOrigin, rayDirection, bodyConstraint, connectionDotRad)
    local connectionDotRadiusGiven = self.connectionDotRadius
    if connectionDotRad ~= nil then
        connectionDotRadiusGiven = connectionDotRad
    end
    -- go till we hit the first body
    local hit, res = sm.physics.raycast(rayOrigin, rayOrigin + rayDirection * 128, sm.localPlayer.getPlayer().character)
    if not hit then
        return false, nil
    end
    if res.type ~= "body" then
        return false, resh
    end
    local body = res:getBody()
    -- check if body is in the bodyConstraint table
    local found = false
    if bodyConstraint ~= nil then
        for i = 1, #bodyConstraint do
            if body == bodyConstraint[i] then
                found = true
                break
            end
        end
    else
        found = true
    end
    if not found then
        return false, nil
    end
    local localAabbMin, localAabbMax = body:getLocalAabb()
    local localAabbMin = localAabbMin / 4
    local localAabbMax = localAabbMax / 4
    local rayPos = res.pointLocal
    -- ray direction is in world space, convert it to local space
    local rayDirection = sm.quat.inverse(body.worldRotation) * rayDirection
    -- table.insert(tags, {
    --     pos = body:transformPoint(rayPos+rayDirection),
    --     color = sm.color.new(1, 1, 1, 1),
    --     txt = "•"
    -- })
    -- if true then
    --     return false, nil
    -- end
    local stepX = 1
    local stepY = 1
    local stepZ = 1
    if rayDirection.x < 0 then
        stepX = -1
    end
    if rayDirection.y < 0 then
        stepY = -1
    end
    if rayDirection.z < 0 then
        stepZ = -1
    end

    local voxelMap = MTMultitoolLib.getVoxelMapMultidotblocks(body)
    -- local tags = {}
    -- -- go through every entry in the voxel map
    -- for k, v in pairs(voxelMap) do
    --     -- k is a string containing the local coordinates of the voxel
    --     local coordTable = parseTableAsNumbers(splitString(k, ";"))
    --     local pos = sm.vec3.new(coordTable[1], coordTable[2], coordTable[3])
    --     table.insert(tags, {
    --         pos = body:transformPoint(pos),
    --         color = sm.color.new(1, 1, 1, 1),
    --         txt = "•"
    --     })
    -- end

    -- print('CASTING RAY')
    -- print(rayDirection)
    local halfBlock = sm.vec3.new(0.125, 0.125, 0.125)
    while true do --DDA loop
        -- check if the ray hits a voxel
        local position = sm.vec3.new(math.floor(rayPos.x * 4), math.floor(rayPos.y * 4), math.floor(rayPos.z * 4)) / 4
        -- table.insert(tags, {
        --     pos = body:transformPoint(position),
        --     color = sm.color.new(0, 1, 0, 1),
        --     txt = "[ ]"
        -- })
        local indexString = position.x .. ";" .. position.y .. ";" .. position.z
        local hitBlock = voxelMap[indexString]
        if hitBlock ~= nil and sm.exists(hitBlock) then
            -- check connection dot hit
            -- print(hitBlock)
            local bb = hitBlock:getBoundingBox()
            local xAxis = hitBlock:getXAxis()
            local yAxis = hitBlock:getYAxis()
            local zAxis = hitBlock:getZAxis()
            local hitBlockPos = hitBlock:getLocalPosition() / 4 + xAxis * bb.x / 2 + yAxis * bb.y / 2 + zAxis * bb.z / 2
            -- print(position-halfBlock)
            -- print(hitBlockPos)
            local sphereToRayOrigin = (hitBlockPos - rayPos) * 4
            local tc = sphereToRayOrigin:dot(rayDirection)
            if tc > 0 then
                local d2 = sphereToRayOrigin:length2() - tc * tc
                -- print("RADIUS")
                -- print(math.min(bb.x, bb.y, bb.z)*4)
                -- local rad = self.connectionDotRadius * math.min(bb.x, bb.y, bb.z)*4
                local rad = math.min(bb.x, bb.y, bb.z) * 2
                -- print(rad)
                local rad2 = rad * rad
                -- print(self.connectionDotRadius2 * math.min(bb.x, bb.y, bb.z)*4)
                if math.abs(d2) < rad2 then
                    local t1c = math.sqrt(connectionDotRadiusGiven * connectionDotRadiusGiven - d2)
                    local distance = tc - t1c
                    local res = {
                        pointWorld = body:transformPoint(hitBlockPos),
                        originWorld = rayOrigin,
                        type = "body",
                        getShape = function()
                            return hitBlock
                        end,
                    }
                    -- self.nametagUpdate(tags)
                    return true, res
                end
            end
        end
        local tMaxX = 0
        local tMaxY = 0
        local tMaxZ = 0
        -- print(rayDirection)
        -- find tMax until the next voxel (voxels are 0.25x0.25x0.25)
        local tMax = nil
        if rayDirection.x ~= 0 then
            if stepX == 1 then
                tMaxX = (math.floor(rayPos.x * 4 + 1) - rayPos.x * 4) / rayDirection.x / 4
            else
                tMaxX = (rayPos.x * 4 - math.floor(rayPos.x * 4)) / -rayDirection.x / 4
            end
            tMax = tMaxX
        end
        if rayDirection.y ~= 0 then
            if stepY == 1 then
                tMaxY = (math.floor(rayPos.y * 4 + 1) - rayPos.y * 4) / rayDirection.y / 4
            else
                tMaxY = (rayPos.y * 4 - math.floor(rayPos.y * 4)) / -rayDirection.y / 4
            end
            if tMax == nil or tMaxY < tMax then
                tMax = tMaxY
            end
        end
        if rayDirection.z ~= 0 then
            if stepZ == 1 then
                tMaxZ = (math.floor(rayPos.z * 4 + 1) - rayPos.z * 4) / rayDirection.z / 4
            else
                tMaxZ = (rayPos.z * 4 - math.floor(rayPos.z * 4)) / -rayDirection.z / 4
            end
            if tMax == nil or tMaxZ < tMax then
                tMax = tMaxZ
            end
        end
        -- print(tMaxX)
        -- print(tMaxY)
        -- print(tMaxZ)
        -- print('-------------------------')
        -- move the ray to the next voxel
        rayPos = rayPos + rayDirection * (tMax+0.01)
        -- check if out ray is outside the body
        if (rayPos.x < localAabbMin.x) or (rayPos.x > localAabbMax.x) or
            (rayPos.y < localAabbMin.y) or (rayPos.y > localAabbMax.y) or
            (rayPos.z < localAabbMin.z) or (rayPos.z > localAabbMax.z) then
            break
        end
    end
    -- self.nametagUpdate(tags)

    return false, nil
end