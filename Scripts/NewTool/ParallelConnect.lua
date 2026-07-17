-- Selects two equal rows and commits index-paired connections.

NewToolParallelConnect = {}

local inputGlyph = NewToolInputGlyph.get
local sourceColor = sm.color.new(0.2, 1, 0.2, 1)
local destinationColor = sm.color.new(1, 0.25, 0.25, 1)
local connectPreviewColor = sm.color.new(1, 0.8, 0.15, 1)
local disconnectPreviewColor = sm.color.new(1, 0.1, 0.1, 1)

function NewToolParallelConnect.new(tool, action)
    local self = {
        id = action.id,
        label = action.label,
        description = action.description
    }

    local sourceRow = RowSelection.new({
        color = sourceColor,
        startPrompt = "Select source row start",
        endPrompt = "Select source row end"
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
        sourceRow.setComparisonLength(nil)
        if destinationRow ~= nil then destinationRow.reset() end
        destinationRow = nil
    end

    local function makeDestinationRow()
        local source = sourceRow.getValue()
        if source == nil or source.start == nil or not sm.exists(source.start) then return nil end

        return RowSelection.new({
            color = destinationColor,
            bodyConstraint = source.start:getBody():getCreationBodies(),
            requiredLength = #source.gates,
            startPrompt = "Select destination row start",
            endPrompt = "Select destination row end"
        })
    end

    local function renderPairingPreview(context)
        local source = sourceRow.getValue()
        local destination = destinationRow and destinationRow.getValue() or nil
        if source == nil or destination == nil then return end

        local color = connectionAction == "connect" and connectPreviewColor or disconnectPreviewColor
        local count = math.min(#source.gates, #destination.gates)
        for index = 1, count do
            context.lineRenderer.draw(
                source.gates[index]:getWorldPosition(),
                destination.gates[index]:getWorldPosition(),
                { color = color, thickness = 0.008 }
            )
        end
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
            showStatus(progressiveVerb .. " " .. status.applied .. " of " .. status.total .. " pairs...")
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
            showStatus("Connection operation failed: " .. status.error)
            return
        end

        local completedVerb = status.kind == "connect" and "Connected" or "Disconnected"
        local skipped = status.skipped > 0 and (" | Skipped " .. status.skipped) or ""
        showStatus(completedVerb .. " " .. status.applied .. " of " .. status.total .. " pairs" .. skipped)
    end

    local function submitRows(context)
        if feedbackOperationId ~= nil then
            local previousStatus = tool.OperationManager.getStatus(feedbackOperationId)
            if previousStatus ~= nil and not previousStatus.complete then
                setTransient("Wait for the current connection operation")
                return
            end
            tool.OperationManager.forget(feedbackOperationId)
            feedbackOperationId = nil
            feedbackCompletedAt = nil
        end

        local source = sourceRow.getValue()
        local destination = destinationRow and destinationRow.getValue() or nil
        if source == nil or destination == nil or #source.gates ~= #destination.gates then
            setTransient("Rows are no longer valid")
            resetSelection()
            return
        end

        local connections = {}
        for index, fromShape in ipairs(source.gates) do
            connections[#connections + 1] = { from = fromShape, to = destination.gates[index] }
        end

        local operationId, operationError = tool.ConnectionOperations.submit(connectionAction, connections)
        if operationId == nil then
            setTransient("Could not commit: " .. tostring(operationError))
            return
        end

        feedbackOperationId = operationId
        feedbackCompletedAt = nil
        showStatus("Queued " .. #connections .. " connection pairs")
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
            presentFeedback(context)
            if event.type == "back" and event.atStart then return "exit" end
            return true
        end

        if destinationRow == nil then
            destinationRow = makeDestinationRow()
            if destinationRow == nil then
                resetSelection()
                presentFeedback(context)
                return true
            end
        end

        if not destinationRow.isComplete() then
            local event = destinationRow.update(context, input)
            if event.type == "back" and event.atStart then
                destinationRow = nil
                sourceRow.setComparisonLength(nil)
                sourceRow.undo()
            else
                sourceRow.setComparisonLength(destinationRow.getCurrentLength())
                sourceRow.render(context)
            end
            presentFeedback(context)
            return true
        end

        if input.secondaryState == 1 then
            destinationRow.undo()
            sourceRow.setComparisonLength(nil)
            presentFeedback(context)
            return true
        end

        sourceRow.setComparisonLength(destinationRow.getCurrentLength())
        sourceRow.render(context)
        destinationRow.render(context)
        renderPairingPreview(context)

        local source = sourceRow.getValue()
        local destination = destinationRow.getValue()
        if source == nil or destination == nil then
            resetSelection()
            setTransient("Rows are no longer valid")
            presentFeedback(context)
            return true
        end

        if input.primaryState == 1 then
            submitRows(context)
            presentFeedback(context)
            return true
        end

        local otherAction = connectionAction == "connect" and "disconnect" or "connect"
        sm.gui.setInteractionText("Parallel rows selected")
        sm.gui.setInteractionText(
            "", inputGlyph("left-click"), connectionAction .. " " .. #source.gates .. " pairs     ",
            inputGlyph("rotate"), "switch to " .. otherAction .. "     ",
            inputGlyph("right-click"), "undo"
        )
        presentFeedback(context)
        return true
    end

    function self.render(context)
        if destinationRow ~= nil then
            sourceRow.setComparisonLength(destinationRow.getCurrentLength())
        else
            sourceRow.setComparisonLength(nil)
        end
        sourceRow.render(context)
        if destinationRow ~= nil then
            destinationRow.render(context)
            if destinationRow.isComplete() then renderPairingPreview(context) end
        end
    end

    function self.onDeselect()
        resetSelection()
    end

    return self
end
