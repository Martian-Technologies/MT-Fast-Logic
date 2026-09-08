-- Selects one row and connects each gate to the next gate in the row.

NewToolSeriesConnect = {}

local inputGlyph = NewToolInputGlyph.get
local rowColor = sm.color.new(0.2, 1, 0.2, 1)
local connectPreviewColor = sm.color.new(1, 0.8, 0.15, 1)
local disconnectPreviewColor = sm.color.new(1, 0.1, 0.1, 1)

function NewToolSeriesConnect.new(tool, action)
    local self = {
        id = action.id,
        label = action.label,
        description = action.description
    }

    local rowSelection = RowSelection.new({
        color = rowColor,
        startPrompt = "Select series start",
        endPrompt = "Select series end"
    })
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

    local function renderConnectionPreview(context, gates)
        local color = connectionAction == "connect" and connectPreviewColor or disconnectPreviewColor
        for index = 1, #gates - 1 do
            context.lineRenderer.draw(
                gates[index]:getWorldPosition(),
                gates[index + 1]:getWorldPosition(),
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
            showStatus("Series operation failed: " .. status.error)
            return
        end

        local completedVerb = status.kind == "connect" and "Connected" or "Disconnected"
        local skipped = status.skipped > 0 and (" | Skipped " .. status.skipped) or ""
        showStatus(completedVerb .. " " .. status.applied .. " of " .. status.total .. " links" .. skipped)
    end

    local function submitRow(context, gates)
        if feedbackOperationId ~= nil then
            local previousStatus = tool.OperationManager.getStatus(feedbackOperationId)
            if previousStatus ~= nil and not previousStatus.complete then
                setTransient("Wait for the current series operation")
                return
            end
            tool.OperationManager.forget(feedbackOperationId)
            feedbackOperationId = nil
            feedbackCompletedAt = nil
        end

        local connections = {}
        for index = 1, #gates - 1 do
            connections[#connections + 1] = { from = gates[index], to = gates[index + 1] }
        end

        local operationId, operationError = tool.ConnectionOperations.submit(connectionAction, connections)
        if operationId == nil then
            setTransient("Could not commit: " .. tostring(operationError))
            return
        end

        feedbackOperationId = operationId
        feedbackCompletedAt = nil
        showStatus("Queued " .. #connections .. " series links")
        rowSelection.reset()
    end

    function self.update(context, input)
        if input.rotatePressed then
            connectionAction = connectionAction == "connect" and "disconnect" or "connect"
            setTransient(connectionAction == "connect" and "Connect mode" or "Disconnect mode")
        end

        if not rowSelection.isComplete() then
            local event = rowSelection.update(context, input)
            presentFeedback(context)
            if event.type == "back" and event.atStart then return "exit" end
            return true
        end

        if input.secondaryState == 1 then
            rowSelection.undo()
            presentFeedback(context)
            return true
        end

        rowSelection.render(context)
        local row = rowSelection.getValue()
        if row == nil then
            rowSelection.reset()
            setTransient("The selected row is no longer valid")
            presentFeedback(context)
            return true
        end

        if #row.gates < 2 then
            rowSelection.undo()
            setTransient("A series needs at least two gates")
            presentFeedback(context)
            return true
        end

        renderConnectionPreview(context, row.gates)

        if input.primaryState == 1 then
            submitRow(context, row.gates)
            presentFeedback(context)
            return true
        end

        local otherAction = connectionAction == "connect" and "disconnect" or "connect"
        sm.gui.setInteractionText("Series selected")
        sm.gui.setInteractionText(
            "", inputGlyph("left-click"), connectionAction .. " " .. (#row.gates - 1) .. " links     ",
            inputGlyph("rotate"), "switch to " .. otherAction .. "     ",
            inputGlyph("right-click"), "undo"
        )
        presentFeedback(context)
        return true
    end

    function self.render(context)
        rowSelection.render(context)
        local row = rowSelection.getValue()
        if row ~= nil and #row.gates >= 2 then
            renderConnectionPreview(context, row.gates)
        end
    end

    function self.onDeselect()
        rowSelection.reset()
    end

    return self
end
