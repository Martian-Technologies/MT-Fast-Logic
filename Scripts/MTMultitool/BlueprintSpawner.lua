dofile "../util/compressionUtil/compressionUtil.lua"

BlueprintSpawner = {}

BlockSelector.svJobs = {}

function BlueprintSpawner.cl_spawn(multitool)
    local bpDataTbl = sm.json.open("$GAME_DATA/blueprint.json")
    for a, _ in pairs(bpDataTbl["bodies"]) do
        bpDataTbl["bodies"][a]["type"] = 0
    end
    local bpData = sm.json.writeJsonString(bpDataTbl)
    local deflatedData = sm.MTFastLogic.CompressionUtil.LibDeflate:EncodeForPrint(sm.MTFastLogic.CompressionUtil
        .LibDeflate:CompressDeflate(bpData))
    local packets = {}
    local packetSize = 10000
    local packetCount = math.ceil(#deflatedData / packetSize)
    local jobId = tostring(sm.uuid.new())
    for i = 1, packetCount do
        local packet = string.sub(deflatedData, (i - 1) * packetSize + 1, i * packetSize)
        table.insert(packets, {
            data = packet,
            jobId = jobId,
            packetCount = packetCount,
            idx = i
        })
    end
    for _, packet in ipairs(packets) do
        multitool.network:sendToServer("sv_receiveBlueprintPacket", packet)
    end
end

function BlueprintSpawner.sv_receiveBlueprintPacket(multitool, params)
    local jobId = params.jobId
    local job = BlockSelector.svJobs[jobId]
    if job == nil then
        job = {
            packets = {},
            packetCount = params.packetCount
        }
        BlockSelector.svJobs[jobId] = job
    end
    job.packets[params.idx] = params.data
    local numPacketsReceived = 0
    for i = 1, job.packetCount do
        if job.packets[i] ~= nil then
            numPacketsReceived = numPacketsReceived + 1
        end
    end
    if numPacketsReceived == job.packetCount then
        local deflatedData = ""
        for i = 1, job.packetCount do
            deflatedData = deflatedData .. job.packets[i]
        end
        local bpData = sm.MTFastLogic.CompressionUtil.LibDeflate:DecompressDeflate(
            sm.MTFastLogic.CompressionUtil.LibDeflate:DecodeForPrint(deflatedData))
        local character = multitool.tool:getOwner().character
        local creationBodies = sm.creation.importFromString(character:getWorld(), bpData,
            character:getWorldPosition() + character:getDirection() * 8, sm.quat.new(0, 0, 0, 1))
        for _, body in pairs(creationBodies) do
            body:setDestructable(true)
        end
        BlockSelector.svJobs[jobId] = nil
    else
        BlockSelector.svJobs[jobId] = job
    end
end