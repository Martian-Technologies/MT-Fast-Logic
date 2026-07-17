-- Selects two rows and connects every gate in the first row to every gate in the second.

NewToolNToNConnect = {}

local inputGlyph = NewToolInputGlyph.get
local sourceColor = sm.color.new(0.2, 1, 0.2, 1)
local destinationColor = sm.color.new(1, 0.25, 0.25, 1)
local connectPreviewColor = sm.color.new(1, 0.8, 0.15, 1)
local disconnectPreviewColor = sm.color.new(1, 0.1, 0.1, 1)
local maximumPreviewLines = 256
local maximumOperationLinks = 8192

function NewToolNToNConnect.new(tool, action)
    local self = {
        id = action.id,
        label = action.label,
        description = action.description
    }

    local sourceRow = RowSelection.new({
        color = sourceColor,
        startPrompt = "Select first row start",
        endPrompt = "Select first row end"
    })
    local destinationRow = nil
    local connectionAction = "connect"
    local feedbackOperationId = nil
    local feedbackCompletedAt = nil
    local transientMessage = nil
    local transientExpiresAt = nil

    local function showStatus(text)
        sm.gui.setInteractionText(tostring(text))
    end

    local function setTransient(message)
        transientMessage = message
        transientExpiresAt = os.clock() + 2
    end

    local function resetSelection()
        sourceRow.reset()
        if destinationRow ~= nil then destinationRow.reset() end
        destinationRow = nil
    end

    local function makeDestinationRow()
        local source = sourceRow.getValue()
        if source == nil or source.start == nil or not sm.exists(source.start) then return nil end

        return RowSelection.new({
            color = destinationColor,
            bodyConstraint = source.start:getBody():getCreationBodies(),
            startPrompt = "Select second row start",
            endPrompt = "Select second row end"
        })
    end

    local function renderConnectionPreview(context)
        local source = sourceRow.getValue()
        local destination = destinationRow and destinationRow.getValue() or nil
        if source == nil or destination == nil then return 0, 0 end

        local color = connectionAction == "connect" and connectPreviewColor or disconnectPreviewColor
        local drawn = 0
        local total = #source.gates * #destination.gates
        for _, fromShape in ipairs(source.gates) do
            for _, toShape in ipairs(destination.gates) do
                if drawn >= maximumPreviewLines then return drawn, total end
                context.lineRenderer.draw(
                    fromShape:getWorldPosition(),
                    toShape:getWorldPosition(),
                    { color = color, thickness = 0.008 }
                )
                drawn = drawn + 1
            end
        end
        return drawn, total
    end

    local function presentFeedback()
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
            showStatus("N-to-N operation failed: " .. status.error)
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
            setTransient("Wait for the current N-to-N operation")
            return false
        end
        tool.OperationManager.forget(feedbackOperationId)
        feedbackOperationId = nil
        feedbackCompletedAt = nil
        return true
    end

    local function submitRows()
        if not beginOperation() then return end

        local source = sourceRow.getValue()
        local destination = destinationRow and destinationRow.getValue() or nil
        if source == nil or destination == nil then
            setTransient("Rows are no longer valid")
            resetSelection()
            return
        end

        local connectionCount = #source.gates * #destination.gates
        if connectionCount > maximumOperationLinks then
            setTransient("Operation is too large: " .. connectionCount .. " links")
            return
        end

        local connections = {}
        for _, fromShape in ipairs(source.gates) do
            for _, toShape in ipairs(destination.gates) do
                connections[#connections + 1] = { from = fromShape, to = toShape }
            end
        end

        local operationId, operationError = tool.ConnectionOperations.submit(connectionAction, connections)
        if operationId == nil then
            setTransient("Could not commit: " .. tostring(operationError))
            return
        end

        feedbackOperationId = operationId
        feedbackCompletedAt = nil
        showStatus("Queued " .. #connections .. " N-to-N links")
        resetSelection()
    end

    function self.update(context, input)
        if input.rotatePressed then
            connectionAction = connectionAction == "connect" and "disconnect" or "connect"
            setTransient(connectionAction == "connect" and "Connect mode" or "Disconnect mode")
        end

        if not sourceRow.isComplete() then
            if destinationRow ~= nil then
                destinationRow.reset()
                destinationRow = nil
            end
            local event = sourceRow.update(context, input)
            presentFeedback()
            if event.type == "back" and event.atStart then return "exit" end
            return true
        end

        if destinationRow == nil then
            destinationRow = makeDestinationRow()
            if destinationRow == nil then
                resetSelection()
                presentFeedback()
                return true
            end
        end

        if not destinationRow.isComplete() then
            local event = destinationRow.update(context, input)
            if event.type == "back" and event.atStart then
                destinationRow = nil
                sourceRow.undo()
            else
                sourceRow.render(context)
            end
            presentFeedback()
            return true
        end

        if input.secondaryState == 1 then
            destinationRow.undo()
            presentFeedback()
            return true
        end

        sourceRow.render(context)
        destinationRow.render(context)
        local _, linkCount = renderConnectionPreview(context)

        local source = sourceRow.getValue()
        local destination = destinationRow.getValue()
        if source == nil or destination == nil then
            resetSelection()
            setTransient("Rows are no longer valid")
            presentFeedback()
            return true
        end

        if input.primaryState == 1 then
            submitRows()
            presentFeedback()
            return true
        end

        local otherAction = connectionAction == "connect" and "disconnect" or "connect"
        local previewWarning = linkCount > maximumPreviewLines and
            (" | Preview limited to " .. maximumPreviewLines .. " of " .. linkCount) or ""
        sm.gui.setInteractionText(
            "First row " .. #source.gates .. " | Second row " .. #destination.gates .. previewWarning
        )
        sm.gui.setInteractionText(
            "", inputGlyph("left-click"), connectionAction .. " " .. linkCount .. " links     ",
            inputGlyph("rotate"), "switch to " .. otherAction .. "     ",
            inputGlyph("right-click"), "undo"
        )
        presentFeedback()
        return true
    end

    function self.render(context)
        sourceRow.render(context)
        if destinationRow ~= nil then
            destinationRow.render(context)
            if destinationRow.isComplete() then renderConnectionPreview(context) end
        end
    end

    function self.onDeselect()
        resetSelection()
    end

    return self
end
