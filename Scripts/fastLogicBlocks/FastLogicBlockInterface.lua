dofile "../util/util.lua"
dofile "BaseFastLogicBlock.lua"

sm.interactable.connectionType.fastLogicInterface = math.pow(2, 27)

FastLogicBlockInterface = table.deepCopyTo(BaseFastLogicBlock, (FastLogicBlockInterface or class()))
FastLogicBlockInterface.colorNormal = sm.color.new(0x0fdf00ff)
FastLogicBlockInterface.colorHighlight = sm.color.new(0x07f500ff)
FastLogicBlockInterface.connectionOutput = (
    FastLogicBlockInterface.connectionOutput + sm.interactable.connectionType.fastLogicInterface
)
FastLogicBlockInterface.connectionInput = (
    FastLogicBlockInterface.connectionInput + sm.interactable.connectionType.fastLogicInterface
)


local modes = { "Address", "DataIn", "DataOut", "WriteData" }
local modeNames = { "Address", "Data In", "Data Out", "Write Data" }
local modeNamesForErrors = { "Address", "Data Out", "Data In", "Write Data" }

local indexToMode = { "Address", "DataIn", "DataOut", "WriteData" }

local modeToIndex = {
    ["Address"] = 1,
    ["DataIn"] = 2,
    ["DataOut"] = 3,
    ["WriteData"] = 4,
}

local descriptions = {
    ["Address"] = "1",
    ["DataIn"] = "2",
    ["DataOut"] = "3",
    ["WriteData"] = "4",
}

function FastLogicBlockInterface.getData2(self)
    self.creation.FastLogicBlockInterfaces[self.data.uuid] = self
end

function FastLogicBlockInterface.server_onCreate2(self)
    self.type = "Interface"
    self.error = self.error or "none"
    if self.storage:load() ~= nil then
        self.data.mode = self.storage:load().mode or (self.data.mode or 1)
    else
        self.data.mode = self.data.mode or 1
    end
    self.network:setClientData(self.data.mode)
    self.storage:save(self.data)
end

function FastLogicBlockInterface.server_onDestroy2(self)
    self.creation.FastLogicBlockInterfaces[self.data.uuid] = nil
end

function FastLogicBlockInterface.client_onCreate2(self)
    self.client_modeIndex = self.client_modeIndex or 1
    self.client_state = self.client_state or false
end

function FastLogicBlockInterface.client_onDestroy2(self)
    if self.gui then
        self.gui:destroy()
    end
end

function FastLogicBlockInterface.client_onInteract(self, character, state)
    if state then
        self:gui_createNewGui()
        self:gui_update()
        self.gui:open()
    end
end

function FastLogicBlockInterface.gui_createNewGui(self)
    if self.gui == nil then
        self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Interactable_FastInterface.layout")
        for i = 1, #indexToMode do
            self.gui:setButtonCallback(indexToMode[i], "gui_selectButton")
        end
    end
end

function FastLogicBlockInterface.gui_update(self)
    local wantedMode = indexToMode[self.client_modeIndex]
    for i = 1, #indexToMode do
        if self.client_modeIndex == i then
            self.gui:setButtonState(wantedMode, true)
        else
            self.gui:setButtonState(indexToMode[i], false)
        end
    end
    self.gui:setText("DescriptionText", "")
    self.network:sendToServer("sever_getError")
end

function FastLogicBlockInterface.makeErrorMessage(self)
    if self.error == nil then return "Valid Interface" end
    if self.error == "none" then return "No Interface Found" end
    local type = self.error[1]
    local stage = self.error[2]
    if type == 1 then
        return "Address has to many outputs. Max 1"
    elseif type == 2 then
        return modeNamesForErrors[stage] .. " can't output to Address"
    elseif type == 3 then
        return "Data In has to many outputs. Max 1"
    elseif type == 4 then
        return modeNamesForErrors[stage] .. " can't output to Data Out"
    elseif type == 5 then
        return "Write Data has to many outputs. Max 1"
    elseif type == 6 then
        return modeNamesForErrors[stage] .. " can't output to Write Data"
    elseif type == 7 then
        return "ERROR: Interface code never stopped looping! Report to ItchyTrack"
    elseif type == 8 then
        return "Interface can't end with " .. modes[stage]
    elseif type == 9 then
        return "Invalid interface"
    else
        return "Unknow error??"
    end
end

function FastLogicBlockInterface.sever_getError(self)
    self.network:sendToClients("client_setError", self:makeErrorMessage())
end

function FastLogicBlockInterface.client_setError(self, error)
    if self.gui == nil then return end
    self.gui:setText("DescriptionText", error)
end

function FastLogicBlockInterface.gui_selectButton(self, mode)
    self.client_modeIndex = modeToIndex[mode]
    self.network:sendToServer("server_saveMode", self.client_modeIndex)
    self:gui_update()
end

function FastLogicBlockInterface.client_onClientDataUpdate(self, mode)
    self:client_updateTexture(nil, mode)
end

function FastLogicBlockInterface.client_updateTexture(self, state, mode)
    local doUpdate = false
    if state == nil then
        state = self.client_state
    elseif self.client_state ~= state then
        doUpdate = true
    end
    if mode == nil then
        mode = self.client_modeIndex
    else
        doUpdate = true
    end
    if doUpdate then
        self.client_state = state
        self.client_modeIndex = mode
        if state then
            self.interactable:setUvFrameIndex(6 + mode - 1)
        else
            self.interactable:setUvFrameIndex(0 + mode - 1)
        end
    end
    -- local doUpdate = false
    -- -- if state == nil then
    -- --     state = self.client_state
    -- -- elseif self.client_state ~= state then
    -- --     doUpdate = true
    -- -- end
    -- if mode == nil then
    --     mode = self.client_modeIndex
    -- else
    --     doUpdate = true
    -- end
    -- if doUpdate then
    -- -- self.client_state = state
    --     self.client_modeIndex = mode
    -- --     if state then
    -- --         self.interactable:setUvFrameIndex(6 + mode - 1)
    -- --     else
    -- --         self.interactable:setUvFrameIndex(0 + mode - 1)
    -- --     end
    -- end
end

function FastLogicBlockInterface.server_saveMode(self, mode)
    self.data.mode = mode
    self.network:setClientData(mode)
    self.storage:save(self.data)
    self.error = "none"
    self.FastLogicAllBlockManager:changeBlockType(self.data.uuid, modes[mode])
end