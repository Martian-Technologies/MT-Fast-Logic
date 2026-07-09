HubMenuView = {}

function HubMenuView.init(tool, layoutEngine)
    tool.HubMenuView = {}
    local self = tool.HubMenuView
    local layout = layoutEngine
    local renderChannel = "hub"
    local startYaw = nil
    local startRotation = nil
    local tileById = {}

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

    local function localToDirection(localX, localY, plan)
        local forward, right, up = getBasis()
        local distance = plan.menuDistance or layout.defaults.menuDistance
        return (forward + right * (localX / distance) + up * (localY / distance)):safeNormalize(forward)
    end

    local function toWorld(localX, localY, plan)
        local cameraPos = sm.camera.getPosition()
        local distance = plan.menuDistance or layout.defaults.menuDistance
        return cameraPos + localToDirection(localX, localY, plan) * distance
    end

    local function getLocalRotation(localX, localY, plan)
        local forward = getBasis()
        local direction = localToDirection(localX, localY, plan)
        local rotation = startRotation or sm.camera.getRotation()
        return sm.vec3.getRotation(forward, direction) * rotation
    end

    local function getPoppedWorldOrigin(stableOrigin, plan)
        local cameraPos = sm.camera.getPosition()
        local stableOffset = stableOrigin - cameraPos
        local stableDistance = stableOffset:length()
        local stableDir = stableOffset:safeNormalize(sm.camera.getDirection())
        local popDir = sm.vec3.lerp(
            sm.camera.getDirection(),
            stableDir,
            plan.hoverDirectionLerp or layout.defaults.hoverDirectionLerp
        ):safeNormalize(stableDir)
        return cameraPos + popDir * stableDistance *
            (plan.hoverDistanceScale or layout.defaults.hoverDistanceScale)
    end

    local function getHoveredTile(plan)
        local forward, right, up = getBasis()
        local cameraDir = sm.camera.getDirection()
        local denom = cameraDir:dot(forward)
        if denom <= 0.05 then return nil end

        local distance = plan.menuDistance or layout.defaults.menuDistance
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

    local function makeWorldPlan(plan, hoveredTile)
        local worldPlan = { tiles = {}, texts = {} }
        for _, tile in ipairs(plan.tiles or {}) do
            local stableOrigin = toWorld(tile.localX, tile.localY, plan)
            local origin = stableOrigin
            if hoveredTile ~= nil and hoveredTile.id == tile.id then
                origin = getPoppedWorldOrigin(stableOrigin, plan)
            end

            worldPlan.tiles[#worldPlan.tiles + 1] = {
                id = tile.id,
                origin = origin,
                rotation = getLocalRotation(tile.localX, tile.localY, plan),
                width = tile.width,
                height = tile.height,
                rectsPath = tile.rectsPath
            }
        end

        for _, text in ipairs(plan.texts or {}) do
            worldPlan.texts[#worldPlan.texts + 1] = {
                id = text.id,
                origin = toWorld(text.localX, text.localY, plan),
                rotation = getLocalRotation(text.localX, text.localY, plan),
                text = text.text,
                options = text.options
            }
        end
        return worldPlan
    end

    function self.open()
        local cameraDir = sm.camera.getDirection()
        local flatDir = sm.vec3.new(cameraDir.x, cameraDir.y, 0)
        local forward = flatDir:safeNormalize(sm.vec3.new(1, 0, 0))
        startYaw = math.atan2(forward.y, forward.x)
        startRotation = sm.vec3.getRotation(cameraDir, forward) * sm.camera.getRotation()
        tileById = {}
        tool.MenuRenderer.clear(renderChannel)
    end

    function self.render(plan)
        tileById = {}
        for _, tile in ipairs(plan.tiles or {}) do
            tileById[tile.id] = tile
        end
        local hoveredTile = getHoveredTile(plan)
        tool.MenuRenderer.render(renderChannel, makeWorldPlan(plan, hoveredTile))
        return hoveredTile
    end

    function self.close()
        startYaw = nil
        startRotation = nil
        tileById = {}
        tool.MenuRenderer.clear(renderChannel)
    end
end
