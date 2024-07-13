Colorizer = {}

-- FastLogicRealBlockManager.changeConnectionColor

function Colorizer.inject(multitool)
    multitool.colorizer = {}
    local self = multitool.colorizer
    self.nametagUpdate = NametagManager.createController(multitool)
    self.gui = nil
end

function Colorizer.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.colorizer
    multitool.BlockSelector.enabled = false
    multitool.VolumeSelector.enabled = true

    -- 40 colors
    multitool.VolumeSelector.modes = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40 }
    multitool.VolumeSelector.modesNice = {
        "White", "Light Gray", "Dark Gray", "Black",
        "Light Yellow", "Yellow", "Dim Yellow", "Dark Yellow",
        "Light Lime", "Lime", "Dim Lime", "Dark Lime",
        "Light Green", "Green", "Dim Green", "Dark Green",
        "Light Cyan", "Cyan", "Dim Cyan", "Dark Cyan",
        "Light Blue", "Blue", "Dim Blue", "Dark Blue",
        "Light Purple", "Purple", "Dim Purple", "Dark Purple",
        "Light Magenta", "Magenta", "Dim Magenta", "Dark Magenta",
        "Light Red", "Red", "Dim Red", "Dark Red",
        "Light Orange", "Orange", "Light Brown", "Dark Brown"
    }
    multitool.VolumeSelector.actionWord = "Colorize"
    multitool.VolumeSelector.isBeta = false

    local result = VolumeSelector.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    if result == nil then
        return
    end

    multitool.network:sendToServer("server_recolor", {
        origin = result.origin,
        final = result.final,
        mode = result.mode-1,
        body = result.body
    })
end

function Colorizer.cleanUp(multitool)
    local self = multitool.colorizer
    self.origin = nil
    self.final = nil
    self.body = nil
    self.nametagUpdate(nil)
end

function Colorizer.cleanNametags(multitool)
    local self = multitool.colorizer
    self.nametagUpdate(nil)
end