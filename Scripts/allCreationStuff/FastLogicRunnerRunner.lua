dofile "../util/util.lua"
dofile "../fastLogicRealBlockManager/FastLogicRealBlockManager.lua"
dofile "../fastLogicAllBlockManager/FastLogicAllBlockManager.lua"
dofile "../fastLogicBlock/FastLogicRunner.lua"
dofile "../silicon/SiliconConverter.lua"
dofile "../util/backupEngine.lua"
dofile "CreationUtil.lua"
local string = string
local table = table
local type = type
local pairs = pairs

local SiliconConverter = SiliconConverter


FastLogicRunnerRunner = FastLogicRunnerRunner or class()

dofile "AllCreationDisplay.lua"
dofile "LogicConverter.lua"

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.Creations = sm.MTFastLogic.Creations or {}
sm.MTFastLogic.DataForSiliconBlocks = sm.MTFastLogic.DataForSiliconBlocks or {}

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
        self.changedUuidsArray = {}
        for k, v in pairs(sm.MTFastLogic.Creations) do
            v.FastLogicRealBlockManager:update()
        end
        self:updatedDisplays()
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

function FastLogicRunnerRunner.client_onCreate(self)
    if sm.isHost then
        sm.MTBackupEngine.cl_setUsername()
    end
end

-- wantedType = "toSilicon" or "toFastLogic"
-- localLocations shoud be in blocks not meters
function FastLogicRunnerRunner.convertSilicon(self, wantedType, body, localLocations)
    if not sm.exists(body) then return end
    sm.MTBackupEngine.sv_backupCreation({
        hasCreationData = false,
        body = body,
        name = "Silicon Conversion Backup",
        description = "Backup created by convertSilicon() in FastLogicRunnerRunner.lua. Converting to " .. wantedType,
    })
    local creationId = sm.MTFastLogic.CreationUtil.getCreationId(body)
    local creation = sm.MTFastLogic.Creations[creationId]
    if creation == nil then return end
    local allBlockManager = creation.FastLogicAllBlockManager
    local blocksToConvert = {}
    for i = 1, #localLocations do
        local keyPos = string.vecToString(localLocations[i])
        local blocks = allBlockManager.locationCash[keyPos]
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
