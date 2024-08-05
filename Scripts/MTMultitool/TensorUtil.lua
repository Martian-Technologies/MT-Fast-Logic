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