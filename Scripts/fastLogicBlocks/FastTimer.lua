dofile "BaseFastLogicBlock.lua"
dofile "../util/util.lua"

FastTimer = table.deepCopyTo(BaseFastLogicBlock, (FastTimer or class()))
FastTimer.maxParentCount = 1 -- infinite
FastTimer.maxChildCount = -1  -- infinite

function FastTimer.getData2(self)
    self.creation.FastTimers[self.data.uuid] = self
end

function FastTimer.server_onCreate2(self)
    self.type = "Timer"
    if self.storage:load() ~= nil then
        local data = self.storage:load()
        self.data.ticks = data.ticks or 0
        self.data.seconds = data.seconds or 0
        self.time = self.data.ticks + self.data.seconds * 40
    else
        self.data.ticks = 0
        self.data.seconds = 0
        self.time = 0
    end
    self.network:setClientData({ticks = self.data.ticks, seconds = self.data.seconds})
    self.storage:save(self.data)
end

function FastTimer.server_onDestroy2(self)
    self.creation.FastTimers[self.data.uuid] = nil
end

function FastTimer.client_onCreate2(self)
    self.client_seconds = 0
    self.client_ticks = 0
end

function FastTimer.client_onDestroy2(self)
    if self.gui then
        self.gui:destroy()
    end
end

function FastTimer.client_onInteract(self, character, state)
    if state then
        self:gui_createNewGui()
        self.gui:open()
    end
end

function FastTimer.gui_createNewGui(self)
    if self.gui == nil then
        self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Interactable_FastTimer.layout")
        self.gui:createVerticalSlider("Ticks", 41, self.client_seconds, "gui_changedTickSlider")
        self.gui:createVerticalSlider("Seconds", 60, self.client_ticks, "gui_changedSecondSlider")
        self:gui_update()
    end
end

function FastTimer.gui_changedTickSlider(self, pos)
    self.client_ticks = pos
    self:gui_update()
    self.network:sendToServer("server_saveTime", { ticks = self.client_ticks, seconds = self.client_seconds })
end

function FastTimer.gui_changedSecondSlider(self, pos)
    self.client_seconds = pos
    self:gui_update()
    self.network:sendToServer("server_saveTime", { ticks = self.client_ticks, seconds = self.client_seconds })
end

function FastTimer.gui_update(self)
    self.gui:setText("SecondsText", string.format("%02d", self.client_seconds + (self.client_ticks == 40 and 1 or 0)))
    self.gui:setText("MillisecondsText", string.format("%03d", self.client_ticks*25))
    self.gui:setText("TicksText", tostring(self.client_seconds * 40 + self.client_ticks) .. " TICKS")
    self.gui:setSliderPosition("Ticks", self.client_ticks)
    self.gui:setSliderPosition("Seconds", self.client_seconds)
end

function FastTimer.client_onClientDataUpdate(self, data)
    self.client_seconds = data.seconds
    self.client_ticks = data.ticks
    if self.gui then
        self:gui_update()
    end
end

function FastTimer.client_updateTexture(self)
end

function FastTimer.server_saveTime(self, data)
    self.data.ticks = data.ticks
    self.data.seconds = data.seconds
    self.time = data.seconds * 40 + data.ticks
    self.network:setClientData({ticks = self.data.ticks, seconds = self.data.seconds})
    self.storage:save(self.data)
    self.FastLogicAllBlockManager:changeTimerTime(self.data.uuid, self.time)
end
