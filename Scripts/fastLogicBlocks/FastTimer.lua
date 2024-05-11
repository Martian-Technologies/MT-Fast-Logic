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
    self.guidata = {}
    self.guidata.seconds = 0
    self.guidata.ticks = 0
end

function FastTimer.client_onDestroy2(self)
    if self.gui then
        self.gui:destroy()
    end
end

function FastTimer.gui_init(self)
    if self.gui == nil then
        self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Interactable_FastTimer.layout")
        self.gui:createVerticalSlider("TickSlider", 41, 0, "gui_tickSlider")
        self.gui:createVerticalSlider("SecondSlider", 60, 0, "gui_secondSlider")
        self.gui:setSliderPosition("TickSlider", self.guidata.ticks)
        self.gui:setSliderPosition("SecondSlider", self.guidata.seconds)
        self:gui_update()
    end
end

function FastTimer.gui_tickSlider(self, pos)
    self.guidata.ticks = pos
    self:gui_update()
    self.network:sendToServer("server_saveTime", { ticks = self.guidata.ticks, seconds = self.guidata.seconds })
end

function FastTimer.gui_secondSlider(self, pos)
    self.guidata.seconds = pos
    self:gui_update()
    self.network:sendToServer("server_saveTime", { ticks = self.guidata.ticks, seconds = self.guidata.seconds })
end

function FastTimer.gui_update(self)
    local seconds = self.guidata.seconds
    local ticks = self.guidata.ticks / 40
    if self.guidata.ticks == 40 then
        seconds = seconds + 1
        ticks = 0
    end
    ticks = ticks * 1000
    local totalticks = self.guidata.seconds * 40 + self.guidata.ticks
    self.gui:setText("SecondsText", string.format("%02d", seconds))
    self.gui:setText("MillisecondsText", string.format("%03d", ticks))
    self.gui:setText("TicksText", tostring(totalticks) .. " TICKS")
end

function FastTimer.client_onInteract(self, character, state)
    if state then
        self:gui_init()
        self:gui_update()
        self.gui:open()
    end
end

function FastTimer.client_onClientDataUpdate(self, data)
    self.guidata.seconds = data.seconds
    self.guidata.ticks = data.ticks

    if self.gui then
        self.gui:setSliderPosition("TickSlider", self.guidata.ticks)
        self.gui:setSliderPosition("SecondSlider", self.guidata.seconds)
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
    self.FastLogicRunner:externalChangeTimerTime(self.data.uuid, self.time)
end
