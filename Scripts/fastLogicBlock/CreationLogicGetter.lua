dofile "../util/util.lua"

function FastLogicRunner.getTable(self, body)
    return sm.creation.exportToTable(body:getCreationBodies()[1], true, false)
end

FastLogicRunner.allUUIDs = {
    "9f0f56e8-2c31-4d83-996c-d00a9b296c3f",
    "8f7fd0e7-c46e-4944-a414-7ce2437bb30f",
    "1e8d93a4-506b-470d-9ada-9c0a321e2db5",
    "7cf717d7-d167-4f2d-a6e7-6b2c70aa3986",
    "ed27f5e2-cac5-4a32-a5d9-49f116acc6af",
    "695d66c8-b937-472d-8bc2-f3d72dd92879",
    "add3acc6-a6fd-44e8-a384-a7a16ce13c81"
}

function FastLogicRunner.getBLockData(self, bodyToGetCreation)
    local allLogicData = {}
    local bodies = self:getTable(bodyToGetCreation).bodies
    local shapes = bodyToGetCreation:getCreationShapes()
    local shapeIndex = 1
    for body in values(bodies) do
        for block in values(body.childs) do
            if (block.controller ~= nil) then
                for shape in values(shapes) do
                    if (
                            shape:getInteractable() ~= nil and
                            shape:getInteractable():getId() == block.controller.id and
                            table.contains(FastLogicRunner.allUUIDs, block.shapeId)
                        ) then
                        local blockData = self:makeBlockData(block, shape)
                        if (blockData.type ~= nil) then
                            allLogicData[blockData.id] = blockData
                        end
                        break
                    end
                end
            end
        end
    end
    for blockId, blockData in pairs(allLogicData) do
        for i, id in pairs(blockData.outputs) do
            if (allLogicData[id] ~= nil) then
                allLogicData[id].inputs[#allLogicData[id].inputs + 1] = blockId
            else
                table.remove(blockData.outputs, i)
                print("did not make data for block with id:", id, "  Deleting...")
            end
        end
    end
    return allLogicData
end

function FastLogicRunner.makeBlockData(self, block, shape)
    -- setup
    local blockData = {
        shape = shape,
        id = block.controller.id,
        outputs = {},
        inputs = {},
        color = block.color,
    }
    -- set block specific data
    if (block.shapeId == "9f0f56e8-2c31-4d83-996c-d00a9b296c3f") then -- vanilla logic
        blockData.type = "vanilla logic"
        blockData.mode = block.controller.mode
    elseif (block.shapeId == "8f7fd0e7-c46e-4944-a414-7ce2437bb30f") then -- vanilla timer
        blockData.type = "vanilla timer"
        blockData.ticks = block.controller.ticks + block.controller.seconds * 40
    elseif (table.contains({ "1e8d93a4-506b-470d-9ada-9c0a321e2db5", "7cf717d7-d167-4f2d-a6e7-6b2c70aa3986", "add3acc6-a6fd-44e8-a384-a7a16ce13c81" }, block.shapeId)) then -- vanilla input
        blockData.type = "vanilla input"
    elseif (table.contains({ "ed27f5e2-cac5-4a32-a5d9-49f116acc6af", "695d66c8-b937-472d-8bc2-f3d72dd92879" }, block.shapeId)) then                                         -- vanilla light
        blockData.type = "vanilla light"
    end
    -- set outputs
    if (block.controller.controllers ~= nil) then
        for id in values(block.controller.controllers) do
            blockData.outputs[#blockData.outputs + 1] = id.id
        end
    end
    return blockData
end
