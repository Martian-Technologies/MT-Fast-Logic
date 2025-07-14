sm.MTTensorUtil = sm.MTTensorUtil or {}

function sm.MTTensorUtil.renderLine(nametagsTable, origin, destination, color, spacing)
    local delta = destination - origin
    local dotCount = math.min(50, math.ceil(delta:length() / spacing))
    for i = 0, dotCount do
        table.insert(nametagsTable, {
            pos = origin + delta * (i / dotCount),
            color = color,
            txt = "•"
        })
    end
end

sm.MTTensorUtil.colorOrder = {
    sm.color.new(1, 0, 0, 1),
    sm.color.new(0, 1, 0, 1),
    sm.color.new(0, 0, 1, 1),
    sm.color.new(1, 1, 0, 1),
    sm.color.new(1, 0, 1, 1),
    sm.color.new(0, 1, 1, 1),
    sm.color.new(1, 1, 1, 1),
    sm.color.new(0.5, 0, 0, 1),
    sm.color.new(0, 0.5, 0, 1),
    sm.color.new(0, 0, 0.5, 1),
    sm.color.new(0.5, 0.5, 0, 1),
    sm.color.new(0.5, 0, 0.5, 1),
    sm.color.new(0, 0.5, 0.5, 1),
    sm.color.new(0.5, 0.5, 0.5, 1),
    sm.color.new(1, 0.5, 0, 1),
    sm.color.new(1, 0, 0.5, 1),
    sm.color.new(0, 1, 0.5, 1),
    sm.color.new(0.5, 1, 0, 1),
    sm.color.new(0.5, 0, 1, 1),
    sm.color.new(0, 0.5, 1, 1),
    sm.color.new(1, 0.5, 0.5, 1),
    sm.color.new(0.5, 1, 0.5, 1),
    sm.color.new(0.5, 0.5, 1, 1),
    sm.color.new(1, 1, 0.5, 1),
    sm.color.new(1, 0.5, 1, 1),
    sm.color.new(0.5, 1, 1, 1),
}

function sm.MTTensorUtil.renderVector(nametagsTable, origin, destination, color, spacing)
    -- print('-----------------------------------------------------------')
    if origin == nil or destination == nil then
        return
    end
    if origin.x == destination.x and origin.y == destination.y and origin.z == destination.z then
        return
    end
    local delta = destination - origin
    sm.MTTensorUtil.renderLine(nametagsTable, origin, destination, color, spacing)
    -- find the 2 vectors perpendicular to the delta vector
    local v1 = sm.vec3.new(0, 0, 0)
    if delta.x == 0 and delta.y == 0 then
        v1 = sm.vec3.new(1, 0, 0)
    else
        v1 = sm.vec3.new(-delta.y, delta.x, 0):normalize()
    end
    local v2 = delta:cross(v1):normalize()
    local theta = os.clock() * 5
    local radius = 0.05
    local backVec = destination - delta:normalize() * radius * 2
    local arrowLeft = backVec + v1 * radius * math.cos(theta) + v2 * radius * math.sin(theta)
    local arrowRight = backVec + v1 * radius * math.cos(theta + math.pi) + v2 * radius * math.sin(theta + math.pi)
    sm.MTTensorUtil.renderLine(nametagsTable, destination, arrowLeft, color, spacing)
    sm.MTTensorUtil.renderLine(nametagsTable, destination, arrowRight, color, spacing)
end

function sm.MTTensorUtil.renderSpinner(nametagsTable, position, color, spinnerCount)
    local baseRadius = 0.03
    local radius = baseRadius + (spinnerCount or 0) * 0.02  -- increase radius with spinner count
    local time = os.clock()
    local count = spinnerCount or 0

    local spinSpeed = 5 + count * 0.7  -- each spinner spins at different rate
    local tiltSpeed = 2.3 + count * 0.4  -- different tilt speeds
    local wobbleSpeed = 3.7 + count * 0.6  -- different wobble speeds
    local rollSpeed = 1.8 + count * 0.3  -- third axis rotation

    local mainSpin = time * spinSpeed + count * math.pi / 3
    local tiltAngle = time * tiltSpeed + count * math.pi / 5
    local wobbleAngle = time * wobbleSpeed + count * math.pi / 7
    local rollAngle = time * rollSpeed + count * math.pi / 11

    local tiltAmp = 0.8 + math.sin(count) * 0.2  -- varying tilt intensity
    local wobbleAmp = 0.6 + math.cos(count) * 0.2  -- varying wobble intensity
    local rollAmp = 0.4 + math.sin(count * 1.3) * 0.2  -- varying roll intensity

    local dotCount = math.max(12, math.ceil(2 * math.pi * radius / 0.05))

    for i = 0, dotCount - 1 do
        local angle = (i / dotCount) * 2 * math.pi + mainSpin

        local x = radius * math.cos(angle)
        local y = radius * math.sin(angle)
        local z = 0

        local tilt = math.sin(tiltAngle) * tiltAmp
        local y1 = y * math.cos(tilt) - z * math.sin(tilt)
        local z1 = y * math.sin(tilt) + z * math.cos(tilt)

        local wobble = math.cos(wobbleAngle) * wobbleAmp
        local x2 = x * math.cos(wobble) + z1 * math.sin(wobble)
        local z2 = -x * math.sin(wobble) + z1 * math.cos(wobble)

        local roll = math.sin(rollAngle) * rollAmp
        local x3 = x2 * math.cos(roll) - y1 * math.sin(roll)
        local y3 = x2 * math.sin(roll) + y1 * math.cos(roll)

        local dotPosition = position + sm.vec3.new(x3, y3, z2)

        table.insert(nametagsTable, {
            pos = dotPosition,
            color = color,
            txt = "•"
        })
    end
end

function sm.MTTensorUtil.iterateTensor(tensor, func)
    local number = {}
    for i = 1, #tensor do
        table.insert(number, 0)
    end
    while number[#number] <= tensor[#tensor] do
        -- print(number)
        func(number)
        number[1] = number[1] + 1
        for i = 1, #number do
            if number[i] > tensor[i] then
                if i == #number then
                    break
                end
                number[i] = 0
                number[i + 1] = number[i + 1] + 1
            end
        end
    end
end