Colorizer = {}

dofile "../FastLogicBlockColors.lua"

-- FastLogicRealBlockManager.changeConnectionColor

function Colorizer.inject(multitool)
    multitool.colorizer = {}
    local self = multitool.colorizer
    self.displayingGUI = false
    self.selectedColor = 1            -- 1-40, "match", "invert"
    self.specialModeLast = "match"    -- "match", "invert"
    self.parameterMode = "Connection" -- "Connection", "Block"
end

local function HSVtoRGB(h, s, v)
    local r, g, b

    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)

    i = i % 6

    if i == 0 then
        r, g, b = v, t, p
    elseif i == 1 then
        r, g, b = q, v, p
    elseif i == 2 then
        r, g, b = p, v, t
    elseif i == 3 then
        r, g, b = p, q, v
    elseif i == 4 then
        r, g, b = t, p, v
    elseif i == 5 then
        r, g, b = v, p, q
    end

    return sm.color.new(r, g, b, 1)
end

local function injectElements(multitool)
    local fovMult = sm.camera.getFov() / 90
    local self = multitool.colorizer
    local hUI = multitool.HoveringUI
    hUI.elements = {}
    local colorNamesMajor = {
        "Gray", "Yellow", "Lime", "Green", "Cyan", "Blue", "Purple", "Magenta", "Red", "Orange"
    }
    local colorNameModifiers = {
        "Light ", "", "Dim ", "Dark "
    }
    local colorOverrides = {
        [1] = "White",
        [2] = "Light Gray",
        [3] = "Dark Gray",
        [4] = "Black",
        [39] = "Light Brown",
        [40] = "Dark Brown"
    }

    local colorNames = {}
    for i = 1, #colorNamesMajor do
        for j = 1, #colorNameModifiers do
            table.insert(colorNames, colorNameModifiers[j] .. colorNamesMajor[i])
        end
    end
    for i, v in pairs(colorOverrides) do
        colorNames[i] = v
    end
    for row = 1, 4 do
        for col = 1, 10 do
            local i = 41 - (row + (col - 1) * 4)
            table.insert(hUI.elements, {
                name = "color_" .. i,
                type = "customButton",
                position = { a = (col - 5.5) * 0.07 * fovMult, e = (row + 0.5) * 0.07 * fovMult + 0.0 }, -- a = azimuth, e = elevation
                color = sm.MTFastLogic.FastLogicBlockColors[i],
                angleBoundHorizontal = 0.035 * fovMult,
                angleBoundVertical = 0.035 * fovMult,
                -- getText = function()
                --     return "▉"
                -- end,
                getrender = function(hovering)
                    local text = "▉"
                    local color = sm.MTFastLogic.FastLogicBlockColors[i]
                    if self.selectedColor == i then
                        text = "▉▉"
                    end
                    if hovering then
                        text = "|" .. text .. "|"
                    end
                    return {
                        text = text,
                        color = color,
                    }
                end,
                onclick = function()
                    -- multitool.colorizer.displayingGUI = false
                    self.selectedColor = i
                end,
            })
        end
    end
    table.insert(hUI.elements, {
        name = "close",
        type = "button",
        position = { a = 0.21 * fovMult, e = 0.07 * 0.5 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.9, 0.2, 0.2),
        text = "Close",
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = 0.05 * fovMult,
        onclick = function()
            multitool.colorizer.displayingGUI = false
        end,
        tooltip = function()
            return "Close the color selection menu. Pressing escape also works."
        end,
    })
    table.insert(hUI.elements, {
        name = "parameterMode",
        type = "customButton",
        position = { a = 0, e = 0.07 * 0.5 * fovMult }, -- a = azimuth, e = elevation
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = 0.05 * fovMult,
        getrender = function(hovering)
            local text = "Connection"
            if self.parameterMode == "Block" then
                text = "Block"
            end
            if hovering then
                text = "[ " .. text .. " ]"
            end
            return {
                text = text,
                color = sm.color.new(0.2, 0.2, 0.9),
            }
        end,
        onclick = function()
            if self.parameterMode == "Connection" then
                self.parameterMode = "Block"
            else
                self.parameterMode = "Connection"
            end
        end,
        tooltip = function()
            if self.parameterMode == "Connection" then
                return "Currently, the color of connection dots will be changed. Click to change to block color."
            else
                return "Currently, the color of blocks will be changed. Click to change to connection dot color."
            end
        end,
    })
    table.insert(hUI.elements, {
        name = "specialColorModes",
        type = "customButton",
        position = { a = -0.21 * fovMult, e = 0.07 * 0.5 * fovMult }, -- a = azimuth, e = elevation
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = 0.05 * fovMult,
        getrender = function(hovering)
            local text = "Match / I"
            if self.specialModeLast == "invert" then
                text = "Invert / M"
            end
            if hovering then
                text = "|" .. text .. "|"
            end
            local color = sm.color.new(0.2, 0.2, 0.5)
            if self.selectedColor == "match" or self.selectedColor == "invert" then
                local hue = os.clock() / 3
                color = HSVtoRGB(hue, 0.8, 0.9)
            end
            return {
                text = text,
                color = color,
            }
        end,
        onclick = function()
            if self.selectedColor == "match" or self.selectedColor == "invert" then
                if self.specialModeLast == "match" then
                    self.specialModeLast = "invert"
                else
                    self.specialModeLast = "match"
                end
            end
            self.selectedColor = self.specialModeLast
        end,
        tooltip = function()
            if self.selectedColor == "match" and self.parameterMode == "Connection" then
                return "Currently, the color of connection dots will be matched to the color of the block. Click to invert."
            elseif self.selectedColor == "match" and self.parameterMode == "Block" then
                return "Currently, the color of blocks will be matched to the color of the connection dot. Click to invert."
            elseif self.selectedColor == "invert" and self.parameterMode == "Connection" then
                return "Currently, the color of connection dots will be inverted from the color of the block. Click to match."
            elseif self.selectedColor == "invert" and self.parameterMode == "Block" then
                return "Currently, the color of blocks will be inverted from the color of the connection dot. Click to match."
            end
            return "Click to enable special color modes."
        end,
    })
    table.insert(hUI.elements, {
        name = "info",
        type = "indicator",
        position = { a = 0, e = 0.07 * -0.5 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.9, 0.9, 0.9),
        getText = function()
            return "Changing the color of connection dots only works on Fast Logic gates."
        end,
        angleBoundHorizontal = 0.2 * fovMult,
        angleBoundVertical = 0.05 * fovMult,
    })
end

function Colorizer.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.colorizer
    multitool.SelectionModeController.modeActive = "VolumeSelector"

    local hasForceBuilt = MTMultitool.handleForceBuild(multitool, forceBuild)
    if hasForceBuilt then
        self.displayingGUI = not self.displayingGUI
    end

    if not self.displayingGUI then
        HoveringUI.cleanUp(multitool)
        multitool.VolumeSelector.modes = nil
        multitool.VolumeSelector.actionWord = "Colorize"
        multitool.VolumeSelector.isBeta = false
        multitool.VolumeSelector.selectionMode = "inside"
        local previewColor = nil
        if self.selectedColor ~= "match" and self.selectedColor ~= "invert" then
            previewColor = sm.MTFastLogic.FastLogicBlockColors[self.selectedColor]
        else
            local hue = os.clock() / 3
            previewColor = HSVtoRGB(hue, 0.8, 0.9)
        end
        multitool.VolumeSelector.previewColor = previewColor
        multitool.VolumeSelector.doConfirm = true


        -- print("Colorizer")
        local result = VolumeSelector.trigger(multitool, primaryState, secondaryState, forceBuild, {
            selectOrigin = "     "..sm.gui.getKeyBinding("ForceBuild", true) .. " Change Color",
            selectFinal = "",
            confirm = ""
        })
        if result == nil then
            return
        end
        
        multitool.network:sendToServer("server_recolor", {
            origin = result.origin,
            final = result.final,
            color = self.selectedColor,
            mode = self.parameterMode,
            body = result.body
        })
    else
        if multitool.HoveringUI.elements == nil then
            injectElements(multitool)
        end
        HoveringUI.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    end
end

function Colorizer.cleanUp(multitool)
    VolumeSelector.cleanUp(multitool)
end

function Colorizer.cleanNametags(multitool)
    VolumeSelector.cleanNametags(multitool)
end