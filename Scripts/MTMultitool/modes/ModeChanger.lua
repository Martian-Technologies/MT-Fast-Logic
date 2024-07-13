ModeChanger = {}

ModeChanger.modes = {
    "AND",
    "OR",
    "XOR",
    "NAND",
    "NOR",
    "XNOR"
}

function ModeChanger.inject(multitool)
    multitool.ModeChanger = {}
    local self = multitool.ModeChanger
    self.modeInd = 1
    self.origin = nil
    self.body = nil
    self.final = nil
    self.nametagUpdate = NametagManager.createController(multitool)
end

function ModeChanger.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.ModeChanger
    multitool.BlockSelector.enabled = false
    multitool.VolumeSelector.enabled = false

    local needToRaycast = false

    if self.origin == nil and self.final == nil then
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Select first corner")
        needToRaycast = true
    elseif self.origin ~= nil and self.final == nil then
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Select second corner     ",
            sm.gui.getKeyBinding("Attack", true), "Cancel")
        needToRaycast = true
    elseif self.origin ~= nil and self.final ~= nil then
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Change Modes     ",
            sm.gui.getKeyBinding("Attack", true), "Cancel")
        needToRaycast = false
    end
    if self.final ~= nil then
        local displayMode = ModeChanger.modes[self.modeInd]
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true),
            "Toggle mode <p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
            displayMode .. "</p>")
    end
    local tags = {}
    local localPosition = nil
    local bodyhit = nil
    if needToRaycast then
        localPosition, bodyhit = ConnectionRaycaster:raycastToBlock()
        if (bodyhit ~= self.body) and (self.body ~= nil) then
            localPosition = nil
            bodyhit = nil
        end
        -- self.nametagUpdate(tags)
    end
    -- print(localPosition)

    -- display a preview
    local minPos = nil
    local maxPos = nil
    local bodyUsed = nil
    if self.origin == nil then
        if localPosition ~= nil then
            minPos = localPosition
            maxPos = localPosition
            bodyUsed = bodyhit
        end
    elseif self.final == nil then
        if localPosition ~= nil then
            minPos = sm.vec3.min(self.origin, localPosition)
            maxPos = sm.vec3.max(self.origin, localPosition)
            bodyUsed = bodyhit
        else
            minPos = self.origin
            maxPos = self.origin
            bodyUsed = self.body
        end
    else
        minPos = sm.vec3.min(self.origin, self.final)
        maxPos = sm.vec3.max(self.origin, self.final)
        bodyUsed = self.body
    end

    if minPos ~= nil and maxPos ~= nil and bodyUsed ~= nil and sm.exists(bodyUsed) then
        local x1 = minPos.x - 0.125
        local y1 = minPos.y - 0.125
        local z1 = minPos.z - 0.125
        local x2 = maxPos.x + 0.125
        local y2 = maxPos.y + 0.125
        local z2 = maxPos.z + 0.125
        local color = sm.color.new(1, 1, 1, 1)
        table.insert(tags, {
            pos = bodyUsed:transformPoint(sm.vec3.new(x1, y1, z1)),
            color = color,
            txt = "•"
        })
        table.insert(tags, {
            pos = bodyUsed:transformPoint(sm.vec3.new(x1, y1, z2)),
            color = color,
            txt = "•"
        })
        table.insert(tags, {
            pos = bodyUsed:transformPoint(sm.vec3.new(x1, y2, z1)),
            color = color,
            txt = "•"
        })
        table.insert(tags, {
            pos = bodyUsed:transformPoint(sm.vec3.new(x1, y2, z2)),
            color = color,
            txt = "•"
        })
        table.insert(tags, {
            pos = bodyUsed:transformPoint(sm.vec3.new(x2, y1, z1)),
            color = color,
            txt = "•"
        })
        table.insert(tags, {
            pos = bodyUsed:transformPoint(sm.vec3.new(x2, y1, z2)),
            color = color,
            txt = "•"
        })
        table.insert(tags, {
            pos = bodyUsed:transformPoint(sm.vec3.new(x2, y2, z1)),
            color = color,
            txt = "•"
        })
        table.insert(tags, {
            pos = bodyUsed:transformPoint(sm.vec3.new(x2, y2, z2)),
            color = color,
            txt = "•"
        })
    end

    self.nametagUpdate(tags)

    if primaryState == 1 then
        if self.origin == nil then
            self.origin = localPosition
            self.body = bodyhit
        elseif self.final == nil then
            self.final = localPosition
        else
            multitool.network:sendToServer("server_changeModes", {
                origin = self.origin,
                final = self.final,
                mode = self.modeInd,
                body = bodyUsed
            })
            ModeChanger.cleanUp(multitool)
        end
    end
    if secondaryState == 1 then
        if self.final ~= nil then
            self.final = nil
        elseif self.origin ~= nil then
            self.origin = nil
            self.body = nil
        end
    end
    if MTMultitool.handleForceBuild(multitool, forceBuild) then
        self.modeInd = self.modeInd + 1
        if self.modeInd > #ModeChanger.modes then
            self.modeInd = 1
        end
    end
end

function ModeChanger.cleanUp(multitool)
    local self = multitool.ModeChanger
    self.origin = nil
    self.final = nil
    self.body = nil
    self.nametagUpdate(nil)
end

function ModeChanger.cleanNametags(multitool)
    local self = multitool.ModeChanger
    self.nametagUpdate(nil)
end