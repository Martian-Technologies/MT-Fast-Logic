MenuManager = {}

function MenuManager.init(tool)
    tool.MenuManager = {}
    local self = tool.MenuManager

    local menuId = nil
    local images = {}
    local labelTexts = {}
    local previewTitleText = nil
    local previewDescriptionText = nil
    local selectedGoalIndex = 1
    local startYaw = nil
    local startRotation = nil
    local forceBuildHeldTime = 0

    local menuDistance = 18
    local goalX = -4.0
    local actionX = 2.75
    local goalRowSpacing = 2.05
    local actionRowSpacing = 3.25
    local goalTileSize = 1.75
    local goalHoveredTileSize = 2.0
    local goalSelectedTileSize = 1.9
    local actionTileSize = 3.0
    local actionHoveredTileSize = 3.35
    local tapMaxTime = 0.2
    local labelGap = 0
    local labelCellHeight = 0.5
    local previewX = -0.6
    local previewTitleY = -9.25
    local previewDescriptionY = -9.95
    local previewTitleCellHeight = 0.42
    local previewDescriptionCellHeight = 0.3

    local function getBasis()
        if startYaw == nil then
            local cameraDir = sm.camera.getDirection()
            startYaw = math.atan2(cameraDir.y, cameraDir.x)
        end

        local forward = sm.vec3.new(math.cos(startYaw), math.sin(startYaw), 0):normalize()
        local right = sm.vec3.new(math.sin(startYaw), -math.cos(startYaw), 0):normalize()
        local up = sm.vec3.new(0, 0, 1)
        return forward, right, up
    end

    local function getMenuRotation(forward)
        return startRotation or sm.camera.getRotation()
    end

    local function getRowY(index, count, spacing)
        return ((count + 1) / 2 - index) * spacing
    end

    local function clearImages()
        for _, imageId in ipairs(images) do
            tool.ImRend.destroy(imageId)
        end
        images = {}

        for _, textId in ipairs(labelTexts) do
            tool.HologramText.destroy(textId)
        end
        labelTexts = {}

        if previewTitleText ~= nil then
            tool.HologramText.destroy(previewTitleText)
            previewTitleText = nil
        end
        if previewDescriptionText ~= nil then
            tool.HologramText.destroy(previewDescriptionText)
            previewDescriptionText = nil
        end
    end

    local function addImage(rectsPath)
        local forward, _, _ = getBasis()
        local id = tool.ImRend.new(
            sm.camera.getPosition() + forward * menuDistance,
            getMenuRotation(forward),
            goalTileSize,
            goalTileSize,
            rectsPath
        )
        table.insert(images, id)
        return id
    end

    local function addLabelText()
        local forward, _, _ = getBasis()
        local id = tool.HologramText.new(
            sm.camera.getPosition() + forward * menuDistance,
            getMenuRotation(forward),
            "",
            { layoutId = "hub_label", cellHeight = labelCellHeight, background = true }
        )
        table.insert(labelTexts, id)
        return id
    end

    local function ensurePreviewText()
        if previewTitleText == nil then
            local forward, _, _ = getBasis()
            previewTitleText = tool.HologramText.new(
                sm.camera.getPosition() + forward * menuDistance,
                getMenuRotation(forward),
                "",
                { layoutId = "hub_preview_title", cellHeight = previewTitleCellHeight, background = true }
            )
            previewDescriptionText = tool.HologramText.new(
                sm.camera.getPosition() + forward * menuDistance,
                getMenuRotation(forward),
                "",
                { layoutId = "hub_preview_description", cellHeight = previewDescriptionCellHeight, background = true }
            )
        end
    end

    local function getManifest()
        if menuId == "main" then
            return NewToolMenuManifest.main
        end
        return nil
    end

    local function buildTiles()
        local manifest = getManifest()
        local tiles = {}
        if manifest == nil then return tiles end

        local goals = manifest.goals or {}
        if selectedGoalIndex < 1 then selectedGoalIndex = 1 end
        if selectedGoalIndex > #goals then selectedGoalIndex = #goals end

        for index, goal in ipairs(goals) do
            table.insert(tiles, {
                type = "goal",
                goalIndex = index,
                label = goal.label,
                description = goal.description,
                icon = goal.icon,
                x = goalX,
                y = getRowY(index, #goals, goalRowSpacing),
                size = goalTileSize,
                hoveredSize = goalHoveredTileSize,
                selectedSize = goalSelectedTileSize,
                selected = index == selectedGoalIndex
            })
        end

        local selectedGoal = goals[selectedGoalIndex]
        if selectedGoal ~= nil then
            local actionIds = selectedGoal.actions or {}
            for index, actionId in ipairs(actionIds) do
                local action = NewToolActionRegistry.get(actionId)
                if action ~= nil then
                    table.insert(tiles, {
                        type = "action",
                        actionId = actionId,
                        label = action.label,
                        description = action.description,
                        icon = action.icon,
                        x = actionX,
                        y = getRowY(index, #actionIds, actionRowSpacing),
                        size = actionTileSize,
                        hoveredSize = actionHoveredTileSize,
                        selectedSize = actionTileSize,
                        selected = false
                    })
                end
            end
        end

        return tiles
    end

    local function syncImageCount(tiles)
        while #images < #tiles do
            addImage(tiles[#images + 1].icon)
        end
        while #images > #tiles do
            tool.ImRend.destroy(images[#images])
            table.remove(images, #images)
        end

        while #labelTexts < #tiles do
            addLabelText()
        end
        while #labelTexts > #tiles do
            tool.HologramText.destroy(labelTexts[#labelTexts])
            table.remove(labelTexts, #labelTexts)
        end

        ensurePreviewText()
    end

    local function getHoveredTile(tiles)
        local forward, right, up = getBasis()
        local cameraPos = sm.camera.getPosition()
        local cameraDir = sm.camera.getDirection()
        local planeCenter = cameraPos + forward * menuDistance
        local denom = cameraDir:dot(forward)
        if denom <= 0.05 then return nil end

        local t = (planeCenter - cameraPos):dot(forward) / denom
        if t <= 0 then return nil end

        local hit = cameraPos + cameraDir * t
        local localHit = hit - planeCenter
        local x = localHit:dot(right)
        local y = localHit:dot(up)

        for index, tile in ipairs(tiles) do
            local halfSize = (tile.size or goalTileSize) * 0.65
            if x >= tile.x - halfSize and x <= tile.x + halfSize and y >= tile.y - halfSize and y <= tile.y + halfSize then
                return index, tile
            end
        end

        return nil
    end

    local function getFallbackPreviewTile()
        local manifest = getManifest()
        local goals = manifest and manifest.goals or {}
        local selectedGoal = goals[selectedGoalIndex]
        if selectedGoal == nil then return nil end
        return {
            label = selectedGoal.label,
            description = selectedGoal.description
        }
    end

    local function updateImages(tiles, hoveredIndex, hoveredTile)
        local forward, right, up = getBasis()
        local cameraPos = sm.camera.getPosition()
        local rotation = getMenuRotation(forward)
        local planeCenter = cameraPos + forward * menuDistance

        for index, tile in ipairs(tiles) do
            local size = tile.size or goalTileSize
            if tile.selected then size = tile.selectedSize or size end
            if index == hoveredIndex then size = tile.hoveredSize or size end

            tool.ImRend.update(images[index], {
                origin = planeCenter + right * tile.x + up * tile.y,
                rotation = rotation,
                size = { size, size },
                rectsPath = tile.icon
            })

            local labelY = tile.y - (tile.size or goalTileSize) * 0.65 - labelGap
            tool.HologramText.update(labelTexts[index], {
                origin = planeCenter + right * tile.x + up * labelY,
                rotation = rotation,
                text = tostring(tile.label or "")
            })
        end

        local previewTile = hoveredTile or getFallbackPreviewTile()
        if previewTile ~= nil and previewTitleText ~= nil and previewDescriptionText ~= nil then
            tool.HologramText.update(previewTitleText, {
                origin = planeCenter + right * previewX + up * previewTitleY,
                rotation = rotation,
                text = tostring(previewTile.label or "")
            })
            tool.HologramText.update(previewDescriptionText, {
                origin = planeCenter + right * previewX + up * previewDescriptionY,
                rotation = rotation,
                text = tostring(previewTile.description or "")
            })
        end
    end

    local function showFocusedText(tile)
        if tile == nil then
            sm.gui.setInteractionText(
                "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
                "Aim at an icon | Left-click: select | Right-click/F: close</p>"
            )
            return
        end

        local action = "select"
        if tile.type == "goal" then
            action = "show actions"
        elseif tile.type == "action" then
            action = "activate"
        end

        sm.gui.setInteractionText(
            "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
            "Left-click: " .. action .. " | Right-click/F: close</p>"
        )
    end

    function self.isOpen()
        return menuId ~= nil
    end

    function self.open(id)
        menuId = id or "main"
        selectedGoalIndex = 1
        forceBuildHeldTime = 0
        local cameraDir = sm.camera.getDirection()
        local flatDir = sm.vec3.new(cameraDir.x, cameraDir.y, 0)
        local forward = flatDir:safeNormalize(sm.vec3.new(1, 0, 0))
        startYaw = math.atan2(forward.y, forward.x)
        startRotation = sm.vec3.getRotation(cameraDir, forward) * sm.camera.getRotation()
        clearImages()
        print("NewTool hub opened: " .. tostring(menuId))
    end

    function self.close()
        if menuId == nil then return end
        print("NewTool hub closed")
        menuId = nil
        startYaw = nil
        startRotation = nil
        forceBuildHeldTime = 0
        clearImages()
    end

    function self.client_onUpdate(dt)
        if menuId == nil then return end
        local tiles = buildTiles()
        syncImageCount(tiles)
        local hoveredIndex, hoveredTile = getHoveredTile(tiles)
        updateImages(tiles, hoveredIndex, hoveredTile)
    end

    function self.run(dt, primaryState, secondaryState, forceBuild)
        if menuId == nil then return false end

        local tiles = buildTiles()
        syncImageCount(tiles)
        local hoveredIndex, hoveredTile = getHoveredTile(tiles)
        updateImages(tiles, hoveredIndex, hoveredTile)
        showFocusedText(hoveredTile)

        if forceBuild then
            forceBuildHeldTime = forceBuildHeldTime + dt
            return true
        elseif forceBuildHeldTime > 0 then
            if forceBuildHeldTime <= tapMaxTime then
                self.close()
            end
            forceBuildHeldTime = 0
            return true
        end

        if secondaryState == 1 then
            self.close()
            return true
        end

        if primaryState == 1 and hoveredTile ~= nil then
            if hoveredTile.type == "goal" then
                selectedGoalIndex = hoveredTile.goalIndex
                print("NewTool hub selected goal: " .. tostring(hoveredTile.label))
            elseif hoveredTile.type == "action" then
                local actionId = hoveredTile.actionId
                self.close()
                tool:executeAction({ type = "registered", id = actionId })
            end
            return true
        end

        return true
    end
end
