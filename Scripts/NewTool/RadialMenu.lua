RadialMenu = {}

function RadialMenu.init(tool)
    tool.RadialMenu = {}
    local self = tool.RadialMenu
    local timeForceBuild = 0

    local maxTimeToOpenBigMenu = 0.3

    local menuOptions = nil

    local menuDistance = 20
    local menuRadiusAngle = math.pi / 14
    local menuOptionCount = 8

    local menuSlots = {
        { angle = nil } -- center option
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
            if timeForceBuild == 0 then
                if menuOptions == nil then
                    menuOptions = {}
                    local cameraPos = sm.camera.getPosition()
                    local cameraRot = sm.camera.getRotation()
                    local cameraDir = sm.camera.getDirection()
                    for _, slot in ipairs(menuSlots) do
                        local menuOffset, menuDirection = getRadialOffset(cameraRot, cameraDir, slot.angle)
                        local menuRot = sm.vec3.getRotation(cameraDir, menuDirection) * cameraRot
                        local image = tool.ImRend.new(
                            cameraPos + menuOffset * menuDistance,
                            menuRot,
                            3,
                            3,
                            "$CONTENT_DATA/Scripts/NewTool/images/cancel.json"
                        )
                        table.insert(menuOptions, {
                            image = image,
                            direction = menuOffset
                        })
                    end
                end
            end
            timeForceBuild = timeForceBuild + dt
        elseif timeForceBuild ~= 0 then
            print(timeForceBuild)

            timeForceBuild = 0
            if menuOptions ~= nil then
                for _, option in ipairs(menuOptions) do
                    tool.ImRend.destroy(option.image)
                end
                menuOptions = nil
            end
        end
        if menuOptions ~= nil then
            local cameraPos = sm.camera.getPosition()
            local bestOption, bestDot = getClosestOption()
            for index, option in ipairs(menuOptions) do
                local offsetScale = menuDistance
                local dir = option.direction
                if index == bestOption then
                    offsetScale = offsetScale * 0.75
                    dir = sm.vec3.lerp(sm.camera.getDirection(), dir, 0.9):normalize()
                end
                tool.ImRend.updateOrigin(option.image, cameraPos + dir * offsetScale)
            end
        end
    end
end
