dofile "../TensorUtil.lua"

DecoderMaker = {}

function DecoderMaker.inject(multitool)
    multitool.DecoderMaker = {}
    local self = multitool.DecoderMaker
    self.nametagUpdate = NametagManager.createController(multitool)
    self.dotSource = VertexRenderer.createSource(multitool)
    self.normalStart = nil
    self.normalEnd = nil
    self.invertedStart = nil
    self.invertedEnd = nil
    self.outputOrigin = nil
    self.outputStep = nil
end

local function getInputSequences(self, normalEnd, invertedEnd)
    local normalSequence = {}
    local invertedSequence = {}
    normalEnd = normalEnd or self.normalEnd
    invertedEnd = invertedEnd or self.invertedEnd
    if self.normalStart ~= nil and normalEnd ~= nil then
        normalSequence = MTMultitoolLib.findSequeceOfGates(self.normalStart, normalEnd)
    end
    if self.invertedStart ~= nil and invertedEnd ~= nil then
        invertedSequence = MTMultitoolLib.findSequeceOfGates(self.invertedStart, invertedEnd)
    end
    return normalSequence, invertedSequence
end

local function getHoverEnd(startShape, lookingAt)
    if startShape == nil or lookingAt == nil or not sm.exists(startShape) or not sm.exists(lookingAt) then
        return nil
    end
    return startShape:getBody() == lookingAt:getBody() and lookingAt or nil
end

local normalColor = sm.color.new(0, 1, 0, 1)
local invertedColor = sm.color.new(1, 0, 0, 1)
local outputColor = sm.color.new(0.2, 0.5, 1, 1)

local function addRangeTags(tags, sequence, color)
    local indices = {}
    for i, shape in ipairs(sequence) do
        table.insert(tags, {
            pos = shape:getWorldPosition(),
            color = color,
            txt = string.format("[%d]", i)
        })
        indices[i] = #tags
    end
    return indices
end

local function updateDecoderNametags(multitool, lookingAt)
    local self = multitool.DecoderMaker
    local tags = {}
    local dots = {}
    local normalPreviewEnd = self.normalEnd
    local invertedPreviewEnd = self.invertedEnd
    if self.normalStart ~= nil and normalPreviewEnd == nil then
        normalPreviewEnd = getHoverEnd(self.normalStart, lookingAt)
    elseif self.invertedStart ~= nil and invertedPreviewEnd == nil then
        invertedPreviewEnd = getHoverEnd(self.invertedStart, lookingAt)
    end

    local normalSequence, invertedSequence = getInputSequences(self, normalPreviewEnd, invertedPreviewEnd)
    local normalTagIndices = addRangeTags(tags, normalSequence, normalColor)
    local invertedTagIndices = addRangeTags(tags, invertedSequence, invertedColor)

    if self.normalStart ~= nil and self.normalEnd == nil and #normalSequence == 0 then
        table.insert(tags, { pos = self.normalStart:getWorldPosition(), color = normalColor, txt = "[1]" })
    end
    if self.invertedStart ~= nil and self.invertedEnd == nil and #invertedSequence == 0 then
        table.insert(tags, { pos = self.invertedStart:getWorldPosition(), color = invertedColor, txt = "[1]" })
    end

    if self.normalEnd ~= nil and invertedPreviewEnd ~= nil and #normalSequence ~= #invertedSequence then
        local longerSequence = #normalSequence > #invertedSequence and normalSequence or invertedSequence
        local longerTagIndices = #normalSequence > #invertedSequence and normalTagIndices or invertedTagIndices
        for i = math.min(#normalSequence, #invertedSequence) + 1, #longerSequence do
            tags[longerTagIndices[i]].color = sm.color.new(1, 0, 0, 1)
            tags[longerTagIndices[i]].txt = "X"
        end
    end

    if self.outputOrigin ~= nil then
        table.insert(tags, { pos = self.outputOrigin:getWorldPosition(), color = outputColor, txt = "O" })
        local step = self.outputStep or lookingAt
        if step ~= nil and step ~= self.outputOrigin and step:getBody() == self.outputOrigin:getBody() then
            local origin = self.outputOrigin:getWorldPosition()
            local delta = step:getWorldPosition() - origin
            local numArrows = 2 ^ #normalSequence - 1
            local function renderArrow(i)
                sm.MTTensorUtil.renderVector(dots, origin + delta * i, origin + delta * (i + 1), outputColor, 0.03)
            end
            for i = 0, math.min(numArrows, 10) - 1 do
                renderArrow(i)
            end
            for i = math.max(10, numArrows - 10), numArrows - 1 do
                renderArrow(i)
            end
        end
    end

    self.nametagUpdate(tags)
    self.dotSource:set(dots)
end

function DecoderMaker.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.DecoderMaker
    local selectedShapes = {
        self.normalStart, self.normalEnd, self.invertedStart,
        self.invertedEnd, self.outputOrigin, self.outputStep
    }
    for _, shape in pairs(selectedShapes) do
        if not sm.exists(shape) then
            DecoderMaker.cleanUp(multitool)
            return
        end
    end
    local normalSequence, invertedSequence = getInputSequences(self)
    local inputRowsMatch = self.invertedEnd == nil or #normalSequence == #invertedSequence
    if self.normalStart == nil then
        multitool.BlockSelector.bodyConstraint = nil
        multitool.SelectionModeController.modeActive = "BlockSelector"
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "mt.decoder.normal_start")
    elseif self.normalEnd == nil then
        multitool.BlockSelector.bodyConstraint = { self.normalStart:getBody() }
        multitool.SelectionModeController.modeActive = "BlockSelector"
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "mt.decoder.normal_end")
    elseif self.invertedStart == nil then
        multitool.BlockSelector.bodyConstraint = nil
        multitool.SelectionModeController.modeActive = "BlockSelector"
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "mt.decoder.inverted_start")
    elseif self.invertedEnd == nil then
        multitool.BlockSelector.bodyConstraint = { self.invertedStart:getBody() }
        multitool.SelectionModeController.modeActive = "BlockSelector"
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "mt.decoder.inverted_end")
    elseif not inputRowsMatch then
        multitool.BlockSelector.bodyConstraint = nil
        multitool.SelectionModeController.modeActive = nil
        multitool.ConnectionManager.preview = {}
        self.outputOrigin = nil
        self.outputStep = nil
        sm.gui.setInteractionText("mt.decoder.input_lengths", "", "")
    elseif self.outputOrigin == nil then
        multitool.BlockSelector.bodyConstraint = nil
        multitool.SelectionModeController.modeActive = "BlockSelector"
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "mt.decoder.output_origin")
    elseif self.outputStep == nil then
        multitool.BlockSelector.bodyConstraint = { self.outputOrigin:getBody() }
        multitool.SelectionModeController.modeActive = "BlockSelector"
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "mt.decoder.output_next")
    else
        multitool.BlockSelector.bodyConstraint = nil
        multitool.SelectionModeController.modeActive = nil
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "mt.decoder.build")
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true), "mt.common.toggle",
            "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
            tr("mt.common." .. multitool.ConnectionManager.mode) .. "</p>")
        if MTMultitool.handleForceBuild(multitool, forceBuild) then
            ConnectionManager.toggleMode(multitool)
        end
    end
    if primaryState == 1 then
        if self.normalStart == nil then
            self.normalStart = lookingAt
        elseif self.normalEnd == nil then
            self.normalEnd = lookingAt
        elseif self.invertedStart == nil then
            self.invertedStart = lookingAt
        elseif self.invertedEnd == nil then
            self.invertedEnd = lookingAt
        elseif not inputRowsMatch then
            multitool.ConnectionManager.preview = {}
        elseif self.outputOrigin == nil then
            self.outputOrigin = lookingAt
        elseif self.outputStep == nil then
            if lookingAt ~= nil and lookingAt ~= self.outputOrigin and lookingAt:getBody() == self.outputOrigin:getBody() then
                self.outputStep = lookingAt
                DecoderMaker.calculatePreview(multitool)
            end
        else
            ConnectionManager.commitPreviewWithBackup(multitool, {
                hasCreationData = false,
                body = self.outputOrigin:getBody(),
                nameId = "mt.backup.name.decoder",
                descriptionId = "mt.backup.description.decoder",
            })
            DecoderMaker.cleanUp(multitool, true)
        end
    elseif secondaryState == 1 then
        if self.outputStep ~= nil then
            self.outputStep = nil
            multitool.ConnectionManager.preview = {}
        elseif self.outputOrigin ~= nil then
            self.outputOrigin = nil
        elseif self.invertedEnd ~= nil then
            self.invertedEnd = nil
        elseif self.invertedStart ~= nil then
            self.invertedStart = nil
        elseif self.normalEnd ~= nil then
            self.normalEnd = nil
        elseif self.normalStart ~= nil then
            self.normalStart = nil
        end
    end
    updateDecoderNametags(multitool, lookingAt)
end

function DecoderMaker.calculatePreview(multitool)
    local self = multitool.DecoderMaker
    if self.outputStep == nil or self.outputOrigin == nil then
        multitool.ConnectionManager.preview = {}
        return
    end
    local voxelGrid = MTMultitoolLib.createVoxelGrid(self.outputOrigin:getBody())
    local outputDelta = MTMultitoolLib.getLocalCenter(self.outputStep) -
        MTMultitoolLib.getLocalCenter(self.outputOrigin)
    local listOfNormalInputs = MTMultitoolLib.findSequeceOfGates(self.normalStart, self.normalEnd)
    local listOfInvertedInputs = MTMultitoolLib.findSequeceOfGates(self.invertedStart, self.invertedEnd)
    if #listOfNormalInputs ~= #listOfInvertedInputs then
        multitool.ConnectionManager.preview = {}
        return
    end
    local numOutputs = 2 ^ #listOfNormalInputs
    multitool.ConnectionManager.preview = {}
    local originPosition = MTMultitoolLib.getLocalCenter(self.outputOrigin)
    for i = 0, numOutputs - 1 do
        local shape = MTMultitoolLib.getShapeAtVoxelGrid(voxelGrid, originPosition + outputDelta * i)
        local inputs = {}
        -- convert i to binary
        local binary = {}
        local num = i
        for j = 1, #listOfNormalInputs do
            table.insert(binary, num % 2)
            num = math.floor(num / 2)
        end
        for j = 1, #listOfNormalInputs do
            if binary[j] == 0 then
                table.insert(inputs, listOfInvertedInputs[j])
            else
                table.insert(inputs, listOfNormalInputs[j])
            end
        end
        for j, input in ipairs(inputs) do
            if input ~= nil and shape ~= nil then
                local task = {
                    from = input,
                    to = shape
                }
                table.insert(multitool.ConnectionManager.preview, task)
            end
        end
    end
end

function DecoderMaker.cleanUp(multitool, noclearpreview)
    local self = multitool.DecoderMaker
    self.nametagUpdate(nil)
    self.dotSource:clear()
    self.normalStart = nil
    self.normalEnd = nil
    self.invertedStart = nil
    self.invertedEnd = nil
    self.outputOrigin = nil
    self.outputStep = nil
    multitool.BlockSelector.bodyConstraint = nil
    if noclearpreview ~= true then
        multitool.ConnectionManager.preview = {}
    end
end