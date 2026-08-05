dofile "../TensorUtil.lua"

CopyPaste = {}

sm.MTCopyPasteLiftData = sm.MTCopyPasteLiftData or {}
sm.MTCopyPasteBodyLocks = sm.MTCopyPasteBodyLocks or {}
if sm.isServerMode() and not sm.MTCopyPasteLiftHooked then
    local originalPlaceLift = sm.player.placeLift

    sm.player.placeLift = function(player, selectedBodies, liftPosition, liftLevel, rotationIndex)
        local selectedShapes = {}
        if selectedBodies ~= nil and selectedBodies[1] ~= nil and sm.exists(selectedBodies[1]) then
            selectedShapes = selectedBodies[1]:getCreationShapes()
        end

        sm.MTCopyPasteLiftData[player.id] = {
            player = player,
            selectedShapes = selectedShapes,
            liftPosition = liftPosition,
            liftLevel = liftLevel,
            rotationIndex = rotationIndex
        }

        return originalPlaceLift(player, selectedBodies, liftPosition, liftLevel, rotationIndex)
    end

    sm.MTCopyPasteLiftHooked = true
end

function CopyPaste.inject(multitool)
    multitool.CopyPaste = {}
    local self = multitool.CopyPaste
    self.nametagUpdate = NametagManager.createController(multitool)
    self.actions = {}
    self.origin = nil
    self.vectors = {}
    self.selectingShapes = true
    self.selectionMode = "region" -- "region" or "individual"
    self.selectedShapes = {}
    self.activeBody = nil
    self.targeting = "subsurface" -- "subsurface" or "surface"
    self.shapeGroups = {}
    self.shapeVisualizations = {}
    self.toCopyPastePackets = {}
    self.externalConnectionsPolicy = "absolute" -- "ignore" | "absolute" | "relative"
    self.lastLiftId = nil
    self.lastLiftLevel = nil
end

local plasticUuid = sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a")

local function localizeExternalConnectionsPolicy(policy)
    return tr("mt.copy.policy." .. policy)
end

local function getEffectData(shape)
	local isShape = type(shape) == "Shape"
	local scale = sm.vec3.one() / 4
	local uuid = shape.uuid

	if isShape then
		if shape.isBlock then
			uuid = plasticUuid
			scale = shape:getBoundingBox() + sm.vec3.one() / 1000
		end
	else
		if shape:getType() == "piston" then
			local pistonLength = shape:getLength()
			local lifted = shape.shapeA.body:isOnLift()

			if pistonLength > 1.05 and not lifted then
				uuid = plasticUuid
				scale.z = pistonLength / 4
			end
		end
	end

	return uuid, scale
end

local function addShapes(multitool, shapes)
    if #shapes == 0 then
        return
    end
    local self = multitool.CopyPaste
    local shapeGroup = {}
    for _, shape in ipairs(shapes) do
        if not table.contains(self.selectedShapes, shape) then
            table.insert(self.selectedShapes, shape)
            table.insert(shapeGroup, shape)
            local effect = self.shapeVisualizations[shape:getId()]
            if effect == nil then
                effect = sm.effect.createEffect("ShapeRenderable")
                self.shapeVisualizations[shape:getId()] = effect
            end
            effect:setParameter("visualization", true)
            effect:start()
            effect:setPosition(shape:getInterpolatedWorldPosition())
            effect:setRotation(shape.worldRotation)

            local uuid, scale = getEffectData(shape)

            effect:setParameter("uuid", uuid)
            effect:setScale(scale)
        end
    end
    if #shapeGroup > 0 then
        table.insert(self.shapeGroups, shapeGroup)
    end
end

local function undoShapeSelect(multitool)
    local self = multitool.CopyPaste
    if #self.shapeGroups == 0 then
        self.shapeGroups = {}
        self.selectedShapes = {}
        return
    end
    local shapeGroup = self.shapeGroups[#self.shapeGroups]
    table.remove(self.shapeGroups, #self.shapeGroups)
    for _, shape in ipairs(shapeGroup) do
        for i, selectedShape in ipairs(self.selectedShapes) do
            if shape == selectedShape then
                table.remove(self.selectedShapes, i)
                local effect = self.shapeVisualizations[shape:getId()]
                if effect ~= nil then
                    effect:stop()
                end
                break
            end
        end
    end
    if #self.selectedShapes == 0 then
        self.shapeGroups = {}
        self.activeBody = nil
    end
end

local function doCopyPaste(multitool)
    local self = multitool.CopyPaste
    local vectors = {}
    local interactables = {}
    local shapes = {}
    for i = 1, #self.selectedShapes do
        local shape = self.selectedShapes[i]
        local interactable = shape:getInteractable()
        if interactable ~= nil then
            table.insert(interactables, interactable:getId())
        else
            table.insert(shapes, shape)
        end
    end
    for i = 1, #self.vectors do
        local vec = self.vectors[i]
        table.insert(vectors, {
            step = vec.step * 4,
            nSteps = vec.range
        })
    end
    local ownedLift = sm.localPlayer.getOwnedLift()
    local data = {
        interactables = interactables,
        shapes = shapes,
        vectors = vectors,
        body = self.activeBody,
        externalConnections = self.externalConnectionsPolicy, -- "ignore" | "absolute" | "relative"
        ownedLift = ownedLift ~= nil and {
            liftPosition = ownedLift.worldPosition * 4,
            liftLevel = ownedLift.level
        } or nil
    }
    multitool.network:sendToServer("server_copyPaste", data)
end

local function positionKey(position)
    return string.format("%.6f;%.6f;%.6f", position.x, position.y, position.z)
end

local function getSelectedControllerData(creationTable, interactables)
    local selected = {}
    local result = {}
    for _, intId in ipairs(interactables) do
        selected[intId] = true
    end
    for _, body in ipairs(creationTable.bodies or {}) do
        for _, shape in ipairs(body.childs or {}) do
            local controller = shape.controller
            if controller ~= nil and selected[controller.id] then
                result[controller.id] = { data = controller.data }
            end
        end
    end
    return result
end

local function restorePreparedBlocks(preparedBlocks)
    local restored = true
    for _, prepared in ipairs(preparedBlocks or {}) do
        if prepared.block ~= nil then
            local success = pcall(
                prepared.block.restoreUuidData, prepared.block, prepared.storageData)
            restored = restored and success
        end
    end
    return restored
end

local function findLiftData(body, player)
    for _, liftData in pairs(sm.MTCopyPasteLiftData) do
        for _, shape in pairs(liftData.selectedShapes) do
            if sm.exists(shape) and shape.body.id == body.id then
                return liftData
            end
        end
    end

    if player ~= nil then
        return sm.MTCopyPasteLiftData[player.id]
    end
end

local function getLiftPositionAdjustment(bodies, liftPosition)
    local lowest = nil
    local highest = nil
    for _, body in pairs(bodies) do
        local low, high = body:getWorldAabb()
        lowest = lowest == nil and low or lowest:min(low)
        highest = highest == nil and high or highest:max(high)
    end

    if lowest == nil then
        return sm.vec3.zero()
    end

    local difference = (lowest + (highest - lowest) / 2 - liftPosition / 4) * 4
    if difference.x >= -1 and difference.x <= 1 then
        difference.x = 0
    end
    if difference.y >= -1 and difference.y <= 1 then
        difference.y = 0
    end
    difference.z = 0
    return difference
end

function CopyPaste.client_onUpdate(multitool)
    if not multitool.tool:isLocal() then
        return
    end

    local self = multitool.CopyPaste
    local lift = sm.localPlayer.getOwnedLift()
    if lift == nil then
        self.lastLiftId = nil
        self.lastLiftLevel = nil
        return
    end

    if self.lastLiftId ~= lift.id or self.lastLiftLevel ~= lift.level then
        self.lastLiftId = lift.id
        self.lastLiftLevel = lift.level
        multitool.network:sendToServer("sv_updateCopyPasteLiftLevel", {
            liftPosition = lift.worldPosition * 4,
            liftLevel = lift.level
        })
    end
end

function CopyPaste.server_updateLiftLevel(multitool, data, player)
    local liftData = sm.MTCopyPasteLiftData[player.id]
    if liftData == nil then
        liftData = {
            player = player,
            selectedShapes = {},
            rotationIndex = 0
        }
        sm.MTCopyPasteLiftData[player.id] = liftData
    end

    liftData.liftPosition = data.liftPosition
    liftData.liftLevel = data.liftLevel
end

function CopyPaste.client_copyPasteFailed(multitool, messageId)
    sm.gui.displayAlertText(tr(messageId))
end

function CopyPaste.server_copyPaste(multitool, data, player)
    if data.ownedLift ~= nil and player ~= nil then
        CopyPaste.server_updateLiftLevel(multitool, data.ownedLift, player)
    end

    local targetBody = data.body
    if targetBody == nil or not sm.exists(targetBody) then
        return
    end

    local creationId = sm.MTFastLogic.CreationUtil.getCreationId(targetBody)
    if sm.MTCopyPasteBodyLocks[creationId] then
        print("CopyPaste: another copy operation is already preparing this creation")
        return
    end

    local creation = sm.MTFastLogic.Creations[creationId]
    local selectedBlocks = {}
    local selectedBlockIds = {}
    if creation ~= nil then
        for _, intId in ipairs(data.interactables or {}) do
            local uuid = creation.uuids[intId]
            local block = uuid ~= nil and creation.AllFastBlocks[uuid] or nil
            if block ~= nil and not selectedBlockIds[intId] then
                if block.hasSiliconConnection ~= nil and block:hasSiliconConnection() then
                    if player ~= nil then
                        multitool.network:sendToClient(player, "cl_copyPasteFailed",
                            "mt.copy.silicon_blocks_cannot_be_copied")
                    end
                    return
                end
                selectedBlockIds[intId] = true
                table.insert(selectedBlocks, block)
            end
        end
    end

    if #selectedBlocks == 0 then
        CopyPaste.doCopyPaste(multitool, data)
        return
    end

    sm.MTCopyPasteBodyLocks[creationId] = true
    local preparedBlocks = {}
    local prepared, prepareError = pcall(function()
        for _, block in ipairs(selectedBlocks) do
            if block.type == "BlockMemory" and block.server_saveHeldMemory ~= nil then
                block:server_saveHeldMemory()
            end
            local success, storageData = block:removeUuidData()
            if not success then
                error("selected Fast Logic block is connected to Silicon")
            end
            table.insert(preparedBlocks, {
                block = block,
                storageData = storageData
            })
        end
    end)

    if not prepared then
        restorePreparedBlocks(preparedBlocks)
        sm.MTCopyPasteBodyLocks[creationId] = nil
        print("CopyPaste: failed to prepare Fast Logic data: " .. tostring(prepareError))
        if player ~= nil then
            multitool.network:sendToClient(player, "cl_copyPasteFailed",
                "mt.copy.silicon_blocks_cannot_be_copied")
        end
        return
    end

    multitool.sv_copyPastePackets = multitool.sv_copyPastePackets or {}
    table.insert(multitool.sv_copyPastePackets, {
        data = data,
        creationId = creationId,
        preparedBlocks = preparedBlocks,
        phase = "sanitized",
        tick = sm.game.getCurrentTick() + 1
    })
end

function CopyPaste.server_onFixedUpdate(multitool, dt)
    local packets = multitool.sv_copyPastePackets
    if packets == nil then
        return
    end

    for packetIndex = #packets, 1, -1 do
        local packet = packets[packetIndex]
        if sm.game.getCurrentTick() >= packet.tick then
            local targetBody = packet.data.body
            if targetBody == nil or not sm.exists(targetBody) then
                if not restorePreparedBlocks(packet.preparedBlocks) then
                    print("CopyPaste: failed to restore Fast Logic data after the target was removed")
                end
                sm.MTCopyPasteBodyLocks[packet.creationId] = nil
                table.remove(packets, packetIndex)
            elseif packet.phase == "sanitized" then
                local isLifted = targetBody:isOnLift()
                local success, creationTable = pcall(sm.creation.exportToTable, targetBody, true, isLifted)
                if success and creationTable ~= nil then
                    packet.data.copyControllerData = getSelectedControllerData(
                        creationTable, packet.data.interactables)
                    if restorePreparedBlocks(packet.preparedBlocks) then
                        packet.preparedBlocks = nil
                        packet.phase = "original"
                    else
                        packet.phase = "restore"
                        print("CopyPaste: retrying Fast Logic data restoration")
                    end
                    packet.tick = sm.game.getCurrentTick() + 1
                else
                    restorePreparedBlocks(packet.preparedBlocks)
                    sm.MTCopyPasteBodyLocks[packet.creationId] = nil
                    table.remove(packets, packetIndex)
                    print("CopyPaste: failed to export UUID-free controller data: " .. tostring(creationTable))
                end
            elseif packet.phase == "restore" then
                if restorePreparedBlocks(packet.preparedBlocks) then
                    packet.preparedBlocks = nil
                    packet.phase = "original"
                end
                packet.tick = sm.game.getCurrentTick() + 1
            else
                local isLifted = targetBody:isOnLift()
                local success, creationTable = pcall(sm.creation.exportToTable, targetBody, true, isLifted)
                sm.MTCopyPasteBodyLocks[packet.creationId] = nil
                table.remove(packets, packetIndex)
                if success and creationTable ~= nil then
                    packet.data.creationTable = creationTable
                    local copied, err = pcall(CopyPaste.doCopyPaste, multitool, packet.data)
                    if not copied then
                        print("CopyPaste: copy operation failed: " .. tostring(err))
                    end
                else
                    print("CopyPaste: failed to export restored creation data: " .. tostring(creationTable))
                end
            end
        end
    end
end

function CopyPaste.server_onDestroy(multitool)
    for _, packet in ipairs(multitool.sv_copyPastePackets or {}) do
        restorePreparedBlocks(packet.preparedBlocks)
        sm.MTCopyPasteBodyLocks[packet.creationId] = nil
    end
    multitool.sv_copyPastePackets = nil
end

function CopyPaste.doCopyPaste(multitool, data)
    local interactables = data.interactables
    local shapes = data.shapes
    local vectors = data.vectors
    local targetBody = data.body
    local externalConnections = data.externalConnections
    local isLifted = targetBody:isOnLift()
    local liftData = isLifted and findLiftData(targetBody, multitool.tool:getOwner()) or nil
    if isLifted and liftData == nil then
        print("CopyPaste: missing lift data; original creation was not changed")
        return
    end
    local creationTable = data.creationTable or sm.creation.exportToTable(targetBody, true, isLifted)
    local selectedControllerIds = {}
    for _, intId in ipairs(interactables) do
        selectedControllerIds[intId] = true
    end

    local targetBodyObject = nil
    for _, body in ipairs(creationTable.bodies or {}) do
        for _, shape in ipairs(body.childs or {}) do
            if shape.controller ~= nil and selectedControllerIds[shape.controller.id] then
                targetBodyObject = body
                break
            end
        end
        if targetBodyObject ~= nil then
            break
        end
    end
    targetBodyObject = targetBodyObject or (creationTable.bodies and creationTable.bodies[1])
    if targetBodyObject == nil then
        return
    end
    local targetBodyShapes = targetBodyObject.childs
    local originalPositionsTakenUpBySource = {}
    local tensor = {}

    sm.MTBackupEngine.sv_backupCreation({
        hasCreation = false,
        body = targetBody,
        nameId = "mt.backup.name.copy_paste",
        descriptionId = "mt.backup.description.copy_paste",
    })

    local creation = sm.MTFastLogic.Creations[sm.MTFastLogic.CreationUtil.getCreationId(targetBody)]
    local interactableModes = {}
    local interactableDelays = {}
    if creation ~= nil then
        for _, intId in ipairs(interactables) do
            local uuid = creation.uuids[intId]
            local block = uuid ~= nil and creation.blocks[uuid] or nil
            local type = block ~= nil and block.type or nil
            if type == "andBlocks" then
                interactableModes[intId] = 0
            elseif type == "orBlocks" then
                interactableModes[intId] = 1
            elseif type == "xorBlocks" then
                interactableModes[intId] = 2
            elseif type == "nandBlocks" then
                interactableModes[intId] = 3
            elseif type == "norBlocks" then
                interactableModes[intId] = 4
            elseif type == "xnorBlocks" then
                interactableModes[intId] = 5
            elseif type == "timerBlocks" then
                local seconds = creation.FastTimers[uuid].client_seconds
                local ticks = creation.FastTimers[uuid].client_ticks
                interactableDelays[intId] = FastLogicRunnerRunner.convertTimerDelayToData(seconds, ticks)
            end
        end
    end

    for i = 1, #vectors do
        table.insert(tensor, vectors[i].nSteps)
    end
    local selectedIndexById = {}
    for index, intId in ipairs(interactables) do
        selectedIndexById[intId] = index
    end

    local runtimeBodies = { targetBody }
    for _, body in ipairs(targetBody:getCreationBodies()) do
        if body ~= targetBody then
            table.insert(runtimeBodies, body)
        end
    end

    local controllerById = {}
    local positionsById = {}
    local idAtWorldPosition = {}
    local maxIntId = 0

    local function registerController(controller)
        if controller == nil then
            return
        end
        local intId = controller.id
        if type(intId) ~= "number" or intId < 0 or intId ~= math.floor(intId) then
            error("CopyPaste: creation contains an invalid controller id")
        end
        controllerById[intId] = controller
        maxIntId = math.max(maxIntId, intId)
    end

    for _, body in ipairs(creationTable.bodies) do
        for _, shape in ipairs(body.childs) do
            registerController(shape.controller)
        end
    end
    for _, joint in ipairs(creationTable.joints or {}) do
        registerController(joint.controller)
    end

    for _, body in ipairs(runtimeBodies) do
        local rawMap = MTMultitoolLib.getVoxelMapInteractableIds(body)
        for positionString, intId in pairs(rawMap) do
            local localPosition = string.stringToVec(positionString, ';')
            local worldPosition = body:transformPoint(localPosition)
            idAtWorldPosition[positionKey(worldPosition)] = intId
            positionsById[intId] = positionsById[intId] or {}
            table.insert(positionsById[intId], worldPosition)
        end
    end

    local internalShapesOrdered = {}
    for i = 1, #interactables do
        internalShapesOrdered[i] = false
    end
    for _, shape in ipairs(targetBodyShapes) do
        local controller = shape.controller
        local selectedIndex = controller ~= nil and selectedIndexById[controller.id] or nil
        if selectedIndex ~= nil then
            internalShapesOrdered[selectedIndex] = shape
        end
    end

    local selectedShapeIds = {}
    for _, shape in ipairs(shapes) do
        if sm.exists(shape) then
            selectedShapeIds[shape:getId()] = true
        end
    end
    local extraShapesToCopy = {}
    for shapeIndex, runtimeShape in ipairs(targetBody:getShapes()) do
        if selectedShapeIds[runtimeShape:getId()] then
            local exportedShape = targetBodyShapes[shapeIndex]
            if exportedShape ~= nil and exportedShape.controller == nil then
                table.insert(extraShapesToCopy, exportedShape)
            end
        end
    end

    for _, intId in ipairs(interactables) do
        originalPositionsTakenUpBySource[intId] = positionsById[intId] or {}
    end

    local internalConnections = {}
    local externalConnectionsIngoing = {}
    local externalConnectionsOutgoing = {}
    local unresolvedRelativeConnections = 0

    local function firstEndpoint(intId)
        local positions = positionsById[intId]
        return positions ~= nil and positions[1] or nil
    end

    for sourceId, sourceController in pairs(controllerById) do
        local sourceIndex = selectedIndexById[sourceId]
        for _, output in ipairs(sourceController.controllers or {}) do
            local targetId = output.id
            local targetIndex = selectedIndexById[targetId]
            if sourceIndex ~= nil and targetIndex ~= nil then
                table.insert(internalConnections, {
                    from = sourceIndex,
                    to = targetIndex
                })
            elseif externalConnections == "absolute" then
                if sourceIndex ~= nil then
                    table.insert(externalConnectionsOutgoing, {
                        from = sourceIndex,
                        to = targetId
                    })
                elseif targetIndex ~= nil then
                    table.insert(externalConnectionsIngoing, {
                        controller = sourceController,
                        to = targetIndex
                    })
                end
            elseif externalConnections == "relative" then
                if sourceIndex ~= nil then
                    local endpoint = firstEndpoint(targetId)
                    if endpoint ~= nil then
                        table.insert(externalConnectionsOutgoing, {
                            from = sourceIndex,
                            endpoint = endpoint
                        })
                    else
                        unresolvedRelativeConnections = unresolvedRelativeConnections + 1
                    end
                elseif targetIndex ~= nil then
                    local endpoint = firstEndpoint(sourceId)
                    if endpoint ~= nil then
                        table.insert(externalConnectionsIngoing, {
                            endpoint = endpoint,
                            to = targetIndex
                        })
                    else
                        unresolvedRelativeConnections = unresolvedRelativeConnections + 1
                    end
                end
            end
        end
    end

    if unresolvedRelativeConnections > 0 then
        print("CopyPaste: skipped " .. unresolvedRelativeConnections ..
            " relative connections without shape positions")
    end

    local jointChildInsertionIndex = 0
    for _, body in ipairs(creationTable.bodies) do
        jointChildInsertionIndex = jointChildInsertionIndex + #body.childs
        if body == targetBodyObject then
            break
        end
    end

    local relativeOutgoingToMake = {}
    local relativeIngoingToMake = {}

    local nShapesAdded = 0

    sm.MTTensorUtil.iterateTensor(tensor, function(number)
        local isAllZero = true
        for i = 1, #number do
            if number[i] ~= 0 then
                isAllZero = false
                break
            end
        end
        if isAllZero then
            return
        end
        local deltaP = sm.vec3.new(0, 0, 0)
        for i = 1, #number do
            deltaP = deltaP + vectors[i].step * number[i]
        end
        local worldDelta = targetBody.worldRotation * (deltaP / 4)
        local newShapes = {}
        for i = 1, #extraShapesToCopy do
            local nonInt = extraShapesToCopy[i]
            local newShape = table.deepCopy(nonInt)
            newShape.pos.x = newShape.pos.x + deltaP.x
            newShape.pos.y = newShape.pos.y + deltaP.y
            newShape.pos.z = newShape.pos.z + deltaP.z
            newShape.joints = nil
            table.insert(newShapes, newShape)
            nShapesAdded = nShapesAdded + 1
        end
        for i = 1, #interactables do
            local shape = internalShapesOrdered[i]
            if shape == false then
                goto continue
            end
            local newShape = table.deepCopy(shape)
            newShape.pos.x = newShape.pos.x + deltaP.x
            newShape.pos.y = newShape.pos.y + deltaP.y
            newShape.pos.z = newShape.pos.z + deltaP.z
            newShape.joints = nil
            local newControllerId = maxIntId + i
            for _, position in ipairs(originalPositionsTakenUpBySource[interactables[i]] or {}) do
                local copiedPosition = position + worldDelta
                idAtWorldPosition[positionKey(copiedPosition)] = newControllerId
            end
            newShape.controller.id = newControllerId
            local copyData = data.copyControllerData and data.copyControllerData[interactables[i]] or nil
            if copyData ~= nil then
                newShape.controller.data = copyData.data
            end
            if interactableModes[interactables[i]] ~= nil then
                newShape.controller.data = sm.MTFastLogic.LogicConverter.vGateModesToFGateModes
                [interactableModes[interactables[i]]]
            end
            if interactableDelays[interactables[i]] ~= nil then
                newShape.controller.data = interactableDelays[interactables[i]]
            end
            newShape.controller.controllers = {}
            for j = 1, #internalConnections do
                local connection = internalConnections[j]
                if connection.from == i then
                    table.insert(newShape.controller.controllers, {
                        id = connection.to + maxIntId
                    })
                end
            end
            if externalConnections == "absolute" then
                for j = 1, #externalConnectionsOutgoing do
                    local connection = externalConnectionsOutgoing[j]
                    if connection.from == i then
                        table.insert(newShape.controller.controllers, {
                            id = connection.to
                        })
                    end
                end
                for j = 1, #externalConnectionsIngoing do
                    local connection = externalConnectionsIngoing[j]
                    if connection.to == i then
                        connection.controller.controllers = connection.controller.controllers or {}
                        table.insert(connection.controller.controllers, {
                            id = newControllerId
                        })
                    end
                end
            elseif externalConnections == "relative" then
                for j = 1, #externalConnectionsOutgoing do
                    local connection = externalConnectionsOutgoing[j]
                    if connection.from == i then
                        local endpoint = connection.endpoint
                        table.insert(relativeOutgoingToMake, {
                            controller = newShape.controller,
                            endpoint = endpoint + worldDelta
                        })
                    end
                end

                for j = 1, #externalConnectionsIngoing do
                    local connection = externalConnectionsIngoing[j]
                    if connection.to == i then
                        local endpoint = connection.endpoint
                        table.insert(relativeIngoingToMake, {
                            endpoint = endpoint + worldDelta,
                            targetId = newControllerId
                        })
                    end
                end
            end
            if #newShape.controller.controllers == 0 then
                newShape.controller.controllers = nil
            end
            controllerById[newControllerId] = newShape.controller

            table.insert(newShapes, newShape)
            nShapesAdded = nShapesAdded + 1
            ::continue::
        end
        for i = 1, #newShapes do
            table.insert(targetBodyShapes, newShapes[i])
        end
        maxIntId = maxIntId + #interactables
    end)
    local function resolveEndpoint(endpoint)
        return idAtWorldPosition[positionKey(endpoint)]
    end

    for _, connection in ipairs(relativeOutgoingToMake) do
        local destinationId = resolveEndpoint(connection.endpoint)
        if destinationId ~= nil then
            connection.controller.controllers = connection.controller.controllers or {}
            table.insert(connection.controller.controllers, { id = destinationId })
        end
    end
    for _, connection in ipairs(relativeIngoingToMake) do
        local sourceId = resolveEndpoint(connection.endpoint)
        local sourceController = sourceId ~= nil and controllerById[sourceId] or nil
        if sourceController ~= nil then
            sourceController.controllers = sourceController.controllers or {}
            table.insert(sourceController.controllers, { id = connection.targetId })
        end
    end

    if nShapesAdded > 0 then
        for _, joint in ipairs(creationTable.joints or {}) do
            if joint.childA >= jointChildInsertionIndex then
                joint.childA = joint.childA + nShapesAdded
            end
            if joint.childB ~= -1 and joint.childB >= jointChildInsertionIndex then
                joint.childB = joint.childB + nShapesAdded
            end
        end
    end

    local worldPosition = targetBody.worldPosition
    local worldRotation = targetBody.worldRotation
    local world = targetBody:getWorld()
    local originalShapes = targetBody:getCreationShapes()

    local serializationSucceeded, jsonString = pcall(sm.json.writeJsonString, creationTable)
    if not serializationSucceeded or type(jsonString) ~= "string" then
        print("CopyPaste: failed to serialize creation: " .. tostring(jsonString))
        return
    end

    for _, shape in pairs(originalShapes) do
        if sm.exists(shape) then
            shape:destroyShape()
        end
    end

    local importSucceeded, importedBodies = pcall(
        sm.creation.importFromString, world, jsonString, worldPosition, worldRotation, false)
    if not importSucceeded or type(importedBodies) ~= "table" or #importedBodies == 0 then
        print("CopyPaste: original creation was deleted, but the replacement failed to import: " ..
            tostring(importedBodies))
        return
    end

    if isLifted then
        local adjustment = getLiftPositionAdjustment(importedBodies, liftData.liftPosition)
        local placed, placeError = pcall(
            sm.player.placeLift,
            liftData.player,
            importedBodies,
            liftData.liftPosition + adjustment,
            liftData.liftLevel,
            liftData.rotationIndex
        )
        if not placed then
            print("CopyPaste: replacement was imported but could not be placed on the lift: " ..
                tostring(placeError))
        end
    end
end

function CopyPaste.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.CopyPaste
    for i = 1, #self.selectedShapes do
        local shape = self.selectedShapes[i]
        local effect = self.shapeVisualizations[shape:getId()]
        if effect ~= nil then
            effect:setPosition(shape:getInterpolatedWorldPosition())
            effect:setRotation(shape.worldRotation)
        end
    end

    multitool.SelectionModeController.modeActive = nil
    self.activeBody = nil
    if #self.selectedShapes > 0 then
        if sm.exists(self.selectedShapes[1]) then
            self.activeBody = self.selectedShapes[1]:getBody()
        else
            table.remove(self.selectedShapes, 1)
        end
    end
    local tags = {}
    if self.selectingShapes then
        if MTMultitool.handleForceBuild(multitool, forceBuild) and #self.selectedShapes ~= 0 then
            CopyPaste.cleanNametags(multitool)
            self.selectingShapes = false
            return
        end
        if secondaryState == 1 and multitool.VolumeSelector.origin == nil then
            undoShapeSelect(multitool)
        end
        if self.selectionMode == "individual" then
            sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "mt.copy.click_add_shape")
            local localPosition, bodyhit = ConnectionRaycaster:raycastToBlock(self.targeting == "surface")
            if (bodyhit ~= self.activeBody) and (self.activeBody ~= nil) then
                localPosition = nil
                bodyhit = nil
            end
            if localPosition ~= nil then
                local voxelMap = MTMultitoolLib.getVoxelMapMultidotblocks(bodyhit)
                local x1 = localPosition.x - 0.125
                local x2 = localPosition.x + 0.125
                local y1 = localPosition.y - 0.125
                local y2 = localPosition.y + 0.125
                local z1 = localPosition.z - 0.125
                local z2 = localPosition.z + 0.125
                local width = 0.25
                local stepsPerBlock = 2
                local steps = math.floor(width / 0.25) * stepsPerBlock
                for i = 0, steps do
                    local x = x1 + i / stepsPerBlock * 0.25
                    local y = y1 + i / stepsPerBlock * 0.25
                    local z = z1 + i / stepsPerBlock * 0.25
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x, y1, z1)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x, y1, z2)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x, y2, z1)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x, y2, z2)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x1, y, z1)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x1, y, z2)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x2, y, z1)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x2, y, z2)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x1, y1, z)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x1, y2, z)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x2, y1, z)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x2, y2, z)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                end
                if primaryState == 1 then
                    local hitBlock = voxelMap
                    [localPosition.x - 0.125 .. ";" .. localPosition.y - 0.125 .. ";" .. localPosition.z - 0.125]
                    if hitBlock ~= nil and sm.exists(hitBlock) then
                        addShapes(multitool, { hitBlock })
                    end
                end
            end
        else
            multitool.SelectionModeController.modeActive = "VolumeSelector"
            local vs = multitool.VolumeSelector
            if self.activeBody ~= nil then
                vs.body = self.activeBody
            else
                if vs.origin == nil then
                    vs.body = nil
                end
            end
            vs.isBeta = false
            vs.modes = nil
            if self.targeting == "surface" then
                vs.selectionMode = "outside"
            else
                vs.selectionMode = "inside"
            end
            vs.actionWord = "mt.copy.add_shapes"
            vs.doConfirm = false
            local extraTooltip = {
                selectOrigin = "",
                selectFinal = "",
                confirm = "",
            }
            if #self.selectedShapes ~= 0 then
                extraTooltip.selectOrigin = "     " .. sm.gui.getKeyBinding("ForceBuild", true) .. tr("mt.copy.confirm_selection")
            end
            if self.targeting == "surface" then
                extraTooltip.selectOrigin = extraTooltip.selectOrigin .. "     " .. sm.gui.getKeyBinding("Reload", true) .. tr("mt.copy.target_subsurface")
                extraTooltip.selectFinal = extraTooltip.selectFinal .. "     " .. sm.gui.getKeyBinding("Reload", true) .. tr("mt.copy.target_subsurface")
            else
                extraTooltip.selectOrigin = extraTooltip.selectOrigin .. "     " .. sm.gui.getKeyBinding("Reload", true) .. tr("mt.copy.target_surface")
                extraTooltip.selectFinal = extraTooltip.selectFinal .. "     " .. sm.gui.getKeyBinding("Reload", true) .. tr("mt.copy.target_surface")
            end
            local result = VolumeSelector.trigger(multitool, primaryState, secondaryState, forceBuild, "copyPaste", extraTooltip)
            if #self.selectedShapes ~= 0 then
                local siliconFound = false
                -- local interactableIds = {}
                -- for _, shape in ipairs(self.selectedShapes) do
                if self.activeBody ~= nil then
                    for _, shape in ipairs(self.activeBody:getCreationShapes()) do
                        local shapeUuid = shape:getShapeUuid()
                        -- table.insert(interactableIds, shape.interactable:getId())
                        if table.contains(sm.MTFastLogic.SiliconBlocksShapeDB.allUuids, tostring(shapeUuid)) then
                            siliconFound = true
                            break
                        end
                    end
                end
                if siliconFound then
                    sm.gui.setInteractionText(
                    "<p textShadow='false' bg='gui_keybinds_bg' color='#ff2211' spacing='4'>" .. tr("mt.common.warn") .. "</p> " .. tr("mt.copy.silicon_warning") .. " <p textShadow='false' bg='gui_keybinds_bg' color='#ff2211' spacing='4'>" .. tr("mt.common.warn") .. "</p>")
                end
            end
            if result ~= nil then
                local halfBlock = 0.125
                local body = result.body
                local originLocal = result.origin
                local finalLocal = result.final
                local voxelMap = MTMultitoolLib.getVoxelMapShapesGW(body, true)
                local x = math.min(originLocal.x, finalLocal.x) - halfBlock
                local y = math.min(originLocal.y, finalLocal.y) - halfBlock
                local z = math.min(originLocal.z, finalLocal.z) - halfBlock
                local xMax = math.max(originLocal.x, finalLocal.x) - halfBlock
                local yMax = math.max(originLocal.y, finalLocal.y) - halfBlock
                local zMax = math.max(originLocal.z, finalLocal.z) - halfBlock
                local allShapes = {}
                local hitSilicon = false
                for i = x * 4, xMax * 4 do
                    for j = y * 4, yMax * 4 do
                        for k = z * 4, zMax * 4 do
                            local indexString = i / 4 .. ";" .. j / 4 .. ";" .. k / 4
                            local shapes = voxelMap[indexString]
                            if shapes ~= nil then
                                for _, shape in ipairs(shapes) do
                                    if sm.exists(shape) then
                                        -- list of silicon uuids = sm.MTFastLogic.SiliconBlocksShapeDB.allUuids
                                        if table.contains(sm.MTFastLogic.SiliconBlocksShapeDB.allUuids, tostring(shape:getShapeUuid())) then
                                            hitSilicon = true
                                        else
                                            table.insert(allShapes, shape)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if hitSilicon then
                    sm.gui.displayAlertText(tr("mt.copy.silicon_blocks_cannot_be_copied"))
                end
                addShapes(multitool, allShapes)
                VolumeSelector.cleanUp(multitool)
            end
        end
    else
        if secondaryState == 1 and #self.actions == 0 then
            self.selectingShapes = true
            return
        elseif secondaryState == 1 then
            table.remove(self.actions, #self.actions)
        end
        local occupiedBlocks = MTMultitoolLib.getOccupiedBlocks(self.selectedShapes[1])
        local x1 = occupiedBlocks[1].x
        local y1 = occupiedBlocks[1].y
        local z1 = occupiedBlocks[1].z
        local x2 = occupiedBlocks[1].x
        local y2 = occupiedBlocks[1].y
        local z2 = occupiedBlocks[1].z
        for i = 1, #self.selectedShapes do
            local occupiedBlocks = MTMultitoolLib.getOccupiedBlocks(self.selectedShapes[i])
            for j = 1, #occupiedBlocks do
                x1 = math.min(x1, occupiedBlocks[j].x)
                y1 = math.min(y1, occupiedBlocks[j].y)
                z1 = math.min(z1, occupiedBlocks[j].z)
                x2 = math.max(x2, occupiedBlocks[j].x)
                y2 = math.max(y2, occupiedBlocks[j].y)
                z2 = math.max(z2, occupiedBlocks[j].z)
            end
        end
        x1 = (x1 - 0.5)/4
        y1 = (y1 - 0.5)/4
        z1 = (z1 - 0.5)/4
        x2 = (x2 + 0.5)/4
        y2 = (y2 + 0.5)/4
        z2 = (z2 + 0.5)/4
        local stepsPerBlock = 2
        local xWidth = x2 - x1
        local yWidth = y2 - y1
        local zWidth = z2 - z1
        local xSteps = math.floor(xWidth / 0.25) * stepsPerBlock
        local ySteps = math.floor(yWidth / 0.25) * stepsPerBlock
        local zSteps = math.floor(zWidth / 0.25) * stepsPerBlock
        for i = 0, xSteps do
            local x = x1 + i / stepsPerBlock * 0.25
            table.insert(tags, {
                pos = self.activeBody:transformPoint(sm.vec3.new(x, y1, z1)),
                color = sm.color.new(1, 1, 1),
                txt = "•"
            })
            table.insert(tags, {
                pos = self.activeBody:transformPoint(sm.vec3.new(x, y1, z2)),
                color = sm.color.new(1, 1, 1),
                txt = "•"
            })
            table.insert(tags, {
                pos = self.activeBody:transformPoint(sm.vec3.new(x, y2, z1)),
                color = sm.color.new(1, 1, 1),
                txt = "•"
            })
            table.insert(tags, {
                pos = self.activeBody:transformPoint(sm.vec3.new(x, y2, z2)),
                color = sm.color.new(1, 1, 1),
                txt = "•"
            })
        end
        for i = 0, ySteps do
            local y = y1 + i / stepsPerBlock * 0.25
            table.insert(tags, {
                pos = self.activeBody:transformPoint(sm.vec3.new(x1, y, z1)),
                color = sm.color.new(1, 1, 1),
                txt = "•"
            })
            table.insert(tags, {
                pos = self.activeBody:transformPoint(sm.vec3.new(x1, y, z2)),
                color = sm.color.new(1, 1, 1),
                txt = "•"
            })
            table.insert(tags, {
                pos = self.activeBody:transformPoint(sm.vec3.new(x2, y, z1)),
                color = sm.color.new(1, 1, 1),
                txt = "•"
            })
            table.insert(tags, {
                pos = self.activeBody:transformPoint(sm.vec3.new(x2, y, z2)),
                color = sm.color.new(1, 1, 1),
                txt = "•"
            })
        end
        for i = 0, zSteps do
            local z = z1 + i / stepsPerBlock * 0.25
            table.insert(tags, {
                pos = self.activeBody:transformPoint(sm.vec3.new(x1, y1, z)),
                color = sm.color.new(1, 1, 1),
                txt = "•"
            })
            table.insert(tags, {
                pos = self.activeBody:transformPoint(sm.vec3.new(x1, y2, z)),
                color = sm.color.new(1, 1, 1),
                txt = "•"
            })
            table.insert(tags, {
                pos = self.activeBody:transformPoint(sm.vec3.new(x2, y1, z)),
                color = sm.color.new(1, 1, 1),
                txt = "•"
            })
            table.insert(tags, {
                pos = self.activeBody:transformPoint(sm.vec3.new(x2, y2, z)),
                color = sm.color.new(1, 1, 1),
                txt = "•"
            })
        end
        local state = "selectOrigin"
        local canConfirm = false
        self.vectors = {}
        self.origin = nil
        for i = 1, #self.actions do
            canConfirm = false
            local action = self.actions[i]
            if action.action == "selectOrigin" then
                state = "selectStep"
                self.origin = action.position
            end
            if action.action == "selectStep" then
                state = "selectRange"
                table.insert(self.vectors, {
                    step = action.position - self.origin,
                    globalStep = self.activeBody:transformPoint(action.position) - self.activeBody:transformPoint(self.origin),
                    range = nil
                })
            end
            if action.action == "selectRange" then
                state = "selectStep"
                canConfirm = true
                self.vectors[#self.vectors].range = action.range
            end
            if action.action == "confirm" then
                state = "confirm"
                canConfirm = false
            end
        end
        local localPosition, bodyhit = nil, nil
        local shapeHit = nil
        if state == "selectOrigin" or state == "selectStep" then
            localPosition, bodyhit = ConnectionRaycaster:raycastToBlock(self.targeting == "surface")
            if (bodyhit ~= self.activeBody) and (self.activeBody ~= nil) then
                localPosition = nil
                bodyhit = nil
            end
            if localPosition ~= nil then
                local voxelMap = MTMultitoolLib.getVoxelMapMultidotblocks(bodyhit)
                local x1 = localPosition.x - 0.125
                local x2 = localPosition.x + 0.125
                local y1 = localPosition.y - 0.125
                local y2 = localPosition.y + 0.125
                local z1 = localPosition.z - 0.125
                local z2 = localPosition.z + 0.125
                local width = 0.25
                local stepsPerBlock = 4
                local steps = math.floor(width / 0.25) * stepsPerBlock
                for i = 0, steps do
                    local x = x1 + i / stepsPerBlock * 0.25
                    local y = y1 + i / stepsPerBlock * 0.25
                    local z = z1 + i / stepsPerBlock * 0.25
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x, y1, z1)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x, y1, z2)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x, y2, z1)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x, y2, z2)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x1, y, z1)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x1, y, z2)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x2, y, z1)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x2, y, z2)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x1, y1, z)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x1, y2, z)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x2, y1, z)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                    table.insert(tags, {
                        pos = bodyhit:transformPoint(sm.vec3.new(x2, y2, z)),
                        color = sm.color.new(1, 1, 1),
                        txt = "•"
                    })
                end
            end
        end

        if state == "selectOrigin" then
            sm.gui.setInteractionText("mt.copy.select_origin", sm.gui.getKeyBinding("Create", true), "mt.copy.click_select_origin")
            if primaryState == 1 and localPosition ~= nil then
                table.insert(self.actions, {
                    action = "selectOrigin",
                    position = localPosition
                })
            end
        elseif state == "selectStep" then
            if localPosition ~= nil then
                sm.gui.setInteractionText("mt.copy.select_step", sm.gui.getKeyBinding("Create", true), "mt.copy.click_select_step")
                local vecColor = sm.MTTensorUtil.colorOrder[math.fmod(#self.vectors, #sm.MTTensorUtil.colorOrder) + 1]
                sm.MTTensorUtil.renderVector(tags, self.activeBody:transformPoint(self.origin),
                    self.activeBody:transformPoint(localPosition),
                    vecColor, 0.025)
                if primaryState == 1 then
                    table.insert(self.actions, {
                        action = "selectStep",
                        position = localPosition
                    })
                end
            end
        elseif state == "selectRange" then
            local vecColor = sm.MTTensorUtil.colorOrder[
                math.fmod(#self.vectors - 1, #sm.MTTensorUtil.colorOrder) + 1]
            local closestDistance, closestPosition, nSteps = MathUtil.closestPassBetweenContinuousRayAndDiscreteRay(
                sm.camera.getPosition(),
                sm.camera.getDirection(),
                self.activeBody:transformPoint(self.origin),
                self.vectors[#self.vectors].globalStep
            )
            local prevPos = self.activeBody:transformPoint(self.origin)
            for i = 0, nSteps do
                if i > 10 and i < nSteps - 10 then
                    goto continue
                end
                local newPos = self.activeBody:transformPoint(self.origin) + self.vectors[#self.vectors].globalStep * i
                sm.MTTensorUtil.renderVector(tags, prevPos, newPos, vecColor, 0.025)
                prevPos = newPos
                ::continue::
            end
            if primaryState == 1 then
                table.insert(self.actions, {
                    action = "selectRange",
                    range = nSteps
                })
            end
            sm.gui.setInteractionText("mt.copy.select_step", sm.gui.getKeyBinding("Create", true),
                tr("mt.copy.click_select_range") .. " <p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>(" ..
                (nSteps + 1) .. ")</p>")
        elseif state == "confirm" then
            sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true),
                tr("mt.copy.external_connections_policy") .. " <p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
                localizeExternalConnectionsPolicy(self.externalConnectionsPolicy) .. "</p>     ", sm.gui.getKeyBinding("Create", true), "mt.copy.confirm")
            if primaryState == 1 then
                doCopyPaste(multitool)
                CopyPaste.cleanUp(multitool)
            end
            if MTMultitool.handleForceBuild(multitool, forceBuild) then
                if self.externalConnectionsPolicy == "absolute" then
                    self.externalConnectionsPolicy = "relative"
                elseif self.externalConnectionsPolicy == "relative" then
                    self.externalConnectionsPolicy = "ignore"
                else
                    self.externalConnectionsPolicy = "absolute"
                end
            end
            local siliconFound = false
            -- local interactableIds = {}
            -- for _, shape in ipairs(self.selectedShapes) do
            if self.activeBody ~= nil then
                for _, shape in ipairs(self.activeBody:getCreationShapes()) do
                    local shapeUuid = shape:getShapeUuid()
                    -- table.insert(interactableIds, shape.interactable:getId())
                    if table.contains(sm.MTFastLogic.SiliconBlocksShapeDB.allUuids, tostring(shapeUuid)) then
                        siliconFound = true
                        break
                    end
                end
            end
            if siliconFound then
                sm.gui.setInteractionText("<p textShadow='false' bg='gui_keybinds_bg' color='#ff2211' spacing='4'>" .. tr("mt.common.warn") .. "</p> " .. tr("mt.copy.silicon_warning") .. " <p textShadow='false' bg='gui_keybinds_bg' color='#ff2211' spacing='4'>" .. tr("mt.common.warn") .. "</p>")
            end
        end
        for i = 1, #self.vectors do
            local vec = self.vectors[i]
            if vec.range ~= nil then
                local prevPos = self.activeBody:transformPoint(self.origin)
                for j = 0, vec.range do
                    if j > 10 and j < vec.range - 10 then
                        goto continue
                    end
                    local newPos = self.activeBody:transformPoint(self.origin) + vec.globalStep * j
                    local colorIndex = math.fmod(i - 1, #sm.MTTensorUtil.colorOrder) + 1
                    sm.MTTensorUtil.renderVector(tags, prevPos, newPos,
                        sm.MTTensorUtil.colorOrder[colorIndex], 0.025)
                    prevPos = newPos
                    ::continue::
                end
            end
        end
        if canConfirm then
            sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true), "mt.copy.confirm")
            if MTMultitool.handleForceBuild(multitool, forceBuild) then
                table.insert(self.actions, {
                    action = "confirm"
                })
            end
        end
    end
    self.nametagUpdate(tags)
end

function CopyPaste.client_onReload(multitool)
    local self = multitool.CopyPaste
    if self.selectionMode == "individual" then
        self.selectionMode = "region"
    else
        if self.targeting == "subsurface" then
            self.targeting = "surface"
        else
            self.targeting = "subsurface"
            -- self.selectionMode = "individual"
        end
    end
end

function CopyPaste.cleanUp(multitool)
    local self = multitool.CopyPaste
    self.nametagUpdate(nil)
    self.selectedShapes = {}
    self.selectingShapes = true
    self.shapeGroups = {}
    for _, effect in pairs(self.shapeVisualizations) do
        effect:stop()
    end
    self.shapeVisualizations = {}
    self.activeBody = nil
    VolumeSelector.cleanUp(multitool)
    self.vectors = {}
    self.actions = {}
    self.origin = nil
end

function CopyPaste.cleanNametags(multitool)
    local self = multitool.CopyPaste
    self.nametagUpdate(nil)
    VolumePlacer.cleanNametags(multitool)
end