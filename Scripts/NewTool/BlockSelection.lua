-- A directly-called, single-block selection component.
-- It is active only during frames in which its owner calls update().

BlockSelection = {}

function BlockSelection.new(options)
    local self = {}
    options = options or {}

    local value = nil
    local hover = nil
    local hit = nil

    local function isValid(shape)
        return shape ~= nil and sm.exists(shape)
    end

    function self.update(context, input)
        if value ~= nil and not isValid(value) then
            value = nil
            hover = nil
            hit = nil
        elseif value ~= nil then
            self.render(context)
            return { type = "complete", value = value }
        end

        if input.secondaryState == 1 then
            hover = nil
            hit = nil
            return { type = "back" }
        end

        local didHit, result = context.targeting.queryBlock(options)
        if not didHit or result == nil then
            hover = nil
            hit = nil
            return { type = "pending" }
        end

        local shape = result:getShape()
        if not isValid(shape) then
            hover = nil
            hit = nil
            return { type = "pending" }
        end

        hover = shape
        hit = result
        context.renderer.showTarget(result)
        context.renderer.drawShape(shape, {
            color = options.hoverColor,
            thickness = options.previewThickness,
            padding = options.previewPadding
        })

        if input.primaryState == 1 then
            value = shape
            return { type = "complete", value = value, changed = true }
        end

        return { type = "pending", hover = hover }
    end

    function self.render(context)
        if not isValid(value) then return end
        context.renderer.drawShape(value, {
            color = options.selectedColor or options.hoverColor,
            thickness = options.previewThickness,
            padding = options.previewPadding
        })
    end

    function self.isComplete()
        return isValid(value)
    end

    function self.getValue()
        if not isValid(value) then return nil end
        return value
    end

    function self.getHover()
        if not isValid(hover) then return nil end
        return hover
    end

    function self.getHit()
        return hit
    end

    function self.reset()
        value = nil
        hover = nil
        hit = nil
    end

    return self
end
