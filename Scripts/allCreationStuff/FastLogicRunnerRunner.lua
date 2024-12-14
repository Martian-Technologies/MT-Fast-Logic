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
local sm = sm

-- global to check if SComputers example has been loaded
SComputersExamplesCreated = SComputersExamplesCreated or {}

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
                    local success, result = pcall(self.convertBodyInternal, self, self.bodiesToConvert[1][i].body, self.bodiesToConvert[1][i].wantedType)
                    if not success then
                        self:sendMessageToAll("AN ERROR OCCURRED IN FAST LOGIC (id: 1). Please report to ItchyTrack on discord")
                        self:sendMessageToAll(result)
                    end
                end
            end
            self.bodiesToConvert[1] = self.bodiesToConvert[2]
            self.bodiesToConvert[2] = {}
        end
        self.changedUuidsArray = {}
        for k, v in pairs(sm.MTFastLogic.Creations) do
            -- v.FastLogicRealBlockManager:update()
            local success, result = pcall(v.FastLogicRealBlockManager.update, v.FastLogicRealBlockManager)
            if not success then
                self:sendMessageToAll("AN ERROR OCCURRED IN FAST LOGIC (id: 2). Please report to ItchyTrack on discord")
                self:sendMessageToAll(result)
            end
        end
        local success, result = pcall(self.updatedDisplays, self)
        if not success then
            self:sendMessageToAll("AN ERROR OCCURRED IN FAST LOGIC (id: 3). Please report to ItchyTrack on discord")
            self:sendMessageToAll(result)
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
    -- self:server_onCreate()
end

function FastLogicRunnerRunner.sendMessageToAll(self, message)
    self.network:sendToClients("client_sendMessage", message)
end

function FastLogicRunnerRunner.client_sendMessage(self, message)
    sm.gui.chatMessage(message)
end

function FastLogicRunnerRunner.client_onCreate(self)
    local success, result = pcall(self.createScomputersCodeAPIExamples, self)
    self.scomputersExamplesCreated = true
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

function FastLogicRunnerRunner.createScomputersCodeAPIExamples(self)
    if sm.scomputers == nil then return end
    if sm.scomputers.addExample == nil then return end
    if table.contains(SComputersExamplesCreated, sm.localPlayer.name) then return end
    SComputersExamplesCreated[#SComputersExamplesCreated + 1] = sm.localPlayer.name
sm.scomputers.addExample("MT Memory API Docs", [[ -- This code cannot be executed, this is a list of functions and their descriptions

local memory = getComponent("MTFastMemory")
-- The component type is called "MTFastMemory"
-- You can then interact with the memory block using
-- the following functions:

setValue(key: number, value: number)
-- Sets an individual value of a key in the memory

getValue(key: number)
-- Returns the value of a key in the memory block

setValues(kvPairs: table<number, number>)
-- Sets the values of multiple keys in the memory block

getValues(keys: table<number>)
-- Returns the values of multiple keys in the memory block

clearMemory()
-- Clears the memory block

setMemory(memory: table<number, number>)
-- Sets the memory block to the given table.
-- this is equivalent to calling clearMemory()
-- and then setValues(kvPairs)

getMemory()
-- Returns the memory block contents as a table]])

sm.scomputers.addExample("MT Memory API Display", [[local display = getComponent("display")
display.setOptimizationLevel(0)
local w = display.getWidth()
local h = display.getHeight()
local memory = getComponent("MTFastMemory")
-- we will assume that the memory given to us is a flattened 2D array of size w*h

function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end

    local data = memory.getMemory()
    -- this gets the whole memory block data as a table

    for y = 0, h-1 do
        for x = 0, w-1 do
            local idx = y * w + x
            local color = data[idx] or 0
            -- assume we are given 24 bits of data, 8 bits for each color component

            display.drawPixel(x, y, color)
        end
    end
    display.flush()
end]])
end