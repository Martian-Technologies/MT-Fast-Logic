print("loading FastLogicGate")

dofile "BaseFastLogicBlock.lua"
dofile "../util/util.lua"

FastLogicGate = table.deepCopyTo(BaseFastLogicBlock, (FastLogicGate or class()))

function FastLogicGate.server_onCreate2(self)
    self.type = "LogicGate"
    self.creation.FastLogicGates[self.id] = self
    self.data = {}
    if self.storage:load() ~= nil then
        self.data.mode = self.storage:load().mode or 0
    else
        self.data.mode = 0
    end
    self.network:setClientData({ mode = self.data.mode })
    self.storage:save({ mode = self.data.mode })
end

function FastLogicGate.server_onDestroy2(self)
    self.creation.FastLogicGates[self.id] = nil
end

function FastLogicGate.client_onCreate2(self)
    if self.client_mode == nil then
        self.client_mode = 0
    end
end

function FastLogicGate.client_onDestroy2(self)
    if self.gui then
        self.gui:destroy()
    end
end

function FastLogicGate.gui_init(self)
    if self.gui == nil then
        self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Interactable_FastLogicGate.layout")
        self.guimodes = {
            { name = "And",  description = "Active if all of the linked triggers are active" },
            { name = "Or",   description = "Active if any of the linked triggers are active" },
            { name = "Xor",  description = "Active if an odd number of linked triggers are active" },
            { name = "Nand", description = "Active if any of the linked triggers are inactive" },
            { name = "Nor",  description = "Active if all of the linked triggers are inactive" },
            { name = "Xnor", description = "Active if an even number of linked triggers are active" }
        }
        local btnNames = { "And", "Or", "Xor", "Nand", "Nor", "Xnor" }
        for _, btnName in pairs(btnNames) do
            self.gui:setButtonCallback(btnName, "gui_buttonCallback")
        end
    end
end

function FastLogicGate.gui_buttonCallback(self, btnName)
    for i = 1, #self.guimodes do
        local name = self.guimodes[i].name
        self.gui:setButtonState(name, name == btnName)
        if name == btnName then
            self.client_mode = i - 1
            self.gui:setText("DescriptionText", self.guimodes[i].description)
        end
    end
    self.network:sendToServer("server_saveMode", self.client_mode)
end

function FastLogicGate.client_onInteract(self, character, state)
    if state then
        self:gui_init()
        local btnNames = { "And", "Or", "Xor", "Nand", "Nor", "Xnor" }
        self:gui_buttonCallback(btnNames[self.client_mode + 1])
        self.gui:open()
    end
end

function FastLogicGate.client_onClientDataUpdate(self, data)
    self.client_mode = data.mode
    self:client_updateTexture()
end

function FastLogicGate.client_updateTexture(self)
    if self.interactable.active then
        self.interactable:setUvFrameIndex(6 + self.client_mode)
    else
        self.interactable:setUvFrameIndex(0 + self.client_mode)
    end
end

function FastLogicGate.server_saveMode(self, mode)
    if mode ~= self.data.mode then
        self.data.mode = mode
        self.network:setClientData({ mode = self.data.mode })
        self.storage:save({ mode = self.data.mode })
        self:rescanSelf()
    end
end
