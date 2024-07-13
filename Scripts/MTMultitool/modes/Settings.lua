Settings = {}

function Settings.inject(multitool)
    multitool.Settings = {}
    local self = multitool.Settings
    self.updateNametags = NametagManager.createController(multitool)
    self.startAngle = nil

    local fovMult = sm.camera.getFov() / 90

    self.elements = {
        -- {
        --     name = "Hello",
        --     type = "button",
        --     position = { a = 0, e = math.pi / 48 }, -- a = azimuth, e = elevation
        --     -- color = "#FFFFFF",
        --     color = sm.color.new(1, 1, 1),
        --     text = "Hello",
        --     angleBoundHorizontal = 0.05,
        --     angleBoundVertical = 0.03,
        --     onclick = function()
        --         print("Hello")
        --     end
        -- },
        -- {
        --     name = "toolToggle_fastLogicConvert",
        --     type = "toggleButton",
        --     position = { a = -math.pi / 12, e = 5*math.pi / 48 }, -- a = azimuth, e = elevation
        --     color = {
        --         -- on = "#33EE33",
        --         -- off = "#EE3333"
        --         on = sm.color.new(0.2, 0.9, 0.2),
        --         off = sm.color.new(0.9, 0.2, 0.2)
        --     },
        --     text = "Fast Logic Convert",
        --     angleBoundHorizontal = 0.1,
        --     angleBoundVertical = 0.03,
        --     getState = function()
        --         local idx = table.find(MTMultitool.internalModes, "LogicConverter")
        --         return idx ~= nil and multitool.enabledModes[idx]
        --     end,
        --     onclick = function()
        --         local idx = table.find(MTMultitool.internalModes, "LogicConverter")
        --         if idx ~= nil then
        --             multitool.enabledModes[idx] = not multitool.enabledModes[idx]
        --         end
        --     end,
        -- }
    }
    local v = 0
    for i = 1, #MTMultitool.internalModes do
        local mode = MTMultitool.internalModes[i]
        if mode == "Settings" then goto continue end
        v = v + 1
        table.insert(self.elements, {
            name = "toolToggle_" .. mode,
            type = "toggleButton",
            position = { a = 0, e = (#MTMultitool.internalModes-v) * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
            color = {
                on = sm.color.new(0.2, 0.9, 0.2),
                off = sm.color.new(0.9, 0.2, 0.2)
            },
            text = MTMultitool.modes[i],
            angleBoundHorizontal = 0.1 * fovMult,
            angleBoundVertical = math.pi / 90 / 2 * fovMult,
            getState = function()
                return multitool.enabledModes[i]
            end,
            onclick = function()
                multitool.enabledModes[i] = not multitool.enabledModes[i]
                local saveData = SaveFile.getSaveData(multitool.saveIdx)
                saveData.modeStates[mode] = multitool.enabledModes[i]
                SaveFile.setSaveData(multitool.saveIdx, saveData)
            end,
        })
        ::continue::
    end

    table.insert(self.elements, {
        name = "saveIndexDisplay",
        type = "indicator",
        position = { a = -math.pi/8 * fovMult, e = 2 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.2, 0.2, 0.9),
        getText = function()
            return "Save Index: " .. tostring(multitool.saveIdx)
        end,
    })

    table.insert(self.elements, {
        name = "saveIndexIncrease",
        type = "button",
        position = { a = -math.pi/8 * fovMult, e = 3 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.2, 0.2, 0.9),
        text = "↑",
        angleBoundHorizontal = 0.03 * fovMult,
        angleBoundVertical = 0.03 * fovMult,
        onclick = function()
            if multitool.saveIdx == 5 then
                multitool.saveIdx = 1
            else
                multitool.saveIdx = multitool.saveIdx + 1
            end
            MTMultitool.repullSettings(multitool)
        end,
    })

    table.insert(self.elements, {
        name = "saveIndexDecrease",
        type = "button",
        position = { a = -math.pi/8 * fovMult, e = 1 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.2, 0.2, 0.9),
        text = "↓",
        angleBoundHorizontal = 0.03 * fovMult,
        angleBoundVertical = 0.03 * fovMult,
        onclick = function()
            if multitool.saveIdx == 1 then
                multitool.saveIdx = 5
            else
                multitool.saveIdx = multitool.saveIdx - 1
            end
            MTMultitool.repullSettings(multitool)
        end,
    })

    table.insert(self.elements, {
        name = "flyModeToggle",
        type = "customButton",
        position = { a = math.pi / 8 * fovMult, e = 2 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        getrender = function()
            local isFlying = multitool.MTFlying.flying
            local text = "Fly Mode: " .. (isFlying and "On" or "Off")
            local color = isFlying and sm.color.new(0.2, 0.9, 0.2) or sm.color.new(0.9, 0.2, 0.2)
            return {
                text = text,
                color = color,
            }
        end,
        onclick = function()
            MTFlying.toggleFlying(multitool)
        end,
    })

    table.insert(self.elements, {
        name = "connectionDisplayLimit",
        type = "customButton",
        position = { a = math.pi / 8 * fovMult, e = 3 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        angleBoundHorizontal = 0.1,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        getrender = function()
            local text = "Connection Display Limit: " .. multitool.ConnectionManager.connectionDisplayLimit
            return {
                text = text,
                color = sm.color.new(0.2, 0.2, 0.9),
            }
        end,
        onclick = function()
            local options = { 128, 256, 512, 1024, 2048, 4096, 8194, 16384, "unlimited" }
            local idx = table.find(options, multitool.ConnectionManager.connectionDisplayLimit)
            local newLimit = options[1]
            if idx ~= #options then
                newLimit = options[idx + 1]
            end
            ConnectionManager.updateConnectionLimitDisplay(multitool, newLimit)
        end,
    })

    table.insert(self.elements, {
        name = "showConnections",
        type = "toggleButton",
        position = { a = math.pi / 8 * fovMult, e = 6 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = {
            on = sm.color.new(0.2, 0.9, 0.2),
            off = sm.color.new(0.9, 0.2, 0.2)
        },
        text = "Show Connections",
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        getState = function()
            return multitool.ConnectionShower.enabled
        end,
        onclick = function()
            ConnectionShower.toggle(multitool)
        end,
    })

    table.insert(self.elements, {
        name = "hideOnPanAway",
        type = "toggleButton",
        position = { a = math.pi / 8 * fovMult, e = 5 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = {
            on = sm.color.new(0.2, 0.9, 0.2),
            off = sm.color.new(0.9, 0.2, 0.2)
        },
        text = "Hide on Pan Away",
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        getState = function()
            return multitool.ConnectionShower.hideOnPanAway
        end,
        onclick = function()
            ConnectionShower.toggleHideOnPanAway(multitool)
        end,
    })

    table.insert(self.elements, {
        name = "importCreation",
        type = "button",
        position = { a = math.pi / 8 * fovMult, e = 9 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.2, 0.2, 0.9),
        text = "Import Creation",
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        onclick = function()
            BlueprintSpawner.cl_spawn(multitool)
        end,
    })
    table.insert(self.elements, {
        name = "importCreationCaption",
        type = "indicator",
        position = { a = math.pi / 8 * fovMult, e = 8 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.2, 0.2, 0.9),
        getText = function()
            return "from Scrap Mechanic/Data/blueprint.json"
        end,
    })

    table.insert(self.elements, {
        name = "doMeleeState",
        type = "toggleButton",
        position = { a = math.pi / 8 * fovMult, e = 11 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = {
            on = sm.color.new(0.2, 0.9, 0.2),
            off = sm.color.new(0.9, 0.2, 0.2)
        },
        text = "Hammer One Tick (fast logic)",
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        getState = function()
            return multitool.DoMeleeState.enabled
        end,
        onclick = function()
            DoMeleeState.toggle(multitool)
        end,
    })
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

    local render = element.getrender()
    local text = render.text
    local color = render.color
    if hover then
        text = "[ " .. text .. " ]"
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

function Settings.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.Settings
    if self.startAngle == nil then
        local cameraAtVec = sm.camera.getDirection()
        local x = cameraAtVec.x
        local y = cameraAtVec.y
        self.startAngle = math.atan2(y, x)
    end
    multitool.BlockSelector.enabled = false
    multitool.VolumeSelector.enabled = false
    multitool.tool:setCrossHairAlpha(0)

    local elements = self.elements

    local tags = {}
    local vertical = math.pi/48
    -- table.insert(tags, {
    --     pos = sm.vec3.new(math.cos(self.startAngle) * 25, math.sin(self.startAngle) * 25, 0) * math.cos(vertical) + sm.vec3.new(0, 0, 25 * math.sin(vertical)) + sm.camera.getPosition(),
    --     txt = "Hello",
    --     color = sm.color.new(1, 1, 1)
    -- })
    -- local cameraQuat = sm.camera.getRotation()
    local cameraVec = sm.camera.getDirection()
    local block = { hovered = false }
    -- print(self.startAngle)
    for i = 1, #elements do
        local element = elements[i]
        -- local pos = sm.vec3.new(math.cos(self.startAngle + element.position.a) * 25,
        --     math.sin(self.startAngle + element.position.a) * 25, 0) * math.cos(element.position.e) +
        --     sm.vec3.new(0, 0, 25 * math.sin(element.position.e)) + sm.camera.getPosition()

        -- (self.startAngle + element.position.a)*180/math.pi
        local levelQuat = sm.quat.fromEuler(sm.vec3.new(0, 90, 0))
        local elevationQuat = sm.quat.fromEuler(sm.vec3.new(0, - element.position.e * 180 / math.pi, 0))
        local azimuthQuat = sm.quat.fromEuler(sm.vec3.new(-(self.startAngle + element.position.a)*180/math.pi, 0, 0))
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
        -- local pos = elementAtVec * 25 + sm.camera.getPosition()
        -- -- get distance between camera rotation and element rotation
        -- local dot = cameraVec:dot(elementAtVec)
        -- local angle = math.acos(dot)
        -- local text = element.text
        -- if angle < element.angleBound then
        --     text = "[ " .. text .. " ]"
        --     if primaryState > 0 then
        --         text = "#000000" .. text
        --     end
        -- end
        -- table.insert(tags, {
        --     pos = pos,
        --     txt = text,
        --     color = element.color
        -- })
        -- self.startAngle = self.startAngle + math.pi / 48
    end

    table.insert(tags, {
        pos = sm.camera.getDirection() * 25 + sm.camera.getPosition(),
        txt = "+",
        color = sm.color.new(1, 1, 1)
    })

    self.updateNametags(tags)
end

function Settings.cleanUp(multitool)
    local self = multitool.Settings
    self.updateNametags(nil)
    self.startAngle = nil
end