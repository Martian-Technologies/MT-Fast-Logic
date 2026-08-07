VertexRenderer = {}

local circleUuid = sm.uuid.new("18d15b07-479f-4558-b78e-c000a3b16d4c")
local circleModelRadius = 0.5
local defaultRadius = 0.015
local defaultColor = sm.color.new(1, 1, 1, 1)
local modelNormal = sm.vec3.new(1, 0, 0)

local maxSparePoints = 256
local poolRetentionSeconds = 5
local minimumPixelDiameter = 0.5
local positionEpsilon = 0.00001
local directionDotThreshold = 0.999999
local fovEpsilon = 0.001
local emptyVertices = {}

local function stopPoint(point)
    if point.visible then
        point.effect:stop()
        point.visible = false
    end
end

local function destroyPoint(point)
    point.effect:destroy()
end

local function cleanPreviousRenderer(multitool)
    local previous = multitool.VertexRenderer
    if previous == nil or previous.points == nil then
        return
    end

    for _, point in ipairs(previous.points) do
        if type(point) == "table" then
            destroyPoint(point)
        else
            point:destroy()
        end
    end
end

function VertexRenderer.inject(multitool)
    cleanPreviousRenderer(multitool)
    multitool.VertexRenderer = {
        points = {},
        activeCount = 0,
        subscriptions = {},
        cameraPosition = nil,
        cameraDirection = nil,
        cameraUp = nil,
        cameraFov = nil,
        screenWidth = nil,
        screenHeight = nil,
        billboardDirection = nil,
        rotation = nil,
        rotationVersion = 0,
        subscriptionsChanged = true,
        poolShrinkAt = nil,
        poolShrinkTarget = nil
    }
end

function VertexRenderer.subscribe(multitool, func)
    local renderer = multitool.VertexRenderer
    local subscriptions = renderer.subscriptions
    local subscription = {
        getVertices = func,
        vertices = emptyVertices,
        vertexCount = 0,
        revision = nil,
        initialized = false
    }
    table.insert(subscriptions, subscription)
    renderer.subscriptionsChanged = true

    return function()
        for i, current in ipairs(subscriptions) do
            if current == subscription then
                table.remove(subscriptions, i)
                renderer.subscriptionsChanged = true
                return
            end
        end
    end
end

function VertexRenderer.createSource(multitool)
    local source = {
        vertices = emptyVertices,
        vertexCount = 0,
        revision = 0
    }

    source.unsubscribe = VertexRenderer.subscribe(multitool, function()
        return source.vertices, source.revision
    end)

    function source:set(vertices)
        vertices = vertices or emptyVertices
        local vertexCount = #vertices
        if self.vertexCount == 0 and vertexCount == 0 then
            self.vertices = vertices
            return
        end
        self.vertices = vertices
        self.vertexCount = vertexCount
        self.revision = self.revision + 1
    end

    function source:clear()
        if self.vertexCount == 0 and #self.vertices == 0 then
            return
        end
        self.vertices = emptyVertices
        self.vertexCount = 0
        self.revision = self.revision + 1
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
        visible = false,
        positionX = nil,
        positionY = nil,
        positionZ = nil,
        radius = nil,
        colorR = nil,
        colorG = nil,
        colorB = nil,
        colorA = nil,
        rotationVersion = nil
    }
end

local function updateSubscriptions(self)
    local changed = self.subscriptionsChanged
    for _, subscription in ipairs(self.subscriptions) do
        local vertices, revision = subscription.getVertices()
        vertices = vertices or emptyVertices
        local vertexCount = #vertices

        if not subscription.initialized or revision == nil or revision ~= subscription.revision or
            vertexCount ~= subscription.vertexCount then
            changed = true
        end

        subscription.vertices = vertices
        subscription.vertexCount = vertexCount
        subscription.revision = revision
        subscription.initialized = true
    end
    self.subscriptionsChanged = false
    return changed
end

local function vectorChanged(previous, current)
    return previous == nil or
        math.abs(previous.x - current.x) > positionEpsilon or
        math.abs(previous.y - current.y) > positionEpsilon or
        math.abs(previous.z - current.z) > positionEpsilon
end

local function copyVector(vector)
    return sm.vec3.new(vector.x, vector.y, vector.z)
end

local function getCameraState(self)
    local position = sm.camera.getPosition()
    local direction = sm.camera.getDirection()
    local up = sm.camera.getUp()
    local fov = sm.camera.getFov()
    local screenWidth, screenHeight = sm.gui.getScreenSize()
    screenWidth = screenWidth or 1920
    screenHeight = screenHeight or 1080

    local positionChanged = vectorChanged(self.cameraPosition, position)
    local directionChanged = self.cameraDirection == nil or
        self.cameraDirection:dot(direction) < directionDotThreshold
    local upChanged = self.cameraUp == nil or self.cameraUp:dot(up) < directionDotThreshold
    local fovChanged = self.cameraFov == nil or math.abs(self.cameraFov - fov) > fovEpsilon
    local screenChanged = self.screenWidth ~= screenWidth or self.screenHeight ~= screenHeight
    local changed = positionChanged or directionChanged or upChanged or fovChanged or screenChanged
    return position, direction, up, fov, screenWidth, screenHeight, changed
end

local function createVisibilityTest(cameraPosition, cameraDirection, cameraUp, fov, screenWidth, screenHeight)
    local clampedFov = math.max(1, math.min(fov, 179))
    local tanHalfVerticalFov = math.tan(math.rad(clampedFov) * 0.5)
    local aspectRatio = screenWidth / math.max(screenHeight, 1)
    local tanHalfHorizontalFov = tanHalfVerticalFov * aspectRatio
    local focalPixels = math.max(screenWidth, screenHeight) / (2 * tanHalfVerticalFov)
    local cameraRight = cameraDirection:cross(cameraUp):safeNormalize(sm.vec3.new(0, 1, 0))

    return function(vertex)
        local radius = vertex.radius or defaultRadius
        if radius <= 0 then
            return false
        end

        local offset = vertex.pos - cameraPosition
        local distance2 = offset:length2()
        if distance2 <= radius * radius then
            return true
        end

        local forwardDistance = offset:dot(cameraDirection)
        if forwardDistance + radius <= 0 then
            return false
        end

        local horizontalDistance = math.abs(offset:dot(cameraRight))
        local verticalDistance = math.abs(offset:dot(cameraUp))
        local positiveDepth = math.max(0, forwardDistance)
        if horizontalDistance > positiveDepth * tanHalfHorizontalFov + radius or
            verticalDistance > positiveDepth * tanHalfVerticalFov + radius then
            return false
        end

        local projectedDiameter = 2 * radius * focalPixels / math.max(forwardDistance, radius)
        return projectedDiameter >= minimumPixelDiameter
    end
end

local function syncPoint(point, vertex, rotation, rotationVersion)
    local position = vertex.pos
    local radius = vertex.radius or defaultRadius
    local color = vertex.color or defaultColor

    if point.positionX == nil or
        math.abs(point.positionX - position.x) > positionEpsilon or
        math.abs(point.positionY - position.y) > positionEpsilon or
        math.abs(point.positionZ - position.z) > positionEpsilon then
        point.effect:setPosition(position)
        point.positionX = position.x
        point.positionY = position.y
        point.positionZ = position.z
    end

    if point.rotationVersion ~= rotationVersion then
        point.effect:setRotation(rotation)
        point.rotationVersion = rotationVersion
    end

    if point.radius ~= radius then
        local scale = radius / circleModelRadius
        point.effect:setScale(sm.vec3.new(scale, scale, scale))
        point.radius = radius
    end

    if point.colorR == nil or
        point.colorR ~= color.r or
        point.colorG ~= color.g or
        point.colorB ~= color.b or
        point.colorA ~= color.a then
        point.effect:setParameter("color", color)
        point.colorR = color.r
        point.colorG = color.g
        point.colorB = color.b
        point.colorA = color.a
    end

    if not point.visible then
        point.effect:start()
        point.visible = true
    end
end

local function shrinkPool(self, activeCount, now)
    local targetSize = activeCount + maxSparePoints
    if #self.points <= targetSize then
        self.poolShrinkAt = nil
        self.poolShrinkTarget = nil
        return
    end

    if self.poolShrinkTarget == nil or targetSize < self.poolShrinkTarget then
        self.poolShrinkTarget = targetSize
        self.poolShrinkAt = now + poolRetentionSeconds
        return
    end

    if targetSize > self.poolShrinkTarget then
        self.poolShrinkTarget = targetSize
    end

    if now < self.poolShrinkAt then
        return
    end

    while #self.points > self.poolShrinkTarget do
        destroyPoint(table.remove(self.points))
    end
    self.poolShrinkAt = nil
    self.poolShrinkTarget = nil
end

local function renderSubscriptions(self, cameraPosition, cameraDirection, cameraUp, fov, screenWidth, screenHeight)
    local billboardChanged = self.billboardDirection == nil or
        self.billboardDirection:dot(cameraDirection) < directionDotThreshold
    if billboardChanged then
        self.billboardDirection = copyVector(cameraDirection)
        self.rotation = sm.vec3.getRotation(modelNormal, cameraDirection * -1)
        self.rotationVersion = self.rotationVersion + 1
    end

    local isVisible = createVisibilityTest(
        cameraPosition,
        cameraDirection,
        cameraUp,
        fov,
        screenWidth,
        screenHeight
    )
    local activeCount = 0

    for _, subscription in ipairs(self.subscriptions) do
        for _, vertex in ipairs(subscription.vertices) do
            if isVisible(vertex) then
                activeCount = activeCount + 1
                if self.points[activeCount] == nil then
                    self.points[activeCount] = createPoint()
                end
                syncPoint(self.points[activeCount], vertex, self.rotation, self.rotationVersion)
            end
        end
    end

    for i = activeCount + 1, self.activeCount do
        stopPoint(self.points[i])
    end

    self.activeCount = activeCount
    shrinkPool(self, activeCount, os.clock())
end

function VertexRenderer.client_onUpdate(multitool)
    local self = multitool.VertexRenderer
    local sourcesChanged = updateSubscriptions(self)
    local cameraPosition, cameraDirection, cameraUp, fov, screenWidth, screenHeight, cameraChanged =
        getCameraState(self)

    if not sourcesChanged and not cameraChanged then
        shrinkPool(self, self.activeCount, os.clock())
        return
    end

    renderSubscriptions(self, cameraPosition, cameraDirection, cameraUp, fov, screenWidth, screenHeight)
    self.cameraPosition = copyVector(cameraPosition)
    self.cameraDirection = copyVector(cameraDirection)
    self.cameraUp = copyVector(cameraUp)
    self.cameraFov = fov
    self.screenWidth = screenWidth
    self.screenHeight = screenHeight
end

function VertexRenderer.destroy(multitool)
    local self = multitool.VertexRenderer
    if self == nil then
        return
    end

    for _, point in ipairs(self.points) do
        destroyPoint(point)
    end
    self.points = {}
    self.activeCount = 0
    self.subscriptions = {}
end
