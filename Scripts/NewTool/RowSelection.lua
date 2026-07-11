-- Selects the two endpoints of a straight row of interactable shapes.
-- Geometry comes from CreationSpatialIndex and presentation is delegated to
-- RowSelectionView; this object owns only selection state and policy.

RowSelection = {}

local defaultColor = sm.color.new(1, 1, 1, 1)

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
    local comparisonLength = nil
    local view = RowSelectionView.new(color)

    local function showPrompt(context, text, warning)
        local warningText = warning ~= nil and (" | " .. tostring(warning)) or ""
        context.prompts.show(
            tostring(text) .. warningText .. " | Left-click: select | Right-click: undo",
            120
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
        view.clear()
    end

    local function recalculate(context, endShape)
        local startShape = startSelection.getValue()
        if startShape == nil or endShape == nil or
            not sm.exists(startShape) or not sm.exists(endShape) or
            startShape:getBody() ~= endShape:getBody() then
            clearCalculation()
            return row
        end

        local bodyIndex = context.spatialIndex.get(startShape:getBody())
        local revision = bodyIndex and bodyIndex.revision or nil
        if calculatedStart == startShape and calculatedEnd == endShape and
            calculatedRevision == revision then
            return row
        end

        row, calculatedRevision = context.spatialIndex.findStraightRow(startShape, endShape)
        calculatedStart = startShape
        calculatedEnd = endShape
        return row
    end

    local function renderRow(context, shapes)
        view.render(context, shapes, comparisonLength or requiredLength)
    end

    function self.update(context, input)
        if not startSelection.isComplete() then
            showPrompt(context, options.startPrompt or "Select row start")
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
                context,
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
        if not startSelection.isComplete() then
            view.clear()
            return
        end
        if endSelection == nil or not endSelection.isComplete() then
            view.clear()
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
