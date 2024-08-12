SingleConnect = {}

function SingleConnect.inject(multitool)
    multitool.SingleConnect = {}
    local self = multitool.SingleConnect
    self.allowedBodies = {}
    self.selectedSource = {}
    self.selectedTarget = {}
    self.updateNametags = NametagManager.createController(multitool)
    self.operationState = nil -- "adding", "removing", nil
end

function SingleConnect.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.SingleConnect
    multitool.SelectionModeController.modeActive = "BlockSelector"
    if primaryState > 0 then
        if self.operationState == nil then
            if table.contains(self.selectedSource, lookingAt) then
                table.remove(self.selectedSource, table.find(self.selectedSource, lookingAt))
                self.operationState = "removing"
            else
                table.insert(self.selectedSource, lookingAt)
                self.operationState = "adding"
            end
        elseif self.operationState == "adding" then
            if not table.contains(self.selectedSource, lookingAt) then
                table.insert(self.selectedSource, lookingAt)
            end
        elseif self.operationState == "removing" then
            if table.contains(self.selectedSource, lookingAt) then
                table.remove(self.selectedSource, table.find(self.selectedSource, lookingAt))
            end
        end
    elseif secondaryState > 0 then
        if self.operationState == nil then
            if table.contains(self.selectedTarget, lookingAt) then
                table.remove(self.selectedTarget, table.find(self.selectedTarget, lookingAt))
                self.operationState = "removing"
            else
                table.insert(self.selectedTarget, lookingAt)
                self.operationState = "adding"
            end
        elseif self.operationState == "adding" then
            if not table.contains(self.selectedTarget, lookingAt) then
                table.insert(self.selectedTarget, lookingAt)
            end
        elseif self.operationState == "removing" then
            if table.contains(self.selectedTarget, lookingAt) then
                table.remove(self.selectedTarget, table.find(self.selectedTarget, lookingAt))
            end
        end
    else
        self.operationState = nil
    end
    local tags = {}
    for i, shape in pairs(self.selectedSource) do
        if table.contains(self.selectedTarget, shape) then
            table.insert(tags, {
                pos = shape.worldPosition,
                txt = "S" .. i .. "#FF0000 T" .. table.find(self.selectedTarget, shape),
                color = sm.color.new(0, 1, 0)
            })
        else
            table.insert(tags, {
                pos = shape.worldPosition,
                txt = "S" .. i,
                color = sm.color.new(0, 1, 0)
            })
        end
    end
    for i, shape in pairs(self.selectedTarget) do
        if not table.contains(self.selectedSource, shape) then
            table.insert(tags, {
                pos = shape.worldPosition,
                txt = "T" .. i,
                color = sm.color.new(1, 0, 0)
            })
        end
    end
    self.updateNametags(tags)
    sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Source     ",
        sm.gui.getKeyBinding("Attack", true), "Target")
    if #self.selectedSource > 0 and #self.selectedTarget > 0 then
        local canParallel = false
        if #self.selectedSource == #self.selectedTarget then
            canParallel = true
            sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true), "Connect NtoN     ",
                sm.gui.getKeyBinding("Reload", true), "Connect Parallel")
        else
            sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true), "Connect NtoN")
        end
        if MTMultitool.handleForceBuild(multitool, forceBuild) then
            local cm = multitool.ConnectionManager
            cm.preview = {}
            cm.mode = "connect"
            for i = 1, #self.selectedSource do
                local shape1 = self.selectedSource[i]
                for j = 1, #self.selectedTarget do
                    local shape2 = self.selectedTarget[j]
                    local task = {
                        from = shape1,
                        to = shape2,
                    }
                    table.insert(cm.preview, task)
                end
            end
            ConnectionManager.commitPreview(multitool)
            SingleConnect.cleanUp(multitool)
        end
    end
end

function SingleConnect.client_onReload(multitool)
    local self = multitool.SingleConnect
    if #self.selectedSource < 0 or #self.selectedTarget < 0 then
        return
    end
    if #self.selectedSource ~= #self.selectedTarget then
        return
    end
    local cm = multitool.ConnectionManager
    cm.preview = {}
    cm.mode = "connect"
    for i = 1, #self.selectedSource do
        local shape1 = self.selectedSource[i]
        local shape2 = self.selectedTarget[i]
        local task = {
            from = shape1,
            to = shape2,
        }
        table.insert(cm.preview, task)
    end
    ConnectionManager.commitPreview(multitool)
    SingleConnect.cleanUp(multitool)
end

function SingleConnect.client_onUpdate(multitool)
end

function SingleConnect.cleanUp(multitool)
    local self = multitool.SingleConnect
    self.allowedBodies = {}
    self.selectedSource = {}
    self.selectedTarget = {}
    self.updateNametags(nil)
end