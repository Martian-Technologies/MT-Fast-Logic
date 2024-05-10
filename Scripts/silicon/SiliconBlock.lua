dofile "../util/util.lua"
local string = string
local table = table

SiliconBlock = SiliconBlock or class()

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.UsedUuids = sm.MTFastLogic.UsedUuids or {}
sm.MTFastLogic.SiliconBlocks = sm.MTFastLogic.SiliconBlocks or {}
sm.MTFastLogic.SiliconBlocksToGetData = sm.MTFastLogic.SiliconBlocksToGetData or {}
sm.MTFastLogic.SiliconBlocksToAddConnections = sm.MTFastLogic.SiliconBlocksToAddConnections or {}
sm.MTFastLogic.NewBlockUuids = sm.MTFastLogic.NewBlockUuids or {}

function SiliconBlock.rescanSelf(self)
    for _, block in ipairs(self.data.blocks) do
        -- self.FastLogicAllBlockMannager:removeBlock(block.uuid)
        sm.MTFastLogic.UsedUuids[block.uuid] = nil
    end
    self.creation.BlocksToScan[#self.creation.BlocksToScan + 1] = self
end

function SiliconBlock.deepRescanSelf(self)
    for _, block in ipairs(self.data.blocks) do
        sm.MTFastLogic.UsedUuids[block.uuid] = nil
        self.FastLogicAllBlockMannager:removeBlock(block.uuid)
    end
    self.lastSeenSpeed = self.creation.FastLogicRunner.numberOfUpdatesPerTick
    self.creation.SiliconBlocks[self.id] = nil
    self.creation = nil
    self.creationId = nil
    self.FastLogicAllBlockMannager = nil
    sm.MTFastLogic.SiliconBlocksToGetData[#sm.MTFastLogic.SiliconBlocksToGetData + 1] = self
end

function SiliconBlock.getData(self)
    self.creationId = sm.MTFastLogic.FastLogicRunnerRunner:getCreationId(self.shape:getBody())
    self.id = self.interactable:getId()
    if (sm.MTFastLogic.Creations[self.creationId] == nil) then
        sm.MTFastLogic.FastLogicRunnerRunner:MakeCreationData(self.creationId, self.shape:getBody(), self.lastSeenSpeed)
    end
    self.creation = sm.MTFastLogic.Creations[self.creationId]
    self.FastLogicAllBlockMannager = self.creation.FastLogicAllBlockMannager
    if self.creation.SiliconBlocks[self.id] == nil then
        self.lastSeenSpeed = self.creation.FastLogicRunner.numberOfUpdatesPerTick
        self.creation.lastBodyUpdate = 0
        self.creation.SiliconBlocks[self.id] = self
        self.creation.BlocksToScan[#self.creation.BlocksToScan + 1] = self
        sm.MTFastLogic.SiliconBlocks[self.id] = self
    end
    for i = 1, #self.data.blocks do
        local block = self.data.blocks[i]
        if self.creation.blocks[block.uuid] == nil then
            if sm.MTFastLogic.UsedUuids[block.uuid] ~= nil then
                local oldUuid = block.uuid
                while sm.MTFastLogic.UsedUuids[block.uuid] ~= nil do
                    block.uuid = string.uuid()
                end
                sm.MTFastLogic.NewBlockUuids[oldUuid] = {block.uuid, 0}
            end
            self.FastLogicAllBlockMannager:addSiliconBlock(block.type, block.uuid, block.pos, block.rot, {}, {}, block.state, self.id)
        end
    end
    self:server_saveBlocks(self.data.blocks)
    if  sm.MTFastLogic.SiliconBlocksToAddConnections[2] == nil then
        sm.MTFastLogic.SiliconBlocksToAddConnections[2] = {}
    end
    sm.MTFastLogic.SiliconBlocksToAddConnections[2][#sm.MTFastLogic.SiliconBlocksToAddConnections[2]+1] = self
end

function SiliconBlock.addConnections(self)
    for i = 1, #self.data.blocks do
        local block = self.data.blocks[i]
        for ii = 1, #block.inputs do
            if (sm.MTFastLogic.NewBlockUuids[block.inputs[ii]] ~= nil) then
                block.inputs[ii] = sm.MTFastLogic.NewBlockUuids[block.inputs[ii]][1]
            end
            self.FastLogicAllBlockMannager:addOutput(block.inputs[ii], block.uuid)
        end

        for ii = 1, #block.outputs do
            if (sm.MTFastLogic.NewBlockUuids[block.outputs[ii]] ~= nil) then
                block.outputs[ii] = sm.MTFastLogic.NewBlockUuids[block.outputs[ii]][1]
            end
            self.FastLogicAllBlockMannager:addOutput(block.uuid, block.outputs[ii])
        end
    end
    self:server_saveBlocks(self.data.blocks)
end

function SiliconBlock.server_onCreate(self)
    self.isSilicon = true
    self.data = self.data or {}
    sm.MTFastLogic.SiliconBlocksToGetData[#sm.MTFastLogic.SiliconBlocksToGetData + 1] = self
    if self.storage:load() ~= nil then
        self.data.blocks = self.storage:load().blocks or {}
    else
        self.data.blocks = {}
    end
    self.storage:save({ blocks = self.data.blocks })
end

function SiliconBlock.server_onDestroy(self)
    self.creation.SiliconBlocks[self.id] = nil
    for _, block in ipairs(self.data.blocks) do
        sm.MTFastLogic.UsedUuids[block.uuid] = nil
        self.FastLogicAllBlockMannager:removeBlock(block.uuid)
    end
end

function SiliconBlock.server_onProjectile(self, position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid)
    -- print(self.data.blocks)
    print("--")
    for k,v in pairs(self.data.blocks) do
        print(self.creation.blocks[v.uuid].uuid)
    end
end

function SiliconBlock.addBlocks(self, uuids, creation)
    local axes = {x=self.shape.xAxis, y=self.shape.yAxis, z=self.shape.zAxis}
    if type(uuids) == "number" then
        uuids = {uuids}
    end
    if #uuids > 0 then
        if self.creation == nil then
            self:getData()
        end

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
            local pos = block.pos - self.shape.localPosition

            pos = sm.vec3.new(
                pos.x*axes.x.x + pos.y*axes.x.y + pos.z*axes.x.z,
                pos.x*axes.y.x + pos.y*axes.y.y + pos.z*axes.y.z,
                pos.x*axes.z.x + pos.y*axes.z.y + pos.z*axes.z.z
            )
            blocks[i] = {
                type = block.type,
                uuid = block.uuid,
                pos = pos,
                rot = block.rot,
                inputs = table.copy(block.inputs),
                outputs = table.copy(block.outputs),
                state = block.state,
                -- timerLength = block.timerLength,
            }
        end
        self:server_saveBlocks(blocks, false)
    end
end

-- function SiliconBlock.removeBlocks(self, uuids)
--     if type(uuids) == "number" then
--         uuids = {uuids}
--     end

--     local blocks = self.data.blocks
--     for _, uuid in ipairs(uuids) do
--         sm.MTFastLogic.UsedUuids[uuid] = nil
--         for index, block in ipairs(blocks) do
--             if block.uuid == uuid then
--                 table.remove(blocks, index)
--                 break
--             end
--         end
--     end

--     self:server_saveBlocks(blocks)
-- end

function SiliconBlock.server_onrefresh(self)
    self:server_onCreate()
end

function SiliconBlock.server_saveBlocks(self, blocks, rescan)
    if rescan ~= false then
        self:rescanSelf()
    end
    self.data.blocks = blocks
    self.storage:save({ blocks = blocks })
end