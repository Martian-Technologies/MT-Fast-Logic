function FastLogicRunnerRunner.updatedDisplays(self)
    local changedUuidsArray = {}
    for i = 1, #self.changedUuidsArray do
        if sm.MTFastLogic.FastLogicBlockLookUp[self.changedUuidsArray[i]] ~= nil then
            local stateNumber = 0
            if sm.MTFastLogic.FastLogicBlockLookUp[self.changedUuidsArray[i]].state then
                stateNumber = 1
            end
            changedUuidsArray[#changedUuidsArray+1] = (
                sm.MTFastLogic.FastLogicBlockLookUp[self.changedUuidsArray[i]].id * 2 + stateNumber
            )
        end
        if #changedUuidsArray > 5000 then
            self.network:sendToClients("client_updateTexturesAndStates", changedUuidsArray)
            changedUuidsArray = {}
        end
    end
    if #changedUuidsArray > 0 then
        self.network:sendToClients("client_updateTexturesAndStates", changedUuidsArray)
        changedUuidsArray = {}
    end
end

function FastLogicRunnerRunner.client_updateTexturesAndStates(self, changedData)
    for i = 1, #changedData do
        local block = sm.MTFastLogic.client_FastLogicBlockLookUp[math.floor(changedData[i] / 2)]
        if block ~= nil then
            if changedData[i] % 2 == 1 then
                block:client_updateTexture(true)
            else
                block:client_updateTexture(false)
            end
        end
    end
end