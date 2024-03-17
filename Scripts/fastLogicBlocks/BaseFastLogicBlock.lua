print("loading BaseFastLogicBlock")

dofile "../util/util.lua"
dofile "../fastLogicBlock/FastLogicRunner.lua"
BaseFastLogicBlock = {}
BaseFastLogicBlock.maxParentCount = -1 -- infinite
BaseFastLogicBlock.maxChildCount = -1  -- infinite
BaseFastLogicBlock.connectionInput = sm.interactable.connectionType.logic
BaseFastLogicBlock.connectionOutput = sm.interactable.connectionType.logic
BaseFastLogicBlock.colorNormal = sm.color.new(0x005555ff)
BaseFastLogicBlock.colorHighlight = sm.color.new(0xff0000ff)

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.FastLogicBlockLookUp = sm.MTFastLogic.FastLogicBlockLookUp or {}
sm.MTFastLogic.Creations = sm.MTFastLogic.Creations or {}

function BaseFastLogicBlock.GetCreationId(self)
    return self.shape:getBody():getId()
end

function BaseFastLogicBlock.RescanSelf(self)
    self.activeInputs = {}
    self.FastLogicRunner:ExtRemoveBlock(self.id)
    self.creation.BlocksToScan[#self.creation.BlocksToScan + 1] = self
end

function BaseFastLogicBlock.DeepRescanSelf(self)
    self.lastSeenSpeed = self.FastLogicRunner.numberOfUpdatesPerTick
    self.activeInputs = {}
    self.FastLogicRunner:ExtRemoveBlock(self.id)
    self.creation.AllFastBlocks[self.id] = nil
    self.FastLogicRunner = nil
    self.creation = nil
    self.creationId = nil
    self:GetData()
end

function BaseFastLogicBlock.getParentIds(self)
    local ids = {}
    for _,v in ipairs(self.interactable:getParents()) do
        if self.creation.AllFastBlocks[v:getId()] ~= nil then
            ids[#ids+1] = v:getId()
        end
    end
    return ids
end

function BaseFastLogicBlock.getChildIds(self)
    local ids = {}
    for _,v in ipairs(self.interactable:getChildren()) do
        if self.creation.AllFastBlocks[v:getId()] ~= nil then
            ids[#ids+1] = v:getId()
        end
    end
    return ids
end

function BaseFastLogicBlock.GetData(self)
    self.state = self.state or nil
    self.activeInputs = {}
    self.creationId = self:GetCreationId()
    self.id = self.interactable:getId()
    if (sm.MTFastLogic.Creations[self.creationId] == nil) then
        sm.MTFastLogic.Creations[self.creationId] = {
            ["FastLogicRunner"] = FastLogicRunner.getNew(self.creationId),
            ["FastLogicGates"] = {},
            ["FastTimers"] = {},
            ["BlocksToScan"] = {},
            ["AllFastBlocks"] = {},
            ["AllNonFastBlocks"] = {},
        }
        sm.MTFastLogic.Creations[self.creationId].FastLogicRunner:refresh()
        if self.lastSeenSpeed ~= nil then
            sm.MTFastLogic.Creations[self.creationId].FastLogicRunner.numberOfUpdatesPerTick = self.lastSeenSpeed
        end
    end
    self.creation = sm.MTFastLogic.Creations[self.creationId]
    self.FastLogicRunner = self.creation.FastLogicRunner
    if self.creation.AllFastBlocks[self.id] == nil then
        self.lastSeenSpeed = self.FastLogicRunner.numberOfUpdatesPerTick
        self.creation.body = self.shape:getBody()
        self.creation.lastBodyUpdate = 0
        self.creation.AllFastBlocks[self.id] = self
        self.creation.BlocksToScan[#self.creation.BlocksToScan + 1] = self
        sm.MTFastLogic.FastLogicBlockLookUp[self.id] = self
    end
end

function BaseFastLogicBlock.server_onCreate(self)
    self.isFastLogic = true
    self.type = nil
    self:GetData()
    self:server_onCreate2()
end

function BaseFastLogicBlock.server_onCreate2(self)
    -- your code
end

function BaseFastLogicBlock.server_onDestroy(self)
    sm.MTFastLogic.FastLogicBlockLookUp[self.id] = nil
    self.creation.AllFastBlocks[self.id] = nil
    self.FastLogicRunner:ExtRemoveBlock(self.id)
    self:server_onDestroy2()
end

function BaseFastLogicBlock.server_onDestroy2(self)
    -- your code
end

function BaseFastLogicBlock.server_onRefresh(self)
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

function BaseFastLogicBlock.client_onRefresh(self)
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
        self.FastLogicRunner.numberOfUpdatesPerTick = self.FastLogicRunner.numberOfUpdatesPerTick / 2
    else
        self.FastLogicRunner.numberOfUpdatesPerTick = self.FastLogicRunner.numberOfUpdatesPerTick * 2
    end
    
    self:sendMessageToAll("UpdatesPerTick = " .. tostring(self.FastLogicRunner.numberOfUpdatesPerTick))
end

function BaseFastLogicBlock.PreUpdate(self)
    if self.creationId ~= self:GetCreationId() then
        self:DeepRescanSelf()
        return
    end
    local id = self.FastLogicRunner.hashedLookUp[self.id]
    self.FastLogicRunner:AddBlockToUpdate(id)
    local inputs = self.interactable:getParents()
    local inputsHash = {}
    for _, v in pairs(inputs) do
        local vId = v:getId()
        inputsHash[vId] = true
        if self.creation.AllFastBlocks[vId] ~= nil then
            local inputId = self.FastLogicRunner.hashedLookUp[vId]
            if self.FastLogicRunner.blockInputsHash[id][inputId] == nil then
                self.FastLogicRunner:AddInput(id, inputId)
            end
        else
            local currentState = v.active
            if self.creation.AllNonFastBlocks[vId] == nil then
                self.creation.AllNonFastBlocks[vId] = {["interactable"] = v, ["currentState"] = currentState, ["outputs"] = {}}
            end
            if not table.contains(self.creation.AllNonFastBlocks[vId].outputs, id) then
                self.creation.AllNonFastBlocks[vId].outputs[#self.creation.AllNonFastBlocks[vId].outputs+1] = id
            end
            local activeInput = self.activeInputs[vId]
            if (activeInput == nil) then
                if currentState then
                    self.FastLogicRunner.countOfOnInputs[id] = self.FastLogicRunner.countOfOnInputs[id] + 1
                    self.activeInputs[vId] = true
                else
                    self.activeInputs[vId] = false
                end
                self.FastLogicRunner:ExtAddOther(id)
            elseif activeInput ~= currentState then
                self.activeInputs[vId] = currentState
                self.FastLogicRunner:AddBlockToUpdate(id)
            end
        end
    end
    for k, state in pairs(self.activeInputs) do
        if inputsHash[k] == nil then
            if table.contains(self.creation.AllNonFastBlocks[k].outputs, id) then
                if self.creation.AllNonFastBlocks[k].currentState then
                    self.FastLogicRunner.countOfOnInputs[id] = self.FastLogicRunner.countOfOnInputs[id] - 1
                end
                if #self.creation.AllNonFastBlocks[k].outputs == 1 then
                    self.creation.AllNonFastBlocks[k] = nil
                else
                    table.removeValue(self.creation.AllNonFastBlocks[k].outputs, id)
                end
            end
            self.activeInputs[k] = nil
            self.FastLogicRunner:ExtRemoveOther(id)
        end
    end
    for k, state in pairs(self.FastLogicRunner.blockInputsHash[id]) do
        if inputsHash[self.FastLogicRunner.unhashedLookUp[k]] == nil then
            self.FastLogicRunner:RemoveOutput(k, id)
        end
    end
end

function BaseFastLogicBlock.UpdateState(self, state)
    if self.interactable.active ~= state or self.state ~= state then
        self.interactable.active = state
        if state then
            self.interactable.power = 1
        else
            self.interactable.power = 0
        end
        self.state = state
        sm.MTFastLogic.FastLogicRunnerRunner.changedIds[#sm.MTFastLogic.FastLogicRunnerRunner.changedIds + 1] = self.id
        return true
    end
    return false
end

function BaseFastLogicBlock.client_updateTexture(self)
end

function BaseFastLogicBlock.sendMessageToAll(self, message)
    self.network:sendToClients("client_sendMessage", message)
end

function BaseFastLogicBlock.client_sendMessage(self, message)
    sm.gui.chatMessage(message)
end
