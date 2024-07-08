dofile "../util/util.lua"
local string = string
local table = table

dofile "BaseFastLogicBlock.lua"

TickStepButton = class()
TickStepButton.poseWeightCount = 1

function TickStepButton.server_onCreate(self)
    self:setState(false)
    self.turnOff = 0
end

function TickStepButton.server_onFixedUpdate(self)
    if self.turnOff > 0 then
        self.turnOff = self.turnOff - 1
        if self.turnOff == 0 then
            self:setState(false)
        end
    end
end

function TickStepButton.server_onProjectile(self, position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid)
    if not self.state then
        self:setState(not self.state)
        self.turnOff = 3
    end
end

function TickStepButton.setState(self, state)
    if self.state ~= state then
        self.state = state
        self.interactable.active = self.state
        self.network:sendToClients("client_setState", self.state)
        if self.state then
            local creationId = sm.MTFastLogic.CreationUtil.getCreationIdFromBlock(self)
            if sm.MTFastLogic.Creations[creationId].FastLogicRunner.numberOfUpdatesPerTick <= 0 then
                self:sendMessageToAll("Step")
            else
                self:sendMessageToAll("Single Steping")
            end
            sm.MTFastLogic.Creations[creationId].FastLogicRunner.numberOfUpdatesPerTick = -1 -- tell the runner to do a step and then stop
        end
    end
end

function TickStepButton.client_setState(self, state)
    self.client_state = state
    self:client_updateTexture()
end

function TickStepButton.client_onCreate(self)
    self:client_setState(false)
end

function TickStepButton.client_onInteract(self, character, state)
    self.network:sendToServer("setState", not self.client_state)
end

function TickStepButton.client_updateTexture(self)
    if self.client_state then
        self.interactable:setPoseWeight(0, 1)
    else
        self.interactable:setPoseWeight(0, 0)
    end
end

function TickStepButton.sendMessageToAll(self, message)
    self.network:sendToClients("client_sendMessage", message)
end

function TickStepButton.client_sendMessage(self, message)
    sm.gui.chatMessage(message)
end