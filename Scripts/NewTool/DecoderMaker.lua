-- Builds binary decoder connections from matching normal and inverted input rows.

NewToolDecoderMaker = {}

local inputGlyph = NewToolInputGlyph.get
local normalColor = sm.color.new(0.2, 1, 0.2, 1)
local invertedColor = sm.color.new(1, 0.25, 0.25, 1)
local outputColor = sm.color.new(0.25, 0.5, 1, 1)
local connectPreviewColor = sm.color.new(1, 0.8, 0.15, 1)
local disconnectPreviewColor = sm.color.new(1, 0.1, 0.1, 1)
local maximumPreviewLines = 256
local maximumOperationLinks = 8192

function NewToolDecoderMaker.new(tool, action)
    local self = {
        id = action.id,
        label = action.label,
        description = action.description
    }

    local normalRow = RowSelection.new({
        color = normalColor,
        startPrompt = "Select normal input row start",
        endPrompt = "Select normal input row end"
    })
    local invertedRow = nil
    local outputOrigin = nil
    local outputStep = nil
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

    local function resetAfterNormal()
        normalRow.setComparisonLength(nil)
        if invertedRow ~= nil then invertedRow.reset() end
        if outputOrigin ~= nil then outputOrigin.reset() end
        if outputStep ~= nil then outputStep.reset() end
        invertedRow = nil
        outputOrigin = nil
        outputStep = nil
    end

    local function resetAfterInverted()
        if outputOrigin ~= nil then outputOrigin.reset() end
        if outputStep ~= nil then outputStep.reset() end
        outputOrigin = nil
        outputStep = nil
    end

    local function resetSelection()
        normalRow.reset()
        resetAfterNormal()
    end

    local function getCreationBodies()
        local normal = normalRow.getValue()
        if normal == nil or normal.start == nil or not sm.exists(normal.start) then return nil end
        return normal.start:getBody():getCreationBodies()
    end

    local function makeInvertedRow()
        local normal = normalRow.getValue()
        if normal == nil or #normal.gates < 1 then return nil end
        return RowSelection.new({
            color = invertedColor,
            bodyConstraint = getCreationBodies(),
            requiredLength = #normal.gates,
            startPrompt = "Select inverted input row start",
            endPrompt = "Select inverted input row end"
        })
    end

    local function makeOutputOrigin()
        return BlockSelection.new({
            bodyConstraint = getCreationBodies(),
            hoverColor = outputColor,
            selectedColor = outputColor
        })
    end

    local function makeOutputStep()
        local origin = outputOrigin and outputOrigin.getValue() or nil
        if origin == nil or not sm.exists(origin) then return nil end
        return BlockSelection.new({
            bodyConstraint = { origin:getBody() },
            hoverColor = outputColor,
            selectedColor = outputColor
        })
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
            showStatus(progressiveVerb .. " " .. status.applied .. " of " .. status.total .. " decoder links...")
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
            showStatus("Decoder operation failed: " .. status.error)
            return
        end

        local completedVerb = status.kind == "connect" and "Connected" or "Disconnected"
        local skipped = status.skipped > 0 and (" | Skipped " .. status.skipped) or ""
        showStatus(completedVerb .. " " .. status.applied .. " of " .. status.total .. " decoder links" .. skipped)
    end

    local function beginOperation()
        if feedbackOperationId == nil then return true end

        local previousStatus = tool.OperationManager.getStatus(feedbackOperationId)
        if previousStatus ~= nil and not previousStatus.complete then
            setTransient("Wait for the current decoder operation")
            return false
        end
        tool.OperationManager.forget(feedbackOperationId)
        feedbackOperationId = nil
        feedbackCompletedAt = nil
        return true
    end

    local function calculateConnections(context)
        local normal = normalRow.getValue()
        local inverted = invertedRow and invertedRow.getValue() or nil
        local origin = outputOrigin and outputOrigin.getValue() or nil
        local nextOutput = outputStep and outputStep.getValue() or nil
        if normal == nil or inverted == nil or origin == nil or nextOutput == nil then
            return nil, nil, "The decoder selection is no longer valid"
        end
        if #normal.gates < 1 or #normal.gates ~= #inverted.gates then
            return nil, nil, "Normal and inverted rows must have the same size"
        end
        if origin == nextOutput then
            return nil, nil, "The first two outputs must be different"
        end

        local outputCount = 2 ^ #normal.gates
        local linkCount = outputCount * #normal.gates
        if linkCount > maximumOperationLinks then
            return nil, nil, "Decoder is too large: " .. linkCount .. " links"
        end

        local body = origin:getBody()
        if body == nil or body ~= nextOutput:getBody() then
            return nil, nil, "The first two outputs must be on one body"
        end
        local bodyIndex = context.spatialIndex.get(body)
        if bodyIndex == nil then return nil, nil, "The output body is no longer valid" end

        local originPosition = context.spatialIndex.getShapeCenterLocal(origin)
        local outputDelta = context.spatialIndex.getShapeCenterLocal(nextOutput) - originPosition
        local connections = {}
        local outputs = {}
        for outputIndex = 0, outputCount - 1 do
            local output = context.spatialIndex.lookupInteractableCenter(
                bodyIndex,
                originPosition + outputDelta * outputIndex
            )
            if output == nil or not sm.exists(output) then
                return nil, nil, "Output " .. (outputIndex + 1) .. " is missing"
            end
            outputs[#outputs + 1] = output

            for inputIndex = 1, #normal.gates do
                local bit = math.floor(outputIndex / (2 ^ (inputIndex - 1))) % 2
                local source = bit == 1 and normal.gates[inputIndex] or inverted.gates[inputIndex]
                connections[#connections + 1] = { from = source, to = output }
            end
        end
        return connections, outputs, nil
    end

    local function renderPreview(context, connections, outputs)
        for _, output in ipairs(outputs) do
            context.renderer.drawShape(output, { color = outputColor })
        end

        local color = connectionAction == "connect" and connectPreviewColor or disconnectPreviewColor
        for index = 1, math.min(#connections, maximumPreviewLines) do
            local connection = connections[index]
            if sm.exists(connection.from) and sm.exists(connection.to) then
                context.lineRenderer.draw(
                    connection.from:getWorldPosition(),
                    connection.to:getWorldPosition(),
                    { color = color, thickness = 0.008 }
                )
            end
        end
    end

    local function submitDecoder(context, connections)
        if not beginOperation() then return end

        local operationId, operationError = tool.ConnectionOperations.submit(connectionAction, connections)
        if operationId == nil then
            setTransient("Could not commit: " .. tostring(operationError))
            return
        end

        feedbackOperationId = operationId
        feedbackCompletedAt = nil
        showStatus("Queued " .. #connections .. " decoder links")
        resetSelection()
    end

    local function showBlockPrompt(text)
        sm.gui.setInteractionText(text)
        sm.gui.setInteractionText(
            "", inputGlyph("left-click"), "select     ",
            inputGlyph("right-click"), "undo"
        )
    end

    function self.update(context, input)
        if input.rotatePressed then
            connectionAction = connectionAction == "connect" and "disconnect" or "connect"
            setTransient(connectionAction == "connect" and "Connect mode" or "Disconnect mode")
        end

        if not normalRow.isComplete() then
            resetAfterNormal()
            local event = normalRow.update(context, input)
            presentFeedback()
            if event.type == "back" and event.atStart then return "exit" end
            return true
        end

        normalRow.render(context)
        local normal = normalRow.getValue()
        if normal == nil or #normal.gates < 1 then
            resetSelection()
            setTransient("The normal input row is no longer valid")
            presentFeedback()
            return true
        end

        if invertedRow == nil then invertedRow = makeInvertedRow() end
        if invertedRow == nil then
            resetSelection()
            presentFeedback()
            return true
        end

        if not invertedRow.isComplete() then
            resetAfterInverted()
            normalRow.setComparisonLength(invertedRow.getCurrentLength())
            local event = invertedRow.update(context, input)
            normalRow.render(context)
            if event.type == "back" and event.atStart then
                invertedRow = nil
                normalRow.setComparisonLength(nil)
                normalRow.undo()
            elseif event.type == "invalid" then
                setTransient("Normal and inverted rows must have the same size")
            end
            presentFeedback()
            return true
        end

        normalRow.setComparisonLength(invertedRow.getCurrentLength())
        normalRow.render(context)
        invertedRow.render(context)
        normal = normalRow.getValue()
        local inverted = invertedRow.getValue()
        if normal == nil or inverted == nil or #normal.gates < 1 or #normal.gates ~= #inverted.gates then
            invertedRow.undo()
            resetAfterInverted()
            setTransient("Normal and inverted rows must have the same size")
            presentFeedback()
            return true
        end

        if outputOrigin == nil then outputOrigin = makeOutputOrigin() end
        if not outputOrigin.isComplete() then
            if outputStep ~= nil then outputStep.reset() end
            outputStep = nil
            showBlockPrompt("Select the first decoder output")
            local event = outputOrigin.update(context, input)
            if event.type == "back" then
                outputOrigin = nil
                invertedRow.undo()
            end
            presentFeedback()
            return true
        end

        outputOrigin.render(context)
        if outputStep == nil then outputStep = makeOutputStep() end
        if outputStep == nil then
            outputOrigin.reset()
            outputOrigin = nil
            presentFeedback()
            return true
        end

        if not outputStep.isComplete() then
            showBlockPrompt("Select the second decoder output to set spacing")
            local event = outputStep.update(context, input)
            if event.type == "back" then
                outputStep = nil
                outputOrigin.reset()
                outputOrigin = nil
            elseif event.type == "complete" and outputStep.getValue() == outputOrigin.getValue() then
                outputStep.reset()
                setTransient("The first two outputs must be different")
            end
            presentFeedback()
            return true
        end

        if input.secondaryState == 1 then
            outputStep.reset()
            presentFeedback()
            return true
        end

        local connections, outputs, connectionError = calculateConnections(context)
        if connections == nil then
            outputStep.reset()
            setTransient(connectionError)
            presentFeedback()
            return true
        end

        renderPreview(context, connections, outputs)
        if input.primaryState == 1 then
            submitDecoder(context, connections)
            presentFeedback()
            return true
        end

        local otherAction = connectionAction == "connect" and "disconnect" or "connect"
        local previewWarning = #connections > maximumPreviewLines and
            (" | Preview limited to " .. maximumPreviewLines .. " of " .. #connections) or ""
        sm.gui.setInteractionText(
            #normal.gates .. " inputs | " .. #outputs .. " outputs | " .. #connections .. " links" .. previewWarning
        )
        sm.gui.setInteractionText(
            "", inputGlyph("left-click"), connectionAction .. " decoder     ",
            inputGlyph("rotate"), "switch to " .. otherAction .. "     ",
            inputGlyph("right-click"), "undo"
        )
        presentFeedback()
        return true
    end

    function self.render(context)
        normalRow.render(context)
        if invertedRow ~= nil then invertedRow.render(context) end
        if outputOrigin ~= nil then outputOrigin.render(context) end
        if outputStep ~= nil then outputStep.render(context) end

        if outputStep ~= nil and outputStep.isComplete() then
            local connections, outputs = calculateConnections(context)
            if connections ~= nil then renderPreview(context, connections, outputs) end
        end
    end

    function self.onDeselect()
        resetSelection()
    end

    return self
end
