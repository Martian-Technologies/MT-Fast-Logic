dofile "../util/util.lua"
local string = string
local table = table

dofile "BaseFastLogicBlock.lua"

FastLogicGate = table.deepCopyTo(BaseFastLogicBlock, (FastLogicGate or {}))

local modes = { "andBlocks", "orBlocks", "xorBlocks", "nandBlocks", "norBlocks", "xnorBlocks" }

local indexToMode = { "And", "Or", "Xor", "Nand", "Nor", "Xnor" }

local modeToIndex = {
    ["And"] = 1,
    ["Or"] = 2,
    ["Xor"] = 3,
    ["Nand"] = 4,
    ["Nor"] = 5,
    ["Xnor"] = 6
}

local descriptions = {
    ["And"] = "Active if all of the linked triggers are active",
    ["Or"] = "Active if any of the linked triggers are active",
    ["Xor"] = "Active if an odd number of linked triggers are active",
    ["Nand"] = "Active if any of the linked triggers are inactive",
    ["Nor"] = "Active if all of the linked triggers are inactive",
    ["Xnor"] = "Active if an even number of linked triggers are active"
}

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
    self.network:setClientData(self.data.mode + 1)
    self.storage:save(self.data)
end

function FastLogicGate.server_onDestroy2(self)
    self.creation.FastLogicGates[self.data.uuid] = nil
end

function FastLogicGate.client_onCreate2(self)
    self.client_modeIndex = self.client_modeIndex or 1
    self.client_state = self.client_state or false
end

function FastLogicGate.client_onDestroy2(self)
    if self.gui then
        self.gui:destroy()
    end
end

function FastLogicGate.client_onInteract(self, character, state)
    if state then
        self:gui_createNewGui()
        self:gui_update()
        self.gui:open()
    end
end

function FastLogicGate.gui_createNewGui(self)
    if self.gui == nil then
        self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Interactable_FastLogicGate.layout")
        for i = 1, #indexToMode do
            self.gui:setButtonCallback(indexToMode[i], "gui_selectButton")
        end
    end
end

function FastLogicGate.gui_update(self)
    local wantedMode = indexToMode[self.client_modeIndex]
    for i = 1, #indexToMode do
        if self.client_modeIndex == i then
            self.gui:setButtonState(wantedMode, true)
            self.gui:setText("DescriptionText", descriptions[wantedMode])
        else
            self.gui:setButtonState(indexToMode[i], false)
        end
    end
end

function FastLogicGate.gui_selectButton(self, mode)
    self.client_modeIndex = modeToIndex[mode]
    self:gui_update()
    self.network:sendToServer("server_saveMode", self.client_modeIndex)
end

function FastLogicGate.client_onClientDataUpdate(self, mode)
    self:client_updateTexture(nil, mode)
end

function FastLogicGate.client_updateTexture(self, state, mode)
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

function FastLogicGate.server_saveMode(self, mode)
    self.data.mode = mode - 1
    self.network:setClientData(mode)
    self.storage:save(self.data)
    self.FastLogicAllBlockManager:changeBlockType(self.data.uuid, modes[mode])
end

-- in this class rn because it only works for Logic Gates
function FastLogicGate.client_onMelee(self, position, attacker, damage, power, direction, normal)
    if sm.MTFastLogic.doMeleeState then
        self.network:sendToServer("server_changeBlockState")
    end
end