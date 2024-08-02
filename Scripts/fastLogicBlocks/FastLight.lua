dofile "../util/util.lua"
local string = string
local table = table

dofile "BaseFastLogicBlock.lua"

FastLight = table.deepCopyTo(BaseFastLogicBlock, (FastLight or class()))
FastLight.maxParentCount = 1
FastLight.maxChildCount = 0
FastLight.connectionInput = sm.interactable.connectionType.logic
FastLight.connectionOutput = nil
FastLight.poseWeightCount = 1

function FastLight.getData2(self)
    self.creation.FastLights[self.data.uuid] = self
end

function FastLight.server_onCreate2(self)
    self.type = "Light"
    if self.storage:load() ~= nil then
        self.data.luminance = self.storage:load().luminance or (self.data.luminance or 50)
    else
        self.data.luminance = self.data.luminance or 50
    end
    self:server_saveLuminance(self.data.luminance)
    -- self.network:setClientData(self.data)
end

function FastLight.server_onDestroy2(self)
    self.creation.FastLights[self.data.uuid] = nil
end

function FastLight.client_onCreate2(self)
    self.client_state = self.client_state or false
    self.client_luminance = self.client_luminance or 10
end

function FastLight.client_onDestroy2(self)
    if self.gui then
        self.gui:destroy()
    end
end


function FastLight.client_onInteract(self, character, state)
    if state then
        self:gui_createNewGui()
        self.gui:open()
    end
end

function FastLight.gui_createNewGui(self)
    if self.gui == nil then
        self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Interactable_FastLight.layout")
        self.gui:createVerticalSlider("Luminance", 41, self.client_luminance, "gui_changedSlider")
        self:gui_update()
    end
end

function FastLight.gui_changedSlider(self, pos)
    self.client_ticks = pos
    self:gui_update()
    self.network:sendToServer("server_saveTime", { ticks = self.client_ticks, seconds = self.client_seconds })
end

function FastLight.gui_update(self)
    self.gui:setSliderPosition("Luminance", self.client_luminance)
end


function FastLight.client_onClientDataUpdate(self, data)
    self.client_luminance = data.luminance
    self:client_updateTexture()
end

function FastLight.client_updateTexture(self, state)
    if state == nil then
        state = self.client_state or false
    end
    if self.client_state ~= state then
        self.client_state = state
        if state then
            self.interactable:setUvFrameIndex(6 + mode)
        else
            self.interactable:setUvFrameIndex(0 + mode)
        end
    end
end

function FastLight.server_saveLuminance(self, luminance)
    self.data.luminance = luminance
    self.network:setClientData(self.data)
    self.storage:save(self.data)
end
