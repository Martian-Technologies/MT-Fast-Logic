VertexRenderer = {}

local circleUuid = sm.uuid.new("18d15b07-479f-4558-b78e-c000a3b16d4c")
local circleModelRadius = 0.5
local defaultRadius = 0.015
local maxSparePoints = 256
local modelNormal = sm.vec3.new(1, 0, 0)
local defaultColor = sm.color.new(1, 1, 1, 1)

local function stopPoint(point)
    if point.visible then
        point.effect:stop()
        point.visible = false
    end
end

local function cleanPreviousRenderer(multitool)
    local previous = multitool.VertexRenderer
    if previous == nil or previous.points == nil then
        return
    end

    for _, point in ipairs(previous.points) do
        if type(point) == "table" then
            point.effect:destroy()
        else
            point:destroy()
        end
    end
end

function VertexRenderer.inject(multitool)
    cleanPreviousRenderer(multitool)
    multitool.VertexRenderer = {}
    local self = multitool.VertexRenderer
    self.points = {}
    self.activeCount = 0
    self.subscriptions = {}
end

function VertexRenderer.subscribe(multitool, func)
    local subscriptions = multitool.VertexRenderer.subscriptions
    table.insert(subscriptions, func)

    return function()
        for i, subscription in ipairs(subscriptions) do
            if subscription == func then
                table.remove(subscriptions, i)
                return
            end
        end
    end
end

function VertexRenderer.createSource(multitool)
    local source = {
        vertices = {}
    }

    source.unsubscribe = VertexRenderer.subscribe(multitool, function()
        return source.vertices
    end)

    function source:set(vertices)
        self.vertices = vertices or {}
    end

    function source:clear()
        self.vertices = {}
    end

    function source:destroy()
        self:clear()
        if self.unsubscribe ~= nil then
            self.unsubscribe()
            self.unsubscribe = nil
        end
    end

    return source
end

local function createPoint()
    local effect = sm.effect.createEffect("ShapeRenderable")
    effect:setParameter("uuid", circleUuid)
    return {
        effect = effect,
        visible = false
    }
end

local function collectVertices(self)
    local vertices = {}
    for _, func in ipairs(self.subscriptions) do
        local newVertices = func()
        if newVertices ~= nil then
            for _, vertex in ipairs(newVertices) do
                table.insert(vertices, vertex)
            end
        end
    end
    return vertices
end

local function hideUnusedPoints(self, activeCount)
    for i = activeCount + 1, self.activeCount do
        stopPoint(self.points[i])
    end

    while #self.points > activeCount + maxSparePoints do
        local point = table.remove(self.points)
        point.effect:destroy()
    end
end

local function renderPoints(self, vertices)
    local cameraPosition = sm.camera.getPosition()
    local fallbackDirection = sm.camera.getDirection() * -1

    for i, vertex in ipairs(vertices) do
        if self.points[i] == nil then
            self.points[i] = createPoint()
        end

        local point = self.points[i]
        local toCamera = (cameraPosition - vertex.pos):safeNormalize(fallbackDirection)
        local radius = vertex.radius or defaultRadius
        local scale = radius / circleModelRadius

        point.effect:setPosition(vertex.pos)
        point.effect:setRotation(sm.vec3.getRotation(modelNormal, toCamera))
        point.effect:setScale(sm.vec3.new(scale, scale, scale))
        point.effect:setParameter("color", vertex.color or defaultColor)

        if not point.visible then
            point.effect:start()
            point.visible = true
        end
    end
end

function VertexRenderer.client_onUpdate(multitool)
    local self = multitool.VertexRenderer
    local vertices = collectVertices(self)
    hideUnusedPoints(self, #vertices)
    renderPoints(self, vertices)
    self.activeCount = #vertices
end

function VertexRenderer.destroy(multitool)
    local self = multitool.VertexRenderer
    if self == nil then
        return
    end

    for _, point in ipairs(self.points) do
        point.effect:destroy()
    end
    self.points = {}
    self.activeCount = 0
    self.subscriptions = {}
end
