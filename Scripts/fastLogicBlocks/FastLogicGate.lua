dofile "../util/util.lua"
local string = string
local table = table

dofile "BaseFastLogicBlock.lua"

FastLogicGate = table.deepCopyTo(BaseFastLogicBlock, (FastLogicGate or {}))

function FastLogicGate.getData2(self)
    self.creation.FastLogicGates[self.data.uuid] = self
end

function FastLogicGate.server_onCreate2(self)
    self.type = "LogicGate"
    if self.storage:load() ~= nil then
        self.data.mode = self.storage:load().mode or (self.data.mode or 0)
    else
        self.data.mode = self.data.mode or 0
    end
    self.network:setClientData(self.data.mode)
    self.storage:save(self.data)
end

function FastLogicGate.server_onDestroy2(self)
    self.creation.FastLogicGates[self.data.uuid] = nil
end

function FastLogicGate.client_onCreate2(self)
    self.client_mode = self.client_mode
    self.client_state = self.client_state
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

function FastLogicGate.client_onClientDataUpdate(self, mode)
    self:client_updateTexture(nil, mode)
end

function FastLogicGate.client_updateTexture(self, state, mode)
    if state == nil then
        state = self.client_state or false
    end
    if mode == nil then
        mode = self.client_mode or 0
    end
    if self.client_state ~= state or client_mode ~= mode then
        self.client_state = state
        self.client_mode = mode
        if state then
            self.interactable:setUvFrameIndex(6 + mode)
        else
            self.interactable:setUvFrameIndex(0 + mode)
        end
    end
end

function FastLogicGate.server_saveMode(self, mode)
    self.data.mode = mode
    self.network:setClientData(self.data.mode)
    self.storage:save(self.data)
    local modes = { "andBlocks", "orBlocks", "xorBlocks", "nandBlocks", "norBlocks", "xnorBlocks" }
    self.FastLogicAllBlockManager:changeBlockType(self.data.uuid, modes[self.data.mode + 1])
end

-- in this class rn because it only works for Logic Gates
function FastLogicGate.client_onMelee(self, position, attacker, damage, power, direction, normal)
    if sm.MTFastLogic.doMeleeState then
        self.network:sendToServer("server_changeBlockState")
    end
end