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

    for i = 0, menuOptionCount - 1 do
        table.insert(menuSlots, { angle = math.pi * 2 * i / menuOptionCount })
    end

    local function getRadialActions()
        local actions = {
            {
                action = nil,
                rectsPath = nil
            }
        }

        local radial = NewToolMenuManifest.radial or {}
        local pinnedTools = radial.pinnedTools or {}
        local commands = radial.commands or {}
        local ids = {}

        for _, actionId in ipairs(pinnedTools) do
            table.insert(ids, actionId)
        end
        for _, actionId in ipairs(commands) do
            table.insert(ids, actionId)
        end

        for slot = 1, menuOptionCount do
            local actionId = ids[slot]
            local actionDef = actionId and NewToolActionRegistry.get(actionId) or nil
            if actionDef ~= nil then
                table.insert(actions, {
                    action = { type = "registered", id = actionId },
                    rectsPath = actionDef.icon
                })
            else
                table.insert(actions, {
                    action = nil,
                    rectsPath = "$CONTENT_DATA/Scripts/NewTool/images/cancel.json"
                })
            end
        end

        return actions
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

    local function destroyOptions()
        if menuOptions == nil then return end
        for _, option in ipairs(menuOptions) do
            if option.image ~= nil then
                tool.ImRend.destroy(option.image)
            end
        end
        menuOptions = nil
    end

    function self.run(dt, primaryState, secondaryState, forceBuild)
        if forceBuild then
            local cameraPos
            local cameraRot
            local cameraDir
            local radialMenuActions
            if timeForceBuild ~= 0 then goto continue end
            if menuOptions ~= nil then goto continue end

            radialMenuActions = getRadialActions()
            menuOptions = {}
            cameraPos = sm.camera.getPosition()
            cameraRot = sm.camera.getRotation()
            cameraDir = sm.camera.getDirection()
            for index, slot in ipairs(menuSlots) do
                local actionData = radialMenuActions[index]
                local rectsPath = actionData and actionData.rectsPath or nil
                local action = actionData and actionData.action or nil
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
                    direction = menuOffset,
                    action = action
                })
            end

            ::continue::
            timeForceBuild = timeForceBuild + dt
            frameCountForceBuild = frameCountForceBuild + 1
        elseif timeForceBuild ~= 0 then
            local bestOption, _ = getClosestOption()
            local action = nil
            if (bestOption == 1 and timeForceBuild < maxTimeToOpenBigMenu) or frameCountForceBuild < 3 then
                action = {
                    type = "openMenu",
                    menu = "main"
                }
            elseif bestOption ~= nil and menuOptions ~= nil then
                action = menuOptions[bestOption].action
            end

            timeForceBuild = 0
            frameCountForceBuild = 0
            destroyOptions()

            if action ~= nil then tool:executeAction(action) end
            return true
        end
        if menuOptions ~= nil then
            local cameraPos = sm.camera.getPosition()
            local bestOption, _ = getClosestOption()
            for index, option in ipairs(menuOptions) do
                if option.image == nil then goto continue end

                local offsetScale = menuDistance
                local dir = option.direction
                if index == bestOption then
                    offsetScale = offsetScale * 0.75
                    dir = sm.vec3.lerp(sm.camera.getDirection(), dir, 0.9):normalize()
                    if option.action ~= nil and option.action.id ~= nil then
                        local actionDef = NewToolActionRegistry.get(option.action.id)
                        if actionDef ~= nil then
                            sm.gui.setInteractionText(
                                "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
                                tostring(actionDef.label) .. " | Release F: select</p>"
                            )
                        end
                    end
                end
                tool.ImRend.updateOrigin(option.image, cameraPos + dir * offsetScale)

                ::continue::
            end
            return true
        end
        return false
    end

    function self.unequip()
        timeForceBuild = 0
        frameCountForceBuild = 0
        destroyOptions()
    end
end
