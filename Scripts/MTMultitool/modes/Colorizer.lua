Colorizer = {}

-- FastLogicRealBlockManager.changeConnectionColor

function Colorizer.inject(multitool)
    multitool.colorizer = {}
    local self = multitool.colorizer
    self.displayingGUI = false
    self.selectedColor = 1
end

local connectionColors = {
    sm.color.new(0.9333333333333333, 0.9333333333333333, 0.9333333333333333),
    sm.color.new(0.4980392156862745, 0.4980392156862745, 0.4980392156862745),
    sm.color.new(0.2901960784313726, 0.2901960784313726, 0.2901960784313726),
    sm.color.new(0.13333333333333333, 0.13333333333333333, 0.13333333333333333),
    sm.color.new(0.9607843137254902, 0.9411764705882353, 0.44313725490196076),
    sm.color.new(0.8862745098039215, 0.8588235294117647, 0.07450980392156863),
    sm.color.new(0.5058823529411764, 0.48627450980392156, 0.0),
    sm.color.new(0.19607843137254902, 0.18823529411764706, 0.0),
    sm.color.new(0.796078431372549, 0.9647058823529412, 0.43529411764705883),
    sm.color.new(0.6274509803921569, 0.9176470588235294, 0.0),
    sm.color.new(0.3411764705882353, 0.49019607843137253, 0.027450980392156862),
    sm.color.new(0.21568627450980393, 0.3137254901960784, 0.0),
    sm.color.new(0.40784313725490196, 1.0, 0.5333333333333333),
    sm.color.new(0.09803921568627451, 0.9058823529411765, 0.3254901960784314),
    sm.color.new(0.054901960784313725, 0.5019607843137255, 0.19215686274509805),
    sm.color.new(0.023529411764705882, 0.25098039215686274, 0.13725490196078433),
    sm.color.new(0.49411764705882355, 0.9294117647058824, 0.9294117647058824),
    sm.color.new(0.17254901960784313, 0.9019607843137255, 0.9019607843137255),
    sm.color.new(0.06666666666666667, 0.5294117647058824, 0.5294117647058824),
    sm.color.new(0.0392156862745098, 0.26666666666666666, 0.26666666666666666),
    sm.color.new(0.2980392156862745, 0.43529411764705883, 0.8901960784313725),
    sm.color.new(0.0392156862745098, 0.24313725490196078, 0.8862745098039215),
    sm.color.new(0.058823529411764705, 0.1803921568627451, 0.5686274509803921),
    sm.color.new(0.0392156862745098, 0.11372549019607843, 0.35294117647058826),
    sm.color.new(0.6823529411764706, 0.4745098039215686, 0.9411764705882353),
    sm.color.new(0.4588235294117647, 0.0784313725490196, 0.9294117647058824),
    sm.color.new(0.3137254901960784, 0.0392156862745098, 0.6509803921568628),
    sm.color.new(0.20784313725490197, 0.03137254901960784, 0.4235294117647059),
    sm.color.new(0.9333333333333333, 0.4823529411764706, 0.9411764705882353),
    sm.color.new(0.8117647058823529, 0.06666666666666667, 0.8235294117647058),
    sm.color.new(0.4470588235294118, 0.0392156862745098, 0.4549019607843137),
    sm.color.new(0.3215686274509804, 0.023529411764705882, 0.3254901960784314),
    sm.color.new(0.9411764705882353, 0.403921568627451, 0.403921568627451),
    sm.color.new(0.8156862745098039, 0.1450980392156863, 0.1450980392156863),
    sm.color.new(0.48627450980392156, 0.0, 0.0),
    sm.color.new(0.33725490196078434, 0.00784313725490196, 0.00784313725490196),
    sm.color.new(0.9333333333333333, 0.6862745098039216, 0.3607843137254902),
    sm.color.new(0.8745098039215686, 0.4980392156862745, 0.0),
    sm.color.new(0.403921568627451, 0.23137254901960785, 0.0),
    sm.color.new(0.2784313725490196, 0.1568627450980392, 0.0),
}

local function injectElements(multitool)
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
                position = { a = (col - 5.5) * 0.07, e = (row) * 0.07 + 0.0 }, -- a = azimuth, e = elevation
                color = connectionColors[i],
                angleBoundHorizontal = 0.035,
                angleBoundVertical = 0.035,
                -- getText = function()
                --     return "▉"
                -- end,
                getrender = function(hovering)
                    local text = "▉"
                    local color = connectionColors[i]
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
        position = { a = 0.0, e = 0.07 * 5 }, -- a = azimuth, e = elevation
        color = sm.color.new(0.9, 0.2, 0.2),
        text = "Close",
        angleBoundHorizontal = 0.1,
        angleBoundVertical = 0.05,
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
        -- 40 colors
        -- multitool.VolumeSelector.modes = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40 }
        -- multitool.VolumeSelector.modesNice = {
        --     "White", "Light Gray", "Dark Gray", "Black",
        --     "Light Yellow", "Yellow", "Dim Yellow", "Dark Yellow",
        --     "Light Lime", "Lime", "Dim Lime", "Dark Lime",
        --     "Light Green", "Green", "Dim Green", "Dark Green",
        --     "Light Cyan", "Cyan", "Dim Cyan", "Dark Cyan",
        --     "Light Blue", "Blue", "Dim Blue", "Dark Blue",
        --     "Light Purple", "Purple", "Dim Purple", "Dark Purple",
        --     "Light Magenta", "Magenta", "Dim Magenta", "Dark Magenta",
        --     "Light Red", "Red", "Dim Red", "Dark Red",
        --     "Light Orange", "Orange", "Light Brown", "Dark Brown"
        -- }
        multitool.VolumeSelector.actionWord = "Colorize"
        multitool.VolumeSelector.isBeta = false
        multitool.VolumeSelector.selectionMode = "inside"
        multitool.VolumeSelector.previewColor = connectionColors[self.selectedColor]


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