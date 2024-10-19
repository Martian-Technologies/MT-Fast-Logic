MultiblockDetector = {}

function MultiblockDetector.inject(multitool)
    multitool.MultiblockDetector = {}
    local self = multitool.MultiblockDetector
    self.shapeVisualizations = {}
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

function MultiblockDetector.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.MultiblockDetector
    multitool.SelectionModeController.modeActive = "BlockSelector"
    local blocksToHighlight = {}
    local shapeIds = {}
    if lookingAt ~= nil then
        local interactable = lookingAt.interactable
        if interactable ~= nil then
            local body = lookingAt:getBody()

            local creationId = sm.MTFastLogic.CreationUtil.getCreationId(body)
            local creation = sm.MTFastLogic.Creations[creationId]

            if creation == nil then
                return
            end

            local FLR = creation.FastLogicRunner
            local multiBlockData = FLR.multiBlockData
            -- fprint(multiBlockData, {depth=3, ignoreTypes={"function"}})

            -- fprint(creation, {depth=2, ignoreTypes={"function"}})
            local uuid = creation.uuids[interactable:getId()]

            local runnerId = FLR.hashedLookUp[uuid]
            -- print(uuid)
            -- fprint(creation.blocks[uuid], {depth=2, ignoreTypes={"function"}})
            for i, multiblock in pairs(multiBlockData) do
                if type(multiblock) ~= "table" then
                    goto continue
                end
                local contents = multiblock[2]
                -- print(contents)
                if contents == nil then
                    goto continue
                end
                for i, block in pairs(contents) do
                    if block == runnerId then
                        -- fprint(multiblock, { depth = 2, ignoreTypes = { "function" } })
                        for i, block in pairs(contents) do
                            local bUuid = FLR.unhashedLookUp[block]
                            local b = creation.AllFastBlocks[bUuid]
                            -- fprint(b, { depth = 2, ignoreTypes = { "function" } })
                            local shape = b.shape
                            table.insert(blocksToHighlight, shape)
                        end
                        break
                    end
                end
                ::continue::
            end
            for _, shape in ipairs(blocksToHighlight) do
                local effect = self.shapeVisualizations[shape:getId()]
                table.insert(shapeIds, shape:getId())
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
        
    end

    for shapeId, effect in pairs(self.shapeVisualizations) do
        if not table.contains(shapeIds, shapeId) then
            effect:setParameter("visualization", false)
            effect:stop()
        end
    end
    -- print(blocksToHighlight)

    -- local origin = sm.camera.getPosition()
    -- local direction = sm.camera.getDirection()
    -- local hit, res = sm.physics.raycast(sm.camera.getPosition(),
    --     sm.camera.getPosition() + sm.camera.getDirection() * 128, sm.localPlayer.getPlayer().character)
    -- -- print(res.type)
    -- local body = nil
    -- if hit and res.type == "body" then
    --     body = res:getBody()
    -- end
    -- if hit and res.type == "joint" then
    --     body = res:getJoint().shapeA.body
    -- end
    -- if body == nil then
    --     sm.gui.setInteractionText("Aim at a creation", "", "")
    --     return
    -- end

    -- sm.visualization.setCreationBodies(body:getCreationBodies())
    -- sm.visualization.setCreationFreePlacement(false)
    -- sm.visualization.setCreationValid(true, true)
    -- sm.visualization.setLiftValid(true)
    -- sm.visualization.setCreationVisible(true)

    -- local creationId = sm.MTFastLogic.CreationUtil.getCreationId(body)
    -- local creation = sm.MTFastLogic.Creations[creationId]
    -- local FLR = creation.FastLogicRunner
    -- local multiBlockData = FLR.multiBlockData
    -- fprint(multiBlockData, {depth=3, ignoreTypes={"function"}})
end