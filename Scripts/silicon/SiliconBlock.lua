dofile "../util/util.lua"
dofile "../allCreationStuff/CreationUtil.lua"
dofile "SiliconSizes.lua"

local string = string
local table = table
local type = type
local pairs = pairs
local sm = sm

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.SiliconBlocks = sm.MTFastLogic.SiliconBlocks or {}
sm.MTFastLogic.DataForSiliconBlocks = sm.MTFastLogic.DataForSiliconBlocks or {}
sm.MTFastLogic.SiliconBlocksToAddConnections = sm.MTFastLogic.SiliconBlocksToAddConnections or {{}, {}}

dofile "compression/SiliconCompressor.lua"
local SiliconCompressor = sm.MTFastLogic.SiliconCompressor

SiliconBlock = SiliconBlock or class()

function SiliconBlock.deepRescanSelf(self, noRemove)
    if noRemove ~= true then
        for _, block in ipairs(self.data.blocks) do
            self.FastLogicAllBlockManager:removeBlock(block.uuid, true)
        end
    end
    self.lastSeenSpeed = self.creation.FastLogicRunner.numberOfUpdatesPerTick
    self.creation.SiliconBlocks[self.id] = nil
    self.creation = nil
    self.creationId = nil
    self.FastLogicAllBlockManager = nil
    self:getData()
end

function SiliconBlock.getCreationData(self)
    self.creationId = sm.MTFastLogic.CreationUtil.getCreationId(self.shape:getBody())
    if (sm.MTFastLogic.Creations[self.creationId] == nil) then
        sm.MTFastLogic.CreationUtil.MakeCreationData(self.creationId, self.shape:getBody(), self.lastSeenSpeed)
    end
    self.creation = sm.MTFastLogic.Creations[self.creationId]
    self.FastLogicAllBlockManager = self.creation.FastLogicAllBlockManager
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
    else
        for i = 1, #self.data.blocks do
            local block = self.data.blocks[i]
            local pos, rot = self:toBodyPosAndRot(block.pos, block.rot)
            self.FastLogicAllBlockManager:addSiliconBlock(block.type, block.uuid, pos, rot, block.inputs, block.outputs, block.state, block.color, block.connectionColorId, self.id)
        end
    end
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

function SiliconBlock.removeOutput(self, uuid, uuidToDisconnect)
    local changed = false
    for i = 1, #self.data.blocks do
        if self.data.blocks[i].uuid == uuid and not table.removeValue(self.data.blocks[i].outputs, uuidToDisconnect) then
            changed = true
        end
        if self.data.blocks[i].uuid == uuidToDisconnect and table.removeValue(self.data.blocks[i].inputs, uuid) then
            changed = true
        end
    end
    if changed then
        sm.event.sendToInteractable(self.interactable, "server_saveBlocks", self.data.blocks)
    end
end

function SiliconBlock.server_onCreate(self)
    self:getCreationData()
    self.size = table.copy(sm.MTFastLogic.SiliconBlocksShapeDB.uuidToSize[tostring(self.shape.shapeUuid)])
    self.isSilicon = true
    self.id = self.interactable:getId()
    self.data = self.data or {}
    -- sm.MTFastLogic.SiliconBlocksToGetData[#sm.MTFastLogic.SiliconBlocksToGetData + 1] = self
    self.data.blocks = SiliconCompressor.decompressBlockData(self, self.storage:load())
    local didUuidChange = false
    for i = 1, #self.data.blocks do
        local block = self.data.blocks[i]
        local oldUUid = block.uuid
        block.uuid = sm.MTFastLogic.CreationUtil.updateOldUuid(block.uuid, self.creationId)
        if oldUUid ~= block.uuid then
            didUuidChange = true
        end
        for ii = 1, #block.inputs do
            oldUUid = block.outputs[ii]
            block.inputs[ii] = sm.MTFastLogic.CreationUtil.updateOldUuid(block.inputs[ii], self.creationId)
            if oldUUid ~= block.inputs[ii] then
                didUuidChange = true
            end
        end
        for ii = 1, #block.outputs do
            oldUUid = block.outputs[ii]
            block.outputs[ii] = sm.MTFastLogic.CreationUtil.updateOldUuid(block.outputs[ii], self.creationId)
            if oldUUid ~= block.inputs[ii] then
                didUuidChange = true
            end
        end
    end
    if didUuidChange then
        self.storage:save(SiliconCompressor.compressBlocks(self))
    end
    self:getData()
end

function SiliconBlock.server_onDestroy(self)
    sm.MTFastLogic.SiliconBlocks[self.id] = nil
    if self.creation == nil or sm.MTFastLogic.Creations[self.creationId] == nil then
        return
    end
    if self.removeData ~= false then
        if self.creation.FastLogicRealBlockManager:checkForCreationDeletion() == false then
            self.creation.SiliconBlocks[self.id] = nil
            for _, block in ipairs(self.data.blocks) do
                self.FastLogicAllBlockManager:removeBlock(block.uuid)
            end
        end
    end
end

function SiliconBlock.server_onProjectile(self, position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid)
    -- print("time per rev: " .. tostring(sm.MTUtil.Profiler.Time.get("revertBlockType"..tostring(self.creationId)) / sm.MTUtil.Profiler.Count.get("revertBlockType"..tostring(self.creationId))))
    -- print("time: " .. tostring(sm.MTUtil.Profiler.Time.get("revertBlockType"..tostring(self.creationId))))
    -- print("count: " .. tostring(sm.MTUtil.Profiler.Count.get("revertBlockType"..tostring(self.creationId))))
    -- sm.MTUtil.Profiler.Time.reset("checkForBodyUpdate" .. tostring(self.creationId))
    -- sm.MTUtil.Profiler.Count.reset("checkForBodyUpdate" .. tostring(self.creationId))
    -- sm.MTUtil.Profiler.Time.reset("2checkForBodyUpdate" .. tostring(self.creationId))
    -- sm.MTUtil.Profiler.Count.reset("2checkForBodyUpdate" .. tostring(self.creationId))
    -- print(SiliconCompressor.compressBlocks(self))
    -- print(self.storage:load())
    print(self.creation.FastLogicRunner.blocksRan)
end

function SiliconBlock.client_onTinker(self, character, state)
    if state then
        self.network:sendToServer("server_changeSpeed", character:isCrouching())
    end
end

function SiliconBlock.server_changeSpeed(self, isCrouching)
    if self.creation.FastLogicRunner.numberOfUpdatesPerTick <= 0 then
        self.creation.FastLogicRunner.numberOfUpdatesPerTick = 1
    else
        if isCrouching then
            self.creation.FastLogicRunner.numberOfUpdatesPerTick = self.creation.FastLogicRunner.numberOfUpdatesPerTick / 2
        else
            self.creation.FastLogicRunner.numberOfUpdatesPerTick = self.creation.FastLogicRunner.numberOfUpdatesPerTick * 2
        end
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
