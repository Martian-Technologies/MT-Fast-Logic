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
    self.previewColor = sm.color.new(1, 1, 1, 1)
    self.selectionMode = "inside" -- "inside" or "outside"
    self.doConfirm = true
    self.nametagUpdate = NametagManager.createController(multitool)
end

function VolumeSelector.trigger(multitool, primaryState, secondaryState, forceBuild, extraTooltip)
    if extraTooltip == nil then
        extraTooltip = {
            selectOrigin = "",
            selectFinal = "",
            confirm = "",
        }
    end
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
            "Select first corner" .. (extraTooltip.selectOrigin or "") .. betaTextEnd)
        needToRaycast = true
    elseif self.origin ~= nil and self.final == nil then
        needToRaycast = true
    elseif self.origin ~= nil and self.final ~= nil then
        needToRaycast = false
    end
    if self.final ~= nil and self.modes ~= nil then
        if MTMultitool.handleForceBuild(multitool, forceBuild) then
            local isCrouching = multitool.tool:isCrouching()
            if isCrouching then
                self.index = self.index - 1
            else
                self.index = self.index + 1
            end
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
        localPosition, bodyhit = ConnectionRaycaster:raycastToBlock(self.selectionMode == "outside")
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
        local color = self.previewColor
        local xWidth = x2 - x1
        local yWidth = y2 - y1
        local zWidth = z2 - z1
        local sizeString = "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>("..(xWidth*4).." x "..(yWidth*4).." x "..(zWidth*4)..")</p>"
        if self.origin ~= nil and self.final == nil then
            sm.gui.setInteractionText(betaTextStart, sm.gui.getKeyBinding("Create", true), "Select second corner     "..sizeString.."     ",
                sm.gui.getKeyBinding("Attack", true), "Cancel" .. betaTextEnd)
        elseif self.origin ~= nil and self.final ~= nil then
            sm.gui.setInteractionText(betaTextStart, sm.gui.getKeyBinding("Create", true), self.actionWord .. "     "..sizeString.."     ",
                sm.gui.getKeyBinding("Attack", true), "Cancel" .. betaTextEnd)
        end
        local stepsPerBlock = 2
        local xSteps = math.floor(xWidth / 0.25) * stepsPerBlock
        local ySteps = math.floor(yWidth / 0.25) * stepsPerBlock
        local zSteps = math.floor(zWidth / 0.25) * stepsPerBlock
        for i = 0, xSteps do
            local x = x1 + i / stepsPerBlock * 0.25
            table.insert(tags, {
                pos = bodyUsed:transformPoint(sm.vec3.new(x, y1, z1)),
                color = color,
                txt = "•"
            })
            table.insert(tags, {
                pos = bodyUsed:transformPoint(sm.vec3.new(x, y1, z2)),
                color = color,
                txt = "•"
            })
            table.insert(tags, {
                pos = bodyUsed:transformPoint(sm.vec3.new(x, y2, z1)),
                color = color,
                txt = "•"
            })
            table.insert(tags, {
                pos = bodyUsed:transformPoint(sm.vec3.new(x, y2, z2)),
                color = color,
                txt = "•"
            })
        end
        for i = 0, ySteps do
            local y = y1 + i / stepsPerBlock * 0.25
            table.insert(tags, {
                pos = bodyUsed:transformPoint(sm.vec3.new(x1, y, z1)),
                color = color,
                txt = "•"
            })
            table.insert(tags, {
                pos = bodyUsed:transformPoint(sm.vec3.new(x1, y, z2)),
                color = color,
                txt = "•"
            })
            table.insert(tags, {
                pos = bodyUsed:transformPoint(sm.vec3.new(x2, y, z1)),
                color = color,
                txt = "•"
            })
            table.insert(tags, {
                pos = bodyUsed:transformPoint(sm.vec3.new(x2, y, z2)),
                color = color,
                txt = "•"
            })
        end
        for i = 0, zSteps do
            local z = z1 + i / stepsPerBlock * 0.25
            table.insert(tags, {
                pos = bodyUsed:transformPoint(sm.vec3.new(x1, y1, z)),
                color = color,
                txt = "•"
            })
            table.insert(tags, {
                pos = bodyUsed:transformPoint(sm.vec3.new(x1, y2, z)),
                color = color,
                txt = "•"
            })
            table.insert(tags, {
                pos = bodyUsed:transformPoint(sm.vec3.new(x2, y1, z)),
                color = color,
                txt = "•"
            })
            table.insert(tags, {
                pos = bodyUsed:transformPoint(sm.vec3.new(x2, y2, z)),
                color = color,
                txt = "•"
            })
        end
    end

    self.nametagUpdate(tags)

    local doNotConfirm = false
    if primaryState == 1 then
        if self.origin == nil then
            self.origin = localPosition
            self.body = bodyhit
            doNotConfirm = true
        elseif self.final == nil then
            self.final = localPosition
            doNotConfirm = true
        end
    end
    if (self.origin ~= nil) and (self.final ~= nil) and (not doNotConfirm) then
        if (primaryState == 1) or (not self.doConfirm) then
            local result = {
                origin = self.origin,
                final = self.final,
                body = self.body
            }
            if self.modes ~= nil then
                result.mode = self.modes[self.index]
            end
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
    self.doConfirm = true
    self.origin = nil
    self.body = nil
    self.final = nil
    self.previewColor = sm.color.new(1, 1, 1, 1)
end

function VolumeSelector.cleanNametags(multitool)
    multitool.VolumeSelector.nametagUpdate(nil)
end