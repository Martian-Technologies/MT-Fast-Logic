sm.HoveringUI.BaseElement = sm.HoveringUI.BaseElement or {}
local BaseElement = sm.HoveringUI.BaseElement

-- called when the element is created (make sure to also call the base one)
function BaseElement.new()
    -- the uuid is needed for deleting certain elements
    local self = {}
    self.uuid = string.uuidLarge()
    return self
end

-- called every client frame update
function BaseElement.update(self)
end

-- called to ask the object if it is colliding with this positions
function BaseElement.isCollidingWithPos(self, pos)
    return false
end

-- return a array of tables to be rendered where each table has
-- {
--     pos = the position to render at {pitch, yaw, layer (you can leave layer nil)} (this is a array),
--     txt = the text to display,
--     color = the color hex you want to display
-- }
function BaseElement.getRenderData(self)
    return {}
end