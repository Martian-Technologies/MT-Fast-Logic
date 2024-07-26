VolumePlacer = {}

function VolumePlacer.inject(multitool)
    multitool.VolumePlacer = {}
    local self = multitool.VolumePlacer
end

function VolumePlacer.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.VolumePlacer
    multitool.BlockSelector.enabled = false
    multitool.VolumeSelector.enabled = true

    multitool.VolumeSelector.modes = { "vanilla", "fast" }
    multitool.VolumeSelector.modesNice = { "Vanilla Logic", "Fast Logic" }
    multitool.VolumeSelector.actionWord = "Place"
    multitool.VolumeSelector.isBeta = false
    multitool.VolumeSelector.selectionMode = "outside"
    multitool.VolumeSelector.doConfirm = true

    local result = VolumeSelector.trigger(multitool, primaryState, secondaryState, forceBuild)
    if result == nil then
        return
    end

    multitool.network:sendToServer("server_volumePlace", {
        origin = result.origin,
        final = result.final,
        body = result.body,
        placingType = result.mode
    })
end

function VolumePlacer.cleanUp(multitool)
    VolumeSelector.cleanUp(multitool)
end

function VolumePlacer.cleanNametags(multitool)
    VolumeSelector.cleanNametags(multitool)
end