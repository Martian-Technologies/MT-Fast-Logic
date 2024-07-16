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
            -- if #changedUuidsArray > 10000 then
            --     self.network:sendToClients("client_updateTexturesAndStates", self:compressData(changedUuidsArray))
            --     changedUuidsArray = {}
            -- end
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
    local str = ""
    for i = 1, #data do
        if #str > 0 then str = str .. "," end
        str = str .. tostring(data[i] - (data[i-1] or 0))
    end
    local dataD = {}
    for c in str:gmatch "%d+" do
        dataD[#dataD+1] = tonumber(c) + (dataD[#dataD] or 0)
    end
    for k, v in pairs(dataD) do
        if data[k] ~= v then
            for i = 1, 100 do
                print("WHAT THE HELL")
            end
        end
    end
    return str
end

function FastLogicRunnerRunner.decompressData(self, str)
    local data = {}
    for c in str:gmatch "%d+" do
        data[#data+1] = tonumber(c) + (data[#data] or 0)
    end
    return data
end