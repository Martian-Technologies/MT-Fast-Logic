VertexRenderer = {}

function VertexRenderer.inject(multitool)
    multitool.VertexRenderer = {}
    local self = multitool.VertexRenderer
    self.points = {}
    self.subscriptions = {}
end

function VertexRenderer.client_onUpdate(multitool)
    local self = multitool.VertexRenderer
    local verteces = {}
    for _, func in pairs(self.subscriptions) do
        local newVertices = func()
        if (newVertices ~= nil) then
            for _, vertex in pairs(newVertices) do
                table.insert(verteces, vertex)
            end
        end
    end
    VertexRenderer.cl_pointsWipe(self, #verteces)
    VertexRenderer.cl_setGUI(self, verteces)
end

function VertexRenderer.subscribe(multitool, func)
    table.insert(multitool.VertexRenderer.subscriptions, func)
end

function VertexRenderer.cl_pointsWipe(self, lengthConstraint)
    if (self.points == nil) then
        return
    end
    -- if the length constraint is not met, remove the last points
    if (lengthConstraint ~= nil) then
        while (#self.points > lengthConstraint) do
            local point = table.remove(self.points)
            point:destroy()
        end
    else
        for i = 1, #self.points do
            local point = table.remove(self.points)
            point:destroy()
        end
    end
end

function VertexRenderer.toHexNoAlpha(color)
    -- drop the last 2 chars of :getHexStr()
    return color:getHexStr():sub(1, -3)
  end


function VertexRenderer.cl_setGUI(self, vertices)
    -- get camera position
    local camPos = sm.camera.getPosition()
    -- dots decreasing in size
    local scaleConstant = 41 * 0.95
    local dots = {"●", "•", "·"}
    local offsets = { 0.02, 0.02, 0.02 }
    local distanceMargin = { scaleConstant/41, scaleConstant/23, scaleConstant/11 }
    -- print(vertices)
    for i = 1, #vertices do
        if (i > #self.points) then
            local point = sm.gui.createNameTagGui()
            point:open()
            table.insert(self.points, point)
        end
        local distance = (camPos - vertices[i].pos):length()
        if (vertices[i].txt ~= nil) then
            self.points[i]:setText("Text", "#" .. VertexRenderer.toHexNoAlpha(vertices[i].color) .. vertices[i].txt)
        else
            local dotIndex = 1
            for j = 1, #distanceMargin do
                if (distance > distanceMargin[j]) then
                    dotIndex = j
                end
            end
            self.points[i]:setText("Text", "#" .. VertexRenderer.toHexNoAlpha(vertices[i].color) .. dots[dotIndex])
        end
        self.points[i]:setWorldPosition(vertices[i].pos - RangeOffset.rangeOffset * distance)
    end
end