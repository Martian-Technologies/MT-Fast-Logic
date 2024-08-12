DecoderMaker = {}

function DecoderMaker.inject(multitool)
    multitool.DecoderMaker = {}
    local self = multitool.DecoderMaker
    self.nametagUpdate = NametagManager.createController(multitool)
    self.listOfNormalInputs = {}
    self.listOfInvertedInputs = {}
    self.outputOrigin = nil
    self.outputFirst = nil
    self.mode = "normal"
end

function DecoderMaker.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.DecoderMaker
    multitool.ConnectionManager.displayMode = "slow"
    local needToUpdateNametags = false
    multitool.SelectionModeController.modeActive = "BlockSelector"
    if self.outputFirst ~= nil and self.outputOrigin ~= nil then
        if primaryState == 1 then
            DecoderMaker.calculatePreview(multitool)
            ConnectionManager.commitPreview(multitool)
            DecoderMaker.cleanUp(multitool)
        end
        if MTMultitool.handleForceBuild(multitool, forceBuild) then
            ConnectionManager.toggleMode(multitool)
        end
    end
    if self.mode == "normal" then
        -- print(primaryState)
        if primaryState == 1 and lookingAt ~= nil then
            table.insert(self.listOfNormalInputs, lookingAt)
            needToUpdateNametags = true
        end
        if secondaryState == 1 then
            if #self.listOfNormalInputs > 0 then
                table.remove(self.listOfNormalInputs)
                needToUpdateNametags = true
            end
        end
        if MTMultitool.handleForceBuild(multitool, forceBuild) then
            self.mode = "inverted"
            needToUpdateNametags = true
        end
    end
    if self.mode == "inverted" then
        if primaryState == 1 and lookingAt ~= nil then
            if #self.listOfInvertedInputs < #self.listOfNormalInputs then
                table.insert(self.listOfInvertedInputs, lookingAt)
                needToUpdateNametags = true
            else
                -- select the output origin
                if self.outputOrigin == nil then
                    self.outputOrigin = lookingAt
                    needToUpdateNametags = true
                elseif self.outputFirst == nil then
                    self.outputFirst = lookingAt
                    needToUpdateNametags = true
                end
            end
        end
        if secondaryState == 1 then
            if self.outputFirst ~= nil then
                self.outputFirst = nil
                needToUpdateNametags = true
            elseif self.outputOrigin ~= nil then
                self.outputOrigin = nil
                needToUpdateNametags = true
            elseif #self.listOfInvertedInputs > 0 then
                table.remove(self.listOfInvertedInputs)
                needToUpdateNametags = true
            else
                self.mode = "normal"
                needToUpdateNametags = true
            end
        end
    end
    if needToUpdateNametags then
        local color = sm.color.new(1, 1, 1, 1)
        local tags = {}
        for i, input in ipairs(self.listOfNormalInputs) do
            if input ~= nil then
                table.insert(tags, { pos = input:getWorldPosition(), txt = "i" .. i, color = color })
            end
        end
        for i, input in ipairs(self.listOfInvertedInputs) do
            if input ~= nil then
                table.insert(tags, { pos = input:getWorldPosition(), txt = "i" .. i .. "'", color = color })
            end
        end
        if self.outputOrigin ~= nil then
            table.insert(tags, { pos = self.outputOrigin:getWorldPosition(), txt = "o", color = color })
        end
        if self.outputFirst ~= nil then
            table.insert(tags, { pos = self.outputFirst:getWorldPosition(), txt = "o'", color = color })
        end
        if self.outputFirst ~= nil and self.outputOrigin ~= nil then
            -- generate connection preview
            DecoderMaker.calculatePreview(multitool)
        else
            multitool.ConnectionManager.preview = {}
        end
        self.nametagUpdate(tags)
    end
end

function DecoderMaker.calculatePreview(multitool)
    local self = multitool.DecoderMaker
    if self.outputFirst == nil or self.outputOrigin == nil then
        multitool.ConnectionManager.preview = {}
        return
    end
    local voxelGrid = MTMultitoolLib.createVoxelGrid(self.outputOrigin:getBody())
    local outputDelta = MTMultitoolLib.getLocalCenter(self.outputFirst) -
        MTMultitoolLib.getLocalCenter(self.outputOrigin)
    local numOutputs = 2 ^ #self.listOfNormalInputs
    multitool.ConnectionManager.preview = {}
    local originPosition = MTMultitoolLib.getLocalCenter(self.outputOrigin)
    for i = 0, numOutputs - 1 do
        local shape = MTMultitoolLib.getShapeAtVoxelGrid(voxelGrid, originPosition + outputDelta * i)
        local inputs = {}
        -- convert i to binary
        local binary = {}
        local num = i
        for j = 1, #self.listOfNormalInputs do
            table.insert(binary, num % 2)
            num = math.floor(num / 2)
        end
        for j = 1, #self.listOfNormalInputs do
            if binary[j] == 0 then
                table.insert(inputs, self.listOfInvertedInputs[j])
            else
                table.insert(inputs, self.listOfNormalInputs[j])
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

function DecoderMaker.cleanUp(multitool)
    local self = multitool.DecoderMaker
    self.nametagUpdate(nil)
    self.listOfNormalInputs = {}
    self.listOfInvertedInputs = {}
    self.outputOrigin = nil
    self.outputFirst = nil
    self.mode = "normal"
    multitool.ConnectionManager.preview = {}
end