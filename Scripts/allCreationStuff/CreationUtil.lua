dofile "../fastLogicAllBlockManager/FastLogicAllBlockManager.lua"
dofile "../fastLogicBlock/FastLogicRunner.lua"
dofile "../fastLogicRealBlockManager/FastLogicRealBlockManager.lua"

local CreationUtil = CreationUtil or {}

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.Creations = sm.MTFastLogic.Creations or {}
sm.MTFastLogic.CreationUtil = CreationUtil
sm.MTFastLogic.UsedUuids = sm.MTFastLogic.UsedUuids or {}

function CreationUtil.MakeCreationData(creationId, body, lastSeenSpeed)
    sm.MTFastLogic.Creations[creationId] = {
        FastLogicRealBlockManager = FastLogicRealBlockManager.getNew(creationId),
        FastLogicAllBlockManager = FastLogicAllBlockManager.getNew(creationId),
        FastLogicRunner = FastLogicRunner.getNew(creationId),
        FastLogicGates = {},
        FastTimers = {},
        EndTickButtons = {},
        FastLights = {},
        BlocksToScan = {},
        AllFastBlocks = {},
        AllNonFastBlocks = {},
        SiliconBlocks = {},
        body = body,
        blocks = {},
        uuids = {},
        ids = {},
        lastBodyUpdate = 0,
        NewBlockUuids = {}
    }
    sm.MTFastLogic.Creations[creationId].FastLogicRealBlockManager:init()
    sm.MTFastLogic.Creations[creationId].FastLogicAllBlockManager:init()
    sm.MTFastLogic.Creations[creationId].FastLogicRunner:init()
    if lastSeenSpeed ~= nil then
        sm.MTFastLogic.Creations[creationId].FastLogicRunner.numberOfUpdatesPerTick = lastSeenSpeed
    end
end

function CreationUtil.getCreationIdFromBlock(block)
    if block == nil or block.shape == nil then return nil end
    -- copied from getCreationId for speed
    local id = 1000000000
    local bodies = block.shape:getBody():getCreationBodies()
    for i = 1, #bodies do
        local b = bodies[i]
        local bId = b:getId()
        if id > bId then
            id = bId
        end
    end
    return id
end

function CreationUtil.getCreationId(body)
    local id = 1000000000
    local bodies = body:getCreationBodies()
    for i = 1, #bodies do
        local b = bodies[i]
        local bId = b:getId()
        if id > bId then
            id = bId
        end
    end
    return id
end

function CreationUtil.newUuid() -- should never return true
    local uuid = string.uuid()
    while sm.MTFastLogic.UsedUuids[uuid] ~= nil do
        uuid = string.uuid()
    end
    sm.MTFastLogic.UsedUuids[uuid] = true
    return uuid
end

function CreationUtil.updateOldUuid(uuid, creationId)
    local creation = sm.MTFastLogic.Creations[creationId]
    local currentTick = sm.game.getCurrentTick()
    if creation.NewBlockUuids[currentTick] == nil then
        creation.NewBlockUuids = {}
        creation.NewBlockUuids[currentTick] = {}
    end
    if sm.MTFastLogic.UsedUuids[uuid] == nil or creation.blocks[uuid] ~= nil or creation.NewBlockUuids[currentTick][uuid] == true then
        sm.MTFastLogic.UsedUuids[uuid] = true
        creation.NewBlockUuids[currentTick][uuid] = true
        return uuid
    end
    if creation.NewBlockUuids[currentTick][uuid] ~= nil then
        return creation.NewBlockUuids[currentTick][uuid]
    end
    local newUuid = CreationUtil.newUuid()
    creation.NewBlockUuids[currentTick][uuid] = newUuid
    return newUuid
end
