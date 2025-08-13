SiliconConverterTool = {}

function SiliconConverterTool.inject(multitool)
    multitool.SiliconConverter = {}
    local self = multitool.SiliconConverter
    self.nametagUpdate = NametagManager.createController(multitool)
end

function SiliconConverterTool.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt_NOTUSED)
    local self = multitool.SiliconConverter
    multitool.SelectionModeController.modeActive = "VolumeSelector"

    multitool.VolumeSelector.modes = { "toSilicon", "toFastLogic" }
    multitool.VolumeSelector.modesNice = { "To Silicon", "To Fast Logic" }
    multitool.VolumeSelector.actionWord = "Convert"
    multitool.VolumeSelector.isBeta = false
    multitool.VolumeSelector.selectionMode = "inside"
    multitool.VolumeSelector.doConfirm = true

    local result = VolumeSelector.trigger(multitool, primaryState, secondaryState, forceBuild, "siliconConverter")
    if result == nil then
        return
    end

    multitool.network:sendToServer("server_convertSilicon", {
        origin = result.origin,
        final = result.final,
        originBody = result.body,
        wantedType = result.mode
    })
end

function SiliconConverterTool.cleanUp(multitool)
    VolumeSelector.cleanUp(multitool)
end

function SiliconConverterTool.cleanNametags(multitool)
    VolumeSelector.cleanNametags(multitool)
end