ConnectionShower = {}

function ConnectionShower.inject(multitool)
    multitool.ConnectionShower = {}
    local self = multitool.ConnectionShower
    self.enabled = false
    self.hideOnPanAway = true
    ConnectionShower.syncStorage(multitool)
    self.updateNametags = NametagManager.createController(multitool)
end

function ConnectionShower.syncStorage(multitool)
    local self = multitool.ConnectionShower
    local saveData = SaveFile.getSaveData(multitool.saveIdx)
    if saveData["config"].connectionShower == nil then
        saveData["config"].connectionShower = {
            enabled = false,
            hideOnPanAway = true
        }
    end
    self.enabled = saveData["config"].connectionShower.enabled
    self.hideOnPanAway = saveData["config"].connectionShower.hideOnPanAway
end

function ConnectionShower.toggle(multitool)
    local self = multitool.ConnectionShower
    self.enabled = not self.enabled
    if not self.enabled then
        self.updateNametags(nil)
    end
    local saveData = SaveFile.getSaveData(multitool.saveIdx)
    if saveData["config"].connectionShower == nil then
        saveData["config"].connectionShower = {
            enabled = self.enabled,
            hideOnPanAway = self.hideOnPanAway
        }
    else
        saveData["config"].connectionShower.enabled = self.enabled
    end
    saveData["config"].connectionShowerToggled = self.enabled
    SaveFile.setSaveData(multitool.saveIdx, saveData)
end

function ConnectionShower.toggleHideOnPanAway(multitool)
    local self = multitool.ConnectionShower
    self.hideOnPanAway = not self.hideOnPanAway
    if self.hideOnPanAway then
        self.updateNametags(nil)
    end
    local saveData = SaveFile.getSaveData(multitool.saveIdx)
    if saveData["config"].connectionShower == nil then
        saveData["config"].connectionShower = {
            enabled = self.enabled,
            hideOnPanAway = self.hideOnPanAway
        }
    else
        saveData["config"].connectionShower.hideOnPanAway = self.hideOnPanAway
    end
    saveData["config"].connectionShower.hideOnPanAway = self.hideOnPanAway
    SaveFile.setSaveData(multitool.saveIdx, saveData)
end

function ConnectionShower.client_onUpdate(multitool)
    local self = multitool.ConnectionShower
    if not self.enabled then
        self.updateNametags(nil)
        return
    end
    local toolsThatDisplayConnections = {
        "8c7efc37-cd7c-4262-976e-39585f8527bf"
    }
    print(MTMultitool.internalModes[multitool.mode])
    if MTMultitool.internalModes[multitool.mode] ~= "Settings" then
        table.insert(toolsThatDisplayConnections, "018e4ca0-c5be-7f80-a80f-259c5951594b")
    end
    local toolsThatDisplayUI = {
        "8c7efc37-cd7c-4262-976e-39585f8527bf"
    }
    local holdingItem = tostring(sm.localPlayer.getActiveItem())
    if not table.contains(toolsThatDisplayConnections, holdingItem) then
        if self.hideOnPanAway then
            self.updateNametags(nil)
        end
        return
    end
    local displayUI = table.contains(toolsThatDisplayUI, holdingItem)
    local rayOrigin = sm.camera.getPosition()
    local rayDirection = sm.camera.getDirection()
    local hit, res = ConnectionRaycaster:rayTraceDDA(rayOrigin, rayDirection, nil, 5)
    if hit then
        local shape = res.getShape()
        if shape == nil then
            if self.hideOnPanAway then
                self.updateNametags(nil)
            end
            return
        end
        local interactable = shape:getInteractable()
        if interactable == nil then
            if self.hideOnPanAway then
                self.updateNametags(nil)
            end
            return
        end
        local inputConnections = interactable:getParents()
        local outputConnections = interactable:getChildren()
        local nametags = {}
        for _, connection in pairs(inputConnections) do
            local nametag = {
                txt = "IN",
                color = sm.color.new(0, 1, 0, 1),
                pos = connection:getShape():getWorldPosition()
            }
            table.insert(nametags, nametag)
        end
        for _, connection in pairs(outputConnections) do
            local nametag = {
                txt = "OUT",
                color = sm.color.new(1, 0, 0, 1),
                pos = connection:getShape():getWorldPosition()
            }
            table.insert(nametags, nametag)
        end
        table.insert(nametags, {
            txt = "X",
            color = sm.color.new(1, 1, 1, 1),
            pos = interactable:getShape():getWorldPosition()
        })
        self.updateNametags(nametags)
        if displayUI then
            sm.gui.setInteractionText("", "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>INPUTS: " ..
            #inputConnections .. "</p>")
            sm.gui.setInteractionText("", "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>OUTPUTS: " ..
            #outputConnections .. "</p>")
        end
    else
        if self.hideOnPanAway then
            self.updateNametags(nil)
        end
    end
end