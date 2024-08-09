dofile "../util/util.lua"
dofile "BaseFastLogicBlock.lua"

FastLogicBlockInterface = table.deepCopyTo(BaseFastLogicBlock, (FastLogicBlockInterface or class()))
FastLogicBlockInterface.colorNormal = sm.color.new(0x0fdf00ff)
FastLogicBlockInterface.colorHighlight = sm.color.new(0x07f500ff)
FastLogicBlockInterface.maxParentCount = -1 -- infinite
FastLogicBlockInterface.maxChildCount = -1  -- infinite

local modes = { "Address", "DataIn", "DataOut", "WriteData" }

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
    print(self.client_modeIndex)
    local wantedMode = indexToMode[self.client_modeIndex]
    for i = 1, #indexToMode do
        if self.client_modeIndex == i then
            print("set")
            self.gui:setButtonState(wantedMode, true)
            self.gui:setText("DescriptionText", descriptions[wantedMode])
        else
            self.gui:setButtonState(indexToMode[i], false)
        end
    end
end

function FastLogicBlockInterface.gui_selectButton(self, mode)
    self.client_modeIndex = modeToIndex[mode]
    self:gui_update()
    self.network:sendToServer("server_saveMode", self.client_modeIndex)
end

function FastLogicBlockInterface.client_onClientDataUpdate(self, mode)
    print("mode:", mode)
    self:client_updateTexture(nil, mode)
    print(self.client_modeIndex)
end

function FastLogicBlockInterface.client_updateTexture(self, state, mode)
    print("got:", mode)
    local doUpdate = false
    -- if state == nil then
    --     state = self.client_state
    -- elseif self.client_state ~= state then
    --     doUpdate = true
    -- end
    if mode == nil then
        mode = self.client_modeIndex
    else
        doUpdate = true
    end
    if doUpdate then
    -- self.client_state = state
        self.client_modeIndex = mode
    --     if state then
    --         self.interactable:setUvFrameIndex(6 + mode - 1)
    --     else
    --         self.interactable:setUvFrameIndex(0 + mode - 1)
    --     end
    end
end

function FastLogicBlockInterface.server_saveMode(self, mode)
    self.data.mode = mode
    self.network:setClientData(mode)
    self.storage:save(self.data)
    -- self.FastLogicAllBlockManager:changeBlockType(self.data.uuid, modes[mode])
end