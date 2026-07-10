-- Shared immediate-mode visuals for selection components.

SelectionRenderer = {}

local defaultPreviewThickness = 0.01
local defaultPreviewPadding = 0.006

function SelectionRenderer.init(tool)
    tool.SelectionRenderer = {}
    local self = tool.SelectionRenderer

    function self.beginFrame()
        tool.tool:setDispersionFraction(0)
        tool.tool:setCrossHairAlpha(0.3)
    end

    function self.showTarget(result)
        if result == nil then return end
        local shape = result:getShape()
        if shape == nil or not sm.exists(shape) then return end

        local hitPosition = result.pointWorld or shape:getWorldPosition()
        local distance = math.max((hitPosition - sm.camera.getPosition()):length(), 0.01)
        tool.tool:setDispersionFraction(0.45 / distance)
        tool.tool:setCrossHairAlpha(1)
    end

    function self.drawShape(shape, options)
        if shape == nil or not sm.exists(shape) then return end

        options = options or {}
        local bounds = shape:getBoundingBox()
        local position = shape:getWorldPosition()
        local rotation = shape:getWorldRotation()
        local padding = options.padding or defaultPreviewPadding
        local at = rotation * sm.vec3.new(1, 0, 0)
        local right = rotation * sm.vec3.new(0, 1, 0)
        local up = rotation * sm.vec3.new(0, 0, 1)
        local halfAt = at * (bounds.x / 2 + padding)
        local halfRight = right * (bounds.y / 2 + padding)
        local halfUp = up * (bounds.z / 2 + padding)
        local color = options.color
        if color == nil then
            local shapeColor = shape:getColor()
            color = sm.color.new(1 - shapeColor.r, 1 - shapeColor.g, 1 - shapeColor.b, 1)
        end
        local lineOptions = {
            color = color,
            thickness = options.thickness or defaultPreviewThickness
        }

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
            tool.LineRend.draw(corners[edge[1]], corners[edge[2]], lineOptions)
        end
    end
end
