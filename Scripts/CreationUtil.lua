local CreationUtil = CreationUtil or {}

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.Creations = sm.MTFastLogic.Creations or {}
sm.MTFastLogic.CreationUtil = CreationUtil
sm.MTFastLogic.UsedUuids = sm.MTFastLogic.UsedUuids or {}

function CreationUtil.MakeCreationData(creationId, body, lastSeenSpeed)
    sm.MTFastLogic.Creations[creationId] = {
        FastLogicRealBlockMannager = FastLogicRealBlockMannager.getNew(creationId),
        FastLogicAllBlockMannager = FastLogicAllBlockMannager.getNew(creationId),
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
    sm.MTFastLogic.Creations[creationId].FastLogicRealBlockMannager:init()
    sm.MTFastLogic.Creations[creationId].FastLogicAllBlockMannager:init()
    sm.MTFastLogic.Creations[creationId].FastLogicRunner:init()
    if lastSeenSpeed ~= nil then
        sm.MTFastLogic.Creations[creationId].FastLogicRunner.numberOfUpdatesPerTick = lastSeenSpeed
    end
end

function CreationUtil.getCreationId(body)
    local id = body:getId()
    for _, b in pairs(body:getCreationBodies()) do
        if id > b:getId() then
            id = b:getId()
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
        reation.NewBlockUuids[currentTick][uuid] = true
        return uuid
    end
    if creation.NewBlockUuids[currentTick][uuid] ~= nil then
        return creation.NewBlockUuids[currentTick][uuid]
    end
    local newUuid = CreationUtil.newUuid()
    creation.NewBlockUuids[currentTick][uuid] = newUuid
    return newUuid
end
