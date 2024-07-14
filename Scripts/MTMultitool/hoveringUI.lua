HoveringUI = {}

function HoveringUI.inject(multitool)
    multitool.HoveringUI = {}
    local self = multitool.HoveringUI
    self.updateNametags = NametagManager.createController(multitool)
    self.startAngle = nil
    self.elements = nil
end

local function button(multitool, ctx)
    local element = ctx.element
    local tags = ctx.tags
    local levelQuat = ctx.levelQuat
    local elevationQuat = ctx.elevationQuat
    local azimuthQuat = ctx.azimuthQuat
    local cameraVec = ctx.cameraVec
    local cameraPos = ctx.cameraPos
    local pos = (levelQuat * azimuthQuat * elevationQuat) * sm.vec3.new(0, 0, 25) + cameraPos
    local elementAtVec = sm.quat.getAt(levelQuat * azimuthQuat * elevationQuat)
    
    local horizontalAngle = ctx.horizontalAngle
    local verticalAngle = ctx.verticalAngle

    local hover = not ctx.block.hovered
    if horizontalAngle > element.angleBoundHorizontal or verticalAngle > element.angleBoundVertical then
        hover = false
    else
        ctx.block.hovered = true
    end

    local text = element.text
    local primaryState = ctx.buttonClicks.primaryState
    local color = element.color
    if hover then
        text = "[ " .. text .. " ]"
        if primaryState > 0 then
            color = sm.color.new(0, 0, 0)
        end
        if primaryState == 1 then
            element.onclick()
        end
    end
    table.insert(tags, {
        pos = pos,
        txt = text,
        color = color
    })
end

local function toggleButton(multitool, ctx)
    local element = ctx.element
    local tags = ctx.tags
    local levelQuat = ctx.levelQuat
    local elevationQuat = ctx.elevationQuat
    local azimuthQuat = ctx.azimuthQuat
    local cameraVec = ctx.cameraVec
    local cameraPos = ctx.cameraPos
    local pos = (levelQuat * azimuthQuat * elevationQuat) * sm.vec3.new(0, 0, 25) + cameraPos
    local elementAtVec = sm.quat.getAt(levelQuat * azimuthQuat * elevationQuat)

    local horizontalAngle = ctx.horizontalAngle
    local verticalAngle = ctx.verticalAngle

    local hover = not ctx.block.hovered
    if horizontalAngle > element.angleBoundHorizontal or verticalAngle > element.angleBoundVertical then
        hover = false
    else
        ctx.block.hovered = true
    end

    local text = element.text
    local primaryState = ctx.buttonClicks.primaryState
    local state = element.getState()
    local color = element.color.off
    if state then
        color = element.color.on
    end
    if hover then
        text = "[ " .. text .. " ]"
        if primaryState > 0 then
            color = sm.color.new(0, 0, 0)
        end
        if primaryState == 1 then
            element.onclick()
        end
    end
    table.insert(tags, {
        pos = pos,
        txt = text,
        color = color
    })
end

local function customButton(multitool, ctx)
    local element = ctx.element
    local tags = ctx.tags
    local levelQuat = ctx.levelQuat
    local elevationQuat = ctx.elevationQuat
    local azimuthQuat = ctx.azimuthQuat
    local cameraVec = ctx.cameraVec
    local cameraPos = ctx.cameraPos
    local pos = (levelQuat * azimuthQuat * elevationQuat) * sm.vec3.new(0, 0, 25) + cameraPos
    local elementAtVec = sm.quat.getAt(levelQuat * azimuthQuat * elevationQuat)

    local horizontalAngle = ctx.horizontalAngle
    local verticalAngle = ctx.verticalAngle

    local hover = not ctx.block.hovered
    if horizontalAngle > element.angleBoundHorizontal or verticalAngle > element.angleBoundVertical then
        hover = false
    else
        ctx.block.hovered = true
    end

    local render = element.getrender(hover)
    local text = render.text
    local color = render.color
    if hover then
        if ctx.buttonClicks.primaryState > 0 then
            color = sm.color.new(0, 0, 0)
        end
        if ctx.buttonClicks.primaryState == 1 then
            element.onclick()
        end
    end
    table.insert(tags, {
        pos = pos,
        txt = text,
        color = color
    })
end

local function indicator(multitool, ctx)
    local element = ctx.element
    local tags = ctx.tags
    local levelQuat = ctx.levelQuat
    local elevationQuat = ctx.elevationQuat
    local azimuthQuat = ctx.azimuthQuat
    local cameraVec = ctx.cameraVec
    local cameraPos = ctx.cameraPos
    local pos = (levelQuat * azimuthQuat * elevationQuat) * sm.vec3.new(0, 0, 25) + cameraPos

    local text = element.getText()

    table.insert(tags, {
        pos = pos,
        txt = text,
        color = element.color
    })
end

function HoveringUI.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.HoveringUI
    if self.elements == nil then
        return
    end
    if self.startAngle == nil then
        local cameraAtVec = sm.camera.getDirection()
        local x = cameraAtVec.x
        local y = cameraAtVec.y
        self.startAngle = math.atan2(y, x)
    end
    multitool.BlockSelector.enabled = false
    multitool.VolumeSelector.enabled = false
    multitool.tool:setCrossHairAlpha(0.7)

    local elements = self.elements

    local tags = {}
    local vertical = math.pi / 48
    local cameraVec = sm.camera.getDirection()
    local block = { hovered = false }
    for i = 1, #elements do
        local element = elements[i]
        local levelQuat = sm.quat.fromEuler(sm.vec3.new(0, 90, 0))
        local elevationQuat = sm.quat.fromEuler(sm.vec3.new(0, -element.position.e * 180 / math.pi, 0))
        local azimuthQuat = sm.quat.fromEuler(sm.vec3.new(-(self.startAngle + element.position.a) * 180 / math.pi, 0, 0))
        local elementQuat = levelQuat * azimuthQuat * elevationQuat
        local elementAtVec = sm.quat.getAt(elementQuat)

        local horizontalVecElement = sm.vec3.new(elementAtVec.x, elementAtVec.y, 0):normalize()
        local horizontalVecCamera = sm.vec3.new(cameraVec.x, cameraVec.y, 0):normalize()
        local horizontalAngle = math.acos(horizontalVecElement:dot(horizontalVecCamera))
        local verticalVecElement = sm.vec3.new(1, 0, elementAtVec.z):normalize()
        local verticalVecCamera = sm.vec3.new(1, 0, cameraVec.z):normalize()
        local verticalAngle = math.acos(verticalVecElement:dot(verticalVecCamera))
        local ctx = {
            tags = tags,
            element = element,
            levelQuat = levelQuat,
            elevationQuat = elevationQuat,
            azimuthQuat = azimuthQuat,
            cameraVec = cameraVec,
            cameraPos = sm.camera.getPosition(),
            horizontalAngle = horizontalAngle,
            verticalAngle = verticalAngle,
            block = block,
            buttonClicks = {
                primaryState = primaryState,
                secondaryState = secondaryState,
                forceBuild = forceBuild
            }
        }
        if element.type == "button" then
            button(multitool, ctx)
        elseif element.type == "toggleButton" then
            toggleButton(multitool, ctx)
        elseif element.type == "customButton" then
            customButton(multitool, ctx)
        elseif element.type == "indicator" then
            indicator(multitool, ctx)
        end
    end

    -- table.insert(tags, {
    --     pos = sm.camera.getDirection() * 25 + sm.camera.getPosition(),
    --     txt = "+",
    --     color = sm.color.new(1, 1, 1)
    -- })

    self.updateNametags(tags)
end

function HoveringUI.cleanUp(multitool)
    local self = multitool.HoveringUI
    self.startAngle = nil
    self.updateNametags(nil)
    self.elements = nil
end