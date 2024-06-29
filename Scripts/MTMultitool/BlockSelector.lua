BlockSelector = {}

dofile("$CONTENT_DATA/Scripts/MTMultitool/ConnectionRaycaster.lua")

local PlasticBLK = sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a")
function BlockSelector.inject(multitool)
    multitool.BlockSelector = {}
    local self = multitool.BlockSelector
    self.visShape = nil
    self.tool = multitool.tool
    self.visualization = sm.effect.createEffect("ShapeRenderable")
    self.visualization:setParameter("visualization", true)
    print("created visualization")
    ConnectionRaycaster:configure(128, 0.4, multitool)
    self.vertexPoints = {}
    self.bodyConstraint = nil
    self.raycastLookingAt = nil
    self.enabled = true
end

function BlockSelector.addVertexPoints(multitool)
    local self = multitool.BlockSelector
    return self.vertexPoints
end

function BlockSelector.client_onUnequip(multitool)
    local self = multitool.BlockSelector
	self.visualization:stop()
end

function BlockSelector.getEffectData(item)
    local isShape = type(item) == "Shape"
    local effectPos
    local effectScale = sm.vec3.one() / 4
    local jointType
    local uuid = item.uuid

    local lifted
    if isShape then
        lifted = item.body:isOnLift()
    else
        lifted = item.shapeA.body:isOnLift()
    end

    local itemWorldPosition = item:getWorldPosition()
    local bb = item:getBoundingBox()

    if isShape then
        effectScale = item.isBlock and bb + sm.vec3.new(0.01, 0.01, 0.01) or effectScale

        if item.isBlock then
            uuid = PlasticBLK
        end

        if effectScale.x == 0 then effectScale.x = 0.0001 end
        if effectScale.y == 0 then effectScale.y = 0.0001 end
        if effectScale.z == 0 then effectScale.z = 0.0001 end
        effectPos = item:getInterpolatedWorldPosition()
    else
        effectPos = itemWorldPosition
        jointType = item:getType()

        local isPiston = jointType == "piston"
        local pistonLength
        if isPiston then
            pistonLength = item:getLength()
        end

        local rot = sm.quat.getAt(item:getWorldRotation())
        if jointType == "unknown" then
            local len = math.max(math.abs(bb.x), math.abs(bb.y), math.abs(bb.z))
            local offset = len / 2 - 0.125

            effectPos = itemWorldPosition + rot * offset
        elseif isPiston and pistonLength > 1.05 and not lifted then
            uuid = PlasticBLK

            effectScale = sm.vec3.new(0.25, 0.25, pistonLength / 4)

            local real = item.worldPosition
            local fake = real + rot * pistonLength / 4
            local dir = fake - real

            effectPos = itemWorldPosition + dir / 2 - (rot * 0.125)
        end
    end
    local absShape = isShape and item or item.shapeA
    local velocity = absShape.velocity
    effectPos = effectPos + velocity * 0.007

    local rot
    if isShape then
        local at = (absShape:getInterpolatedAt() + absShape.body.angularVelocity:rotate(-math.rad(90), absShape:getInterpolatedAt()) * 0.008)
        :normalize()
        local right = (absShape:getInterpolatedRight() + absShape.body.angularVelocity:rotate(-math.rad(90), absShape:getInterpolatedRight()) * 0.008)
        :normalize()
        local up = (absShape:getInterpolatedUp() + absShape.body.angularVelocity:rotate(-math.rad(90), absShape:getInterpolatedUp()) * 0.008)
        :normalize()

        rot = BlockSelector.betterQuatRotation(at, right, up)
    else
        rot = item:getWorldRotation()
    end

    return effectPos, rot, effectScale, uuid
end

function BlockSelector.raycast(multitool)
    local self = multitool.BlockSelector
    if not self.enabled then
        return false, nil
    end
    if multitool.raycastMode == 'connectionRaycast' then
        local rayRange = 128
        local castHit, castRes = sm.physics.raycast(sm.camera.getPosition(),
            sm.camera.getPosition() + sm.camera.getDirection() * rayRange, sm.localPlayer.getPlayer().character)
        local bodies = {}
        local originInteractable = nil
        if castHit then
            -- if what we hit is on a body, add it to the list of bodies
            if castRes.type == "body" then
                if self.bodyConstraint ~= nil and table.find(self.bodyConstraint, castRes:getShape():getBody()) == nil then
                    return false, nil
                end
                table.insert(bodies, castRes:getShape():getBody())
                local interactible = castRes:getShape():getInteractable()
                if interactible then
                    originInteractable = interactible
                end
            end
        else
            return false, nil
        end
        local hit, res = ConnectionRaycaster:raycastToConnection(sm.camera.getDirection(), castRes.pointWorld,
            bodies, originInteractable)
        return hit, res
    elseif multitool.raycastMode == 'blockRaycast' then
        local rayRange = 128
        local castHit, castRes = sm.physics.raycast(sm.camera.getPosition(),
            sm.camera.getPosition() + sm.camera.getDirection() * rayRange, sm.localPlayer.getPlayer().character)
        if not castHit then
            return false, castRes
        end
        -- check that the hit is a body
        if castRes.type ~= "body" then
            return false, castRes
        end
        if self.bodyConstraint ~= nil and table.find(self.bodyConstraint, castRes:getShape():getBody()) == nil then
            return false, nil
        end
        -- check that the body is a shape
        local shape = castRes:getShape()
        if not shape then
            return false, castRes
        end
        -- check that the shape is interactable
        local interactable = shape:getInteractable()
        if not interactable then
            return false, castRes
        end
        return true, castRes
    elseif multitool.raycastMode == 'DDA' then
        local hit, res = ConnectionRaycaster:rayTraceDDA(sm.camera.getPosition(), sm.camera.getDirection(), self.bodyConstraint)
        return hit, res
    end
end

function BlockSelector.client_onUpdate(multitool)
    local self = multitool.BlockSelector
    -- if self.visualization == nil then
    --     -- print("Visualization is nil")
    --     return
    -- end
    if self.tool:isLocal() then
        self.raycastLookingAt = nil
        if not self.tool:isEquipped() then
            -- wipe gui points
            self.vertexPoints = {}
            return
        end
        if self.visualization:isPlaying() then
            self.visualization:stop()
        end
        local hit, res = BlockSelector.raycast(multitool)
        if not hit then
            self.visShape = nil
            self.vertexPoints = {}
            self.tool:setDispersionFraction(0)
            self.tool:setCrossHairAlpha(0.3)
            return
        end
        if (not res) then -- this will never happen, but it makes vscode happy
            return
        end
        local hitPosition = res.pointWorld
        local rayOrigin = sm.camera.getPosition()
        local rayDistance = (hitPosition - rayOrigin):length()
        -- set the dispersion fraction such that when taking perspective into account, the dispersion is 0.1 at the hit position
        -- when further away, the dispersion is smaller because the object is smaller in the screen
        local dispersionFraction = 0.45 / rayDistance
        self.tool:setDispersionFraction(dispersionFraction)
        self.tool:setCrossHairAlpha(1)

        local type_ = res.type
        if (type_ ~= "body") then
            self.visShape = nil
        end

        local shape
        shape = type_ == "body" and res:getShape()

        if shape and hit then
            self.visShape = shape
        end
        if (not (self.visShape and sm.exists(self.visShape))) then
            return true
        end
        self.raycastLookingAt = self.visShape
        local pos, rot, scale, uuid = BlockSelector.getEffectData(self.visShape)

        self.visualization:setPosition(pos)
        self.visualization:setParameter("uuid", uuid)
        self.visualization:setScale(scale)
        self.visualization:setRotation(rot)
        self.visualization:start()

        -- local distance = (sm.camera.getPosition() - hitPosition):length()
        local bb = self.visShape:getBoundingBox()
        local pos = self.visShape:getWorldPosition()
        local rot = self.visShape:getWorldRotation()
        local at = rot * sm.vec3.new(1, 0, 0)
        local right = rot * sm.vec3.new(0, 1, 0)
        local up = rot * sm.vec3.new(0, 0, 1)
        local halfSize = bb / 2
        local halfSizeAt = at * halfSize.x
        local halfSizeRight = right * halfSize.y
        local halfSizeUp = up * halfSize.z
        local invColor = sm.color.new(1, 1, 1, 1) - self.visShape:getColor()
        local posBottomLeftBack = pos - halfSizeAt - halfSizeRight - halfSizeUp
        local posBottomLeftFront = pos - halfSizeAt - halfSizeRight + halfSizeUp
        local posBottomRightBack = pos - halfSizeAt + halfSizeRight - halfSizeUp
        local posBottomRightFront = pos - halfSizeAt + halfSizeRight + halfSizeUp
        local posTopLeftBack = pos + halfSizeAt - halfSizeRight - halfSizeUp
        local posTopLeftFront = pos + halfSizeAt - halfSizeRight + halfSizeUp
        local posTopRightBack = pos + halfSizeAt + halfSizeRight - halfSizeUp
        local posTopRightFront = pos + halfSizeAt + halfSizeRight + halfSizeUp
        local verteces = {}
        local interSteps = 16 * bb.z
        for i = 0, interSteps do
            -- interpolate between the Back and Front positions
            local posLeftBack = posBottomLeftBack * (interSteps - i) / interSteps + posTopLeftBack * i / interSteps
            local posRightBack = posBottomRightBack * (interSteps - i) / interSteps + posTopRightBack * i / interSteps
            local posLeftFront = posBottomLeftFront * (interSteps - i) / interSteps + posTopLeftFront * i / interSteps
            local posRightFront = posBottomRightFront * (interSteps - i) / interSteps + posTopRightFront * i / interSteps
            table.insert(verteces, { pos = posLeftBack, color = invColor, txt = nil })
            table.insert(verteces, { pos = posRightBack, color = invColor, txt = nil })
            table.insert(verteces, { pos = posLeftFront, color = invColor, txt = nil })
            table.insert(verteces, { pos = posRightFront, color = invColor, txt = nil })
        end
        interSteps = 16 * bb.y
        for i = 0, interSteps do
            -- interpolate between the Left and Right positions
            local posBottomBack = posBottomLeftBack * (interSteps - i) / interSteps + posBottomRightBack * i / interSteps
            local posTopBack = posTopLeftBack * (interSteps - i) / interSteps + posTopRightBack * i / interSteps
            local posBottomFront = posBottomLeftFront * (interSteps - i) / interSteps +
                posBottomRightFront * i / interSteps
            local posTopFront = posTopLeftFront * (interSteps - i) / interSteps + posTopRightFront * i / interSteps
            table.insert(verteces, { pos = posBottomBack, color = invColor, txt = nil })
            table.insert(verteces, { pos = posTopBack, color = invColor, txt = nil })
            table.insert(verteces, { pos = posBottomFront, color = invColor, txt = nil })
            table.insert(verteces, { pos = posTopFront, color = invColor, txt = nil })
        end
        interSteps = 16 * bb.x
        for i = 0, interSteps do
            -- interpolate between the Bottom and Top positions
            local posLeftBottom = posBottomLeftBack * (interSteps - i) / interSteps + posBottomLeftFront * i / interSteps
            local posRightBottom = posBottomRightBack * (interSteps - i) / interSteps +
            posBottomRightFront * i / interSteps
            local posLeftTop = posTopLeftBack * (interSteps - i) / interSteps + posTopLeftFront * i / interSteps
            local posRightTop = posTopRightBack * (interSteps - i) / interSteps + posTopRightFront * i / interSteps
            table.insert(verteces, { pos = posLeftBottom, color = invColor, txt = nil })
            table.insert(verteces, { pos = posRightBottom, color = invColor, txt = nil })
            table.insert(verteces, { pos = posLeftTop, color = invColor, txt = nil })
            table.insert(verteces, { pos = posRightTop, color = invColor, txt = nil })
        end
        -- send a raycast from camera to the hit position, and add a color parameter to the vertex to be the opposite of the color of what it hits
        -- if it hits nothing, do nothing
        -- if it hits a body, get the color of the body and subtract it from 1 to get the opposite color
        local function doRaycast(origin, target)
            local hit, res = sm.physics.raycast(origin, target * 2 - origin, sm.localPlayer.getPlayer().character)
            if hit and res.type == "body" then
                local color = sm.color.new(1, 1, 1, 1) - res:getShape():getColor()
                return color
            end
            return sm.color.new(1, 1, 1, 1)
        end
        -- for i, vertex in pairs(verteces) do
        --     local color = doRaycast(sm.camera.getPosition(), vertex.pos*0.9+(pos+halfSizeAt+halfSizeRight+halfSizeUp)*0.1)
        --     verteces[i].color = color
        -- end
        self.vertexPoints = verteces
    end
end

function BlockSelector.betterQuatRotation(forward, right, up)
    forward                        = forward:safeNormalize(sm.vec3.new(1, 0, 0))
    right                          = right:safeNormalize(sm.vec3.new(0, 0, 1))
    up                             = up:safeNormalize(sm.vec3.new(0, 1, 0))

    local m11                      = right.x; local m12 = right.y; local m13 = right.z
    local m21                      = forward.x; local m22 = forward.y; local m23 = forward.z
    local m31                      = up.x; local m32 = up.y; local m33 = up.z

    local biggestIndex             = 0
    local fourBiggestSquaredMinus1 = m11 + m22 + m33

    local fourXSquaredMinus1       = m11 - m22 - m33
    if fourXSquaredMinus1 > fourBiggestSquaredMinus1 then
        fourBiggestSquaredMinus1 = fourXSquaredMinus1
        biggestIndex = 1
    end

    local fourYSquaredMinus1 = m22 - m11 - m33
    if fourYSquaredMinus1 > fourBiggestSquaredMinus1 then
        fourBiggestSquaredMinus1 = fourYSquaredMinus1
        biggestIndex = 2
    end

    local fourZSquaredMinus1 = m33 - m11 - m22
    if fourZSquaredMinus1 > fourBiggestSquaredMinus1 then
        fourBiggestSquaredMinus1 = fourZSquaredMinus1
        biggestIndex = 3
    end

    local biggestVal = math.sqrt(fourBiggestSquaredMinus1 + 1.0) * 0.5
    local mult = 0.25 / biggestVal

    if biggestIndex == 1 then
        return sm.quat.new(biggestVal, (m12 + m21) * mult, (m31 + m13) * mult, (m23 - m32) * mult)
    elseif biggestIndex == 2 then
        return sm.quat.new((m12 + m21) * mult, biggestVal, (m23 + m32) * mult, (m31 - m13) * mult)
    elseif biggestIndex == 3 then
        return sm.quat.new((m31 + m13) * mult, (m23 + m32) * mult, biggestVal, (m12 - m21) * mult)
    end

    return sm.quat.new((m23 - m32) * mult, (m31 - m13) * mult, (m12 - m21) * mult, biggestVal)
end

