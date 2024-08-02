dofile "../util/util.lua"

dofile "../util/compressionUtil/CompressionUtil.lua"
dofile "../util/compressionUtil/LibDeflate.lua"

local function sendStatesToClients(self, changedUuidsArray)
    local status, result = pcall(self.network.sendToClients, self.network, "client_updateTexturesAndStates",
        table.arrayToString(changedUuidsArray))
    if not status then
        -- split changedUuids in two and try again
        local half = math.floor(#changedUuidsArray / 2)
        local t1 = {}
        local t2 = {}
        for i = 1, half do
            t1[i] = changedUuidsArray[i]
        end
        for i = half + 1, #changedUuidsArray do
            t2[i - half] = changedUuidsArray[i]
        end
        sendStatesToClients(self, t1)
        sendStatesToClients(self, t2)
    end
end

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
        end
        if #changedUuidsArray > 0 then
            sendStatesToClients(self, changedUuidsArray)
            changedUuidsArray = {}
        end
        self.changedUuidsArray = {}
    end
end

function FastLogicRunnerRunner.client_updateTexturesAndStates(self, changedData)
    changedData = table.stringToArray(changedData)
    for i = 1, #changedData do
        local block = sm.MTFastLogic.client_FastLogicBlockLookUp[math.floor(changedData[i] / 2)]
        if block ~= nil then
            block:client_updateTexture(changedData[i] % 2 == 1)
        end
    end
end
