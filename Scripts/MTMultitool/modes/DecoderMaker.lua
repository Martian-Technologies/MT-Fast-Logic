DecoderMaker = {}

function DecoderMaker.inject(multitool)
    multitool.DecoderMaker = {}
    local self = multitool.DecoderMaker
    self.nametagUpdate = NametagManager.createController(multitool)
    self.normalStart = nil
    self.normalEnd = nil
    self.invertedStart = nil
    self.invertedEnd = nil
    self.outputOrigin = nil
    self.outputStep = nil
end

function DecoderMaker.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.DecoderMaker
    if self.normalStart == nil then
        multitool.SelectionModeController.modeActive = "BlockSelector"
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Select the start of the normal input")
    elseif self.normalEnd == nil then
        multitool.SelectionModeController.modeActive = "BlockSelector"
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Select the end of the normal input")
    elseif self.invertedStart == nil then
        multitool.SelectionModeController.modeActive = "BlockSelector"
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Select the start of the inverted input")
    elseif self.invertedEnd == nil then
        multitool.SelectionModeController.modeActive = "BlockSelector"
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Select the end of the inverted input")
    elseif self.outputOrigin == nil then
        multitool.SelectionModeController.modeActive = "BlockSelector"
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Select the origin of the output row of gates")
    elseif self.outputStep == nil then
        multitool.SelectionModeController.modeActive = "BlockSelector"
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Select the next gate in the output row")
    else
        multitool.SelectionModeController.modeActive = nil
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Press to build the decoder")
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true), "Toggle",
            "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
            multitool.ConnectionManager.mode .. "<p>")
        if MTMultitool.handleForceBuild(multitool, forceBuild) then
            ConnectionManager.toggleMode(multitool)
        end
    end
    local updateNametags = false
    if primaryState == 1 then
        if self.normalStart == nil then
            self.normalStart = lookingAt
        elseif self.normalEnd == nil then
            self.normalEnd = lookingAt
        elseif self.invertedStart == nil then
            self.invertedStart = lookingAt
        elseif self.invertedEnd == nil then
            self.invertedEnd = lookingAt
        elseif self.outputOrigin == nil then
            self.outputOrigin = lookingAt
        elseif self.outputStep == nil then
            self.outputStep = lookingAt
            DecoderMaker.calculatePreview(multitool)
        else
            -- ConnectionManager.commitPreview(multitool)
            ConnectionManager.commitPreviewWithBackup(multitool, {
                hasCreationData = false,
                body = self.outputOrigin:getBody(),
                name = "Decoder Backup",
                description = "Backup created by decoder maker",
            })
            DecoderMaker.cleanUp(multitool, true)
        end
        updateNametags = true
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
        updateNametags = true
    end
    if updateNametags then
        local tags = {}
        if self.normalStart ~= nil then
            if self.normalEnd == nil then
                table.insert(tags, {
                    pos = self.normalStart:getWorldPosition(),
                    color = sm.color.new(0, 1, 0, 1),
                    txt = "n0"
                })
            else
                local normalSequence = MTMultitoolLib.findSequeceOfGates(self.normalStart, self.normalEnd)
                for i, shape in pairs(normalSequence) do
                    local worldPosition = shape:getWorldPosition()
                    table.insert(tags, {
                        pos = worldPosition,
                        color = sm.color.new(0, 1, 0, 1),
                        txt = string.format("n%d", i - 1)
                    })
                end
            end
        end
        if self.invertedStart ~= nil then
            if self.invertedEnd == nil then
                table.insert(tags, {
                    pos = self.invertedStart:getWorldPosition(),
                    color = sm.color.new(1, 0, 0, 1),
                    txt = "i0"
                })
            else
                local invertedSequence = MTMultitoolLib.findSequeceOfGates(self.invertedStart, self.invertedEnd)
                for i, shape in pairs(invertedSequence) do
                    local worldPosition = shape:getWorldPosition()
                    table.insert(tags, {
                        pos = worldPosition,
                        color = sm.color.new(1, 0, 0, 1),
                        txt = string.format("i%d", i - 1)
                    })
                end
            end
        end
        if self.outputOrigin ~= nil then
            table.insert(tags, {
                pos = self.outputOrigin:getWorldPosition(),
                color = sm.color.new(0, 0, 1, 1),
                txt = "o0"
            })
        end
        if self.outputStep ~= nil then
            table.insert(tags, {
                pos = self.outputStep:getWorldPosition(),
                color = sm.color.new(0, 0, 1, 1),
                txt = "o1"
            })
        end
        self.nametagUpdate(tags)
    end
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
    self.normalStart = nil
    self.normalEnd = nil
    self.invertedStart = nil
    self.invertedEnd = nil
    self.outputOrigin = nil
    self.outputStep = nil
    if noclearpreview ~= true then
        multitool.ConnectionManager.preview = {}
    end
end