dofile "../util/compressionUtil/CompressionUtil.lua"
dofile "../util/compressionUtil/LibDeflate.lua"

function FastLogicRunnerRunner.updatedDisplays(self)
    if 0 < #self.changedUuidsArray then
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
                self.network:sendToClients("client_updateTexturesAndStates", self:compressData(changedUuidsArray))
                changedUuidsArray = {}
            end
        end
        if #changedUuidsArray > 0 then
            self.network:sendToClients("client_updateTexturesAndStates", self:compressData(changedUuidsArray))
            changedUuidsArray = {}
        end
        self.changedUuidsArray = {}
    end
end

function FastLogicRunnerRunner.client_updateTexturesAndStates(self, changedData)
    changedData = self:decompressData(changedData)
    for i = 1, #changedData do
        local block = sm.MTFastLogic.client_FastLogicBlockLookUp[math.floor(changedData[i] / 2)]
        if block ~= nil then
            block:client_updateTexture(changedData[i] % 2 == 1)
        end
    end
end

function FastLogicRunnerRunner.compressData(self, data)
    return sm.MTFastLogic.CompressionUtil.tableToString(data)
end

function FastLogicRunnerRunner.decompressData(self, data)
    return sm.MTFastLogic.CompressionUtil.stringToTable(data)
end