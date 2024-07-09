Colorizer = {}

-- FastLogicRealBlockManager.changeConnectionColor

function Colorizer.inject(multitool)
    multitool.colorizer = {}
    local self = multitool.colorizer
    self.origin = nil
    self.body = nil
    self.final = nil
    self.color = 1
    self.nametagUpdate = NametagManager.createController(multitool)
    self.gui = nil
end

function Colorizer.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.colorizer
    multitool.BlockSelector.enabled = false

    -- handle forcebuild
    -- if MTMultitool.handleForceBuild(multitool, forceBuild) then
    --     self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Tool/Tool_Colorizer.layout", true)
    --     self.gui:setGridSize("ColorGrid", 10)
    --     self.gui:addGridItem("ColorGrid", {
            
    --     })
    --     self.gui:open()
    -- end

    local needToRaycast = false

    if self.origin == nil and self.final == nil then
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Select first corner")
        needToRaycast = true
    elseif self.origin ~= nil and self.final == nil then
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Select second corner     ",
            sm.gui.getKeyBinding("Attack", true), "Cancel")
        needToRaycast = true
    elseif self.origin ~= nil and self.final ~= nil then
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Recolor     ",
            sm.gui.getKeyBinding("Attack", true), "Cancel")
        needToRaycast = false
    end
    if self.final ~= nil then
        local displayColor = tostring(self.color)
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true),
            "Toggle mode <p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
            displayColor .. "</p>")
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
            multitool.network:sendToServer("server_recolor", {
                origin = self.origin,
                final = self.final,
                mode = self.color-1,
                body = bodyUsed
            })
            Colorizer.cleanUp(multitool)
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
        self.color = self.color + 1
        if self.color > 40 then
            self.color = 1
        end
    end
end

function Colorizer.cleanUp(multitool)
    local self = multitool.colorizer
    self.origin = nil
    self.final = nil
    self.body = nil
    self.nametagUpdate(nil)
end

function Colorizer.cleanNametags(multitool)
    local self = multitool.colorizer
    self.nametagUpdate(nil)
end