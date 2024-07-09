dofile "../util/util.lua"
local string = string
local table = table

dofile "BaseFastLogicBlock.lua"

TickStepButton = class()
TickStepButton.poseWeightCount = 1

function TickStepButton.server_onCreate(self)
end

function TickStepButton.server_triggerUpdate(self)
    local creationId = sm.MTFastLogic.CreationUtil.getCreationIdFromBlock(self)
    if sm.MTFastLogic.Creations[creationId] == nil then
        return
    end
    sm.MTFastLogic.Creations[creationId].FastLogicRunner.numberOfUpdatesPerTick = -1 -- tell the runner to do a step and then stop
end

function TickStepButton.client_onCreate(self)
    self.interactable:setPoseWeight(0, 0)
end

function TickStepButton.client_onProjectile(self, position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid)
    sm.gui.chatMessage("Stepped")
    self.network:sendToServer("server_triggerUpdate")
end

function TickStepButton.client_onInteract(self, character, state)
    if state then
        sm.gui.chatMessage("Stepped")
        self.interactable:setPoseWeight(0, 1)
        self.network:sendToServer("server_triggerUpdate")
    else
        self.interactable:setPoseWeight(0, 0)
    end
end
