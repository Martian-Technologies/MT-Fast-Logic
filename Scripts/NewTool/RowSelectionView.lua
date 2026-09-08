-- Presentation for a row selection. RowSelection owns selection state and
-- delegates all outlines and number-label lifetime management to this object.

RowSelectionView = {}

function RowSelectionView.new(color)
    local self = {}
    local numberLabels = {}
    local numberLabelMismatches = {}
    local labelRenderer = nil

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

    local function syncNumberLabels(context, shapes, comparisonLength)
        if context.textRenderer == nil then return end
        labelRenderer = context.textRenderer
        local cameraPosition = sm.camera.getPosition()
        local cameraRotation = sm.camera.getRotation()
        local rowsMismatch = comparisonLength ~= nil and #shapes ~= comparisonLength
        local matchingLength = comparisonLength ~= nil and math.min(#shapes, comparisonLength) or #shapes

        for index, shape in ipairs(shapes) do
            if sm.exists(shape) then
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
        end

        for index = #numberLabels, #shapes + 1, -1 do
            labelRenderer.destroy(numberLabels[index])
            numberLabels[index] = nil
            numberLabelMismatches[index] = nil
        end
    end

    function self.render(context, shapes, comparisonLength)
        syncNumberLabels(context, shapes, comparisonLength)
        for _, shape in ipairs(shapes) do
            if sm.exists(shape) then
                context.renderer.drawShape(shape, { color = color })
            end
        end
    end

    function self.clear()
        if labelRenderer ~= nil then
            for _, labelId in ipairs(numberLabels) do
                labelRenderer.destroy(labelId)
            end
        end
        numberLabels = {}
        numberLabelMismatches = {}
    end

    return self
end
