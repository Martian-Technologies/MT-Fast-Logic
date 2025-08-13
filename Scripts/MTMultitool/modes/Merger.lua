Merger = {}

function Merger.inject(multitool)
    multitool.Merger = {}
    local self = multitool.Merger
end

function Merger.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.Merger
    multitool.SelectionModeController.modeActive = "VolumeSelector"

    multitool.VolumeSelector.modes = nil
    multitool.VolumeSelector.isBeta = false
    multitool.VolumeSelector.actionWord = "Merge"
    multitool.VolumeSelector.selectionMode = "inside"
    multitool.VolumeSelector.doConfirm = true

    local result = VolumeSelector.trigger(multitool, primaryState, secondaryState, forceBuild, "merger")
    if result == nil then
        return
    end

    multitool.network:sendToServer("server_blockMerge", {
        origin = result.origin,
        final = result.final,
        body = result.body
    })
end

function Merger.cleanUp(multitool)
    VolumeSelector.cleanUp(multitool)
end

function Merger.cleanNametags(multitool)
    VolumeSelector.cleanNametags(multitool)
end