MenuManager = {}

function MenuManager.init(tool)
    tool.MenuManager = {}
    local self = tool.MenuManager

    local menuId = nil
    local menuState = nil
    local imageById = {}
    local textById = {}
    local tileById = {}
    local startYaw = nil
    local startRotation = nil
    local forceBuildHeldTime = 0

    local tapMaxTime = 0.2

    local function getManifest()
        if menuId == nil then return nil end
        return NewToolMenuManifest[menuId]
    end

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

    local function getMenuRotation(forward, direction)
        local rotation = startRotation or sm.camera.getRotation()
        if direction ~= nil then
            rotation = sm.vec3.getRotation(forward, direction) * rotation
        end
        return rotation
    end

    local function clearRenderables()
        for _, imageId in pairs(imageById) do
            tool.ImRend.destroy(imageId)
        end
        imageById = {}

        for _, textId in pairs(textById) do
            tool.HologramText.destroy(textId)
        end
        textById = {}
        tileById = {}
    end

    local function localToDirection(localX, localY, plan)
        local forward, right, up = getBasis()
        local distance = plan.menuDistance or MenuLayout.defaults.menuDistance

        -- Project the menu's 2D layout onto a sphere around the camera instead
        -- of a flat plane. localX/localY keep their old layout scale, but now
        -- they become angular offsets, so every tile sits on the same radius.
        return (forward + right * (localX / distance) + up * (localY / distance)):safeNormalize(forward)
    end

    local function toWorld(localX, localY, plan)
        local cameraPos = sm.camera.getPosition()
        local distance = plan.menuDistance or MenuLayout.defaults.menuDistance
        return cameraPos + localToDirection(localX, localY, plan) * distance
    end

    local function getLocalRotation(localX, localY, plan)
        local forward = getBasis()
        local direction = localToDirection(localX, localY, plan)
        return getMenuRotation(forward, direction)
    end

    local function getPoppedWorldOrigin(stableOrigin, plan)
        local cameraPos = sm.camera.getPosition()
        local stableOffset = stableOrigin - cameraPos
        local stableDistance = stableOffset:length()
        local stableDir = stableOffset:safeNormalize(sm.camera.getDirection())
        local popDir = sm.vec3.lerp(sm.camera.getDirection(), stableDir, plan.hoverDirectionLerp or 0.9):safeNormalize(stableDir)
        return cameraPos + popDir * stableDistance * (plan.hoverDistanceScale or 0.75)
    end

    local function getHoveredTile(plan)
        local forward, right, up = getBasis()
        local cameraDir = sm.camera.getDirection()
        local denom = cameraDir:dot(forward)
        if denom <= 0.05 then return nil end

        -- Inverse of localToDirection(). This lets the old rectangular hitboxes
        -- keep working while the rendered menu itself is curved around the camera.
        local distance = plan.menuDistance or MenuLayout.defaults.menuDistance
        local x = cameraDir:dot(right) / denom * distance
        local y = cameraDir:dot(up) / denom * distance

        for _, hitbox in ipairs(plan.hitboxes or {}) do
            local halfWidth = hitbox.width / 2
            local halfHeight = hitbox.height / 2
            if x >= hitbox.localX - halfWidth and x <= hitbox.localX + halfWidth and
                y >= hitbox.localY - halfHeight and y <= hitbox.localY + halfHeight then
                return tileById[hitbox.id]
            end
        end

        return nil
    end

    local function reconcileImages(plan, hoveredTile)
        local seen = {}
        for _, tile in ipairs(plan.tiles or {}) do
            local imageId = imageById[tile.id]
            local stableOrigin = toWorld(tile.localX, tile.localY, plan)
            local origin = stableOrigin
            local rotation = getLocalRotation(tile.localX, tile.localY, plan)
            if hoveredTile ~= nil and hoveredTile.id == tile.id then
                origin = getPoppedWorldOrigin(stableOrigin, plan)
            end

            if imageId == nil then
                imageId = tool.ImRend.new(
                    origin,
                    rotation,
                    tile.width,
                    tile.height,
                    tile.rectsPath
                )
                imageById[tile.id] = imageId
            else
                tool.ImRend.update(imageId, {
                    origin = origin,
                    rotation = rotation,
                    size = { tile.width, tile.height },
                    rectsPath = tile.rectsPath
                })
            end

            tileById[tile.id] = tile
            seen[tile.id] = true
        end

        for id, imageId in pairs(imageById) do
            if not seen[id] then
                tool.ImRend.destroy(imageId)
                imageById[id] = nil
                tileById[id] = nil
            end
        end
    end

    local function reconcileTexts(plan)
        local seen = {}
        for _, text in ipairs(plan.texts or {}) do
            local textId = textById[text.id]
            local origin = toWorld(text.localX, text.localY, plan)
            local rotation = getLocalRotation(text.localX, text.localY, plan)

            if textId == nil then
                textId = tool.HologramText.new(
                    origin,
                    rotation,
                    text.text,
                    text.options
                )
                textById[text.id] = textId
            else
                tool.HologramText.update(textId, {
                    origin = origin,
                    rotation = rotation,
                    text = text.text,
                    cellHeight = text.options and text.options.cellHeight or nil
                })
            end

            seen[text.id] = true
        end

        for id, textId in pairs(textById) do
            if not seen[id] then
                tool.HologramText.destroy(textId)
                textById[id] = nil
            end
        end
    end

    local function buildAndRender()
        local manifest = getManifest()
        if manifest == nil or menuState == nil then return nil, nil end

        local plan = MenuLayout.build(manifest, menuState, tool.HologramText)
        tileById = {}
        for _, tile in ipairs(plan.tiles or {}) do
            tileById[tile.id] = tile
        end
        local hoveredTile = getHoveredTile(plan)
        reconcileImages(plan, hoveredTile)
        reconcileTexts(plan)
        return plan, hoveredTile
    end

    local function formatInteractionText(text)
        sm.gui.setInteractionText(
            "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
            tostring(text or "") .. "</p>"
        )
    end

    local function showInteractionText(tile)
        if tile == nil then
            formatInteractionText("Aim at an icon | Left-click: select | Right-click/F: close")
            return
        end

        local actionText = "select"
        if tile.action ~= nil then
            actionText = "activate"
        elseif tile.onSelect ~= nil then
            actionText = "show actions"
        end

        local label = tostring(tile.label or "")
        local description = tostring(tile.description or "")
        if description ~= "" then
            formatInteractionText(label .. " - " .. description .. " | Left-click: " .. actionText .. " | Right-click/F: close")
        else
            formatInteractionText(label .. " | Left-click: " .. actionText .. " | Right-click/F: close")
        end
    end

    local function handleMenuEvent(event)
        assert(menuState ~= nil)
        if event == nil then return end

        if event.type == "selectSwitcher" then
            if menuState.switchers[event.switcher] == event.child then return end
            menuState.switchers[event.switcher] = event.child
            print("NewTool hub selected switcher child: " .. tostring(event.switcher) .. " = " .. tostring(event.child))
            return
        end

        print("Unknown NewTool menu event: " .. tostring(event.type))
    end

    function self.isOpen()
        return menuId ~= nil
    end

    function self.open(id)
        menuId = id or "main"
        local manifest = getManifest()
        if manifest == nil then
            print("Unknown NewTool menu: " .. tostring(menuId))
            menuId = nil
            return
        end

        menuState = MenuLayout.createState(manifest)
        forceBuildHeldTime = 0
        local cameraDir = sm.camera.getDirection()
        local flatDir = sm.vec3.new(cameraDir.x, cameraDir.y, 0)
        local forward = flatDir:safeNormalize(sm.vec3.new(1, 0, 0))
        startYaw = math.atan2(forward.y, forward.x)
        startRotation = sm.vec3.getRotation(cameraDir, forward) * sm.camera.getRotation()
        clearRenderables()
        print("NewTool hub opened: " .. tostring(menuId))
    end

    function self.close()
        if menuId == nil then return end
        print("NewTool hub closed")
        menuId = nil
        menuState = nil
        startYaw = nil
        startRotation = nil
        forceBuildHeldTime = 0
        clearRenderables()
    end

    function self.client_onUpdate(dt)
        if menuId == nil then return end
        buildAndRender()
    end

    function self.run(dt, primaryState, secondaryState, forceBuild)
        if menuId == nil then return false end

        local _, hoveredTile = buildAndRender()
        showInteractionText(hoveredTile)

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
            if hoveredTile.onSelect ~= nil then
                handleMenuEvent(hoveredTile.onSelect)
            elseif hoveredTile.action ~= nil then
                local action = hoveredTile.action
                self.close()
                tool:executeAction(action)
            end
            return true
        end

        return true
    end
end
