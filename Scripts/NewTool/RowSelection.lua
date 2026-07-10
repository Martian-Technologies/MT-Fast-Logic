-- Selects the two endpoints of a straight row of interactable shapes.
-- RowSelection directly owns and calls its BlockSelection children.

RowSelection = {}

local defaultColor = sm.color.new(1, 1, 1, 1)

local function round(value)
    if value >= 0 then return math.floor(value + 0.5) end
    return math.ceil(value - 0.5)
end

local function gcd(a, b)
    a = math.abs(round(a))
    b = math.abs(round(b))
    while b ~= 0 do
        a, b = b, a % b
    end
    return a
end

local function centerKey(position)
    return round(position.x * 4000) .. ";" ..
        round(position.y * 4000) .. ";" ..
        round(position.z * 4000)
end

local function getCenterLocal(shape)
    local bounds = shape:getBoundingBox()
    return shape:getLocalPosition() / 4 +
        shape:getXAxis() * (bounds.x / 2) +
        shape:getYAxis() * (bounds.y / 2) +
        shape:getZAxis() * (bounds.z / 2)
end

local function findRow(startShape, endShape, shapesAtCenter)
    if startShape == nil or endShape == nil or
        not sm.exists(startShape) or not sm.exists(endShape) then
        return {}
    end

    local body = startShape:getBody()
    if body == nil or body ~= endShape:getBody() then return {} end

    local startPosition = getCenterLocal(startShape)
    local endPosition = getCenterLocal(endShape)
    local deltaInBlocks = (endPosition - startPosition) * 4
    local steps = gcd(deltaInBlocks.x, gcd(deltaInBlocks.y, deltaInBlocks.z))
    if steps == 0 then return { startShape } end

    local row = {}
    local step = (endPosition - startPosition) / steps
    for index = 0, steps do
        local shape = shapesAtCenter[centerKey(startPosition + step * index)]
        if shape ~= nil then row[#row + 1] = shape end
    end
    return row
end

function RowSelection.new(options)
    local self = {}
    options = options or {}

    local color = options.color or defaultColor
    local requiredLength = options.requiredLength
    local startSelection = BlockSelection.new({
        raycastMode = options.raycastMode,
        bodyConstraint = options.bodyConstraint,
        maxDistance = options.maxDistance,
        connectionRadius = options.connectionRadius,
        hoverColor = color,
        selectedColor = color
    })
    local endSelection = nil
    local row = {}
    local calculatedStart = nil
    local calculatedEnd = nil
    local calculatedRevision = nil
    local numberLabels = {}
    local numberLabelMismatches = {}
    local labelRenderer = nil
    local comparisonLength = nil

    local function clearNumberLabels()
        if labelRenderer ~= nil then
            for _, labelId in ipairs(numberLabels) do
                labelRenderer.destroy(labelId)
            end
        end
        numberLabels = {}
        numberLabelMismatches = {}
    end

    local function showPrompt(text, warning)
        local warningText = warning ~= nil and (" | " .. tostring(warning)) or ""
        sm.gui.setInteractionText(
            "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
            tostring(text) .. warningText .. " | Left-click: select | Right-click: undo</p>"
        )
    end

    local function createEndSelection()
        local startShape = startSelection.getValue()
        if startShape == nil then return nil end
        return BlockSelection.new({
            raycastMode = options.raycastMode,
            bodyConstraint = { startShape:getBody() },
            maxDistance = options.maxDistance,
            connectionRadius = options.connectionRadius,
            hoverColor = color,
            selectedColor = color
        })
    end

    local function clearCalculation()
        row = {}
        calculatedStart = nil
        calculatedEnd = nil
        calculatedRevision = nil
        clearNumberLabels()
    end

    local function recalculate(context, endShape)
        local startShape = startSelection.getValue()
        if startShape == nil or endShape == nil or
            not sm.exists(startShape) or not sm.exists(endShape) or
            startShape:getBody() ~= endShape:getBody() then
            clearCalculation()
            return row
        end

        local shapesAtCenter, revision = context.targeting.getInteractableCenterMap(startShape:getBody())
        if calculatedStart == startShape and calculatedEnd == endShape and
            calculatedRevision == revision then
            return row
        end

        row = findRow(startShape, endShape, shapesAtCenter)
        calculatedStart = startShape
        calculatedEnd = endShape
        calculatedRevision = revision
        return row
    end

    local function getLabelOptions(mismatched)
        return {
            maxColumns = 6,
            maxLines = 1,
            align = "center",
            cellHeight = 0.117,
            background = true,
            fitBackground = true,
            backgroundPaddingX = 1,
            backgroundPaddingY = 1,
            color = sm.color.new(1, 1, 1, 1),
            backgroundColor = mismatched and sm.color.new(1, 0, 0, 1) or sm.color.new(0, 0, 0, 1)
        }
    end

    local function syncNumberLabels(context, shapes)
        if context.textRenderer == nil then return end
        labelRenderer = context.textRenderer
        local cameraPosition = sm.camera.getPosition()
        local cameraRotation = sm.camera.getRotation()
        local comparedLength = comparisonLength or requiredLength
        local rowsMismatch = comparedLength ~= nil and #shapes ~= comparedLength
        local matchingLength = comparedLength ~= nil and math.min(#shapes, comparedLength) or #shapes

        for index, shape in ipairs(shapes) do
            local position = shape:getWorldPosition()
            local origin = sm.vec3.lerp(position, cameraPosition, 0.2)
            local mismatched = rowsMismatch and index > matchingLength
            local text = mismatched and "X" or tostring(index)

            if numberLabels[index] == nil then
                numberLabels[index] = labelRenderer.new(
                    origin,
                    cameraRotation,
                    text,
                    getLabelOptions(mismatched)
                )
            else
                local changes = {
                    origin = origin,
                    rotation = cameraRotation,
                    text = text
                }
                if numberLabelMismatches[index] ~= mismatched then
                    changes.options = getLabelOptions(mismatched)
                end
                labelRenderer.update(numberLabels[index], changes)
            end
            numberLabelMismatches[index] = mismatched
        end

        for index = #numberLabels, #shapes + 1, -1 do
            labelRenderer.destroy(numberLabels[index])
            numberLabels[index] = nil
            numberLabelMismatches[index] = nil
        end
    end

    local function renderRow(context, shapes)
        syncNumberLabels(context, shapes)
        for _, shape in ipairs(shapes) do
            context.renderer.drawShape(shape, { color = color })
        end
    end

    function self.update(context, input)
        if not startSelection.isComplete() then
            showPrompt(options.startPrompt or "Select row start")
            local event = startSelection.update(context, input)
            if event.type == "back" then
                return { type = "back", atStart = true }
            end
            if startSelection.isComplete() then
                endSelection = createEndSelection()
                return { type = "changed" }
            end
            return event
        end

        if endSelection == nil then endSelection = createEndSelection() end
        if endSelection == nil then
            self.reset()
            return { type = "changed" }
        end

        if not endSelection.isComplete() then
            startSelection.render(context)
            local event = endSelection.update(context, input)
            local previewEnd = endSelection.getValue() or endSelection.getHover()
            local previewRow = recalculate(context, previewEnd)
            local currentLength = previewEnd ~= nil and #previewRow or nil
            local mismatched = requiredLength ~= nil and currentLength ~= nil and currentLength ~= requiredLength
            showPrompt(
                options.endPrompt or "Select row end",
                mismatched and "Lengths must match" or nil
            )
            renderRow(context, previewRow)

            if event.type == "back" then
                startSelection.reset()
                endSelection = nil
                clearCalculation()
                return { type = "changed" }
            end
            if endSelection.isComplete() then
                if mismatched then
                    endSelection.reset()
                    return {
                        type = "invalid",
                        actualLength = currentLength,
                        requiredLength = requiredLength
                    }
                end
                return { type = "complete", value = self.getValue(), changed = true }
            end
            return event
        end

        if input.secondaryState == 1 then
            self.undo()
            return { type = "changed" }
        end

        self.render(context)
        return { type = "complete", value = self.getValue() }
    end

    function self.render(context)
        if not startSelection.isComplete() then return end
        if endSelection == nil or not endSelection.isComplete() then
            startSelection.render(context)
            return
        end
        renderRow(context, recalculate(context, endSelection.getValue()))
    end

    function self.isComplete()
        return startSelection.isComplete() and endSelection ~= nil and endSelection.isComplete()
    end

    function self.getValue()
        if not self.isComplete() then return nil end
        assert(endSelection ~= nil)
        return {
            start = startSelection.getValue(),
            finish = endSelection.getValue(),
            gates = row
        }
    end

    function self.getCurrentLength()
        if calculatedEnd == nil then return nil end
        return #row
    end

    function self.setComparisonLength(length)
        comparisonLength = length
    end

    function self.undo()
        if endSelection ~= nil and endSelection.isComplete() then
            endSelection.reset()
            clearCalculation()
            return true
        end
        if startSelection.isComplete() then
            startSelection.reset()
            endSelection = nil
            clearCalculation()
            return true
        end
        return false
    end

    function self.reset()
        startSelection.reset()
        endSelection = nil
        clearCalculation()
    end

    return self
end
