SeriesConnect = {}

function SeriesConnect.inject(multitool)
    multitool.SeriesConnect = {}
    local self = multitool.SeriesConnect
    self.data = {}
    local selfData = self.data
    selfData.selected = {}
    selfData.sequence = {}
    selfData.sequenceFinalGate = nil
    selfData.nametagUpdate = NametagManager.createController(multitool)
end

function SeriesConnect.recalculateSequence(multitool, from, to)
    local self = multitool.SeriesConnect
    local selfData = self.data
    -- recalculate the sequence
    if #selfData.selected == 0 then
        selfData.sequence = {}
        multitool.ConnectionManager.preview = {}
        selfData.sequenceFinalGate = nil
        selfData.nametagUpdate(nil)
        return
    end
    local sequence = MTMultitoolLib.findSequeceOfGates(from or selfData.selected[1], to or selfData.selected[2])
    selfData.sequenceFinalGate = sequence[#sequence]
    selfData.sequence = sequence
    -- then the preview
    multitool.ConnectionManager.preview = {}
    for i, shape in pairs(sequence) do
        if i == #sequence then
            break
        end
        local task = {
            from = shape,
            to = sequence[i + 1],
            polarity = (i % 2 == 0),
        }
        table.insert(multitool.ConnectionManager.preview, task)
    end
    local nametags = {}
    for i, shape in pairs(sequence) do
        local worldPosition = shape:getWorldPosition()
        table.insert(nametags, {
            pos = worldPosition,
            color = sm.color.new(1, 1, 1, 1),
            txt = string.format("[%d]", i)
        })
    end
    selfData.nametagUpdate(nametags)
end

function SeriesConnect.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    multitool.ConnectionManager.displayMode = "fast"
    local self = multitool.SeriesConnect
    local selfData = self.data
    if #selfData.selected < 2 then
        multitool.SelectionModeController.modeActive = "BlockSelector"
    else
        multitool.SelectionModeController.modeActive = nil
    end
    if primaryState == 1 then
        if #selfData.selected < 2 then
            if lookingAt ~= nil then
                selfData.selected[#selfData.selected + 1] = lookingAt
                SeriesConnect.recalculateSequence(multitool)
            end
        else
            -- commit the preview
            ConnectionManager.commitPreview(multitool)
            SeriesConnect.cleanUp(multitool)
        end
    end
    if secondaryState == 1 then
        -- pop the last selected shape
        if #selfData.selected > 0 then
            table.remove(selfData.selected)
            if #selfData.selected == 1 then
                selfData.sequence = { selfData.selected[1] }
                selfData.sequenceFinalGate = nil
                SeriesConnect.recalculateSequence(multitool, selfData.selected[1], lookingAt)
            else
                SeriesConnect.recalculateSequence(multitool)
            end
        end
    end
    if #selfData.selected == 1 then
        if lookingAt ~= nil then
            local from = selfData.selected[1]
            local to = lookingAt
            if to ~= selfData.sequenceFinalGate then
                SeriesConnect.recalculateSequence(multitool, from, to)
            end
        else
            multitool.ConnectionManager.preview = {}
            selfData.sequenceFinalGate = nil
            selfData.sequence = { selfData.selected[1] }
            selfData.nametagUpdate(nil)
        end
    end
    
    if #selfData.selected == 0 then
        sm.gui.setInteractionText("Select the start of the series", sm.gui.getKeyBinding("Create", true), "Select")
    elseif #selfData.selected == 1 then
        sm.gui.setInteractionText("Select the end of the series", sm.gui.getKeyBinding("Create", true), "Select")
    else
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true), "Toggle", "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" .. multitool.ConnectionManager.mode .. "<p>")
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Connect")
        if MTMultitool.handleForceBuild(multitool, forceBuild) then
            ConnectionManager.toggleMode(multitool)
        end
    end
end

function SeriesConnect.client_onUpdate(multitool)
    local self = multitool.SeriesConnect
    local selfData = self.data
    -- check if all shapes still exist
    for i, shape in pairs(selfData.selected) do
        if not sm.exists(shape) then
            SeriesConnect.cleanUp(multitool)
            return
        end
    end
    for i, shape in pairs(selfData.sequence) do
        local recalc = false
        if not sm.exists(shape) then
            recalc = true
        end
        if recalc then
            SeriesConnect.recalculateSequence(multitool)
        end
    end
end

function SeriesConnect.cleanUp(multitool)
    local self = multitool.SeriesConnect
    local selfData = self.data
    selfData.selected = {}
    selfData.sequence = {}
    selfData.sequenceFinalGate = nil
    multitool.ConnectionManager.preview = {}
    selfData.nametagUpdate(nil)
end
