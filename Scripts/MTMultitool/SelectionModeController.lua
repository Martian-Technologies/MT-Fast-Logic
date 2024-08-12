SelectionModeController = {}

function SelectionModeController.inject(multitool)
    multitool.SelectionModeController = {}
    local self = multitool.SelectionModeController
    self.modeActive = nil -- nil, "BlockSelector", "VolumeSelector", "BetterVolumeSelector"
end

function SelectionModeController.trigger(multitool)
    local self = multitool.SelectionModeController
    multitool.BlockSelector.enabled = self.modeActive == "BlockSelector"
    multitool.VolumeSelector.enabled = self.modeActive == "VolumeSelector"
    multitool.BetterVolumeSelector.enabled = self.modeActive == "BetterVolumeSelector"
end