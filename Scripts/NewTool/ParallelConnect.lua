-- Parallel Connect selection mode. It directly owns two RowSelections.
-- Connection preview/commit behavior intentionally comes later.

NewToolParallelConnect = {}

local sourceColor = sm.color.new(0.2, 1, 0.2, 1)
local destinationColor = sm.color.new(1, 0.25, 0.25, 1)
local pairingColor = sm.color.new(1, 0.8, 0.15, 1)

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

    local function showStatus(text)
        sm.gui.setInteractionText(
            "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
            tostring(text) .. "</p>"
        )
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

        local count = math.min(#source.gates, #destination.gates)
        for index = 1, count do
            context.lineRenderer.draw(
                source.gates[index]:getWorldPosition(),
                destination.gates[index]:getWorldPosition(),
                { color = pairingColor, thickness = 0.008 }
            )
        end
    end

    function self.update(context, input)
        if not sourceRow.isComplete() then
            local event = sourceRow.update(context, input)
            if event.type == "back" and event.atStart then
                return "exit"
            end
            return true
        end

        if destinationRow == nil then
            destinationRow = makeDestinationRow()
            if destinationRow == nil then
                sourceRow.reset()
                return true
            end
        end

        if not destinationRow.isComplete() then
            local event = destinationRow.update(context, input)
            if event.type == "back" and event.atStart then
                destinationRow = nil
                sourceRow.setComparisonLength(nil)
                sourceRow.undo()
                return true
            end
            sourceRow.setComparisonLength(destinationRow.getCurrentLength())
            sourceRow.render(context)
            return true
        end

        if input.secondaryState == 1 then
            destinationRow.undo()
            sourceRow.setComparisonLength(nil)
            return true
        end

        sourceRow.setComparisonLength(destinationRow.getCurrentLength())
        sourceRow.render(context)
        destinationRow.render(context)
        renderPairingPreview(context)

        local source = sourceRow.getValue()
        local destination = destinationRow.getValue()
        assert(source ~= nil)
        assert(destination ~= nil)
        showStatus("Parallel rows selected | Right-click: undo")
        return true
    end

    -- Selected points remain visible while NewTool is not equipped.
    function self.render(context)
        if destinationRow ~= nil then
            sourceRow.setComparisonLength(destinationRow.getCurrentLength())
        else
            sourceRow.setComparisonLength(nil)
        end
        sourceRow.render(context)
        if destinationRow ~= nil then
            destinationRow.render(context)
            if destinationRow.isComplete() then
                renderPairingPreview(context)
            end
        end
    end

    function self.onDeselect()
        sourceRow.reset()
        if destinationRow ~= nil then destinationRow.reset() end
    end

    return self
end
