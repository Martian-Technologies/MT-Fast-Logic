TensorConnect = {}

function TensorConnect.inject(multitool)
    multitool.TensorConnect = {}
    local self = multitool.TensorConnect
    self.data = {}
    local selfData = self.data
    selfData.actions = {}
    selfData.nextAction = "selectOrigin"
    selfData.selecting = "from"
    selfData.nDimsFrom = 0
    selfData.nDimsTo = 0
    selfData.fromOrigin = nil
    selfData.toOrigin = nil
    selfData.selecting = "from"
    selfData.dimSteps = {}
    selfData.vectorsFrom = {}
    selfData.vectorsTo = {}
    selfData.nametagUpdate = NametagManager.createController(multitool)
end

local colorOrder = {
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

local function renderLine(nametagsTable, origin, destination, color, spacing)
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

local function renderVector(nametagsTable, origin, destination, color, spacing)
    -- print('-----------------------------------------------------------')
    if origin == nil or destination == nil then
        return
    end
    if origin.x == destination.x and origin.y == destination.y and origin.z == destination.z then
        return
    end
    local delta = destination - origin
    renderLine(nametagsTable, origin, destination, color, spacing)
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
    renderLine(nametagsTable, destination, arrowLeft, color, spacing)
    renderLine(nametagsTable, destination, arrowRight, color, spacing)
end

function TensorConnect.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local tags = {}
    multitool.ConnectionManager.displayMode = "slow"
    local self = multitool.TensorConnect
    local selfData = self.data
    local recalculateNextAction = false
    -- print(selfData.actions)
    if secondaryState == 1 then
        if #selfData.actions > 0 then
            table.remove(selfData.actions)
            recalculateNextAction = true
        end
    elseif selfData.nextAction == "selectOrigin" then
        if selfData.selecting == "from" then
            multitool.BlockSelector.bodyConstraint = nil
            sm.gui.setInteractionText("Select the origin of source tensor", sm.gui.getKeyBinding("Create", true),
                "Select")
        elseif selfData.selecting == "to" then
            multitool.BlockSelector.bodyConstraint = selfData.fromOrigin:getBody():getCreationBodies()
            sm.gui.setInteractionText("Select the origin of destination tensor", sm.gui.getKeyBinding("Create", true),
                "Select")
        end
        multitool.BlockSelector.enabled = true
        if primaryState == 1 then
            if lookingAt ~= nil then
                selfData.actions[#selfData.actions + 1] = {
                    action = "selectOrigin",
                    origin = lookingAt
                }
                recalculateNextAction = true
            end
        end
    elseif selfData.nextAction == "nextVector" then
        multitool.BlockSelector.enabled = true
        if selfData.selecting == "to" then
            if selfData.toOrigin:getBody():isOnLift() then
                multitool.BlockSelector.bodyConstraint = selfData.toOrigin:getBody():getCreationBodies()
            else
                multitool.BlockSelector.bodyConstraint = { selfData.toOrigin:getBody() }
            end
            sm.gui.setInteractionText(
                "Specify the " ..
                MTMultitoolLib.formatOrdinal(selfData.nDimsTo + 1) ..
                " dimension vector of the destination tensor <p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>(" ..
                selfData.nDimsTo .. "/" .. selfData.nDimsFrom .. ")</p>", sm.gui.getKeyBinding("Create", true), "Select")
        else
            if selfData.fromOrigin:getBody():isOnLift() then
                multitool.BlockSelector.bodyConstraint = selfData.fromOrigin:getBody():getCreationBodies()
            else
                multitool.BlockSelector.bodyConstraint = { selfData.fromOrigin:getBody() }
            end
            sm.gui.setInteractionText(
            "Specify the " ..
            MTMultitoolLib.formatOrdinal(selfData.nDimsFrom + 1) .. " dimension vector of the source tensor",
                sm.gui.getKeyBinding("Create", true), "Select")
            sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true),
                "Complete Source Tensor; Begin Destination Tensor")
        end
        if MTMultitool.handleForceBuild(multitool, forceBuild) and selfData.selecting == "from" then
            selfData.actions[#selfData.actions + 1] = {
                action = "switchToDestination"
            }
            recalculateNextAction = true
        elseif primaryState == 1 then
            if lookingAt ~= nil then
                selfData.actions[#selfData.actions + 1] = {
                    action = "nextVector",
                    vecEnd = lookingAt
                }
                recalculateNextAction = true
            end
        end
        if lookingAt ~= nil then
            if selfData.selecting == "from" then
                local vecColor = colorOrder[math.fmod(selfData.nDimsFrom, #colorOrder) + 1]
                renderVector(tags, selfData.fromOrigin:getWorldPosition(), lookingAt:getWorldPosition(), vecColor, 0.03)
            else
                local vecColor = colorOrder[math.fmod(selfData.nDimsTo, #colorOrder) + 1]
                local steps = selfData.dimSteps[selfData.nDimsTo + 1]
                if steps == 0 then steps = 1 end
                -- print(steps)
                local delta = lookingAt:getWorldPosition() - selfData.toOrigin:getWorldPosition()
                local spacing = 0.03
                if steps > 100 then
                    spacing = 0.1
                end
                local prevPos = selfData.toOrigin:getWorldPosition()
                for i = 0, steps do
                    if i > 10 and i < steps - 10 then
                        goto continue
                    end
                    local pos = selfData.toOrigin:getWorldPosition() + delta * i
                    renderVector(tags, prevPos, pos, vecColor, spacing)
                    prevPos = pos
                    ::continue::
                end
            end
        end
    elseif selfData.nextAction == "setVectorRange" then
        multitool.BlockSelector.enabled = false

        local origin = selfData.fromOrigin
        local vecColor = colorOrder[math.fmod(selfData.nDimsFrom, #colorOrder)]
        if selfData.selecting == "to" then
            origin = selfData.toOrigin
            vecColor = colorOrder[math.fmod(selfData.nDimsTo, #colorOrder)]
        end
        local closestDistance, closestPosition, nSteps = MathUtil.closestPassBetweenContinuousRayAndDiscreteRay(
            sm.camera.getPosition(),
            sm.camera.getDirection(),
            origin:getWorldPosition(),
            selfData.actions[#selfData.actions].vecEnd:getWorldPosition() - origin:getWorldPosition()
        )
        local prevPos = origin:getWorldPosition()
        if nSteps > 40 then
            local spacing = 0.03
            -- if nSteps > 100 then
            --     spacing = 0.1
            -- end
            for i = 0, 20 do
                local pos = origin:getWorldPosition() +
                    (selfData.actions[#selfData.actions].vecEnd:getWorldPosition() - origin:getWorldPosition()) * i
                renderVector(tags, prevPos, pos, vecColor, spacing)
                prevPos = pos
            end
            for i = nSteps - 20, nSteps do
                local pos = origin:getWorldPosition() +
                    (selfData.actions[#selfData.actions].vecEnd:getWorldPosition() - origin:getWorldPosition()) * i
                renderVector(tags, prevPos, pos, vecColor, spacing)
                prevPos = pos
            end
        else
            for i = 0, nSteps do
                local pos = origin:getWorldPosition() +
                (selfData.actions[#selfData.actions].vecEnd:getWorldPosition() - origin:getWorldPosition()) * i
                renderVector(tags, prevPos, pos, vecColor, 0.03)
                prevPos = pos
            end
        end
        if primaryState == 1 then
            selfData.actions[#selfData.actions + 1] = {
                action = "setVectorRange",
                range = nSteps
            }
            recalculateNextAction = true
        end
        if selfData.selecting == "to" then
            if selfData.toOrigin:getBody():isOnLift() then
                multitool.BlockSelector.bodyConstraint = selfData.toOrigin:getBody():getCreationBodies()
            else
                multitool.BlockSelector.bodyConstraint = { selfData.toOrigin:getBody() }
            end
            sm.gui.setInteractionText(
            "Specify the range of the " ..
            MTMultitoolLib.formatOrdinal(selfData.nDimsTo) ..
            " dimension vector of the destination tensor" ..
            " <p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>(" .. (nSteps + 1) .. ")</p>",
                sm.gui.getKeyBinding("Create", true), "Select")
        else
            if selfData.fromOrigin:getBody():isOnLift() then
                multitool.BlockSelector.bodyConstraint = selfData.fromOrigin:getBody():getCreationBodies()
            else
                multitool.BlockSelector.bodyConstraint = { selfData.fromOrigin:getBody() }
            end
            sm.gui.setInteractionText(
            "Specify the range of the " ..
            MTMultitoolLib.formatOrdinal(selfData.nDimsFrom) ..
            " dimension vector of the source tensor" ..
            " <p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>(" .. (nSteps + 1) .. ")</p>",
                sm.gui.getKeyBinding("Create", true), "Select")
        end
    elseif selfData.nextAction == "confirm" then
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true), "Toggle",
            "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
            multitool.ConnectionManager.mode .. "<p>")
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Connect")
        multitool.BlockSelector.enabled = false
        if MTMultitool.handleForceBuild(multitool, forceBuild) then
            ConnectionManager.toggleMode(multitool)
        end
        if primaryState == 1 then
            TensorConnect.calculatePreview(multitool)
            ConnectionManager.commitPreview(multitool)
            TensorConnect.cleanUp(multitool)
        end
    end
    
    -- render all previously selected vectors
    for i = 0, #selfData.vectorsFrom - 1 do
        local vecColor = colorOrder[math.fmod(i, #colorOrder) + 1]
        local fromCreationRotationQuat = selfData.fromOrigin:getBody().worldRotation
        local prevPos = selfData.fromOrigin:getWorldPosition()
        for l = 1, selfData.dimSteps[i + 1] do
            if l > 10 and l < selfData.dimSteps[i + 1] - 10 then
                goto continue
            end
            -- gotta rotate selfData.vectorsFrom[i + 1] * l / 4 by fromCreationRotationQuat
            local pos = selfData.fromOrigin:getWorldPosition() +
                fromCreationRotationQuat * (selfData.vectorsFrom[i + 1] * l / 4)
            renderVector(tags, prevPos, pos, vecColor, 0.03)
            prevPos = pos
            ::continue::
        end
    end

    if selfData.selecting == "to" then
        for i = 0, #selfData.vectorsTo - 1 do
            local vecColor = colorOrder[math.fmod(i, #colorOrder) + 1]
            local toCreationRotationQuat = selfData.toOrigin:getBody().worldRotation
            local prevPos = selfData.toOrigin:getWorldPosition()
            for l = 1, selfData.dimSteps[i + 1] do
                if l > 10 and l < selfData.dimSteps[i + 1] - 10 then
                    goto continue
                end
                local pos = selfData.toOrigin:getWorldPosition() + toCreationRotationQuat * (selfData.vectorsTo[i + 1] * l / 4)
                renderVector(tags, prevPos, pos, vecColor, 0.03)
                prevPos = pos
                ::continue::
            end
        end
    end

    if recalculateNextAction then
        TensorConnect.recalculateNextAction(multitool)
    end
    selfData.nametagUpdate(tags)
end

function TensorConnect.recalculateNextAction(multitool)
    local self = multitool.TensorConnect
    local selfData = self.data
    local actions = selfData.actions
    if #actions == 0 then
        selfData.nextAction = "selectOrigin"
        return
    end
    local nextAction = "selectOrigin"
    local selecting = "from"
    local nDimsFrom = 0
    local nDimsTo = 0
    local dimSteps = {}
    local dimIndex = 1
    local vectorsFrom = {}
    local vectorsTo = {}
    for i, actionObj in pairs(actions) do
        local action = actionObj.action
        if action == "selectOrigin" then
            if nextAction == "selectOrigin" then
                if selecting == "from" then
                    selfData.fromOrigin = actionObj.origin
                elseif selecting == "to" then
                    selfData.toOrigin = actionObj.origin
                else
                    error("Invalid selecting: " .. selecting)
                end
                nextAction = "nextVector"
                if selecting == "to" then
                    if nDimsTo == nDimsFrom then
                        nextAction = "confirm"
                    end
                end
            else
                error("Invalid action sequence: expected 'selectOrigin' but got '" .. nextAction .. "'")
            end
        elseif action == "nextVector" then
            if nextAction == "nextVector" then
                if selecting == "from" then
                    if selfData.fromOrigin:getBody():isOnLift() then
                        vectorsFrom[dimIndex] = actionObj.vecEnd:getWorldPosition() -
                        selfData.fromOrigin:getWorldPosition()
                    else
                        vectorsFrom[dimIndex] = MTMultitoolLib.getLocalCenter(actionObj.vecEnd) -
                            MTMultitoolLib.getLocalCenter(selfData.fromOrigin)
                    end
                    nDimsFrom = nDimsFrom + 1
                    dimSteps[dimIndex] = 0
                    if vectorsFrom[dimIndex]:length() == 0 then
                        dimIndex = dimIndex + 1
                        nextAction = "nextVector"
                    else
                        nextAction = "setVectorRange"
                    end
                elseif selecting == "to" then
                    if selfData.toOrigin:getBody():isOnLift() then
                        vectorsTo[dimIndex] = actionObj.vecEnd:getWorldPosition() - selfData.toOrigin:getWorldPosition()
                    else
                        vectorsTo[dimIndex] = MTMultitoolLib.getLocalCenter(actionObj.vecEnd) -
                        MTMultitoolLib.getLocalCenter(selfData.toOrigin)
                    end
                    nextAction = "nextVector"
                    nDimsTo = nDimsTo + 1
                    if dimSteps[dimIndex] == 0 then
                        nextAction = "setVectorRange"
                    elseif nDimsTo == nDimsFrom then
                        nextAction = "confirm"
                    else
                        dimIndex = dimIndex + 1
                        nextAction = "nextVector"
                    end
                else
                    error("Invalid selecting: " .. selecting)
                end
            else
                error("Invalid action sequence: expected 'nextVector' but got '" .. nextAction .. "'")
            end
        elseif action == "setVectorRange" then
            dimSteps[dimIndex] = actionObj.range
            dimIndex = dimIndex + 1
            if nextAction == "setVectorRange" then
                if selecting == "from" then
                    nextAction = "nextVector"
                elseif selecting == "to" then
                    if nDimsTo == nDimsFrom then
                        nextAction = "confirm"
                    else
                        nextAction = "nextVector"
                    end
                else
                    error("Invalid selecting: " .. selecting)
                end
            else
                error("Invalid action sequence: expected 'setVectorRange' but got '" .. nextAction .. "'")
            end
        elseif action == "switchToDestination" then
            dimIndex = 1
            if nextAction == "nextVector" then
                nextAction = "selectOrigin"
                selecting = "to"
            else
                error("Invalid action sequence: expected 'switchToDestination' but got '" .. nextAction .. "'")
            end
        else
            error("Invalid action: " .. action)
        end
    end
    selfData.nextAction = nextAction
    selfData.selecting = selecting
    selfData.nDimsFrom = nDimsFrom
    selfData.nDimsTo = nDimsTo
    selfData.selecting = selecting
    selfData.dimSteps = dimSteps
    selfData.vectorsFrom = vectorsFrom
    selfData.vectorsTo = vectorsTo
    if nextAction == "confirm" then
        TensorConnect.calculatePreview(multitool)
    else
        multitool.ConnectionManager.preview = {}
    end
end

function TensorConnect.client_onUpdate(multitool)
    local self = multitool.TensorConnect
    local selfData = self.data
    local actions = selfData.actions
    if #actions == 0 then
        return
    end
    -- check if origins still exist
    for i, actionObj in pairs(actions) do
        local action = actionObj.action
        if action == "selectOrigin" then
            if not sm.exists(actionObj.origin) then
                TensorConnect.cleanUp(multitool)
                return
            end
        end
    end
end

function TensorConnect.cleanUp(multitool)
    local self = multitool.TensorConnect
    local selfData = self.data
    selfData.actions = {}
    selfData.nextAction = "selectOrigin"
    selfData.selecting = "from"
    selfData.nDimsFrom = 0
    selfData.nDimsTo = 0
    selfData.fromOrigin = nil
    selfData.toOrigin = nil
    selfData.selecting = "from"
    selfData.dimSteps = {}
    selfData.vectorsFrom = {}
    selfData.vectorsTo = {}
    multitool.ConnectionManager.preview = {}
end

function TensorConnect.calculatePreview(multitool)
    local self = multitool.TensorConnect
    local selfData = self.data
    local dimSteps = selfData.dimSteps
    local fromOrigin = selfData.fromOrigin
    local toOrigin = selfData.toOrigin
    local vectorsFrom = selfData.vectorsFrom
    local vectorsTo = selfData.vectorsTo
    local counting = {}
    for i, dimStep in pairs(dimSteps) do
        counting[i] = 0
    end
    local tasksListByPositions = {}
    local nDims = #dimSteps
    local fromPositions = {}
    local toPositions = {}
    while true do
        -- print(counting)
        local fromPos = MTMultitoolLib.getLocalCenter(fromOrigin)
        local toPos = MTMultitoolLib.getLocalCenter(toOrigin)
        if fromOrigin:getBody():isOnLift() then
            fromPos = fromOrigin:getWorldPosition()
            toPos = toOrigin:getWorldPosition()
        end
        local fromOffset = sm.vec3.new(0, 0, 0)
        local toOffset = sm.vec3.new(0, 0, 0)
        for i, dimStep in pairs(dimSteps) do
            fromOffset = fromOffset + vectorsFrom[i] * counting[i]
            toOffset = toOffset + vectorsTo[i] * counting[i]
        end
        local task = {
            from = fromPos + fromOffset,
            to = toPos + toOffset,
        }
        table.insert(tasksListByPositions, task)
        table.insert(fromPositions, fromPos + fromOffset)
        table.insert(toPositions, toPos + toOffset)
        -- increment the first dimension, then carry over to the next dimension if necessary
        counting[1] = counting[1] + 1
        local i = 1
        while counting[i] > dimSteps[i] do
            counting[i] = 0
            i = i + 1
            if i > nDims then
                break
            end
            counting[i] = counting[i] + 1
        end
        if i > nDims then
            break
        end
    end
    multitool.ConnectionManager.preview = {}
    local voxelGridFrom = {}
    local voxelGridTo = {}
    if fromOrigin:getBody():isOnLift() then
        voxelGridFrom = MTMultitoolLib.createVoxelGridFromCreationBodies(fromOrigin:getBody():getCreationBodies())
        voxelGridTo = MTMultitoolLib.createVoxelGridFromCreationBodies(toOrigin:getBody():getCreationBodies())
    else
        voxelGridFrom = MTMultitoolLib.createVoxelGrid(fromOrigin:getBody())
        voxelGridTo = MTMultitoolLib.createVoxelGrid(toOrigin:getBody())
    end
    local offsets = {
        sm.vec3.new(0, 0, 1),
        sm.vec3.new(0, 0, -1),
        sm.vec3.new(0, 1, 0),
        sm.vec3.new(0, -1, 0),
        sm.vec3.new(1, 0, 0),
        sm.vec3.new(-1, 0, 0)
    }
    for i, task in pairs(tasksListByPositions) do
        local from = MTMultitoolLib.getShapeAtVoxelGrid(voxelGridFrom, task.from)
        local to = MTMultitoolLib.getShapeAtVoxelGrid(voxelGridTo, task.to)
        if (from ~= nil) and (to ~= nil) then
            local task = {
                from = from,
                to = to
            }
            table.insert(multitool.ConnectionManager.preview, task)
        end
    end
end