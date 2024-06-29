SiliconConverterTool = {}

function SiliconConverterTool.inject(multitool)
    multitool.SiliconConverter = {}
    local self = multitool.SiliconConverter
    self.origin = nil
    self.body = nil
    self.final = nil
    self.wantedType = "toSilicon"
    self.nametagUpdate = NametagManager.createController(multitool)
end

function SiliconConverterTool.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt_NOTUSED)
    local self = multitool.SiliconConverter
    multitool.BlockSelector.enabled = false

    local needToRaycast = false

    if self.origin == nil and self.final == nil then
        sm.gui.setInteractionText("<p textShadow='false' bg='gui_keybinds_bg' color='#ff2211' spacing='4'>! BETA !</p>     ", sm.gui.getKeyBinding("Create", true), "Select first corner     <p textShadow='false' bg='gui_keybinds_bg' color='#ff2211' spacing='4'>! BETA !</p>")
        needToRaycast = true
    elseif self.origin ~= nil and self.final == nil then
        sm.gui.setInteractionText("<p textShadow='false' bg='gui_keybinds_bg' color='#ff2211' spacing='4'>! BETA !</p>     ", sm.gui.getKeyBinding("Create", true), "Select second corner     ",
            sm.gui.getKeyBinding("Attack", true), "Cancel     <p textShadow='false' bg='gui_keybinds_bg' color='#ff2211' spacing='4'>! BETA !</p>")
        needToRaycast = true
    elseif self.origin ~= nil and self.final ~= nil then
        sm.gui.setInteractionText("<p textShadow='false' bg='gui_keybinds_bg' color='#ff2211' spacing='4'>! BETA !</p>     ", sm.gui.getKeyBinding("Create", true), "Convert     ",
            sm.gui.getKeyBinding("Attack", true), "Cancel     <p textShadow='false' bg='gui_keybinds_bg' color='#ff2211' spacing='4'>! BETA !</p>")
        needToRaycast = false
    end
    if self.final ~= nil then
        local wantedTypeNice = "To Silicon"
        if self.wantedType == "toFastLogic" then
            wantedTypeNice = "To Fast Logic"
        end
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true),
            "Toggle type <p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
            wantedTypeNice .. "</p>")
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

    if minPos ~= nil and maxPos ~= nil and bodyUsed ~= nil then
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
            multitool.network:sendToServer("server_convertSilicon", {
                origin = self.origin,
                final = self.final,
                wantedType = self.wantedType,
                originBody = self.body
            })
            SiliconConverterTool.cleanUp(multitool)
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
        if self.wantedType == "toSilicon" then
            self.wantedType = "toFastLogic"
        else
            self.wantedType = "toSilicon"
        end
    end
end

function SiliconConverterTool.cleanUp(multitool)
    local self = multitool.SiliconConverter
    self.origin = nil
    self.final = nil
    self.body = nil
    self.nametagUpdate(nil)
end

function SiliconConverterTool.cleanNametags(multitool)
    local self = multitool.SiliconConverter
    self.nametagUpdate(nil)
end