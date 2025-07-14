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

function EndTickButton.client_onDestroy2(self)
end

function EndTickButton.client_onInteract(self, character, state)
    local success, result = pcall(self.pcalled_client_onInteract, self, character, state)
    if not success then
        self:client_sendMessage("AN ERROR OCCURRED IN FAST LOGIC (id: 5). Please report to ItchyTrack on discord")
        self:client_sendMessage(result)
    end
end

function EndTickButton.pcalled_client_onInteract(self, character, state)
    self:client_sendMessage("Sorry, the end tick button has to be activated by logic. Just connect a regular button to it and press that.")
    -- self.FastLogicRunner:externalChangeNonFastOnInput(sewlf.data.uuid, state and 1 or -1)
    -- self.FastLogicRunner:externalAddBlockToUpdate(self.data.uuid)
end

function EndTickButton.client_onCreate2(self)
    self.client_state = self.client_state or false
end

function EndTickButton.client_updateTexture(self, state)
    if state == nil then
        state = self.client_state or false
    end
    if self.client_state ~= state then
        self.client_state = state
        if state then
            self.interactable:setPoseWeight(0, 1)

        else
            self.interactable:setPoseWeight(0, 0)

        end
    end
end
