dofile "../util/util.lua"
dofile "../CreationUtil.lua"
local string = string
local table = table
local type = type
local pairs = pairs

SiliconBlock = SiliconBlock or class()

dofile "SiliconCompressor.lua"

sm.MTFastLogic = sm.MTFastLogic or {}
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
    self.data.blocks = SiliconCompressor.decompressBlockData(self, self.storage:load())
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
    self.storage:save(SiliconCompressor.compressBlocks(self))
    self:getData()
end

function SiliconBlock.server_onDestroy(self)
    self.creation.SiliconBlocks[self.id] = nil
    if self.removeData ~= false then
        for _, block in ipairs(self.data.blocks) do
            self.FastLogicAllBlockMannager:removeBlock(block.uuid)
        end
    end
end

function SiliconBlock.server_onProjectile(self, position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid)
    -- advPrint(self., 3)
    print(SiliconCompressor.compressBlocks(self))
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
    self.storage:save(SiliconCompressor.compressBlocks(self))
end

function SiliconBlock.server_resave(self)
    self.storage:save(SiliconCompressor.compressBlocks(self))
end

function SiliconBlock.remove(self, removeData)
    self.removeData = removeData
    self.shape:destroyPart()
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
