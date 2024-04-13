dofile "fastLogicRealBlockMannager/FastLogicRealBlockMannager.lua"
dofile "fastLogicAllBlockMannager/FastLogicAllBlockMannager.lua"
dofile "fastLogicBlock/FastLogicRunner.lua"
dofile "util/util.lua"
dofile "silicon/SiliconConverter.lua"
local SiliconConverter = SiliconConverter


FastLogicRunnerRunner = FastLogicRunnerRunner or class()

dofile "fastLogicRealBlockMannager/LogicConverter.lua"

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.Creations = sm.MTFastLogic.Creations or {}

function FastLogicRunnerRunner.server_onFixedUpdate(self)
    -- advPrint(sm.MTFastLogic, 4, 5)
    if self.run then
        if sm.MTFastLogic.BlocksToGetData ~= nil then
            for i = 1, #sm.MTFastLogic.BlocksToGetData do
                sm.MTFastLogic.BlocksToGetData[i]:getData()
            end
            sm.MTFastLogic.BlocksToGetData = {}
        end
        self.changedIdsArray = {}
        for k, v in pairs(sm.MTFastLogic.Creations) do
            v.FastLogicRealBlockMannager:update()
        end
        for i = 1, #self.changedIdsArray do
            self.network:sendToClients("client_updateTextures", self.changedIdsArray[i])
        end
    end
end

function FastLogicRunnerRunner.server_onCreate(self)
    if sm.isHost then
        sm.MTFastLogic.FastLogicRunnerRunner = self
        self.run = true
    else
        self.run = false
    end
end

function FastLogicRunnerRunner.server_onDestroy(self)
end

function FastLogicRunnerRunner.MakeCreationData(self, creationId, body, lastSeenSpeed)
    sm.MTFastLogic.Creations[creationId] = {
        ["FastLogicRealBlockMannager"] = FastLogicRealBlockMannager.getNew(creationId),
        ["FastLogicAllBlockMannager"] = FastLogicAllBlockMannager.getNew(creationId),
        ["FastLogicRunner"] = FastLogicRunner.getNew(creationId),
        ["FastLogicGates"] = {},
        ["FastTimers"] = {},
        ["EndTickButtons"] = {},
        ["FastLights"] = {},
        ["BlocksToScan"] = {},
        ["AllFastBlocks"] = {},
        ["AllNonFastBlocks"] = {},
        ["body"] = body,
        ["blocks"] = {},
        ["lastBodyUpdate"] = 0
    }
    sm.MTFastLogic.Creations[creationId].FastLogicRealBlockMannager:init()
    sm.MTFastLogic.Creations[creationId].FastLogicAllBlockMannager:init()
    sm.MTFastLogic.Creations[creationId].FastLogicRunner:init()
    if lastSeenSpeed ~= nil then
        sm.MTFastLogic.Creations[creationId].FastLogicRunner.numberOfUpdatesPerTick = lastSeenSpeed
    end
end


function FastLogicRunnerRunner.server_onrefresh(self)
    self:server_onCreate()
end

function FastLogicRunnerRunner.client_sendMessage(self, message)
    sm.gui.chatMessage( message )
end

function FastLogicRunnerRunner.client_updateTextures(self, changedIds)
    for i = 1, #changedIds do
        local block = sm.MTFastLogic.FastLogicBlockLookUp[changedIds[i]]
        if block ~= nil then
            block:client_updateTexture()
        end
    end
end

function FastLogicRunnerRunner.getCreationId(self, body)
    local id = body:getId()
    for _, b in pairs(body:getCreationBodies()) do
        if id > b:getId() then
            id = b:getId()
        end
    end
    return id
end

 -- wantedType = "toSilicon" or "toFastLogic"
 -- localLocations shoud be in blocks not meters
 function FastLogicRunnerRunner.convertSilicon(self, wantedType, body, localLocations)
    local creationId = self:getCreationId(body)
    local creation = sm.MTFastLogic.Creations[creationId]
    if creation == nil then return end
    local allBlockMannager = creation.FastLogicAllBlockMannager
    local blocksToConvert = {}
    for i = 1, #localLocations do
        local keyPos = (
            tostring(math.floor(localLocations[i].x)) .. "," ..
            tostring(math.floor(localLocations[i].y)) .. "," ..
            tostring(math.floor(localLocations[i].z))
        )
        local blocks = allBlockMannager.locationCash[keyPos]
        if blocks ~= nil then
            for i = 1, #blocks do
                blocksToConvert[#blocksToConvert+1] = blocks[i]
            end
        end
    end
    if wantedType == "toSilicon" then
        SiliconConverter.convertToSilicon(creationId, blocksToConvert)
    elseif wantedType == "toFastLogic" then
        SiliconConverter.convertFromSilicon(creationId, body, blocksToConvert)
    end
end