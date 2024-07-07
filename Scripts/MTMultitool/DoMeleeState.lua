sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.doMeleeState = sm.MTFastLogic.doMeleeState or false

DoMeleeState = {}

function DoMeleeState.inject(multitool)
    multitool.DoMeleeState = {}
    local self = multitool.DoMeleeState
    self.enabled = false
    sm.MTFastLogic.doMeleeState = false
    DoMeleeState.syncStorage(multitool)
end

function DoMeleeState.syncStorage(multitool)
    local self = multitool.DoMeleeState
    local saveData = SaveFile.getSaveData(multitool.saveIdx)
    if saveData["config"].doMeleeState == nil then
        saveData["config"].doMeleeState = false
    end
    self.enabled = saveData["config"].doMeleeState
    sm.MTFastLogic.doMeleeState = self.enabled
end

function DoMeleeState.toggle(multitool)
    local self = multitool.DoMeleeState
    self.enabled = not self.enabled
    sm.MTFastLogic.doMeleeState = self.enabled
    local saveData = SaveFile.getSaveData(multitool.saveIdx)
    saveData["config"].doMeleeState = self.enabled
    SaveFile.setSaveData(multitool.saveIdx, saveData)
end