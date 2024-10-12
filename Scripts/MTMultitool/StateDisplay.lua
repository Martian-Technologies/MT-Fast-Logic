StateDisplay = {}

function StateDisplay.inject(multitool)
    multitool.StateDisplay = {}
    local self = multitool.StateDisplay
    self.enabled = false
    StateDisplay.syncStorage(multitool)
end

function StateDisplay.syncStorage(multitool)
    local self = multitool.StateDisplay
    local saveData = SaveFile.getSaveData(multitool.saveIdx)
    if saveData["config"].stateDisplay == nil then
        saveData["config"].stateDisplay = {
            enabled = false
        }
    end
    self.enabled = saveData["config"].stateDisplay.enabled
end

function StateDisplay.toggle(multitool)
    local self = multitool.StateDisplay
    self.enabled = not self.enabled
    local saveData = SaveFile.getSaveData(multitool.saveIdx)
    if saveData["config"].stateDisplay == nil then
        saveData["config"].stateDisplay = {
            enabled = false
        }
    else
        saveData["config"].stateDisplay.enabled = self.enabled
    end
    SaveFile.setSaveData(multitool.saveIdx, saveData)
end

local stateOnlyUUIDs = {
    "6a9dbff5-7562-4e9a-99ae-3590ece88087", -- all fast logic gates
    "6a9dbff5-7562-4e9a-99ae-3590ece88088",
    "6a9dbff5-7562-4e9a-99ae-3590ece88089",
    "6a9dbff5-7562-4e9a-99ae-3590ece88090",
    "6a9dbff5-7562-4e9a-99ae-3590ece88091",
    "6a9dbff5-7562-4e9a-99ae-3590ece88092",
    "6a9dbff5-7562-4e9a-99ae-3590ece88093",
    "6a9dbff5-7562-4e9a-99ae-3590ece88094",
    "6a9dbff5-7562-4e9a-99ae-3590ece88095",
    "6a9dbff5-7562-4e9a-99ae-3590ece88096",
    "6a9dbff5-7562-4e9a-99ae-3590ece88097",
    "6a9dbff5-7562-4e9a-99ae-3590ece88098",
    "6a9dbff5-7562-4e9a-99ae-3590ece88099",
    "6a9dbff5-7562-4e9a-99ae-3590ece88100",
    "6a9dbff5-7562-4e9a-99ae-3590ece88101",
    "6a9dbff5-7562-4e9a-99ae-3590ece88102",
    "6a9dbff5-7562-4e9a-99ae-3590ece88103",
    "6a9dbff5-7562-4e9a-99ae-3590ece88104",
    "6a9dbff5-7562-4e9a-99ae-3590ece88105",
    "6a9dbff5-7562-4e9a-99ae-3590ece88106",
    "6a9dbff5-7562-4e9a-99ae-3590ece88107",
    "6a9dbff5-7562-4e9a-99ae-3590ece88108",
    "6a9dbff5-7562-4e9a-99ae-3590ece88109",
    "6a9dbff5-7562-4e9a-99ae-3590ece88110",
    "6a9dbff5-7562-4e9a-99ae-3590ece88111",
    "6a9dbff5-7562-4e9a-99ae-3590ece88112",
    "6a9dbff5-7562-4e9a-99ae-3590ece88113",
    "6a9dbff5-7562-4e9a-99ae-3590ece88114",
    "6a9dbff5-7562-4e9a-99ae-3590ece88115",
    "6a9dbff5-7562-4e9a-99ae-3590ece88116",
    "6a9dbff5-7562-4e9a-99ae-3590ece88117",
    "6a9dbff5-7562-4e9a-99ae-3590ece88118",
    "6a9dbff5-7562-4e9a-99ae-3590ece88119",
    "6a9dbff5-7562-4e9a-99ae-3590ece88120",
    "6a9dbff5-7562-4e9a-99ae-3590ece88121",
    "6a9dbff5-7562-4e9a-99ae-3590ece88122",
    "6a9dbff5-7562-4e9a-99ae-3590ece88123",
    "6a9dbff5-7562-4e9a-99ae-3590ece88124",
    "6a9dbff5-7562-4e9a-99ae-3590ece88125",
    "6a9dbff5-7562-4e9a-99ae-3590ece88126",
    "db0bc11b-c083-4a6a-843f-73ac1033e6fe", -- fast timer
    "9f0f56e8-2c31-4d83-996c-d00a9b296c3f", -- vanilla gate
    "8f7fd0e7-c46e-4944-a414-7ce2437bb30f", -- vanilla timer
    "ce73327a-1cf9-49cc-9ee7-e63110ccc43f", -- interface block
    "1e8d93a4-506b-470d-9ada-9c0a321e2db5", -- button
    "7cf717d7-d167-4f2d-a6e7-6b2c70aa3986", -- switch
    "161786c1-1290-4817-8f8b-7f80de755a06", -- totebot heads
    "4c6e27a2-4c35-4df3-9794-5e206fef9012",
    "a052e116-f273-4d73-872c-924a97b86720",
    "1c04327f-1de4-4b06-92a8-2c9b40e491aa",
}

local noDisplayUUIDs = {
    "1d4f99c0-1df8-4acb-9fd4-f3437062016c" -- memory block
}

function StateDisplay.client_onUpdate(multitool)
    local self = multitool.StateDisplay
    if not self.enabled then return end
    
    local toolsThatDisplayStates = {
        "8c7efc37-cd7c-4262-976e-39585f8527bf"
    }
    local raycastType = "DDA"
    if MTMultitool.internalModes[multitool.mode] ~= "Settings" then
        table.insert(toolsThatDisplayStates, "018e4ca0-c5be-7f80-a80f-259c5951594b")
    end
    local holdingItem = tostring(sm.localPlayer.getActiveItem())
    local doRaycast = true
    if not table.contains(toolsThatDisplayStates, holdingItem) then
        doRaycast = false
        if self.hideOnPanAway then
            self.updateNametags(nil)
        end
        if self.lastLookAt == nil then
            return
        end
    end
    if holdingItem == "8c7efc37-cd7c-4262-976e-39585f8527bf" then
        raycastType = "closestDot"
    end
    local hit = false
    local res = nil
    if doRaycast then
        local rayOrigin = sm.camera.getPosition()
        local rayDirection = sm.camera.getDirection()
        if raycastType == "DDA" then
            hit, res = ConnectionRaycaster:rayTraceDDA(rayOrigin, rayDirection, nil, 5)
        elseif raycastType == "closestDot" then
            hit, res = ConnectionRaycaster:rayTraceClosestDot(rayOrigin, rayDirection, nil, 5)
        end
    end
    if hit then
        local shape = nil
        if hit then
            shape = res.getShape()
        end
        if shape == nil then
            return
        end
        local interactable = shape:getInteractable()
        if interactable == nil then
            return
        end
        local uuid = tostring(shape:getShapeUuid())
        local state = interactable:isActive()
        local power = interactable:getPower()
        local stateText = ""
        local ignorePower = table.contains(noDisplayUUIDs, uuid) or table.contains(stateOnlyUUIDs, uuid)
        local ignoreState = table.contains(noDisplayUUIDs, uuid)
        if ignorePower then
            power = nil
        end
        if ignoreState then
            state = nil
        end
        if state == nil and power == nil then
            return
        end
        if state ~= nil then
            stateText = stateText .. "State: " .. (state and "True" or "False") .. "\n"
        end
        if power ~= nil then
            stateText = stateText .. "Power: " .. power
        end
        sm.gui.displayAlertText(stateText, 1)
    end
end