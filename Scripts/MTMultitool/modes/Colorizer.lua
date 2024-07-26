Colorizer = {}

dofile "../FastLogicBlockColors.lua"

-- FastLogicRealBlockManager.changeConnectionColor

function Colorizer.inject(multitool)
    multitool.colorizer = {}
    local self = multitool.colorizer
    self.displayingGUI = false
    self.selectedColor = 1
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
                position = { a = (col - 5.5) * 0.07 * fovMult, e = (row) * 0.07 * fovMult + 0.0 }, -- a = azimuth, e = elevation
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
        position = { a = 0.0, e = 0.07 * 5 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.9, 0.2, 0.2),
        text = "Close",
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = 0.05 * fovMult,
        onclick = function()
            multitool.colorizer.displayingGUI = false
        end,
    })
end

function Colorizer.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.colorizer
    multitool.BlockSelector.enabled = false
    multitool.VolumeSelector.enabled = not self.displayingGUI

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
        multitool.VolumeSelector.previewColor = sm.MTFastLogic.FastLogicBlockColors[self.selectedColor]
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
            mode = self.selectedColor - 1,
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