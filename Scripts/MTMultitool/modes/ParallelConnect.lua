ParallelConnect = {}

function ParallelConnect.inject(multitool)
    multitool.ParallelConnect = {}
    local self = multitool.ParallelConnect
    self.data = {}
    local selfData = self.data
    selfData.selected = {}
    selfData.nametagUpdate = NametagManager.createController(multitool)
    selfData.seq1 = {
        start = nil,
        final = nil,
        sequence = {}
    }
    selfData.seq2 = {
        start = nil,
        final = nil,
        sequence = {}
    }
end

function ParallelConnect.recalculateSequences(multitool, lookingAt)
    local self = multitool.ParallelConnect
    local selfData = self.data
    if #selfData.selected == 0 then
        multitool.ConnectionManager.preview = {}
        selfData.nametagUpdate(nil)
        return
    end
    local from1 = selfData.selected[1]
    local to1 = nil
    if #selfData.selected == 1 then
        to1 = lookingAt
    else
        to1 = selfData.selected[2]
    end
    if to1 == nil then
        multitool.ConnectionManager.preview = {}
        selfData.nametagUpdate(nil)
        return
    end
    local nametags = {}
    local sequence1 = selfData.seq1.sequence
    if selfData.seq1.start ~= from1 or selfData.seq1.final ~= to1 then
        selfData.seq1.start = from1
        selfData.seq1.final = to1
        selfData.seq1.sequence = MTMultitoolLib.findSequeceOfGates(from1, to1)
        sequence1 = selfData.seq1.sequence
    end
    -- local sequence1 = MTMultitoolLib.findSequeceOfGates(from1, to1)
    for i, shape in pairs(sequence1) do
        local worldPosition = shape:getWorldPosition()
        table.insert(nametags, {
            pos = worldPosition,
            color = sm.color.new(1, 1, 1, 1),
            txt = string.format("[%d]", i)
        })
    end
    if #selfData.selected == 2 then
        selfData.nametagUpdate(nametags)
        multitool.ConnectionManager.preview = {}
        return
    end
    local from2 = selfData.selected[3]
    local to2 = nil
    if #selfData.selected == 3 then
        to2 = lookingAt
    else
        to2 = selfData.selected[4]
    end
    if to2 == nil then
        selfData.nametagUpdate(nametags)
        multitool.ConnectionManager.preview = {}
        return
    end
    local sequence2 = selfData.seq2.sequence
    if selfData.seq2.start ~= from2 or selfData.seq2.final ~= to2 then
        selfData.seq2.start = from2
        selfData.seq2.final = to2
        selfData.seq2.sequence = MTMultitoolLib.findSequeceOfGates(from2, to2)
        sequence2 = selfData.seq2.sequence
    end
    -- local sequence2 = MTMultitoolLib.findSequeceOfGates(from2, to2)
    for i, shape in pairs(sequence2) do
        local worldPosition = shape:getWorldPosition()
        table.insert(nametags, {
            pos = worldPosition,
            color = sm.color.new(1, 1, 1, 1),
            txt = string.format("[%d]", i)
        })
    end
    if #sequence1 ~= #sequence2 then
        -- different lengths, draw red Xs on the longer sequence
        local lengthDifference = math.abs(#sequence1 - #sequence2)
        if #sequence1 > #sequence2 then
            -- replace existing entries in the nametags table
            for i = 0, lengthDifference-1 do
                nametags[#sequence1 - i].color = sm.color.new(1, 0, 0, 1)
                nametags[#sequence1 - i].txt = "X"
            end
        else
            -- replace existing entries in the nametags table
            for i = 0, lengthDifference-1 do
                nametags[#sequence1+#sequence2 - i].color = sm.color.new(1, 0, 0, 1)
                nametags[#sequence1+#sequence2 - i].txt = "X"
            end
        end
        multitool.ConnectionManager.preview = {}
        selfData.nametagUpdate(nametags)
        return
    end
    selfData.nametagUpdate(nametags)
    multitool.ConnectionManager.preview = {}
    for i, shape in pairs(sequence1) do
        local task = {
            from = shape,
            to = sequence2[i]
        }
        table.insert(multitool.ConnectionManager.preview, task)
    end
end

function ParallelConnect.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    multitool.ConnectionManager.displayMode = "fast"
    local self = multitool.ParallelConnect
    local selfData = self.data
    if #selfData.selected < 4 then
        multitool.BlockSelector.enabled = true
    else
        multitool.BlockSelector.enabled = false
    end
    local updateConstraints = false
    if primaryState == 1 then
        if #selfData.selected < 4 then
            local block = lookingAt
            if block then
                table.insert(selfData.selected, block)
                ParallelConnect.recalculateSequences(multitool, lookingAt)
                updateConstraints = true
            end
        elseif #selfData.selected == 4 then
            ConnectionManager.commitPreview(multitool)
            ParallelConnect.cleanUp(multitool)
            updateConstraints = true
        end
    end
    if secondaryState == 1 then
        if #selfData.selected > 0 then
            table.remove(selfData.selected)
            ParallelConnect.recalculateSequences(multitool, lookingAt)
            updateConstraints = true
        end
    end
    if updateConstraints then
        if #selfData.selected == 0 then
            multitool.BlockSelector.bodyConstraint = nil
        elseif #selfData.selected == 1 then
            multitool.BlockSelector.bodyConstraint = {
                selfData.selected[1]:getBody()
            }
        elseif #selfData.selected == 2 then
            multitool.BlockSelector.bodyConstraint = selfData.selected[1]:getBody():getCreationBodies()
            print(multitool.BlockSelector.bodyConstraint)
        elseif #selfData.selected == 3 then
            multitool.BlockSelector.bodyConstraint = {
                selfData.selected[3]:getBody()
            }
        elseif #selfData.selected == 4 then
            multitool.BlockSelector.bodyConstraint = nil
        end
    end
    if #selfData.selected == 0 then
        sm.gui.setInteractionText("Select the start of the first series", sm.gui.getKeyBinding("Create", true), "Select")
    elseif #selfData.selected == 1 then
        sm.gui.setInteractionText("Select the end of the first series", sm.gui.getKeyBinding("Create", true), "Select")
        ParallelConnect.recalculateSequences(multitool, lookingAt)
    elseif #selfData.selected == 2 then
        sm.gui.setInteractionText("Select the start of the second series", sm.gui.getKeyBinding("Create", true), "Select")
        ParallelConnect.recalculateSequences(multitool, lookingAt)
    elseif #selfData.selected == 3 then
        sm.gui.setInteractionText("Select the end of the second series", sm.gui.getKeyBinding("Create", true), "Select")
        ParallelConnect.recalculateSequences(multitool, lookingAt)
    elseif #selfData.selected == 4 then
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true), "Toggle", "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" .. multitool.ConnectionManager.mode .. "<p>")
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Connect")
        ParallelConnect.recalculateSequences(multitool, lookingAt)
        if MTMultitool.handleForceBuild(multitool, forceBuild) then
            ConnectionManager.toggleMode(multitool)
        end
    end
end

function ParallelConnect.cleanUp(multitool)
    local self = multitool.ParallelConnect
    local selfData = self.data
    selfData.seq1.start = nil
    selfData.seq1.final = nil
    selfData.selected = {}
    multitool.ConnectionManager.preview = {}
    selfData.nametagUpdate(nil)
end

function ParallelConnect.client_onUpdate(multitool)
    local self = multitool.ParallelConnect
    local selfData = self.data
    for i, shape in pairs(selfData.selected) do
        if not sm.exists(shape) then
            ParallelConnect.cleanUp(multitool)
            return
        end
    end
    for i, shape in pairs(selfData.seq1.sequence) do
        local recalc = false
        if not sm.exists(shape) then
            recalc = true
        end
        if recalc then
            selfData.seq1.start = nil
            ParallelConnect.recalculateSequences(multitool)
        end
    end
    for i, shape in pairs(selfData.seq2.sequence) do
        local recalc = false
        if not sm.exists(shape) then
            recalc = true
        end
        if recalc then
            selfData.seq2.start = nil
            ParallelConnect.recalculateSequences(multitool)
        end
    end
end