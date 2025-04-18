dofile "../util/util.lua"
local string = string
local table = table

dofile "BaseFastLogicBlock.lua"

FastLogicGate = table.deepCopyTo(BaseFastLogicBlock, (FastLogicGate or {}))

local modes = { "andBlocks", "orBlocks", "xorBlocks", "nandBlocks", "norBlocks", "xnorBlocks" }

local indexToMode = { "And", "Or", "Xor", "Nand", "Nor", "Xnor" }

local modeToLampPattern = {
    ["And"] = { false, false, true },
    ["Or"] = { false, true, true },
    ["Xor"] = { false, true, false },
    ["Nand"] = { true, true, false },
    ["Nor"] = { true, false, false },
    ["Xnor"] = { true, false, true }
}

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

function FastLogicGate.client_checkSelfwired(self)
    local parents = self.interactable:getParents()
    for k, v in pairs(parents) do
        if v == self.interactable then
            return true
        end
    end
    return false
end

function FastLogicGate.getData2(self)
    self.creation.FastLogicGates[self.data.uuid] = self
end

function FastLogicGate.server_onCreate2(self)
    self.type = "LogicGate"
    self.network:setClientData(self.data.mode + 1)
    self:server_saveDataToStorage()
end

function FastLogicGate:server_loadData()
    local storageData = self.storage:load()
    if storageData == nil then
        self.data.mode = self.data.mode or 0
        return
    end
    if type(storageData) == "table" then
        self.data = storageData
        self.data.mode = self.data.mode or (self.data.mode or 0)
    elseif type(storageData) == "string" then
        -- check if the string starts with a comma, if so assume no uuid
        if string.sub(storageData, 1, 1) == "," then
            self.data.uuid = nil
            self.data.mode = tonumber(string.sub(storageData, 2)) or 0
        else
            local splitData = string.split(storageData, ",")
            self.data.uuid = tonumber(splitData[1])
            self.data.mode = tonumber(splitData[2])
        end
    else
        self.data.mode = self.data.mode or 0
    end
end

function FastLogicGate:server_saveDataToStorage()
    if self.data.uuid == nil then
        self.storage:save("," .. (self.data.mode or 0))
    else
        self.storage:save(self.data.uuid .. "," .. (self.data.mode or 0))
    end
    -- self.storage:save("," .. (self.data.mode or 0))
    -- self.storage:save(self.data)
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

function FastLogicGate.gui_selfwire(self)
    print("selfwiring")
    self.network:sendToServer("server_selfwire")
    self.gui:setVisible("UnselfwireButton", true)
    self.gui:setVisible("SelfwireButton", false)
end

function FastLogicGate.gui_unselfwire(self)
    print("unselfwiring")
    self.network:sendToServer("server_unselfwire")
    self.gui:setVisible("UnselfwireButton", false)
    self.gui:setVisible("SelfwireButton", true)
end

function FastLogicGate.server_selfwire(self)
    self.interactable:connect(self.interactable)
end

function FastLogicGate.server_unselfwire(self)
    self.interactable:disconnect(self.interactable)
end

function FastLogicGate.gui_createNewGui(self)
    if self.gui == nil then
        self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Interactable_FastLogicGate.layout")
        for i = 1, #indexToMode do
            self.gui:setButtonCallback(indexToMode[i], "gui_selectButton")
        end
        self.gui:setButtonCallback("SelfwireButton", "gui_selfwire")
        self.gui:setButtonCallback("UnselfwireButton", "gui_unselfwire")
    end
end

function FastLogicGate.gui_update(self)
    local wantedMode = indexToMode[self.client_modeIndex]
    local lampPattern = modeToLampPattern[wantedMode]
    self.gui:setVisible("Lamp00on", lampPattern[1])
    self.gui:setVisible("Lamp01on", lampPattern[2])
    self.gui:setVisible("Lamp11on", lampPattern[3])
    local selfwired = self:client_checkSelfwired()
    self.gui:setVisible("UnselfwireButton", selfwired)
    self.gui:setVisible("SelfwireButton", not selfwired)
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
    self:server_saveDataToStorage()
    self.FastLogicAllBlockManager:changeBlockType(self.data.uuid, modes[mode])
end

-- in this class rn because it only works for Logic Gates
function FastLogicGate.client_onMelee(self, position, attacker, damage, power, direction, normal)
    if sm.MTFastLogic.doMeleeState then
        self.network:sendToServer("server_changeBlockState")
    end
end
