sm.HoveringUI.Cursor = sm.HoveringUI.Cursor or {}
local Cursor = sm.HoveringUI.Cursor

-- resets all state on the Cursor
function Cursor.reset()
    Cursor.primaryState = false
    Cursor.secondaryState = false
    Cursor.forceBuild = false
    Cursor.doCollisions = true
end

Cursor.reset()

-- Gets the cursor position local to player pos and ui rotation
function Cursor.getPosition()
    return sm.quat.inverse(sm.HoveringUI.rotation) * sm.camera.getDirection() * 25
end

-- Gets the cursor position on the screen pitch and yaw
function Cursor.getScreenPosition()
    local camDirection =  sm.quat.inverse(sm.HoveringUI.rotation) * sm.camera.getDirection()
    return {
        pitch = math.atan2(camDirection.x, math.sqrt(
            camDirection.y*camDirection.y +
            camDirection.x*camDirection.x
        )),
        yaw = math.atan2(camDirection.y, camDirection.x)
    }
end

-- called by hovering ui manager when player starts/stops clicking
function Cursor.setStates(primaryState, secondaryState, forceBuild)
    Cursor.state = state
end

-- sets if the cursor can collide with elements (this means it wont call touchedCursor)
function Cursor.setDoCollisions(doCollisions)
    Cursor.doCollisions = doCollisions
end

-- called by hovering ui manager every client frame update
function Cursor.update()
end

function Cursor.isCollidingWithElement(element)
    if (not Cursor.doCollisions) then return false end
    return element.isCollidingWithPos(element, Cursor.getScreenPosition())
end
