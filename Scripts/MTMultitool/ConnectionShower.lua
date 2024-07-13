ConnectionShower = {}

function ConnectionShower.inject(multitool)
    multitool.ConnectionShower = {}
    local self = multitool.ConnectionShower
    self.enabled = false
    self.hideOnPanAway = true
    ConnectionShower.syncStorage(multitool)
    self.updateNametags = NametagManager.createController(multitool)
    self.lastLookAt = nil
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
    if MTMultitool.internalModes[multitool.mode] ~= "Settings" then
        table.insert(toolsThatDisplayConnections, "018e4ca0-c5be-7f80-a80f-259c5951594b")
    end
    local toolsThatDisplayUI = {
        "8c7efc37-cd7c-4262-976e-39585f8527bf"
    }
    local holdingItem = tostring(sm.localPlayer.getActiveItem())
    local doRaycast = true
    if not table.contains(toolsThatDisplayConnections, holdingItem) then
        doRaycast = false
        if self.hideOnPanAway then
            self.updateNametags(nil)
        end
        if self.lastLookAt == nil then
            return
        end
    end

    local displayUI = table.contains(toolsThatDisplayUI, holdingItem)
    local hit = false
    local res = nil
    if doRaycast then
        local rayOrigin = sm.camera.getPosition()
        local rayDirection = sm.camera.getDirection()
        hit, res = ConnectionRaycaster:rayTraceDDA(rayOrigin, rayDirection, nil, 5)
    end
    if hit or self.lastLookAt ~= nil and self.hideOnPanAway == false then
        local shape = nil
        if not hit then
            shape = self.lastLookAt
        else
            shape = res.getShape()
        end
        if not sm.exists(shape) then
            self.updateNametags(nil)
            self.lastLookAt = nil
            return
        end
        if shape == nil then
            if self.hideOnPanAway then
                self.updateNametags(nil)
            end
            return
        end
        self.lastLookAt = shape
        local interactable = shape:getInteractable()
        if interactable == nil then
            if self.hideOnPanAway then
                self.updateNametags(nil)
            end
            return
        end
        local uuid = tostring(shape:getShapeUuid())
        -- print(uuid)
        -- print(FastLogicAllBlockManager.fastLogicGateBlockUuids)
        local numInputs = 0
        local numOutputs = 0
        local positionsAsInput = {}
        local positionsAsOutput = {}
        local selfWired = false
        local creationId = sm.MTFastLogic.CreationUtil.getCreationId(shape:getBody())
        local creation = sm.MTFastLogic.Creations[creationId]
        if creation ~= nil and creation.uuids[interactable.id] ~= nil then
            -- print("EEE")
            local blockFastUuid = creation.uuids[interactable.id]
            local block = creation.blocks[blockFastUuid]
            local inputs = block.inputs
            local outputs = block.outputs
            local shapesOutput = {}
            local shapesInput = {}
            -- local backdoneUuid = FLR.unhashedLookUp[runnerId]
            -- print(blockFastUuid, backdoneUuid)
            numInputs = #inputs
            numOutputs = #outputs
            for _, input in pairs(inputs) do
                local block = creation.blocks[input]
                if input == blockFastUuid then
                    selfWired = true
                    goto continue
                end
                local isSilicon = block.isSilicon
                local body = nil
                if isSilicon then
                    local siliconBlockId = block.siliconBlockId
                    local siliconBlock = creation.SiliconBlocks[siliconBlockId]
                    if siliconBlock == nil then
                        -- print("SILICON BLOCK IS NIL") idk why this happens, but by the next tick the system realizes it has shat itself and everything gets fixed
                        goto continue
                    end
                    body = siliconBlock.shape:getBody()
                else
                    local block = creation.AllFastBlocks[input]
                    if block == nil then
                        goto continue
                    end
                    body = block.shape:getBody()
                    table.insert(shapesInput, creation.AllFastBlocks[input].shape)
                end
                table.insert(positionsAsInput, body:transformPoint(block.pos / 4))
                ::continue::
            end
            for _, output in pairs(outputs) do
                if output == blockFastUuid then
                    selfWired = true
                    goto continue
                end
                local block = creation.blocks[output]
                local isSilicon = block.isSilicon
                local body = nil
                if isSilicon then
                    local siliconBlockId = block.siliconBlockId
                    local siliconBlock = creation.SiliconBlocks[siliconBlockId]
                    if siliconBlock == nil then
                        -- print("SILICON BLOCK IS NIL") idk why this happens, but by the next tick the system realizes it has shat itself and everything gets fixed
                        goto continue
                    end
                    body = siliconBlock.shape:getBody()
                else
                    local block = creation.AllFastBlocks[output]
                    if block == nil then
                        goto continue
                    end
                    body = block.shape:getBody()
                    table.insert(shapesOutput, creation.AllFastBlocks[output].shape)
                end
                table.insert(positionsAsOutput, body:transformPoint(block.pos / 4))
                ::continue::
            end
            for _, connection in pairs(interactable:getParents()) do
                if connection == interactable then
                    goto continue
                end
                if not table.contains(shapesInput, connection:getShape()) then
                    table.insert(positionsAsInput, connection:getShape():getWorldPosition())
                    numInputs = numInputs + 1
                end
                ::continue::
            end
            for _, connection in pairs(interactable:getChildren()) do
                if connection == interactable then
                    goto continue
                end
                if not table.contains(shapesOutput, connection:getShape()) then
                    table.insert(positionsAsOutput, connection:getShape():getWorldPosition())
                    numOutputs = numOutputs + 1
                end
                ::continue::
            end
            -- advPrint(creation, 4, 100, true)
        else
            local inputConnections = interactable:getParents()
            local outputConnections = interactable:getChildren()
            numInputs = #inputConnections
            numOutputs = #outputConnections
            for _, connection in pairs(inputConnections) do
                if connection == interactable then
                    goto continue
                end
                table.insert(positionsAsInput, connection:getShape():getWorldPosition())
                ::continue::
            end
            for _, connection in pairs(outputConnections) do
                if connection == interactable then
                    selfWired = true
                    goto continue
                end
                table.insert(positionsAsOutput, connection:getShape():getWorldPosition())
                ::continue::
            end
        end

        local nametags = {}
        if selfWired then
            table.insert(nametags, {
                txt = "SW", -- ↻
                color = sm.color.new(0.95, 0.9, 0, 1),
                pos = interactable:getShape():getWorldPosition()
            })
        else
            table.insert(nametags, {
                txt = "X",
                color = sm.color.new(1, 1, 1, 1),
                pos = interactable:getShape():getWorldPosition()
            })
        end
        for _, pos in pairs(positionsAsInput) do
            table.insert(nametags, {
                txt = "IN",
                color = sm.color.new(0, 1, 0, 1),
                pos = pos
            })
        end
        for _, pos in pairs(positionsAsOutput) do
            table.insert(nametags, {
                txt = "OUT",
                color = sm.color.new(1, 0, 0, 1),
                pos = pos
            })
        end
        self.updateNametags(nametags)
        if displayUI then
            sm.gui.setInteractionText("", "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>INPUTS: " ..
            numInputs .. "</p>")
            sm.gui.setInteractionText("", "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>OUTPUTS: " ..
            numOutputs .. "</p>")
        end
    else
        if self.hideOnPanAway then
            self.updateNametags(nil)
        end
    end
end