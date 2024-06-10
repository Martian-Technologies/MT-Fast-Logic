local CreationUtil = CreationUtil or {}

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.Creations = sm.MTFastLogic.Creations or {}
sm.MTFastLogic.CreationUtil = CreationUtil

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
