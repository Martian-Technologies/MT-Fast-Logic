dofile "../util/util.lua"
dofile "../CreationUtil.lua"
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
sm.MTFastLogic.dataToSet = sm.MTFastLogic.dataToSet or {}

function BaseFastLogicBlock.deepRescanSelf(self)
    if self.creation ~= nil then
        self.lastSeenSpeed = self.creation.FastLogicRunner.numberOfUpdatesPerTick
        self.creation.FastLogicAllBlockMannager:removeBlock(self.data.uuid)
        self.creation.AllFastBlocks[self.data.uuid] = nil
    end
    self.activeInputs = {}
    self.FastLogicRunner = nil
    self.creation = nil
    self.creationId = nil
    self:getData()
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

function BaseFastLogicBlock.getCreationData(self)
    self.creationId = sm.MTFastLogic.CreationUtil.getCreationId(self.shape:getBody())
    if (sm.MTFastLogic.Creations[self.creationId] == nil) then
        sm.MTFastLogic.CreationUtil.MakeCreationData(self.creationId, self.shape:getBody(), self.lastSeenSpeed)
    end
    self.creation = sm.MTFastLogic.Creations[self.creationId]
    self.FastLogicRunner = self.creation.FastLogicRunner
    self.FastLogicAllBlockMannager = self.creation.FastLogicAllBlockMannager
end

function BaseFastLogicBlock.getData(self)
    self.state = self.state or nil
    self.activeInputs = {}
    self.removeAllData = self.removeAllData or true
    self:getCreationData()
    if sm.MTFastLogic.dataToSet[self.id] ~= nil then
        self.creation.FastLogicRealBlockMannager:setData(self.data.uuid, sm.MTFastLogic.dataToSet[self.id])
        sm.MTFastLogic.dataToSet[self.id] = nil
    end
    if self.creation.AllFastBlocks[self.data.uuid] == nil then
        self.lastSeenSpeed = self.creation.FastLogicRunner.numberOfUpdatesPerTick
        self.creation.lastBodyUpdate = 0
        self.creation.AllFastBlocks[self.data.uuid] = self
        self.creation.BlocksToScan[#self.creation.BlocksToScan + 1] = self
        self.creation.uuids[self.id] = self.data.uuid
        self.creation.ids[self.data.uuid] = self.id
        print("weewooweewoo")
        print(self.id)
        print(self.data.uuid)
    end
    self:getData2()
end

function BaseFastLogicBlock.getData2(self)
    -- your code
end

function BaseFastLogicBlock.server_onCreate(self)
    self:getCreationData()
    self.data = self.data or {}
    self.isFastLogic = true
    self.type = nil
    self.id = self.interactable:getId()
    print("oncreate")
    print(self.id)
    if self.storage:load() ~= nil then
        self.data = self.storage:load()
        if self.data.uuid == nil then
            self.data.uuid = sm.MTFastLogic.CreationUtil.newUuid()
        else
            self.data.uuid = sm.MTFastLogic.CreationUtil.updateOldUuid(self.data.uuid, self.creationId)
        end
    else
        self.data.uuid = sm.MTFastLogic.CreationUtil.newUuid()
    end
    print(self.data.uuid)
    sm.MTFastLogic.FastLogicBlockLookUp[self.data.uuid] = self
    self.storage:save(self.data)
    self:server_onCreate2()
    self:getData()
end

function BaseFastLogicBlock.server_onCreate2(self)
    -- your code
end

function BaseFastLogicBlock.server_onDestroy(self)
    sm.MTFastLogic.FastLogicBlockLookUp[self.data.uuid] = nil
    print("setting gate to nil")
    print(self.data.uuid)
    if self.creation == nil then
        return
    end

    self.creation.AllFastBlocks[self.data.uuid] = nil
    self.creation.uuids[self.id] = nil
    self.creation.ids[self.data.uuid] = nil

    self.creation.AllFastBlocks[self.data.uuid] = nil
    if self.removeAllData then
        self.FastLogicAllBlockMannager:removeBlock(self.data.uuid) -- remove
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
    print(self.FastLogicRunner.pathNames[self.FastLogicRunner.altBlockData[self.FastLogicRunner.hashedLookUp[self.data.uuid]]])
    print(self.FastLogicRunner.pathNames[self.FastLogicRunner.runnableBlockPathIds[self.FastLogicRunner.hashedLookUp[self.data.uuid]]])
    print(self.data.uuid)
end

-- function BaseFastLogicBlock.server_onMelee(self, position, attacker, damage, power, direction, normal)
--     local targetBody = self.shape:getBody()
--     sm.MTFastLogic.FastLogicRunnerRunner:server_convertBody({ body = targetBody, wantedType = "VanillaLogic" })
-- end

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
