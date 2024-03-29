print("loading EndTickButton")

dofile "BaseFastLogicBlock.lua"
dofile "../util/util.lua"

EndTickButton = table.deepCopyTo(BaseFastLogicBlock, (EndTickButton or class()))
EndTickButton.maxParentCount = -1 -- infinite
EndTickButton.maxChildCount = 0
EndTickButton.connectionInput = sm.interactable.connectionType.logic
EndTickButton.connectionOutput = nil
EndTickButton.poseWeightCount = 1

function EndTickButton.server_onCreate2(self)
    self.type = "EndTickButton"
    self.creation.EndTickButtons[self.id] = self
end

function EndTickButton.server_onDestroy2(self)
    self.creation.EndTickButtons[self.id] = nil
end

function EndTickButton.client_onCreate2(self)
end

function EndTickButton.client_onDestroy2(self)
end

function EndTickButton.client_onInteract(self, character, state)
    local id = self.FastLogicRunner.hashedLookUp[self.id]
    if state then
        self.FastLogicRunner.countOfOnInputs[id] = self.FastLogicRunner.countOfOnInputs[id] + 1
    else
        self.FastLogicRunner.countOfOnInputs[id] = self.FastLogicRunner.countOfOnInputs[id] - 1
    end
    self.FastLogicRunner:AddBlockToUpdate(id)
end

function EndTickButton.client_updateTexture(self)
    if self.interactable.active then
        self.interactable:setPoseWeight(0, 1)
    else
        self.interactable:setPoseWeight(0, 0)
    end
end
