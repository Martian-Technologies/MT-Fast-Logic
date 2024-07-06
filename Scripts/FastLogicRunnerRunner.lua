dofile "util/util.lua"
dofile "CreationUtil.lua"
local string = string
local table = table
local type = type
local pairs = pairs

dofile "fastLogicRealBlockMannager/FastLogicRealBlockMannager.lua"
dofile "fastLogicAllBlockMannager/FastLogicAllBlockMannager.lua"
dofile "fastLogicBlock/FastLogicRunner.lua"
dofile "silicon/SiliconConverter.lua"
local SiliconConverter = SiliconConverter


FastLogicRunnerRunner = FastLogicRunnerRunner or class()

dofile "fastLogicRealBlockMannager/LogicConverter.lua"

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.Creations = sm.MTFastLogic.Creations or {}
sm.MTFastLogic.DataForSiliconBlocks = sm.MTFastLogic.DataForSiliconBlocks or {}
sm.MTFastLogic.SiliconBlocksToAddConnections = sm.MTFastLogic.SiliconBlocksToAddConnections or {{}, {}}

function FastLogicRunnerRunner.server_onFixedUpdate(self)
    if self.run then
        -- bodiesToConvert
        if self.bodiesToConvert ~= nil then
            if self.bodiesToConvert[1] ~= nil then
                for i = 1, #self.bodiesToConvert[1] do
                    self:convertBodyInternal(self.bodiesToConvert[1][i].body, self.bodiesToConvert[1][i].wantedType)
                end
            end
            self.bodiesToConvert[1] = self.bodiesToConvert[2]
            self.bodiesToConvert[2] = {}
        end
        if sm.MTFastLogic.SiliconBlocksToAddConnections[1] ~= nil then
            for i = 1, #sm.MTFastLogic.SiliconBlocksToAddConnections[1] do
                sm.MTFastLogic.SiliconBlocksToAddConnections[1][i]:addConnections()
            end
        end
        sm.MTFastLogic.SiliconBlocksToAddConnections[1] = sm.MTFastLogic.SiliconBlocksToAddConnections[2]
        sm.MTFastLogic.SiliconBlocksToAddConnections[2] = {}
        self.changedUuidsArray = {}
        for k, v in pairs(sm.MTFastLogic.Creations) do
            v.FastLogicRealBlockMannager:update()
        end
        for i = 1, #self.changedUuidsArray do
            local changedUuidsArray = {}
            for ii = 1, #self.changedUuidsArray[i] do
                if  sm.MTFastLogic.FastLogicBlockLookUp[self.changedUuidsArray[i][ii]] ~= nil then
                    changedUuidsArray[ii] = {
                        sm.MTFastLogic.FastLogicBlockLookUp[self.changedUuidsArray[i][ii]].id,
                        sm.MTFastLogic.FastLogicBlockLookUp[self.changedUuidsArray[i][ii]].state
                    }
                    print(sm.MTFastLogic.FastLogicBlockLookUp[self.changedUuidsArray[i][ii]].state)
                end
            end
            self.network:sendToClients("client_updateTexturesAndStates", changedUuidsArray)
        end
    end
end

function FastLogicRunnerRunner.server_onCreate(self)
    if sm.isHost and sm.MTFastLogic.FastLogicRunnerRunner == nil then
        self.bodiesToConvert = {}
        sm.MTFastLogic.FastLogicRunnerRunner = self
        self.run = true
    else
        self.run = false
    end
end

function FastLogicRunnerRunner.server_onDestroy(self)
end

function FastLogicRunnerRunner.server_onrefresh(self)
    self:server_onCreate()
end

function FastLogicRunnerRunner.client_sendMessage(self, message)
    sm.gui.chatMessage(message)
end

function FastLogicRunnerRunner.client_updateTexturesAndStates(self, changedIds)
    for i = 1, #changedIds do
        local block = sm.MTFastLogic.client_FastLogicBlockLookUp[changedIds[i][1]]
        if block ~= nil then
            print(changedIds[i][2])
            block:client_updateTexture(changedIds[i][2])
        end
    end
end

-- wantedType = "toSilicon" or "toFastLogic"
-- localLocations shoud be in blocks not meters
function FastLogicRunnerRunner.convertSilicon(self, wantedType, body, localLocations)
    local creationId = sm.MTFastLogic.CreationUtil.getCreationId(body)
    local creation = sm.MTFastLogic.Creations[creationId]
    if creation == nil then return end
    local allBlockMannager = creation.FastLogicAllBlockMannager
    local blocksToConvert = {}
    for i = 1, #localLocations do
        local keyPos = string.vecToString(localLocations[i])
        local blocks = allBlockMannager.locationCash[keyPos]
        if blocks ~= nil then
            for i = 1, #blocks do
                blocksToConvert[#blocksToConvert + 1] = blocks[i]
            end
        end
    end
    if wantedType == "toSilicon" then
        SiliconConverter.convertToSilicon(creationId, blocksToConvert)
    elseif wantedType == "toFastLogic" then
        SiliconConverter.convertFromSilicon(creationId, blocksToConvert)
    end
end
