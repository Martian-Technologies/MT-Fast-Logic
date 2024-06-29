MathUtil = {}

function MathUtil.gcd(a, b)
    if type(a) == "number" and type(b) == "number" and a == math.floor(a) and b == math.floor(b) then
        if b == 0 then
            return a
        else
            return MathUtil.gcd(b, a % b) -- tail recursion
        end
    else
        error("Invalid argument to gcd (" .. tostring(a) .. "," ..
            tostring(b) .. ")", 2)
    end
end

function MathUtil.lcm(a, b)
    if type(a) == "number" and type(b) == "number" and a == math.floor(a) and b == math.floor(b) then
        return math.abs(a * b) / MathUtil.gcd(a, b)
    else
        error("Invalid argument to lcm (" .. tostring(a) .. "," ..
            tostring(b) .. ")", 2)
    end
end

function MathUtil.rayPointDistance(rayOrigin, rayDirection, point)
    if type(rayOrigin) == "Vec3" and type(rayDirection) == "Vec3" and type(point) == "Vec3" then
        local rayToPoint = point - rayOrigin
        local rayToPointLength = rayToPoint:length()
        local rayDirectionLength = rayDirection:length()
        local rayDirectionNormalized = rayDirection / rayDirectionLength
        local dotProduct = rayDirectionNormalized:dot(rayToPoint)
        local projection = rayDirectionNormalized * dotProduct
        local projectionLength = projection:length()
        local distance = math.sqrt(rayToPointLength^2 - projectionLength^2)
        return distance
    else
        error("Invalid argument to rayPointDistance (" .. tostring(rayOrigin) .. "," ..
            tostring(rayDirection) .. "," .. tostring(point) .. ")", 2)
    end
end

function MathUtil.closestPassBetweenConinuousRayAndDiscreteRay(contRayOrigin, contRayDirection, discRayOrigin, discRayDelta)
    local position = discRayOrigin
    local delta = discRayDelta
    local closestDistance = math.huge
    local closestPosition = nil
    local nSteps = -1
    while true do
        local distance = MathUtil.rayPointDistance(contRayOrigin, contRayDirection, position)
        if distance < closestDistance then
            closestDistance = distance
            closestPosition = position
            position = position + delta
            nSteps = nSteps + 1
        else
            break
        end
    end
    return closestDistance, closestPosition, nSteps
end