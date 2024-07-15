sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.SiliconCompressor = sm.MTFastLogic.SiliconCompressor or {
    Versions = {}
}
local SiliconCompressor = sm.MTFastLogic.SiliconCompressor


dofile "compressorVersions/Version_tagless.lua"
dofile "compressorVersions/Version_a.lua"
dofile "compressorVersions/Version_b.lua"

local highestVersion = "b"

function SiliconCompressor.decompressBlockData(siliconBlock, blockData)
    if blockData == nil then return {} end
    local firstChar = string.sub(blockData, 1, 1)
    local version = SiliconCompressor.Versions[firstChar]
    if version == nil then
        version = SiliconCompressor.Versions["tagless"]
    else
        blockData = string.sub(blockData, 2)
    end
    return version.decompressBlockData(siliconBlock, blockData)
end

function SiliconCompressor.compressBlocks(siliconBlock)
    local dataStringC = SiliconCompressor.Versions[highestVersion].compressBlocks(siliconBlock)
    local dataStringU = SiliconCompressor.Versions["tagless"].compressBlocks(siliconBlock)
    local data
    local compressionUsed
    if #dataStringC < #dataStringU then
        data = dataStringC
        compressionUsed = highestVersion
    else
        data = dataStringU
        compressionUsed = "tagless"
    end
    if compressionUsed ~= "tagless" then
        data = highestVersion .. data
    end
    return data
end