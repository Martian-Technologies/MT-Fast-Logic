ModeChanger = {}

ModeChanger.modes = {
    "AND",
    "OR",
    "XOR",
    "NAND",
    "NOR",
    "XNOR"
}

function ModeChanger.inject(multitool)
    multitool.ModeChanger = {}
    local self = multitool.ModeChanger
end

function ModeChanger.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.ModeChanger
    multitool.BlockSelector.enabled = false
    multitool.VolumeSelector.enabled = true

    multitool.VolumeSelector.modes = { 1, 2, 3, 4, 5, 6 }
    multitool.VolumeSelector.modesNice = ModeChanger.modes
    multitool.VolumeSelector.actionWord = "Change Mode"
    multitool.VolumeSelector.isBeta = false

    local result = VolumeSelector.trigger(multitool, primaryState, secondaryState, forceBuild)
    if result == nil then
        return
    end

    multitool.network:sendToServer("server_changeModes", {
        origin = result.origin,
        final = result.final,
        mode = result.mode,
        body = result.body
    })
end

function ModeChanger.cleanUp(multitool)
    VolumeSelector.cleanUp(multitool)
end

function ModeChanger.cleanNametags(multitool)
    VolumeSelector.cleanNametags(multitool)
end