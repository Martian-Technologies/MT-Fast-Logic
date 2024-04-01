-- print("loading BaseFastLogicBlock")

dofile "../util/util.lua"
BaseFastLogicBlock = {}
BaseFastLogicBlock.maxParentCount = -1 -- infinite
BaseFastLogicBlock.maxChildCount = -1  -- infinite
BaseFastLogicBlock.connectionInput = sm.interactable.connectionType.logic
BaseFastLogicBlock.connectionOutput = sm.interactable.connectionType.logic
BaseFastLogicBlock.colorNormal = sm.color.new(0x5612CCff)
BaseFastLogicBlock.colorHighlight = sm.color.new(0xA530C2ff)

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.FastLogicBlockLookUp = sm.MTFastLogic.FastLogicBlockLookUp or {}
sm.MTFastLogic.Creations = sm.MTFastLogic.Creations or {}
sm.MTFastLogic.BlocksToGetData = sm.MTFastLogic.BlocksToGetData or {}

function BaseFastLogicBlock.rescanSelf(self)
    self.activeInputs = {}
    self.FastLogicAllBlockMannager:removeBlock(self.id)
    self.creation.BlocksToScan[#self.creation.BlocksToScan + 1] = self
end

function BaseFastLogicBlock.deepRescanSelf(self)
    self.lastSeenSpeed = self.FastLogicRunner.numberOfUpdatesPerTick
    self.activeInputs = {}
    self.FastLogicAllBlockMannager:removeBlock(self.id)
    self.creation.AllFastBlocks[self.id] = nil
    self.FastLogicRunner = nil
    self.creation = nil
    self.creationId = nil
    sm.MTFastLogic.BlocksToGetData[#sm.MTFastLogic.BlocksToGetData+1] = self
end

function BaseFastLogicBlock.getParentIds(self)
    local ids = {}
    for _, v in ipairs(self.interactable:getParents()) do
        if self.creation.AllFastBlocks[v:getId()] ~= nil then
            ids[#ids + 1] = v:getId()
        end
    end
    return ids
end

function BaseFastLogicBlock.getChildIds(self)
    local ids = {}
    for _, v in ipairs(self.interactable:getChildren()) do
        if self.creation.AllFastBlocks[v:getId()] ~= nil then
            ids[#ids + 1] = v:getId()
        end
    end
    return ids
end

function BaseFastLogicBlock.getData(self)
    self.state = self.state or nil
    self.activeInputs = {}
    self.creationId = sm.MTFastLogic.FastLogicRunnerRunner:getCreationId(self.shape:getBody())
    self.id = self.interactable:getId()
    if (sm.MTFastLogic.Creations[self.creationId] == nil) then
        sm.MTFastLogic.FastLogicRunnerRunner:MakeCreationData(self.creationId, self.shape:getBody(), self.lastSeenSpeed)
    end
    self.creation = sm.MTFastLogic.Creations[self.creationId]
    self.FastLogicRunner = self.creation.FastLogicRunner
    self.FastLogicAllBlockMannager = self.creation.FastLogicAllBlockMannager
    if self.creation.AllFastBlocks[self.id] == nil then
        self.lastSeenSpeed = self.creation.FastLogicRunner.numberOfUpdatesPerTick
        self.creation.lastBodyUpdate = 0
        self.creation.AllFastBlocks[self.id] = self
        self.creation.BlocksToScan[#self.creation.BlocksToScan + 1] = self
        sm.MTFastLogic.FastLogicBlockLookUp[self.id] = self
    end
    self:getData2()
end

function BaseFastLogicBlock.getData2(self)
    -- your code
end

function BaseFastLogicBlock.server_onCreate(self)
    self.isFastLogic = true
    self.type = nil
    sm.MTFastLogic.BlocksToGetData[#sm.MTFastLogic.BlocksToGetData+1] = self
    self:server_onCreate2()
end

function BaseFastLogicBlock.server_onCreate2(self)
    -- your code
end

function BaseFastLogicBlock.server_onDestroy(self)
    sm.MTFastLogic.FastLogicBlockLookUp[self.id] = nil
    self.creation.AllFastBlocks[self.id] = nil
    if self.removeAllData then
        self.FastLogicAllBlockMannager:removeBlock(self.id) -- remove
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
    sm.MTFastLogic.FastLogicBlockLookUp[self.interactable:getId()] = self
    self:client_onCreate2()
end

function BaseFastLogicBlock.client_onCreate2(self)
    -- your code
end

function BaseFastLogicBlock.client_onDestroy(self)
    sm.MTFastLogic.FastLogicBlockLookUp[self.interactable:getId()] = nil
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
    local targetBody = self.shape:getBody()
    sm.MTFastLogic.FastLogicRunnerRunner:server_convertBody({ body = targetBody, wantedType = "FastLogic" })
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

function BaseFastLogicBlock.remove(self, removeAllData)
    if removeAllData == false then
        self.removeAllData = false
    end
    self.shape:destroyShape()
end