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
local modeNameIdsForErrors = { "mt.interface.mode.address", "mt.interface.mode.data_out", "mt.interface.mode.data_in", "mt.interface.mode.write_data" }

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
    self.gui:setText("TitleText", trNative("mt.interface.title"))
    self.gui:setText("Address", trNative("mt.interface.button.address"))
    self.gui:setText("DataIn", trNative("mt.interface.button.data_in"))
    self.gui:setText("DataOut", trNative("mt.interface.button.data_out"))
    self.gui:setText("WriteData", trNative("mt.interface.button.write_data"))
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
    if self.error == nil then return { id = "mt.interface.valid" } end
    if self.error == "none" then return { id = "mt.interface.no_interface" } end
    local type = self.error[1]
    local stage = self.error[2]
    local vars = { modeId = modeNameIdsForErrors[stage] }
    if type == 1 then
        return { id = "mt.interface.error.address_too_many_outputs" }
    elseif type == 2 then
        return { id = "mt.interface.error.cant_output_to_address", vars = vars }
    elseif type == 3 then
        return { id = "mt.interface.error.data_in_too_many_outputs" }
    elseif type == 4 then
        return { id = "mt.interface.error.cant_output_to_data_out", vars = vars }
    elseif type == 5 then
        return { id = "mt.interface.error.write_data_too_many_outputs" }
    elseif type == 6 then
        return { id = "mt.interface.error.cant_output_to_write_data", vars = vars }
    elseif type == 7 then
        return { id = "mt.interface.error.loop" }
    elseif type == 8 then
        return { id = "mt.interface.error.cant_end_with", vars = vars }
    elseif type == 9 then
        return { id = "mt.interface.error.invalid" }
    elseif type == 10 then
        return { id = "mt.interface.error.cant_end_without_write_data", vars = vars }
    elseif type == 11 then
        return { id = "mt.interface.error.cant_end_without_data_in", vars = vars }
    elseif type == 12 then
        return { id = "mt.interface.error.data_out_too_many_inputs" }
    else
        return { id = "mt.interface.error.unknown" }
    end
end

function FastLogicBlockInterface.sever_getError(self)
    self.network:sendToClients("client_setError", self:makeErrorMessage())
end

function FastLogicBlockInterface.client_setError(self, error)
    if self.gui == nil then return end
    if type(error) == "table" and error.id ~= nil then
        local vars = error.vars
        if vars ~= nil and vars.modeId ~= nil then
            vars.mode = trNative(vars.modeId)
        end
        error = trNative(error.id, vars)
    end
    self.gui:setText("DescriptionText", error)
end

function FastLogicBlockInterface.gui_selectButton(self, mode)
    self.client_modeIndex = modeToIndex[mode]
    self.network:sendToServer("server_saveMode", self.client_modeIndex)
    self:gui_update()
end

function FastLogicBlockInterface.client_onClientDataUpdate(self, mode)
    self:client_updateTexture(nil, mode)
    if self.gui ~= nil then
        self:gui_update()
    end
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
end

function FastLogicBlockInterface.server_saveMode(self, mode)
    self.data.mode = mode
    self.network:setClientData(mode)
    self.storage:save(self.data)
    self.error = "none"
    self.FastLogicAllBlockManager:changeBlockType(self.data.uuid, modes[mode])
end