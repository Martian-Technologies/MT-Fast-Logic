RadialMenu = {}

function RadialMenu.init(tool)
    tool.RadialMenu = {}
    local self = tool.RadialMenu
    local timeForceBuild = 0
    local frameCountForceBuild = 0

    local maxTimeToOpenBigMenu = 0.2

    local menuOptions = nil

    local menuDistance = 20
    local menuRadiusAngle = math.pi / 14
    local menuOptionCount = 8

    local menuSlots = {
        { angle = nil }
    }

    local radialMenuActions = {
        {
            action = nil,
            rectsPath = "$CONTENT_DATA/Scripts/NewTool/images/cancel.json"
        },
        {
            action = nil,
            rectsPath = nil
        },
        {
            action = nil,
            rectsPath = "$CONTENT_DATA/Scripts/NewTool/images/cancel.json"
        },
        {
            action = nil,
            rectsPath = nil
        },
        {
            action = nil,
            rectsPath = "$CONTENT_DATA/Scripts/NewTool/images/cancel.json"
        },
        {
            action = nil,
            rectsPath = "$CONTENT_DATA/Scripts/NewTool/images/cancel.json"
        },
        {
            action = nil,
            rectsPath = nil
        },
        {
            action = {
                type = "toggleFlight"
            },
            rectsPath = "$CONTENT_DATA/Scripts/NewTool/images/toggleFlight.json"
        },
        {
            action = nil,
            rectsPath = "$CONTENT_DATA/Scripts/NewTool/images/cancel.json"
        }
    }

    for i = 0, menuOptionCount - 1 do
        table.insert(menuSlots, { angle = math.pi * 2 * i / menuOptionCount })
    end

    local function getCameraBasis(cameraRot, cameraDir)
        -- Build a stable screen-space basis around the camera direction.
        -- The radial offsets need to use this basis, not world-space axes.
        local worldUp = sm.vec3.new(0, 0, 1)
        local right = cameraDir:cross(worldUp):safeNormalize(sm.quat.getRight(cameraRot))
        local up = right:cross(cameraDir):safeNormalize(sm.quat.getUp(cameraRot))
        return right, up
    end

    local function getRadialOffset(cameraRot, cameraDir, angle)
        if angle == nil then
            return cameraDir, cameraDir
        end

        -- Put the options on a cone/sphere around the camera, not on a flat
        -- plane. This keeps every element exactly menuDistance from the camera.
        local right, up = getCameraBasis(cameraRot, cameraDir)
        local radialDir = (cameraDir * math.cos(menuRadiusAngle) +
            (right * math.cos(angle) + up * math.sin(angle)) * math.sin(menuRadiusAngle)):normalize()
        return radialDir, radialDir
    end

    local function getClosestOption()
        if menuOptions == nil then
            return nil, nil
        end

        local cameraDir = sm.camera.getDirection()
        local bestOption = nil
        local bestDot = -math.huge

        for index, option in ipairs(menuOptions) do
            local dot = cameraDir:dot(option.direction)
            if dot > bestDot then
                bestDot = dot
                bestOption = index
            end
        end

        return bestOption, bestDot
    end

    function self.run(dt, primaryState, secondaryState, forceBuild)
        if forceBuild then
            local cameraPos
            local cameraRot
            local cameraDir
            if timeForceBuild ~= 0 then goto continue end
            if menuOptions ~= nil then goto continue end

            menuOptions = {}
            cameraPos = sm.camera.getPosition()
            cameraRot = sm.camera.getRotation()
            cameraDir = sm.camera.getDirection()
            for index, slot in ipairs(menuSlots) do
                local rectsPath = radialMenuActions[index].rectsPath
                local menuOffset, menuDirection = getRadialOffset(cameraRot, cameraDir, slot.angle)
                local image = nil
                if rectsPath ~= nil then
                    local menuRot = sm.vec3.getRotation(cameraDir, menuDirection) * cameraRot
                    image = tool.ImRend.new(
                        cameraPos + menuOffset * menuDistance,
                        menuRot,
                        3,
                        3,
                        rectsPath
                    )
                end
                table.insert(menuOptions, {
                    image = image,
                    direction = menuOffset
                })
            end

            ::continue::
            timeForceBuild = timeForceBuild + dt
            frameCountForceBuild = frameCountForceBuild + 1
        elseif timeForceBuild ~= 0 then
            local bestOption, _ = getClosestOption()
            local action = nil
            if bestOption == 1 and timeForceBuild < maxTimeToOpenBigMenu or frameCountForceBuild < 3 then
                action = {
                    type = "openMenu",
                    menu = "main"
                } -- open the full menu listing off every mode and every setting
            else
                action = radialMenuActions[bestOption].action
            end

            timeForceBuild = 0
            frameCountForceBuild = 0
            if menuOptions ~= nil then
                for _, option in ipairs(menuOptions) do
                    if option.image ~= nil then
                        tool.ImRend.destroy(option.image)
                    end
                end
                menuOptions = nil
            end

            if action ~= nil then tool:executeAction(action) end
        end
        if menuOptions ~= nil then
            local cameraPos = sm.camera.getPosition()
            local bestOption, bestDot = getClosestOption()
            for index, option in ipairs(menuOptions) do
                if option.image == nil then goto continue end

                local offsetScale = menuDistance
                local dir = option.direction
                if index == bestOption then
                    offsetScale = offsetScale * 0.75
                    dir = sm.vec3.lerp(sm.camera.getDirection(), dir, 0.9):normalize()
                end
                tool.ImRend.updateOrigin(option.image, cameraPos + dir * offsetScale)

                ::continue::
            end
        end
    end

    function self.unequip()
        timeForceBuild = 0
        frameCountForceBuild = 0
        if menuOptions == nil then return end
        for _, option in ipairs(menuOptions) do
            if option.image == nil then goto continue end
            tool.ImRend.destroy(option.image)
            ::continue::
        end
        menuOptions = nil
    end
end
