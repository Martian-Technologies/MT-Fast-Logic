-- Optional connection and state overlays shared by every NewTool mode.

NewToolInspectionSettings = {}

local targetColor = sm.color.new(1, 1, 1, 1)
local inputColor = sm.color.new(0.2, 1, 0.2, 1)
local outputColor = sm.color.new(1, 0.25, 0.25, 1)
local selfColor = sm.color.new(1, 0.8, 0.15, 1)
local maximumPreviewLines = 256
local siliconAimRadius = 0.18
local connectionToolUuid = "8c7efc37-cd7c-4262-976e-39585f8527bf"

local stateOnlyUuids = {
    ["9f0f56e8-2c31-4d83-996c-d00a9b296c3f"] = true,
    ["8f7fd0e7-c46e-4944-a414-7ce2437bb30f"] = true,
    ["ce73327a-1cf9-49cc-9ee7-e63110ccc43f"] = true,
    ["1e8d93a4-506b-470d-9ada-9c0a321e2db5"] = true,
    ["7cf717d7-d167-4f2d-a6e7-6b2c70aa3986"] = true,
    ["161786c1-1290-4817-8f8b-7f80de755a06"] = true,
    ["4c6e27a2-4c35-4df3-9794-5e206fef9012"] = true,
    ["a052e116-f273-4d73-872c-924a97b86720"] = true,
    ["1c04327f-1de4-4b06-92a8-2c9b40e491aa"] = true
}

local noDisplayUuids = {
    ["1d4f99c0-1df8-4acb-9fd4-f3437062016c"] = true
}

local function interactableId(interactable)
    if interactable == nil then return nil end
    local ok, id = pcall(function() return interactable:getId() end)
    if ok then return id end
    return interactable.id
end

local function getCreation(body)
    local api = sm.MTFastLogic
    if api == nil or api.CreationUtil == nil or api.Creations == nil or body == nil then return nil end
    local ok, creationId = pcall(api.CreationUtil.getCreationId, body)
    if not ok then return nil end
    return api.Creations[creationId]
end

local function resolveFastEndpoint(creation, uuid)
    if creation == nil or creation.blocks == nil then return nil end
    local block = creation.blocks[uuid]
    if block == nil then return nil end

    if block.isSilicon then
        local silicon = creation.SiliconBlocks and creation.SiliconBlocks[block.siliconBlockId] or nil
        local shape = silicon and silicon.shape or nil
        if shape == nil or not sm.exists(shape) then return nil end
        return {
            key = "fast:" .. tostring(uuid),
            uuid = uuid,
            block = block,
            creation = creation,
            position = shape:getBody():transformPoint(block.pos / 4),
            shape = shape,
            virtual = true
        }
    end

    local realBlock = creation.AllFastBlocks and creation.AllFastBlocks[uuid] or nil
    local shape = realBlock and realBlock.shape or nil
    if shape == nil or not sm.exists(shape) then return nil end
    return {
        key = "fast:" .. tostring(uuid),
        uuid = uuid,
        block = block,
        creation = creation,
        position = shape:getWorldPosition(),
        shape = shape,
        interactable = shape:getInteractable(),
        virtual = false
    }
end

local function endpointFromInteractable(interactable, creation)
    if interactable == nil then return nil end
    local shape = interactable:getShape()
    if shape == nil or not sm.exists(shape) then return nil end

    local id = interactableId(interactable)
    local uuid = creation and creation.uuids and creation.uuids[id] or nil
    if uuid ~= nil then
        local endpoint = resolveFastEndpoint(creation, uuid)
        if endpoint ~= nil then return endpoint end
    end

    return {
        key = "interactable:" .. tostring(id),
        position = shape:getWorldPosition(),
        shape = shape,
        interactable = interactable,
        creation = creation,
        virtual = false
    }
end

local function refreshTarget(target)
    if target == nil then return nil end
    if target.uuid ~= nil and target.creation ~= nil then
        return resolveFastEndpoint(target.creation, target.uuid)
    end
    if target.shape == nil or not sm.exists(target.shape) then return nil end
    local interactable = target.shape:getInteractable()
    if interactable == nil then return nil end
    return endpointFromInteractable(interactable, getCreation(target.shape:getBody()))
end

local function findSiliconCell(creation, siliconId)
    local origin = sm.camera.getPosition()
    local direction = sm.camera.getDirection()
    local best = nil
    local bestDistance = nil

    for uuid, block in pairs(creation.blocks or {}) do
        if block.isSilicon and block.siliconBlockId == siliconId then
            local endpoint = resolveFastEndpoint(creation, uuid)
            if endpoint ~= nil then
                local offset = endpoint.position - origin
                local distance = offset:dot(direction)
                local lateral = offset - direction * distance
                if distance >= 0 and lateral:length2() <= siliconAimRadius * siliconAimRadius and
                    (bestDistance == nil or distance < bestDistance) then
                    best = endpoint
                    bestDistance = distance
                end
            end
        end
    end
    return best
end

local function queryTarget(context, findLogicalTarget, options)
    options = options or {}
    local didHit, result = context.targeting.queryBlock({
        raycastMode = options.raycastMode or "DDA",
        maxDistance = options.maxDistance
    })
    if not didHit or result == nil then return nil, nil, nil end

    local shape = result:getShape()
    if shape == nil or not sm.exists(shape) then return nil, nil, nil end
    local interactable = shape:getInteractable()
    if interactable == nil then return nil, nil, nil end

    local creation = getCreation(shape:getBody())
    local id = interactableId(interactable)
    local silicon = creation and creation.SiliconBlocks and creation.SiliconBlocks[id] or nil
    if silicon ~= nil then
        local target = findLogicalTarget and findSiliconCell(creation, id) or nil
        return target, shape, result
    end

    local target = findLogicalTarget and endpointFromInteractable(interactable, creation) or nil
    return target, shape, result
end

local function collectConnections(target)
    local inputs = {}
    local outputs = {}
    local inputKeys = {}
    local outputKeys = {}
    local selfWired = false

    local function add(list, keys, endpoint)
        if endpoint == nil then return end
        if endpoint.key == target.key then
            selfWired = true
            return
        end
        if keys[endpoint.key] then return end
        keys[endpoint.key] = true
        list[#list + 1] = endpoint
    end

    if target.block ~= nil and target.creation ~= nil then
        for _, uuid in pairs(target.block.inputs or {}) do
            add(inputs, inputKeys, resolveFastEndpoint(target.creation, uuid))
        end
        for _, uuid in pairs(target.block.outputs or {}) do
            add(outputs, outputKeys, resolveFastEndpoint(target.creation, uuid))
        end
    end

    if target.interactable ~= nil then
        for _, parent in pairs(target.interactable:getParents() or {}) do
            add(inputs, inputKeys, endpointFromInteractable(parent, target.creation))
        end
        for _, child in pairs(target.interactable:getChildren() or {}) do
            add(outputs, outputKeys, endpointFromInteractable(child, target.creation))
        end
    end

    return inputs, outputs, selfWired
end

local function drawMarker(context, position, color)
    local size = 0.07
    local options = { color = color, thickness = 0.008 }
    context.lineRenderer.draw(position - sm.vec3.new(size, 0, 0), position + sm.vec3.new(size, 0, 0), options)
    context.lineRenderer.draw(position - sm.vec3.new(0, size, 0), position + sm.vec3.new(0, size, 0), options)
    context.lineRenderer.draw(position - sm.vec3.new(0, 0, size), position + sm.vec3.new(0, 0, size), options)
end

local function drawEndpoint(context, endpoint, color)
    if endpoint.virtual then
        drawMarker(context, endpoint.position, color)
    else
        context.renderer.drawShape(endpoint.shape, { color = color })
    end
end

local function drawConnections(context, target)
    local inputs, outputs, selfWired = collectConnections(target)
    drawEndpoint(context, target, targetColor)

    local drawn = 0
    for _, endpoint in ipairs(inputs) do
        if drawn >= maximumPreviewLines then break end
        context.lineRenderer.drawCurve(endpoint.position, target.position, { color = inputColor, thickness = 0.008 })
        drawEndpoint(context, endpoint, inputColor)
        drawn = drawn + 1
    end
    for _, endpoint in ipairs(outputs) do
        if drawn >= maximumPreviewLines then break end
        context.lineRenderer.drawCurve(target.position, endpoint.position, { color = outputColor, thickness = 0.008 })
        drawEndpoint(context, endpoint, outputColor)
        drawn = drawn + 1
    end
    if selfWired then drawMarker(context, target.position, selfColor) end
end

local function displayState(shape)
    if shape == nil or not sm.exists(shape) then return end
    local interactable = shape:getInteractable()
    if interactable == nil then return end

    local uuid = tostring(shape:getShapeUuid())
    local state = nil
    local power = nil
    local lookup = sm.MTFastLogic and sm.MTFastLogic.client_FastLogicBlockLookUp or nil
    local fastBlock = lookup and lookup[interactableId(interactable)] or nil
    local isFastLogic = fastBlock ~= nil

    if isFastLogic then
        state = fastBlock.state
    else
        local stateOk, stateValue = pcall(function() return interactable:isActive() end)
        local powerOk, powerValue = pcall(function() return interactable:getPower() end)
        if stateOk then state = stateValue end
        if powerOk then power = powerValue end
    end

    if isFastLogic or noDisplayUuids[uuid] or stateOnlyUuids[uuid] then power = nil end
    if noDisplayUuids[uuid] then state = nil end
    if state == nil and power == nil then return end

    local stateValue = state and tr("mt.common.true") or tr("mt.common.false")
    local text = nil
    if state ~= nil and power ~= nil then
        local textId = "mt.state_display.state_power"
        if MTLocalization ~= nil and MTLocalization.getSystemLanguage() == "Russian" then
            textId = "mt.state_display.state_power_inline"
        end
        text = tr(textId, { state = stateValue, power = power })
    elseif state ~= nil then
        text = tr("mt.state_display.state", { state = stateValue })
    else
        text = tr("mt.state_display.power", { power = power })
    end
    sm.gui.displayAlertText(text, 1)
end

function NewToolInspectionSettings.init(tool)
    tool.InspectionSettings = {}
    local self = tool.InspectionSettings
    local lastConnectionTarget = nil

    local function toggle(name, label)
        local enabled = tool.SettingsStore.toggle(name)
        if enabled == nil then return end
        sm.gui.displayAlertText(label .. ": " .. (enabled and "ON" or "OFF"), 2)
    end

    function self.toggleConnectionShower()
        toggle("connectionShower", "Connection Shower")
    end

    function self.toggleStateDisplay()
        toggle("stateDisplay", "State Display")
    end

    function self.toggleHideConnectionOnLookAway()
        toggle("hideConnectionOnLookAway", "Hide Connection On Look Away")
    end

    function self.shouldRunWithConnectionTool()
        local activeItem = tostring(sm.localPlayer.getActiveItem())
        local enabled = tool.SettingsStore.get("connectionShower") == true or
            tool.SettingsStore.get("stateDisplay") == true
        return enabled and activeItem == connectionToolUuid
    end

    function self.shouldRunWhileUnequipped()
        return lastConnectionTarget ~= nil and
            tool.SettingsStore.get("connectionShower") == true and
            tool.SettingsStore.get("hideConnectionOnLookAway") ~= true
    end

    function self.update(context, options)
        local showConnections = tool.SettingsStore.get("connectionShower") == true
        local showState = tool.SettingsStore.get("stateDisplay") == true
        if not showConnections and not showState then return end

        options = options or {}
        local target, shape, result = nil, nil, nil
        if options.forceLookAway ~= true then
            target, shape, result = queryTarget(context, showConnections, options)
        end
        if showState then displayState(shape) end
        if not showConnections then return end

        local isLookingAtTarget = target ~= nil
        if isLookingAtTarget then
            lastConnectionTarget = target
        elseif tool.SettingsStore.get("hideConnectionOnLookAway") ~= true then
            lastConnectionTarget = refreshTarget(lastConnectionTarget)
            target = lastConnectionTarget
        end

        if target ~= nil then
            if isLookingAtTarget and options.showTarget ~= false then context.renderer.showTarget(result) end
            drawConnections(context, target)
        end
    end
end
