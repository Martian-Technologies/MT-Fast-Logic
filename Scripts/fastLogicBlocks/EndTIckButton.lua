dofile "../util/util.lua"
local string = string
local table = table

dofile "BaseFastLogicBlock.lua"

EndTickButton = table.deepCopyTo(BaseFastLogicBlock, (EndTickButton or class()))
EndTickButton.maxParentCount = -1 -- infinite
EndTickButton.maxChildCount = 0
EndTickButton.connectionInput = sm.interactable.connectionType.logic
EndTickButton.connectionOutput = nil
EndTickButton.poseWeightCount = 1

function EndTickButton.getData2(self)
    self.creation.EndTickButtons[self.data.uuid] = self
end

function EndTickButton.server_onCreate2(self)
    self.type = "EndTickButton"
end

function EndTickButton.server_onDestroy2(self)
    self.creation.EndTickButtons[self.data.uuid] = nil
end

function EndTickButton.client_onCreate2(self)
end

function EndTickButton.client_onDestroy2(self)
end

function EndTickButton.client_onInteract(self, character, state)
    self.FastLogicRunner:externalChangeNonFastOnInput(self.data.uuid, state and 1 or -1)
    self.FastLogicRunner:externalAddBlockToUpdate(self.data.uuid)
end

function EndTickButton.client_updateTexture(self)
    if self.interactable.active then
        self.interactable:setPoseWeight(0, 1)
    else
        self.interactable:setPoseWeight(0, 0)
    end
end
