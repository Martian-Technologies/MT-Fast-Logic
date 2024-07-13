VolumeSelector = {}

function VolumeSelector.inject(multitool)
    multitool.VolumeSelector = {}
    local self = multitool.VolumeSelector
    self.enabled = false
    self.origin = nil
    self.body = nil
    self.final = nil
    self.isBeta = false
    self.actionWord = ""
    self.modes = nil
    self.modesNice = nil
    self.index = 1
    self.nametagUpdate = NametagManager.createController(multitool)
end

function VolumeSelector.trigger(multitool, primaryState, secondaryState, forceBuild)
    local self = multitool.VolumeSelector
    local needToRaycast = false
    local betaTextStart = ""
    local betaTextEnd = ""
    if self.isBeta then
        betaTextStart = "<p textShadow='false' bg='gui_keybinds_bg' color='#ff2211' spacing='4'>! BETA !</p>     "
        betaTextEnd = "     <p textShadow='false' bg='gui_keybinds_bg' color='#ff2211' spacing='4'>! BETA !</p>"
    end
    if self.origin == nil and self.final == nil then
        sm.gui.setInteractionText(betaTextStart, sm.gui.getKeyBinding("Create", true),
            "Select first corner" .. betaTextEnd)
        needToRaycast = true
    elseif self.origin ~= nil and self.final == nil then
        sm.gui.setInteractionText(betaTextStart, sm.gui.getKeyBinding("Create", true), "Select second corner     ",
            sm.gui.getKeyBinding("Attack", true), "Cancel" .. betaTextEnd)
        needToRaycast = true
    elseif self.origin ~= nil and self.final ~= nil then
        sm.gui.setInteractionText(betaTextStart, sm.gui.getKeyBinding("Create", true), self.actionWord .. "     ",
            sm.gui.getKeyBinding("Attack", true), "Cancel" .. betaTextEnd)
        needToRaycast = false
    end
    if self.final ~= nil and self.modes ~= nil then
        if MTMultitool.handleForceBuild(multitool, forceBuild) then
            self.index = self.index + 1
        end
        if self.index > #self.modes then
            self.index = 1
        end
        if self.index < 1 then
            self.index = #self.modes
        end
        local niceMode = self.modesNice[self.index]
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true),
            "Toggle mode <p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
            niceMode .. "</p>")
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

    if not sm.exists(bodyUsed) then
        bodyUsed = nil
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
            local result = {
                origin = self.origin,
                final = self.final,
                mode = self.modes[self.index],
                body = self.body
            }
            VolumeSelector.cleanUp(multitool)
            return result
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
    return nil
end

function VolumeSelector.client_onUpdate(multitool, dt)
    local self = multitool.VolumeSelector
    if self.enabled == false then
        VolumeSelector.cleanNametags(multitool)
    end
end

function VolumeSelector.cleanUp(multitool)
    local self = multitool.VolumeSelector
    self.origin = nil
    self.body = nil
    self.final = nil
end

function VolumeSelector.cleanNametags(multitool)
    multitool.VolumeSelector.nametagUpdate(nil)
end