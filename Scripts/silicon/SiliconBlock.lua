dofile "../util/util.lua"
dofile "../CreationUtil.lua"
local string = string
local table = table
local type = type
local pairs = pairs

SiliconBlock = SiliconBlock or class()

sm.MTFastLogic = sm.MTFastLogic or {}
-- sm.MTFastLogic.UsedUuids = sm.MTFastLogic.UsedUuids or {}
sm.MTFastLogic.SiliconBlocks = sm.MTFastLogic.SiliconBlocks or {}
sm.MTFastLogic.DataForSiliconBlocks = sm.MTFastLogic.DataForSiliconBlocks or {}
sm.MTFastLogic.SiliconBlocksToAddConnections = sm.MTFastLogic.SiliconBlocksToAddConnections or {{}, {}}

local uuidToSize = {
    ["3706ba55-bd11-4053-b437-bbf2aff823b4"] = { 1, 1, 1 },
    ["f0e1640f-7776-4232-b1d9-8c1a41b53958"] = { 2, 1, 1 },
    ["f0e2828f-7776-4232-b1d9-8a3c45b63898"] = { 3, 1, 1 },
    ["f0e1640f-7406-1984-b1d9-8c1a41b53958"] = { 4, 1, 1 },
    ["f0e1640f-7406-4232-b1d9-8c1a41b53958"] = { 8, 1, 1 },
    ["f3e2828f-1212-1111-b1d4-8d3c45b63000"] = { 12, 1, 1 },
    ["f590d9d1-179d-49ff-86ab-7f74a730e243"] = { 2, 2, 1 },
    ["d576a4c9-e6bc-46c0-9230-f92967cc39b6"] = { 4, 4, 1 },
    ["195aa046-017a-4f0b-809c-98ed141955fb"] = { 8, 8, 1 },
    ["f0e2828f-1234-4321-b1d9-8a3c45b63898"] = { 16, 16, 1 },
    ["f3e2828f-1241-1412-b1f2-8d3c45b63000"] = { 12, 4, 1 },
    ["e6011dc4-8842-4d94-a196-0c7386065ab6"] = { 2, 2, 2 },
    ["f0e2828f-8888-4444-b1d9-8a3c45b63898"] = { 8, 8, 4 },
}

function SiliconBlock.deepRescanSelf(self)
    for _, block in ipairs(self.data.blocks) do
        -- sm.MTFastLogic.UsedUuids[block.uuid] = nil
        self.FastLogicAllBlockMannager:removeBlock(block.uuid)
    end
    self.lastSeenSpeed = self.creation.FastLogicRunner.numberOfUpdatesPerTick
    self.creation.SiliconBlocks[self.id] = nil
    self.creation = nil
    self.creationId = nil
    self.FastLogicAllBlockMannager = nil
    self:getData()
end

function SiliconBlock.getCreationData(self)
    self.creationId = sm.MTFastLogic.CreationUtil.getCreationId(self.shape:getBody())
    if (sm.MTFastLogic.Creations[self.creationId] == nil) then
        sm.MTFastLogic.CreationUtil.MakeCreationData(self.creationId, self.shape:getBody(), self.lastSeenSpeed)
    end
    self.creation = sm.MTFastLogic.Creations[self.creationId]
    self.FastLogicAllBlockMannager = self.creation.FastLogicAllBlockMannager
end

function SiliconBlock.getData(self)
    self:getCreationData()
    if self.creation.SiliconBlocks[self.id] == nil then
        self.lastSeenSpeed = self.creation.FastLogicRunner.numberOfUpdatesPerTick
        self.creation.lastBodyUpdate = 0
        self.creation.SiliconBlocks[self.id] = self
        self.creation.BlocksToScan[#self.creation.BlocksToScan + 1] = self
        sm.MTFastLogic.SiliconBlocks[self.id] = self
    end
    if sm.MTFastLogic.DataForSiliconBlocks[self.id] ~= nil then
        self:addBlocks(sm.MTFastLogic.DataForSiliconBlocks[self.id])
        sm.MTFastLogic.DataForSiliconBlocks[self.id] = nil
    end
    for i = 1, #self.data.blocks do
        local block = self.data.blocks[i]
        local pos, rot = self:toBodyPosAndRot(block.pos, block.rot)
        self.FastLogicAllBlockMannager:addSiliconBlock(block.type, block.uuid, pos, rot, {}, {}, block.state, block.color, block.connectionColorId, self.id)
    end
    self:server_saveBlocks(self.data.blocks)
    sm.MTFastLogic.SiliconBlocksToAddConnections[2][#sm.MTFastLogic.SiliconBlocksToAddConnections[2] + 1] = self
end

function SiliconBlock.addConnections(self)
    for i = 1, #self.data.blocks do
        local block = self.data.blocks[i]
        for ii = 1, #block.inputs do
            self.FastLogicAllBlockMannager:addOutput(block.inputs[ii], block.uuid)
        end

        for ii = 1, #block.outputs do
            self.FastLogicAllBlockMannager:addOutput(block.uuid, block.outputs[ii])
        end
    end
    sm.event.sendToInteractable(self.interactable, "server_saveBlocks", self.data.blocks)
end

function SiliconBlock.addOutput(self, uuid, uuidToConnect)
    local changed = false
    for i = 1, #self.data.blocks do
        if self.data.blocks[i].uuid == uuid and not table.contains(self.data.blocks[i].outputs, uuidToConnect) then
            changed = true
            self.data.blocks[i].outputs[#self.data.blocks[i].outputs + 1] = uuidToConnect
        end
        if self.data.blocks[i].uuid == uuidToConnect and not table.contains(self.data.blocks[i].inputs, uuid) then
            changed = true
            self.data.blocks[i].inputs[#self.data.blocks[i].inputs + 1] = uuid
        end
    end
    if changed then
        sm.event.sendToInteractable(self.interactable, "server_saveBlocks", self.data.blocks)
    end
end

function SiliconBlock.server_onCreate(self)
    self:getCreationData()
    self.size = table.copy(uuidToSize[tostring(self.shape.shapeUuid)])
    self.isSilicon = true
    self.id = self.interactable:getId()
    self.data = self.data or {}
    -- sm.MTFastLogic.SiliconBlocksToGetData[#sm.MTFastLogic.SiliconBlocksToGetData + 1] = self
    self.data.blocks = self:decompressBlockData(self.storage:load())
    for i = 1, #self.data.blocks do
        local block = self.data.blocks[i]
        block.uuid = sm.MTFastLogic.CreationUtil.updateOldUuid(block.uuid, self.creationId)
        for ii = 1, #block.inputs do
            block.inputs[ii] = sm.MTFastLogic.CreationUtil.updateOldUuid(block.inputs[ii], self.creationId)
        end
        for ii = 1, #block.outputs do
            block.outputs[ii] = sm.MTFastLogic.CreationUtil.updateOldUuid(block.outputs[ii], self.creationId)
        end
    end
    self.storage:save(self:compressBlocks())
    self:getData()
end

function SiliconBlock.server_onDestroy(self)
    self.creation.SiliconBlocks[self.id] = nil
    if self.removeData ~= false then
        for _, block in ipairs(self.data.blocks) do
            -- sm.MTFastLogic.UsedUuids[block.uuid] = nil
            self.FastLogicAllBlockMannager:removeBlock(block.uuid)
        end
    end
end

function SiliconBlock.server_onProjectile(self, position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid)
    -- advPrint(self., 3)
end

function SiliconBlock.client_onTinker(self, character, state)
    if state then
        self.network:sendToServer("server_changeSpeed", character:isCrouching())
    end
end

function SiliconBlock.server_changeSpeed(self, isCrouching)
    if isCrouching then
        self.creation.FastLogicRunner.numberOfUpdatesPerTick = self.creation.FastLogicRunner.numberOfUpdatesPerTick / 2
    else
        self.creation.FastLogicRunner.numberOfUpdatesPerTick = self.creation.FastLogicRunner.numberOfUpdatesPerTick * 2
    end

    self:sendMessageToAll("UpdatesPerTick = " .. tostring(self.creation.FastLogicRunner.numberOfUpdatesPerTick))
end

function SiliconBlock.sendMessageToAll(self, message)
    self.network:sendToClients("client_sendMessage", message)
end

function SiliconBlock.client_sendMessage(self, message)
    sm.gui.chatMessage(message)
end

function SiliconBlock.addBlocks(self, uuids)
    if type(uuids) == "number" then
        uuids = { uuids }
    end
    if #uuids > 0 then
        local blocks = self.data.blocks
        for _, uuid in ipairs(uuids) do
            local i = 1
            while i <= #blocks do
                if blocks[i].uuid == uuid then
                    break
                end
                i = i + 1
            end
            local block = self.creation.blocks[uuid]
            local pos, rot = self:toLocalPosAndRot(block.pos, block.rot)
            blocks[i] = {
                type = block.type,
                uuid = block.uuid,
                pos = pos,
                rot = rot,
                inputs = table.copy(block.inputs),
                outputs = table.copy(block.outputs),
                state = block.state,
                color = block.color,
                connectionColorId = block.connectionColorId,
                -- timerLength = block.timerLength,
            }
        end
        self:server_saveBlocks(blocks)
    end
end

function SiliconBlock.server_onrefresh(self)
    self:server_onCreate()
end

function SiliconBlock.server_saveBlocks(self, blocks)
    self.data.blocks = blocks
    self.storage:save(self:compressBlocks())
end

function SiliconBlock.server_resave(self)
    self.storage:save(self:compressBlocks())
end

function SiliconBlock.remove(self, removeData)
    self.removeData = removeData
    self.shape:destroyPart()
end

local typeToNumber = {
    andBlocks = 0,
    orBlocks = 1,
    xorBlocks = 2,
    nandBlocks = 3,
    norBlocks = 4,
    xnorBlocks = 5,
}

local numberToType = {
    [0] = "andBlocks",
    [1] = "orBlocks",
    [2] = "xorBlocks",
    [3] = "nandBlocks",
    [4] = "norBlocks",
    [5] = "xnorBlocks",
}

local rotationToNumber = {
    ["1000-10"] = 1,
    ["10000-1"] = 2,
    ["010-100"] = 3,
    ["01000-1"] = 4,
    ["001-100"] = 5,
    ["0010-10"] = 6,
    ["0-10100"] = 7,
    ["00-1100"] = 8,
    ["010100"] = 9,
    ["001100"] = 10,
    ["-100010"] = 11,
    ["00-1010"] = 12,
    ["100010"] = 13,
    ["001010"] = 14,
    ["-100001"] = 15,
    ["0-10001"] = 16,
    ["100001"] = 17,
    ["010001"] = 18,
    ["0-10-100"] = 19,
    ["00-1-100"] = 20,
    ["-1000-10"] = 21,
    ["00-10-10"] = 22,
    ["-10000-1"] = 23,
    ["0-1000-1"] = 24,
}

local numberToRotation = {
    [1] = { sm.vec3.new(1, 0, 0), sm.vec3.new(0, 0, 1), sm.vec3.new(0, -1, 0) },
    [2] = { sm.vec3.new(1, 0, 0), sm.vec3.new(0, -1, 0), sm.vec3.new(0, 0, -1) },
    [3] = { sm.vec3.new(0, 1, 0), sm.vec3.new(0, 0, -1), sm.vec3.new(-1, 0, 0) },
    [4] = { sm.vec3.new(0, 1, 0), sm.vec3.new(1, 0, 0), sm.vec3.new(0, 0, -1) },
    [5] = { sm.vec3.new(0, 0, 1), sm.vec3.new(0, 1, 0), sm.vec3.new(-1, 0, 0) },
    [6] = { sm.vec3.new(0, 0, 1), sm.vec3.new(-1, 0, 0), sm.vec3.new(0, -1, 0) },
    [7] = { sm.vec3.new(0, -1, 0), sm.vec3.new(0, 0, -1), sm.vec3.new(1, 0, 0) },
    [8] = { sm.vec3.new(0, 0, -1), sm.vec3.new(0, 1, 0), sm.vec3.new(1, 0, 0) },
    [9] = { sm.vec3.new(0, 1, 0), sm.vec3.new(0, 0, 1), sm.vec3.new(1, 0, 0) },
    [10] = { sm.vec3.new(0, 0, 1), sm.vec3.new(0, -1, 0), sm.vec3.new(1, 0, 0) },
    [11] = { sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 0, 1), sm.vec3.new(0, 1, 0) },
    [12] = { sm.vec3.new(0, 0, -1), sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 1, 0) },
    [13] = { sm.vec3.new(1, 0, 0), sm.vec3.new(0, 0, -1), sm.vec3.new(0, 1, 0) },
    [14] = { sm.vec3.new(0, 0, 1), sm.vec3.new(1, 0, 0), sm.vec3.new(0, 1, 0) },
    [15] = { sm.vec3.new(-1, 0, 0), sm.vec3.new(0, -1, 0), sm.vec3.new(0, 0, 1) },
    [16] = { sm.vec3.new(0, -1, 0), sm.vec3.new(1, 0, 0), sm.vec3.new(0, 0, 1) },
    [17] = { sm.vec3.new(1, 0, 0), sm.vec3.new(0, 1, 0), sm.vec3.new(0, 0, 1) },
    [18] = { sm.vec3.new(0, 1, 0), sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 0, 1) },
    [19] = { sm.vec3.new(0, -1, 0), sm.vec3.new(0, 0, 1), sm.vec3.new(-1, 0, 0) },
    [20] = { sm.vec3.new(0, 0, -1), sm.vec3.new(0, -1, 0), sm.vec3.new(-1, 0, 0) },
    [21] = { sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 0, -1), sm.vec3.new(0, -1, 0) },
    [22] = { sm.vec3.new(0, 0, -1), sm.vec3.new(1, 0, 0), sm.vec3.new(0, -1, 0) },
    [23] = { sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 1, 0), sm.vec3.new(0, 0, -1) },
    [24] = { sm.vec3.new(0, -1, 0), sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 0, -1) },
}

function SiliconBlock.compressBlocks(self)
    if self.data.blocks == nil then return {} end
    local blocks = table.makeArray(self.size[1] * self.size[2] * self.size[3])
    local colorHash = {}
    local colorIndex = 1
    for i = 1, #self.data.blocks do
        local block = self.data.blocks[i]
        if colorHash[block.color] == nil then
            colorHash[block.color] = colorIndex
            colorIndex = colorIndex + 1
        end
        local inputs = table.copy(block.inputs)
        if self.creation ~= nil then
            local j = 1
            while j <= #inputs do
                if self.creation.blocks[inputs[j]] ~= nil and self.creation.blocks[inputs[j]].isSilicon then
                    table.remove(inputs, j)
                else
                    j = j + 1
                end
            end
        end
        local rotNumber = rotationToNumber[tostring(block.rot[1].x) .. tostring(block.rot[1].y) .. tostring(block.rot[1].z) .. tostring(block.rot[3].x) .. tostring(block.rot[3].y) .. tostring(block.rot[3].z)]
        blocks[(block.pos.x - 0.5) + (block.pos.y - 0.5) * self.size[1] + (block.pos.z - 0.5) * self.size[2] * self.size[1] + 1] = {
            rotNumber * 6 + typeToNumber[block.type],
            block.uuid,
            inputs,
            block.outputs,
            colorHash[block.color],
            block.connectionColorId,
        }
    end
    local colorIndexHash = {}
    for color, index in pairs(colorHash) do
        colorIndexHash[index] = color
    end
    return self:tableToString({ blocks, colorIndexHash })
end

function SiliconBlock.decompressBlockData(self, blockData)
    if blockData == nil then return {} end
    blockData = self:stringToTable(blockData)
    if blockData == nil then return {} end
    local colorIndexHash = blockData[2]
    local onlyBlockData = blockData[1]
    local blocks = {}
    for i = 1, #onlyBlockData do
        local block = onlyBlockData[i]
        if block ~= nil and block ~= false then
            blocks[#blocks + 1] = {
                type = numberToType[math.fmod(block[1], 6)],
                uuid = block[2],
                pos = sm.vec3.new(
                    math.fmod(i - 1, self.size[1]) + 0.5,
                    math.floor(math.fmod(i - 1, self.size[2] * self.size[1]) / self.size[1]) + 0.5,
                    math.floor((i - 1) / (self.size[2] * self.size[1])) + 0.5
                ),
                rot = numberToRotation[math.floor(block[1] / 6)],
                inputs = block[3],
                outputs = block[4],
                state = false,
                color = colorIndexHash[block[5]],
                connectionColorId = block[6],
            }
        end
    end
    return blocks
end

function SiliconBlock.toLocalPosAndRot(self, pos, rot)
    local axes = { x = self.shape.xAxis, y = self.shape.yAxis, z = self.shape.zAxis }
    pos = pos - self.shape.localPosition -- - sm.MTUtil.getOffset(block.rot)
    pos = sm.vec3.new(
        pos.x * axes.x.x + pos.y * axes.x.y + pos.z * axes.x.z,
        pos.x * axes.y.x + pos.y * axes.y.y + pos.z * axes.y.z,
        pos.x * axes.z.x + pos.y * axes.z.y + pos.z * axes.z.z
    )
    rot = {
        sm.vec3.new(
            rot[1].x * axes.x.x + rot[1].y * axes.x.y + rot[1].z * axes.x.z,
            rot[1].x * axes.y.x + rot[1].y * axes.y.y + rot[1].z * axes.y.z,
            rot[1].x * axes.z.x + rot[1].y * axes.z.y + rot[1].z * axes.z.z
        ),
        sm.vec3.new(
            rot[2].x * axes.x.x + rot[2].y * axes.x.y + rot[2].z * axes.x.z,
            rot[2].x * axes.y.x + rot[2].y * axes.y.y + rot[2].z * axes.y.z,
            rot[2].x * axes.z.x + rot[2].y * axes.z.y + rot[2].z * axes.z.z
        ),
        sm.vec3.new(
            rot[3].x * axes.x.x + rot[3].y * axes.x.y + rot[3].z * axes.x.z,
            rot[3].x * axes.y.x + rot[3].y * axes.y.y + rot[3].z * axes.y.z,
            rot[3].x * axes.z.x + rot[3].y * axes.z.y + rot[3].z * axes.z.z
        )
    }
    return pos, rot
end

function SiliconBlock.toBodyPosAndRot(self, pos, rot)
    local axes = { x = self.shape.xAxis, y = self.shape.yAxis, z = self.shape.zAxis }
    pos = sm.vec3.new(
        pos.x * axes.x.x + pos.y * axes.y.x + pos.z * axes.z.x,
        pos.x * axes.x.y + pos.y * axes.y.y + pos.z * axes.z.y,
        pos.x * axes.x.z + pos.y * axes.y.z + pos.z * axes.z.z
    )
    rot = {
        sm.vec3.new(
            rot[1].x * axes.x.x + rot[1].y * axes.y.x + rot[1].z * axes.z.x,
            rot[1].x * axes.x.y + rot[1].y * axes.y.y + rot[1].z * axes.z.y,
            rot[1].x * axes.x.z + rot[1].y * axes.y.z + rot[1].z * axes.z.z
        ),
        sm.vec3.new(
            rot[2].x * axes.x.x + rot[2].y * axes.y.x + rot[2].z * axes.z.x,
            rot[2].x * axes.x.y + rot[2].y * axes.y.y + rot[2].z * axes.z.y,
            rot[2].x * axes.x.z + rot[2].y * axes.y.z + rot[2].z * axes.z.z
        ),
        sm.vec3.new(
            rot[3].x * axes.x.x + rot[3].y * axes.y.x + rot[3].z * axes.z.x,
            rot[3].x * axes.x.y + rot[3].y * axes.y.y + rot[3].z * axes.z.y,
            rot[3].x * axes.x.z + rot[3].y * axes.y.z + rot[3].z * axes.z.z
        )
    }
    pos = pos + self.shape.localPosition
    return pos, rot
end

function SiliconBlock.tableToString(self, table)
    local str = ""
    local i = 1
    for k, v in pairs(table) do
        local needsKey = k == i
        if type(v) == "table" then
            v = "{" .. self:tableToString(v) .. "}"
        elseif type(v) ~= "string" then
            v = tostring(v)
        else
            if tonumber(v) ~= nil then
                v = v .. "'"
            end
        end
        if type(k) ~= "string" then
            k = tostring(k)
        else
            if tonumber(k) ~= nil then
                k = k .. "'"
            end
        end
        if string.sub(str, -1, -1) ~= "}" and string.sub(str, -1, -1) ~= "'" and string.sub(v, 1, 1) ~= "{" and str ~= "" then
            str = str .. "|"
        end
        if needsKey then
            i = i + 1
            str = str .. v
        else
            str = str .. k .. "]" .. v
        end
    end
    -- if string.sub(str, -1, -1) == "}" then
    --     str = string.sub(str, 1, -2)
    -- end
    return str--string.sub(str, 2, -1)
end

function SiliconBlock.stringToTable(self, str)
    local tbl = {}
    local chunk = ""
    local gettingTableString = false
    local key = 1
    local isString = false
    local countKey = true
    local depth = 0
    local stringIndex = 1
    for c in str:gmatch "." do
        ::again::
        if gettingTableString then
            if c == "{" then
                depth = depth + 1
                chunk = chunk .. c
            elseif c == "}" then
                if depth > 0 then
                    depth = depth - 1
                    chunk = chunk .. c
                else
                    chunk = self:stringToTable(chunk)
                    gettingTableString = false
                    c = "|"
                    goto again
                end
            else
                chunk = chunk .. c
            end
        else
            local endChunk = false
            if c == "|" then
                endChunk = true
            elseif c == "{" then
                if chunk ~= "" then
                    endChunk = true
                end
                gettingTableString = true
            elseif c == "}" then
                endChunk = true
            elseif c == "]" then
                if chunk == "" then
                    key = key - 1
                    chunk = tbl[key]
                    tbl[key] = nil
                    if tonumber(chunk) ~= nil then
                        chunk = tonumber(chunk)
                    end
                end
                key = chunk
                chunk = ""
                countKey = false
            elseif c == "'" then
                isString = true
                endChunk = true
            else
                chunk = chunk .. c
            end

            if endChunk then
                if tonumber(chunk) ~= nil and not isString then
                    chunk = tonumber(chunk)
                end
                isString = false
                if countKey ~= nil then
                    if chunk ~= "" then
                        tbl[key] = chunk
                    end
                    if c == "}" then
                        tbl = { tbl }
                    end
                    if chunk ~= "" then
                        if countKey == true then
                            key = key + 1
                        else
                            countKey = nil
                        end
                    end
                    chunk = ""
                end
            end
        end
        if stringIndex == #str then
            if gettingTableString then
                chunk = self:stringToTable(chunk)
                gettingTableString = false
            end
            c = "|"
            stringIndex = stringIndex + 1
            goto again
        end
        stringIndex = stringIndex + 1
    end
    return tbl
end

