RadialMenuView = {}

local inputGlyph = NewToolInputGlyph.get

function RadialMenuView.init(tool)
    tool.RadialMenuView = {}
    local self = tool.RadialMenuView
    local renderChannel = "radial"
    local radialPlan = nil
    local options = nil

    local function getCameraBasis(cameraRot, cameraDir)
        local worldUp = sm.vec3.new(0, 0, 1)
        local right = cameraDir:cross(worldUp):safeNormalize(sm.quat.getRight(cameraRot))
        local up = right:cross(cameraDir):safeNormalize(sm.quat.getUp(cameraRot))
        return right, up
    end

    local function getDirection(cameraRot, cameraDir, angle)
        if angle == nil then return cameraDir end
        local right, up = getCameraBasis(cameraRot, cameraDir)
        return (cameraDir * math.cos(radialPlan.radiusAngle) +
            (right * math.cos(angle) + up * math.sin(angle)) * math.sin(radialPlan.radiusAngle)):normalize()
    end

    local function showInteractionText(option)
        if option == nil or option.action == nil or option.label == nil then return end
        local description = tostring(option.description or "")
        local text = tostring(option.label)
        if description ~= "" then text = text .. " - " .. description end
        sm.gui.setInteractionText(text)
        sm.gui.setInteractionText("Release ", inputGlyph("forcebuild"), "to select")
    end

    function self.open(plan)
        radialPlan = plan
        options = {}

        local cameraRot = sm.camera.getRotation()
        local cameraDir = sm.camera.getDirection()
        for _, option in ipairs(radialPlan.options) do
            local direction = getDirection(cameraRot, cameraDir, option.angle)
            options[#options + 1] = {
                id = option.id,
                direction = direction,
                rotation = sm.vec3.getRotation(cameraDir, direction) * cameraRot,
                action = option.action,
                label = option.label,
                description = option.description,
                rectsPath = option.rectsPath
            }
        end
    end

    function self.getClosestIndex()
        if options == nil then return nil end

        local cameraDir = sm.camera.getDirection()
        local bestIndex = nil
        local bestDot = -math.huge
        for index, option in ipairs(options) do
            local dot = cameraDir:dot(option.direction)
            if dot > bestDot then
                bestDot = dot
                bestIndex = index
            end
        end
        return bestIndex
    end

    function self.getAction(index)
        local option = options and options[index] or nil
        return option and option.action or nil
    end

    function self.render()
        if options == nil or radialPlan == nil then return end

        local cameraPos = sm.camera.getPosition()
        local cameraDir = sm.camera.getDirection()
        local bestIndex = self.getClosestIndex()
        local worldPlan = { tiles = {}, texts = {} }

        for index, option in ipairs(options) do
            local distance = radialPlan.menuDistance
            local direction = option.direction
            local rotation = option.rotation

            if index == bestIndex then
                distance = distance * radialPlan.hoverDistanceScale
                local poppedDirection = sm.vec3.lerp(
                    cameraDir,
                    direction,
                    radialPlan.hoverDirectionLerp
                ):safeNormalize(direction)
                rotation = sm.vec3.getRotation(direction, poppedDirection) * rotation
                direction = poppedDirection
                showInteractionText(option)
            end

            if option.rectsPath ~= nil then
                worldPlan.tiles[#worldPlan.tiles + 1] = {
                    id = option.id,
                    origin = cameraPos + direction * distance,
                    rotation = rotation,
                    width = radialPlan.iconSize,
                    height = radialPlan.iconSize,
                    rectsPath = option.rectsPath
                }
            end
        end

        tool.MenuRenderer.render(renderChannel, worldPlan)
    end

    function self.close()
        tool.MenuRenderer.clear(renderChannel)
        options = nil
        radialPlan = nil
    end
end
