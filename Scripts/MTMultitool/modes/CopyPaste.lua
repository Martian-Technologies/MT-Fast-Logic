dofile "../TensorUtil.lua"

CopyPaste = {}

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
end

local plasticUuid = sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a")

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
        if table.contains(self.selectedShapes, shape) then
            return
        end
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
    table.insert(self.shapeGroups, shapeGroup)
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
    local data = {
        interactables = interactables,
        shapes = shapes,
        vectors = vectors,
        body = self.activeBody,
        externalConnections = self.externalConnectionsPolicy -- "ignore" | "absolute" | "relative"
    }
    multitool.network:sendToServer("server_copyPaste", data)
end

local function findPositionInIntIdMap(intIdMap, intId)
    for p, id in pairs(intIdMap) do
        if id == intId then
            return string.stringToVec(p, ';')
        end
    end
end

function CopyPaste.server_copyPaste(multitool, data)
    local self = multitool.CopyPaste
    -- local targetBody = data.body
    -- local creationTable = sm.creation.exportToTable(targetBody, true, false)
    -- local interactables = data.interactables
    -- local creation = sm.MTFastLogic.Creations[sm.MTFastLogic.CreationUtil.getCreationId(targetBody)]
    -- local gatesToRestore = {}
    -- if creation ~= nil then
    --     for _, block in pairs(creation.AllFastBlocks) do
    --         if table.contains(interactables, block.interactable:getId()) then
    --             local s = sm.event.sendToInteractable(block.interactable, "removeUuidData")
    --             if s == false then
    --             end
    --         end
    --     end
    -- end
    -- for _, body in ipairs(creationTable.bodies) do
    --     for _, shape in ipairs(body.childs) do
    --         if shape.controller == nil then
    --             goto continue
    --         end
    --         local intId = shape.controller.id
    --         if table.contains(interactables, intId) then
    --             gatesToRestore[intId] = shape.controller.data
    --         end
    --         ::continue::
    --     end
    -- end
    -- data.gatesToRestore = gatesToRestore
    -- table.insert(self.toCopyPastePackets, {
    --     data = data,
    --     tick = sm.game.getCurrentTick() + 1
    -- })
    CopyPaste.doCopyPaste(multitool, data)
end

function CopyPaste.server_onFixedUpdate(multitool, dt)
    -- local self = multitool.CopyPaste
    -- if #self.toCopyPastePackets == 0 then
    --     return
    -- end
    -- local data = self.toCopyPastePackets[1]
    -- if sm.game.getCurrentTick() < data.tick then
    --     return
    -- end
    -- table.remove(self.toCopyPastePackets, 1)
    -- CopyPaste.doCopyPaste(multitool, data.data)
end

function CopyPaste.doCopyPaste(multitool, data)
    local interactables = data.interactables
    local shapes = data.shapes
    local vectors = data.vectors
    local targetBody = data.body
    local targetBodyObject = nil
    local externalConnections = data.externalConnections
    local intIdMap = MTMultitoolLib.getVoxelMapInteractableIds(targetBody)
    local creationTable = sm.creation.exportToTable(targetBody, true, false)
    local generatedShapes = {}
    local originalPositionsTakenUpBySource = {}
    local tensor = {}

    sm.MTBackupEngine.sv_backupCreation({
        hasCreation = false,
        body = targetBody,
        name = "CopyPaste Backup",
        description = "Backup created by CopyPaste.lua",
    })

    local creation = sm.MTFastLogic.Creations[sm.MTFastLogic.CreationUtil.getCreationId(targetBody)]
    local interactableModes = {}
    local interactableLums = {}
    local interactableDelays = {}
    local interactableWipeData = {}
    if creation ~= nil then
        for _, intId in ipairs(interactables) do
            local uuid = creation.uuids[intId]
            if uuid == nil then
                goto continue
            end
            local block = creation.blocks[uuid]
            if block == nil then
                goto continue
            end
            local type = block.type
            if type ~= nil then
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
                elseif type == "lightBlocks" then
                    -- advPrint(creation.FastLights[uuid], 3, 100, true)
                    local light = creation.FastLights[uuid]
                    interactableLums[intId] = light.data.luminance
                elseif type == "timerBlocks" then
                    local seconds = creation.FastTimers[uuid].client_seconds
                    local ticks = creation.FastTimers[uuid].client_ticks
                    interactableDelays[intId] = FastLogicRunnerRunner.convertTimerDelayToData(seconds, ticks)
                end
            -- elseif luminance ~= nil then
            --     interactableLums[intId] = luminance
            end
            ::continue::
        end
    end


    -- local worldpos = targetBody.worldPosition
    -- local worldrot = targetBody.worldRotation
    -- local world = targetBody:getWorld()

    -- local shapes = targetBody:getCreationShapes()
    -- for _, shape in pairs(shapes) do
    --     shape:destroyShape()
    -- end
    -- local jsonString = sm.json.writeJsonString(creationTable)

    -- sm.creation.importFromString(world, jsonString, worldpos, worldrot, false)

-- end if false then

    for i = 1, #vectors do
        table.insert(tensor, vectors[i].nSteps)
    end
    local maxIntId = 0
    local everyShapeByIntId = {}

    local jointShapeIndex = 0
    local maxJointIndexToNotIncrement = 0
    for _, body in ipairs(creationTable.bodies) do
        for _, shape in ipairs(body.childs) do
            shape.jointShapeIndex = jointShapeIndex
            jointShapeIndex = jointShapeIndex + 1
            if shape.controller == nil then
                for _, nonInt in ipairs(shapes) do
                    if tostring(nonInt.uuid) == shape.shapeId then
                        if nonInt.localPosition.x == shape.pos.x and nonInt.localPosition.y == shape.pos.y and nonInt.localPosition.z == shape.pos.z then
                            targetBodyObject = body
                            goto continue
                        end
                    end
                end
                goto continue
            end
            local intId = shape.controller.id
            everyShapeByIntId[intId] = shape
            if table.contains(interactables, intId) then
                targetBodyObject = body
                maxJointIndexToNotIncrement = jointShapeIndex - 1
            end
            if intId > maxIntId then
                maxIntId = intId
            end
            ::continue::
        end
    end

    local externalConnectionsIngoing = {}
    local externalConnectionsOutgoing = {}
    if externalConnections == "absolute" then
        for _, body in ipairs(creationTable.bodies) do
            for _, shape in ipairs(body.childs) do
                if shape.controller == nil then
                    goto continue
                end
                local intId = shape.controller.id
                if table.contains(interactables, intId) then
                    if shape.controller.controllers == nil then
                        goto continue
                    end
                    for _, output in ipairs(shape.controller.controllers) do
                        local outputId = output.id
                        if table.contains(interactables, outputId) then
                            goto continue2
                        end
                        table.insert(externalConnectionsOutgoing, {
                            from = table.find(interactables, intId),
                            to = outputId
                        })
                        ::continue2::
                    end
                    goto continue
                end
                local outputs = shape.controller.controllers
                if outputs == nil then
                    goto continue
                end
                for _, output in ipairs(outputs) do
                    local outputId = output.id
                    table.insert(externalConnectionsIngoing, {
                        from = shape.controller.controllers,
                        to = table.find(interactables, outputId)
                    })
                end
                ::continue::
            end
        end
    end
    if targetBodyObject == nil then
        return
    end
    local targetBodyShapes = targetBodyObject.childs
    local internalShapesOrdered = {}
    for i = 1, #interactables do
        internalShapesOrdered[i] = false
    end
    for i = 1, #targetBodyShapes do
        local shape = targetBodyShapes[i]
        if shape.controller == nil then
            goto continue
        end
        local intId = shape.controller.id
        if table.contains(interactables, intId) then
            internalShapesOrdered[table.find(interactables, intId)] = shape
        end
        ::continue::
    end

    local internalConnections = {}
    local extraShapesToCopy = {}
    for i = 1, #targetBodyShapes do
        local shape = targetBodyShapes[i]
        if shape.controller == nil then
            local shapeUuid = shape.shapeId
            local shapePos = shape.pos
            for _, nonInt in ipairs(shapes) do
                if tostring(nonInt.uuid) ~= shapeUuid then
                    goto continue2
                end
                if nonInt.localPosition.x ~= shapePos.x or nonInt.localPosition.y ~= shapePos.y or nonInt.localPosition.z ~= shapePos.z then
                    goto continue2
                end
                table.insert(extraShapesToCopy, shape)
                ::continue2::
            end
            goto continue
        end
        local intId = shape.controller.id
        local sourceInternal = table.contains(interactables, intId)
        if sourceInternal then
            local allPositions = {}
            for p, id in pairs(intIdMap) do
                if id == intId then
                    table.insert(allPositions, string.stringToVec(p, ';'))
                end
            end
            originalPositionsTakenUpBySource[intId] = allPositions
        end
        if externalConnections ~= "relative" and not sourceInternal then
            goto continue
        end
        -- guaranteed for sourceInternal or externalConnections == "relative"
        local outputs = shape.controller.controllers
        if outputs == nil then
            goto continue
        end
        for _, output in ipairs(outputs) do
            local outputId = output.id
            local targetInternal = table.contains(interactables, outputId)
            if externalConnections ~= "relative" and not targetInternal then
                goto continue
            end
            -- guaranteed for targetInternal and sourceInternal or externalConnections == "relative"
            if sourceInternal and not targetInternal then
                -- guaranteed externalConnections == "relative"
                local destinationPos = findPositionInIntIdMap(intIdMap, outputId)
                table.insert(externalConnectionsOutgoing, {
                    from = table.find(interactables, intId),
                    to = destinationPos
                })
            elseif targetInternal and not sourceInternal then
                -- guaranteed externalConnections == "relative"
                local sourcePos = findPositionInIntIdMap(intIdMap, intId)
                table.insert(externalConnectionsIngoing, {
                    from = sourcePos,
                    to = table.find(interactables, outputId)
                })
            elseif sourceInternal and targetInternal then
                table.insert(internalConnections, {
                    from = table.find(interactables, intId),
                    to = table.find(interactables, outputId)
                })
            end
        end
        ::continue::
    end

    local relativeConnectionsToMake = {}

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
            for intId, pList in pairs(originalPositionsTakenUpBySource) do
                if intId ~= interactables[i] then
                    goto continue2
                end
                for j = 1, #pList do
                    local p = pList[j] + deltaP / 4
                    intIdMap[p.x .. ";" .. p.y .. ";" .. p.z] = i + maxIntId
                end
                ::continue2::
            end
            newShape.controller.id = maxIntId + i
            if interactableModes[interactables[i]] ~= nil then
                newShape.controller.data = sm.MTFastLogic.LogicConverter.vGateModesToFGateModes
                [interactableModes[interactables[i]]]
            end
            if interactableLums[interactables[i]] ~= nil then
                newShape.controller.data = sm.MTFastLogic.LogicConverter.vLightLumsToFLightLums
                    [interactableLums[interactables[i]]]
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
                        table.insert(connection.from, {
                            id = connection.to + maxIntId
                        })
                    end
                end
            elseif externalConnections == "relative" then
                for j = 1, #externalConnectionsOutgoing do
                    local connection = externalConnectionsOutgoing[j]
                    if connection.from == i then
                        local destinationPos = connection.to + deltaP / 4
                        table.insert(relativeConnectionsToMake, {
                            from = newShape,
                            to = destinationPos,
                            type = "outgoing"
                        })
                    end
                end

                for j = 1, #externalConnectionsIngoing do
                    local connection = externalConnectionsIngoing[j]
                    if connection.to == i then
                        local sourcePos = connection.from + deltaP / 4
                        table.insert(relativeConnectionsToMake, {
                            from = sourcePos,
                            to = connection.to + maxIntId,
                            type = "ingoing"
                        })
                        -- local sourceIntId = intIdMap[sourcePos.x .. ";" .. sourcePos.y .. ";" .. sourcePos.z]
                        -- if sourceIntId ~= nil then
                        --     local sourceShape = everyShapeByIntId[sourceIntId]
                        --     if sourceShape ~= nil then
                        --         if sourceShape.controller.controllers == nil then
                        --             sourceShape.controller.controllers = {}
                        --         end
                        --         table.insert(sourceShape.controller.controllers, {
                        --             id = connection.to + maxIntId
                        --         })
                        --     end
                        -- end
                    end
                end
            end
            if #newShape.controller.controllers == 0 then
                newShape.controller.controllers = nil
            end
            everyShapeByIntId[newShape.controller.id] = newShape
            
            table.insert(newShapes, newShape)
            nShapesAdded = nShapesAdded + 1
            ::continue::
        end
        for i = 1, #newShapes do
            table.insert(targetBodyShapes, newShapes[i])
        end
        maxIntId = maxIntId + #interactables
    end)
    for i = 1, #relativeConnectionsToMake do
        local connection = relativeConnectionsToMake[i]
        if connection.type == "outgoing" then
            local destinationIntId = intIdMap
                [connection.to.x .. ";" .. connection.to.y .. ";" .. connection.to.z]
            if destinationIntId ~= nil then
                if connection.from.controller.controllers == nil then
                    connection.from.controller.controllers = {}
                end
                table.insert(connection.from.controller.controllers, {
                    id = destinationIntId
                })
            end
        elseif connection.type == "ingoing" then
            local sourceIntId = intIdMap
                [connection.from.x .. ";" .. connection.from.y .. ";" .. connection.from.z]
            if sourceIntId ~= nil then
                local sourceShape = everyShapeByIntId[sourceIntId]
                if sourceShape ~= nil then
                    if sourceShape.controller.controllers == nil then
                        sourceShape.controller.controllers = {}
                    end
                    table.insert(sourceShape.controller.controllers, {
                        id = connection.to
                    })
                end
            end
        end
    end

    for _, body in ipairs(creationTable.bodies) do
        for _, shape in ipairs(body.childs) do
            if shape.controller == nil then
                goto continue
            end
            local intId = shape.controller.id
            -- if table.contains(gatesToRestore, intId) then
            --     shape.controller.data = gatesToRestore[gatesToRestore[intId]]
            -- end
            ::continue::
        end
    end

    if creationTable.joints ~= nil then
        for _, joint in ipairs(creationTable.joints) do
            if joint.childA > maxJointIndexToNotIncrement then
                joint.childA = joint.childA + nShapesAdded
            end
            if joint.childB > maxJointIndexToNotIncrement then
                joint.childB = joint.childB + nShapesAdded
            end
        end
    end

    local worldpos = targetBody.worldPosition
    local worldrot = targetBody.worldRotation
    local world = targetBody:getWorld()

    local shapes = targetBody:getCreationShapes()
    for _, shape in pairs(shapes) do
        shape:destroyShape()
    end
    local jsonString = sm.json.writeJsonString(creationTable)

    sm.creation.importFromString(world, jsonString, worldpos, worldrot, false)
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
            sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Click to add shape")
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
            vs.actionWord = "Add Shapes"
            vs.doConfirm = false
            local result = VolumeSelector.trigger(multitool, primaryState, secondaryState, forceBuild)
            if result ~= nil then
                local halfBlock = 0.125
                local body = result.body
                local originLocal = result.origin
                local finalLocal = result.final
                local voxelMap = MTMultitoolLib.getVoxelMapShapes(body, true)
                local x = math.min(originLocal.x, finalLocal.x) - halfBlock
                local y = math.min(originLocal.y, finalLocal.y) - halfBlock
                local z = math.min(originLocal.z, finalLocal.z) - halfBlock
                local xMax = math.max(originLocal.x, finalLocal.x) - halfBlock
                local yMax = math.max(originLocal.y, finalLocal.y) - halfBlock
                local zMax = math.max(originLocal.z, finalLocal.z) - halfBlock
                local shapes = {}
                for i = x * 4, xMax * 4 do
                    for j = y * 4, yMax * 4 do
                        for k = z * 4, zMax * 4 do
                            local indexString = i / 4 .. ";" .. j / 4 .. ";" .. k / 4
                            local shape = voxelMap[indexString]
                            if shape ~= nil and sm.exists(shape) then
                                table.insert(shapes, shape)
                            end
                        end
                    end
                end
                addShapes(multitool, shapes)
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
            sm.gui.setInteractionText("Select origin", sm.gui.getKeyBinding("Create", true), "Click to select origin")
            if primaryState == 1 and localPosition ~= nil then
                table.insert(self.actions, {
                    action = "selectOrigin",
                    position = localPosition
                })
            end
        elseif state == "selectStep" then
            if localPosition ~= nil then
                sm.gui.setInteractionText("Select step", sm.gui.getKeyBinding("Create", true), "Click to select step")
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
            local vecColor = sm.MTTensorUtil.colorOrder[math.fmod(#self.vectors, #sm.MTTensorUtil.colorOrder)]
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
            sm.gui.setInteractionText("Select step", sm.gui.getKeyBinding("Create", true),
                "Click to select range <p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>(" ..
                (nSteps + 1) .. ")</p>")
        elseif state == "confirm" then
            sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true),
                "Change External Connections Policy: <p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
                self.externalConnectionsPolicy .. "</p>     ", sm.gui.getKeyBinding("Create", true), "Confirm Copy/Paste")
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
                sm.gui.setInteractionText("<p textShadow='false' bg='gui_keybinds_bg' color='#ff2211' spacing='4'>! WARNING !</p> Copying and pasting silicon-related blocks will lead to undefined behavior. <p textShadow='false' bg='gui_keybinds_bg' color='#ff2211' spacing='4'>! WARNING !</p>")
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
                    sm.MTTensorUtil.renderVector(tags, prevPos, newPos, sm.MTTensorUtil.colorOrder[math.fmod(i, #sm.MTTensorUtil.colorOrder)], 0.025)
                    prevPos = newPos
                    ::continue::
                end
            end
        end
        if canConfirm then
            sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true), "Confirm Copy/Paste")
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
    multitool.VolumeSelector.body = nil
    self.vectors = {}
    self.actions = {}
    self.origin = nil
end

function CopyPaste.cleanNametags(multitool)
    local self = multitool.CopyPaste
    self.nametagUpdate(nil)
    VolumePlacer.cleanNametags(multitool)
end