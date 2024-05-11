dofile "../util/util.lua"
local string = string
local table = table

BaseFastLogicBlock = {}
BaseFastLogicBlock.maxParentCount = -1 -- infinite
BaseFastLogicBlock.maxChildCount = -1  -- infinite
BaseFastLogicBlock.connectionInput = sm.interactable.connectionType.logic
BaseFastLogicBlock.connectionOutput = sm.interactable.connectionType.logic
BaseFastLogicBlock.colorNormal = sm.color.new(0x5612CCff)
BaseFastLogicBlock.colorHighlight = sm.color.new(0xA530C2ff)

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.FastLogicBlockLookUp = sm.MTFastLogic.FastLogicBlockLookUp or {}
sm.MTFastLogic.client_FastLogicBlockLookUp = sm.MTFastLogic.client_FastLogicBlockLookUp or {}
sm.MTFastLogic.Creations = sm.MTFastLogic.Creations or {}
sm.MTFastLogic.BlocksToGetData = sm.MTFastLogic.BlocksToGetData or {}
sm.MTFastLogic.NewBlockUuids = sm.MTFastLogic.NewBlockUuids or {}

-- function BaseFastLogicBlock.rescanSelf(self)
--     self.activeInputs = {}
--     self.creation.FastLogicAllBlockMannager:removeBlock(self.data.uuid)
--     self.creation.BlocksToScan[#self.creation.BlocksToScan + 1] = self
-- end

function BaseFastLogicBlock.deepRescanSelf(self)
    self.lastSeenSpeed = self.FastLogicRunner.numberOfUpdatesPerTick
    self.activeInputs = {}
    self.FastLogicAllBlockMannager:removeBlock(self.data.uuid)
    self.creation.AllFastBlocks[self.data.uuid] = nil
    self.FastLogicRunner = nil
    self.creation = nil
    self.creationId = nil
    sm.MTFastLogic.BlocksToGetData[#sm.MTFastLogic.BlocksToGetData + 1] = self
end

function BaseFastLogicBlock.getParentUuids(self)
    local uuids = {}
    for _, v in ipairs(self.interactable:getParents()) do
        local otherUuid = self.creation.uuids[v:getId()]
        if otherUuid ~= nil then
            uuids[#uuids + 1] = otherUuid
        end
    end
    return uuids
end

function BaseFastLogicBlock.getChildUuids(self)
    local uuids = {}
    for _, v in ipairs(self.interactable:getChildren()) do
        local otherUuid = self.creation.uuids[v:getId()]
        if otherUuid ~= nil then
            uuids[#uuids + 1] = otherUuid
        end
    end
    return uuids
end

function BaseFastLogicBlock.getData(self)
    self.state = self.state or nil
    self.activeInputs = {}
    self.removeAllData = self.removeAllData or true
    self.creationId = sm.MTFastLogic.FastLogicRunnerRunner:getCreationId(self.shape:getBody())
    if (sm.MTFastLogic.Creations[self.creationId] == nil) then
        sm.MTFastLogic.FastLogicRunnerRunner:MakeCreationData(self.creationId, self.shape:getBody(), self.lastSeenSpeed)
    end
    self.creation = sm.MTFastLogic.Creations[self.creationId]
    self.FastLogicRunner = self.creation.FastLogicRunner
    self.FastLogicAllBlockMannager = self.creation.FastLogicAllBlockMannager
    if self.creation.AllFastBlocks[self.data.uuid] == nil then
        self.lastSeenSpeed = self.creation.FastLogicRunner.numberOfUpdatesPerTick
        self.creation.lastBodyUpdate = 0
        self.creation.AllFastBlocks[self.data.uuid] = self
        self.creation.BlocksToScan[#self.creation.BlocksToScan + 1] = self
        self.creation.uuids[self.id] = self.data.uuid
        self.creation.ids[self.data.uuid] = self.id
    end
    self:getData2()
end

function BaseFastLogicBlock.getData2(self)
    -- your code
end

function BaseFastLogicBlock.server_onCreate(self)
    self.data = self.data or {}
    self.isFastLogic = true
    self.type = nil
    self.id = self.interactable:getId()
    sm.MTFastLogic.BlocksToGetData[#sm.MTFastLogic.BlocksToGetData + 1] = self
    if self.storage:load() ~= nil then
        self.data = self.storage:load()
        if self.data.uuid == nil then
            self.data.uuid = string.uuid()
        elseif sm.MTFastLogic.FastLogicBlockLookUp[self.data.uuid] == nil then
            self.data.uuid = self.data.uuid
        else
            local oldUuid = self.data.uuid
            while sm.MTFastLogic.FastLogicBlockLookUp[self.data.uuid] ~= nil do
                self.data.uuid = string.uuid()
            end
            sm.MTFastLogic.NewBlockUuids[oldUuid] = {self.data.uuid, 0}
        end
    else
        self.data.uuid = string.uuid()
    end
    sm.MTFastLogic.FastLogicBlockLookUp[self.data.uuid] = self
    self.storage:save(self.data)
    self:server_onCreate2()
end

function BaseFastLogicBlock.server_onCreate2(self)
    -- your code
end

function BaseFastLogicBlock.server_onDestroy(self)
    sm.MTFastLogic.FastLogicBlockLookUp[self.data.uuid] = nil
    self.creation.AllFastBlocks[self.data.uuid] = nil
    if self.removeAllData then
        self.FastLogicAllBlockMannager:removeBlock(self.data.uuid) -- remove
    else
        self.creation.blocks[self.data.uuid].isSilicon = true
    end
    self:server_onDestroy2()
end

function BaseFastLogicBlock.server_onDestroy2(self)
    -- your code
end

function BaseFastLogicBlock.server_onrefresh(self)
    self:server_onCreate()
end

function BaseFastLogicBlock.client_onCreate(self)
    sm.MTFastLogic.client_FastLogicBlockLookUp[self.interactable:getId()] = self
    self:client_onCreate2()
end

function BaseFastLogicBlock.client_onCreate2(self)
    -- your code
end

function BaseFastLogicBlock.client_onDestroy(self)
    sm.MTFastLogic.client_FastLogicBlockLookUp[self.interactable:getId()] = nil
    self:client_onDestroy2()
end

function BaseFastLogicBlock.client_onDestroy2(self)
    -- your code
end

function BaseFastLogicBlock.client_onrefresh(self)
    self:client_onCreate()
end

function BaseFastLogicBlock.client_onTinker(self, character, state)
    if state then
        self.network:sendToServer("server_changeSpeed", character:isCrouching())
    end
end

function BaseFastLogicBlock.server_onProjectile(self, position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid)
    print(self.shape:getLocalPosition())
    --local targetBody = self.shape:getBody()
    --sm.MTFastLogic.FastLogicRunnerRunner:server_convertBody({ body = targetBody, wantedType = "FastLogic" })
end

function BaseFastLogicBlock.server_onMelee(self, position, attacker, damage, power, direction, normal)
    local targetBody = self.shape:getBody()
    sm.MTFastLogic.FastLogicRunnerRunner:server_convertBody({ body = targetBody, wantedType = "VanillaLogic" })
end

function BaseFastLogicBlock.server_changeSpeed(self, isCrouching)
    if isCrouching then
        self.creation.FastLogicRunner.numberOfUpdatesPerTick = self.creation.FastLogicRunner.numberOfUpdatesPerTick / 2
    else
        self.creation.FastLogicRunner.numberOfUpdatesPerTick = self.creation.FastLogicRunner.numberOfUpdatesPerTick * 2
    end

    self:sendMessageToAll("UpdatesPerTick = " .. tostring(self.creation.FastLogicRunner.numberOfUpdatesPerTick))
end

function BaseFastLogicBlock.client_updateTexture(self)
end

function BaseFastLogicBlock.sendMessageToAll(self, message)
    self.network:sendToClients("client_sendMessage", message)
end

function BaseFastLogicBlock.client_sendMessage(self, message)
    sm.gui.chatMessage(message)
end

function BaseFastLogicBlock.getLocalCenter(self)
    return self.shape:getLocalPosition() + (self.shape.xAxis + self.shape.yAxis + self.shape.zAxis) * 0.5
end

function BaseFastLogicBlock.remove(self, removeAllData)
    if removeAllData == false then
        self.removeAllData = false
    end
    self.shape:destroyShape()
end

function BaseFastLogicBlock.removeUuidData(self)
    for i = 1, #self.creation.blocks[self.data.uuid].inputs do
        local otherUuid = self.creation.blocks[self.data.uuid].inputs[i]
        if self.creation.blocks[otherUuid].isSilicon then
            return
        end
    end
    for i = 1, #self.creation.blocks[self.data.uuid].outputs do
        local otherUuid = self.creation.blocks[self.data.uuid].outputs[i]
        if self.creation.blocks[otherUuid].isSilicon then
            return
        end
    end
    local uuid = self.data.uuid
    self.data.uuid = nil
    self.storage:save(self.data)
    self.data.uuid = uuid
end
