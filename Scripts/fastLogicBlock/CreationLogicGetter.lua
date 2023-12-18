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
    "add3acc6-a6fd-44e8-a384-a7a16ce13c81",
    "8684ad89-94ad-4f46-b50e-c1aff63893f4",
    "20dcd41c-0a11-4668-9b00-97f278ce21af",
    "de018bc6-1db5-492c-bfec-045e63f9d64b",
    "90fc3603-3544-4254-97ef-ea6723510961",
    "cf46678b-c947-4267-ba85-f66930f5faa4",
    "1d4793af-cb66-4628-804a-9d7404712643"
}

function FastLogicRunner.getBLockData(self, bodyToGetCreation)
    self.allLogicData = {}
    self.allLogicDataTemp = {}
    self.isScanning = true
    self.scanningStep = 0
    self.bodies = self:getTable(bodyToGetCreation).bodies
    local shapes = bodyToGetCreation:getCreationShapes()
    self.shapes = {}
    for shapeK, shape in pairs(shapes) do
        if shape:getInteractable() ~= nil then
            self.shapes[shape:getInteractable():getId()] = shape
        end
    end
end

function FastLogicRunner.doScanning(self)
    local blocksScannedThisTick = 0
    if self.scanningStep == 0 then
        for bodyK, body in pairs(self.bodies) do
            for blockK, block in pairs(body.childs) do
                blocksScannedThisTick = blocksScannedThisTick + 1
                if (block.controller ~= nil) then
                    local shape = self.shapes[block.controller.id]
                    if (table.contains(FastLogicRunner.allUUIDs, block.shapeId)) then
                        local blockData = self:makeBlockData(block, shape)
                        if (blockData.type ~= nil) then
                            self.allLogicData[blockData.id] = blockData
                            self.allLogicDataTemp[blockData.id] = blockData
                        end
                    end
                end
                body.childs[blockK] = nil
                if blocksScannedThisTick == 500 then
                    return nil
                end
            end
            self.bodies[bodyK] = nil
        end
    else
        for blockId, blockData in pairs(self.allLogicDataTemp) do
            --blocksScannedThisTick = blocksScannedThisTick + 1
            local i = 1
            while #blockData.outputs >= i do
                local id = blockData.outputs[i]
                if (self.allLogicData[id] ~= nil) then
                    self.allLogicData[id].inputs[#self.allLogicData[id].inputs + 1] = blockId
                    i = i + 1
                else
                    table.remove(blockData.outputs, i)
                    print("did not make data for block with id:", id, "  Deleting...")
                end
            end
            --self.allLogicDataTemp[blockId] = nil
            --if (blocksScannedThisTick) == 2000 then
            --return nil
            -- end
        end
        self.isScanning = false
        return self.allLogicData
    end
    self.scanningStep = 1
    return nil
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
    elseif (table.contains({
            "1e8d93a4-506b-470d-9ada-9c0a321e2db5",
            "7cf717d7-d167-4f2d-a6e7-6b2c70aa3986",
            "add3acc6-a6fd-44e8-a384-a7a16ce13c81",
            "8684ad89-94ad-4f46-b50e-c1aff63893f4",
            "20dcd41c-0a11-4668-9b00-97f278ce21af",
            "de018bc6-1db5-492c-bfec-045e63f9d64b",
            "90fc3603-3544-4254-97ef-ea6723510961",
            "cf46678b-c947-4267-ba85-f66930f5faa4",
            "1d4793af-cb66-4628-804a-9d7404712643"
        }, block.shapeId)) then                                                                                                     -- vanilla input
        blockData.type = "vanilla input"
    elseif (table.contains({ "ed27f5e2-cac5-4a32-a5d9-49f116acc6af", "695d66c8-b937-472d-8bc2-f3d72dd92879" }, block.shapeId)) then -- vanilla light
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
