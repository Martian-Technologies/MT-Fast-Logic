VolumeDeleter = {}

function VolumeDeleter.inject(multitool)
    multitool.VolumeDeleter = {}
    local self = multitool.VolumeDeleter
end

function VolumeDeleter.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.VolumeDeleter
    multitool.SelectionModeController.modeActive = "VolumeSelector"

    multitool.VolumeSelector.modes = nil
    multitool.VolumeSelector.isBeta = false
    multitool.VolumeSelector.actionWord = "Delete"
    multitool.VolumeSelector.selectionMode = "inside"
    multitool.VolumeSelector.doConfirm = true

    local result = VolumeSelector.trigger(multitool, primaryState, secondaryState, forceBuild)
    if result == nil then
        return
    end

    multitool.network:sendToServer("server_volumeDelete", {
        origin = result.origin,
        final = result.final,
        body = result.body
    })
end

function VolumeDeleter.cleanUp(multitool)
    VolumeSelector.cleanUp(multitool)
end

function VolumeDeleter.cleanNametags(multitool)
    VolumeSelector.cleanNametags(multitool)
end