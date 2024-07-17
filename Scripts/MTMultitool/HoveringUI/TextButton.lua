sm.HoveringUI.TextButton = sm.HoveringUI.TextButton or {}
local HoveringUI = sm.HoveringUI
local TextButton = HoveringUI.TextButton
local BaseElement = HoveringUI.BaseElement
local Cursor = HoveringUI.Cursor

-- called when the element is created (make sure to also call the base one)
function TextButton.new(actionFunc, text, toolTip, color, collisionWidth, collisionHight, yaw, pitch, layer)
    local self = BaseElement.new()
    self.pos = {yaw=yaw, pitch=pitch, layer=layer}
    self.color = color
    self.hover = false
    self.pressed = false
    self.actionFunc = actionFunc
    self.collisionWidth = collisionWidth
    self.collisionHight = collisionHight
    return self
end

function TextButton.update(self)
    if Cursor.isCollidingWithElement(self) then
        if Cursor.primaryState then
            if not self.pressed then
                self.actionFunc()
                self.pressed = true
            end
        else
            self.pressed = false
        end
        self.hover = true
    else
        self.pressed = false
        self.hover = false
    end
end

-- called to ask the object if it is colliding with this positions
function TextButton.isCollidingWithPos(self, pos)
    return HoveringUI.doPointBoxCollision(pos, self.pos, self.collisionWidth. self.collisionHight)
end

-- return a array of tables to be rendered where each table has
-- {
--     pos = the position to render at {pitch=pitch, yaw=yaw, layer=layer (you can leave layer nil)},
--     txt = the text to display,
--     color = the color hex you want to display
-- }
function TextButton.getRenderData(self)
    return {{self.pos, self.text, self.color}}
end