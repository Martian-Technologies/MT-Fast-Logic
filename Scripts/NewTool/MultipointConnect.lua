-- Connects or disconnects selected source and destination groups.

NewToolMultipointConnect = {}

local inputGlyph = NewToolInputGlyph.get
local sourceColor = sm.color.new(0.2, 1, 0.2, 1)
local destinationColor = sm.color.new(1, 0.25, 0.25, 1)
local hoverColor = sm.color.new(1, 1, 1, 1)
local overlapColor = sm.color.new(0.8, 0.25, 1, 1)
local connectPreviewColor = sm.color.new(1, 0.8, 0.15, 1)
local disconnectPreviewColor = sm.color.new(1, 0.1, 0.1, 1)
local maximumPreviewLines = 256
local maximumOperationLinks = 8192

function NewToolMultipointConnect.new(tool, action)
    local self = {
        id = action.id,
        label = action.label,
        description = action.description
    }

    local sources = {}
    local destinations = {}
    local sourceView = RowSelectionView.new(sourceColor)
    local destinationView = RowSelectionView.new(destinationColor)
    local connectionAction = "connect"
    local feedbackOperationId = nil
    local feedbackCompletedAt = nil
    local transientMessage = nil
    local transientExpiresAt = nil
    local previewPairing = "all"

    local function showStatus(text)
        sm.gui.setInteractionText(tostring(text))
    end

    local function setTransient(message)
        transientMessage = message
        transientExpiresAt = os.clock() + 2
    end

    local function indexOf(shapes, wanted)
        for index, shape in ipairs(shapes) do
            if shape == wanted then return index end
        end
        return nil
    end

    local function toggleShape(shapes, shape)
        local index = indexOf(shapes, shape)
        if index ~= nil then
            table.remove(shapes, index)
            return false
        end
        shapes[#shapes + 1] = shape
        return true
    end

    local function clearSelection()
        sources = {}
        destinations = {}
        sourceView.clear()
        destinationView.clear()
    end

    local function removeInvalid(shapes)
        local changed = false
        for index = #shapes, 1, -1 do
            if shapes[index] == nil or not sm.exists(shapes[index]) then
                table.remove(shapes, index)
                changed = true
            end
        end
        return changed
    end

    local function getAllowedBodies()
        local first = sources[1] or destinations[1]
        if first == nil or not sm.exists(first) then return nil end
        return first:getBody():getCreationBodies()
    end

    local function getHover(context)
        local didHit, result = context.targeting.queryBlock({ bodyConstraint = getAllowedBodies() })
        if not didHit or result == nil then return nil end

        local shape = result:getShape()
        if shape == nil or not sm.exists(shape) then return nil end
        context.renderer.showTarget(result)
        context.renderer.drawShape(shape, { color = hoverColor })
        return shape
    end

    local function drawPair(context, source, destination, color)
        if source == nil or destination == nil or not sm.exists(source) or not sm.exists(destination) then return end
        context.lineRenderer.draw(
            source:getWorldPosition(),
            destination:getWorldPosition(),
            { color = color, thickness = 0.008 }
        )
    end

    local function renderPreview(context, pairing)
        local color = connectionAction == "connect" and connectPreviewColor or disconnectPreviewColor
        local drawn = 0
        local total = 0

        if pairing == "index" then
            total = math.min(#sources, #destinations)
            for index = 1, total do
                if drawn >= maximumPreviewLines then break end
                drawPair(context, sources[index], destinations[index], color)
                drawn = drawn + 1
            end
        else
            total = #sources * #destinations
            for _, source in ipairs(sources) do
                for _, destination in ipairs(destinations) do
                    if drawn >= maximumPreviewLines then break end
                    drawPair(context, source, destination, color)
                    drawn = drawn + 1
                end
                if drawn >= maximumPreviewLines then break end
            end
        end

        return drawn, total
    end

    local function presentFeedback(context)
        if transientMessage ~= nil then
            if os.clock() <= transientExpiresAt then
                showStatus(transientMessage)
            else
                transientMessage = nil
                transientExpiresAt = nil
            end
        end

        if feedbackOperationId == nil then return end
        local status = tool.OperationManager.getStatus(feedbackOperationId)
        if status == nil then
            feedbackOperationId = nil
            feedbackCompletedAt = nil
            return
        end

        local progressiveVerb = status.kind == "connect" and "Connecting" or "Disconnecting"
        if not status.complete then
            showStatus(progressiveVerb .. " " .. status.applied .. " of " .. status.total .. " links...")
            return
        end

        if feedbackCompletedAt == nil then feedbackCompletedAt = os.clock() end
        if os.clock() - feedbackCompletedAt > 3 then
            tool.OperationManager.forget(feedbackOperationId)
            feedbackOperationId = nil
            feedbackCompletedAt = nil
            return
        end

        if status.error ~= nil then
            showStatus("Multipoint operation failed: " .. status.error)
            return
        end

        local completedVerb = status.kind == "connect" and "Connected" or "Disconnected"
        local skipped = status.skipped > 0 and (" | Skipped " .. status.skipped) or ""
        showStatus(completedVerb .. " " .. status.applied .. " of " .. status.total .. " links" .. skipped)
    end

    local function beginOperation()
        if feedbackOperationId == nil then return true end

        local previousStatus = tool.OperationManager.getStatus(feedbackOperationId)
        if previousStatus ~= nil and not previousStatus.complete then
            setTransient("Wait for the current multipoint operation")
            return false
        end
        tool.OperationManager.forget(feedbackOperationId)
        feedbackOperationId = nil
        feedbackCompletedAt = nil
        return true
    end

    local function submitSelection(context, pairing)
        if not beginOperation() then return end
        if #sources == 0 or #destinations == 0 then
            setTransient("Select at least one source and destination")
            return
        end
        if pairing == "index" and #sources ~= #destinations then
            setTransient("Index-paired groups must have the same size")
            return
        end

        local connectionCount = pairing == "index" and #sources or #sources * #destinations
        if connectionCount > maximumOperationLinks then
            setTransient("Operation is too large: " .. connectionCount .. " links")
            return
        end

        local connections = {}
        if pairing == "index" then
            for index, source in ipairs(sources) do
                connections[#connections + 1] = { from = source, to = destinations[index] }
            end
        else
            for _, source in ipairs(sources) do
                for _, destination in ipairs(destinations) do
                    connections[#connections + 1] = { from = source, to = destination }
                end
            end
        end

        local operationId, operationError = tool.ConnectionOperations.submit(connectionAction, connections)
        if operationId == nil then
            setTransient("Could not commit: " .. tostring(operationError))
            return
        end

        feedbackOperationId = operationId
        feedbackCompletedAt = nil
        showStatus("Queued " .. #connections .. " multipoint links")
        clearSelection()
    end

    local function renderSelection(context, pairing)
        sourceView.render(context, sources, pairing == "index" and #destinations or nil)
        destinationView.render(context, destinations, pairing == "index" and #sources or nil)
        for _, source in ipairs(sources) do
            if indexOf(destinations, source) ~= nil and sm.exists(source) then
                context.renderer.drawShape(source, { color = overlapColor })
            end
        end
        return renderPreview(context, pairing)
    end

    function self.update(context, input)
        local selectionChanged = removeInvalid(sources)
        selectionChanged = removeInvalid(destinations) or selectionChanged
        if selectionChanged then setTransient("Removed an invalid selection") end

        if input.rotatePressed then
            connectionAction = connectionAction == "connect" and "disconnect" or "connect"
            setTransient(connectionAction == "connect" and "Connect mode" or "Disconnect mode")
        end

        previewPairing = input.crouching and "index" or "all"
        local hover = getHover(context)
        if input.primaryState == 1 and hover ~= nil then
            toggleShape(sources, hover)
        elseif input.secondaryState == 1 and hover ~= nil then
            toggleShape(destinations, hover)
        end

        local _, previewTotal = renderSelection(context, previewPairing)

        if input.reloadPressed then
            submitSelection(context, input.crouching and "index" or "all")
            presentFeedback(context)
            return true
        end

        local actionLabel = connectionAction == "connect" and "Connect" or "Disconnect"
        local previewWarning = previewTotal > maximumPreviewLines and
            (" | Preview limited to " .. maximumPreviewLines .. " of " .. previewTotal) or ""
        sm.gui.setInteractionText(
            "Sources " .. #sources .. " | Targets " .. #destinations .. previewWarning
        )
        sm.gui.setInteractionText(
            "", inputGlyph("left-click"), "toggle source     ",
            inputGlyph("right-click"), "toggle target     ",
            inputGlyph("reload"), actionLabel .. " all-to-all"
        )
        sm.gui.setInteractionText(
            "", inputGlyph("crouch"), "+", inputGlyph("reload"), "index-paired     ",
            inputGlyph("rotate"), "switch mode"
        )
        presentFeedback(context)
        return true
    end

    function self.render(context)
        renderSelection(context, previewPairing)
    end

    function self.onDeselect()
        clearSelection()
    end

    return self
end
