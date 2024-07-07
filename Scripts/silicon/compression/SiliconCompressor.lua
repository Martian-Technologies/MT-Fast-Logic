sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.SiliconCompressor = sm.MTFastLogic.SiliconCompressor or {
    Versions = {}
}
local SiliconCompressor = sm.MTFastLogic.SiliconCompressor


dofile "compressorVersions/Version_tagless.lua"
dofile "compressorVersions/Version_a.lua"

local highestVersion = "a"

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
    local dataString = SiliconCompressor.Versions[highestVersion].compressBlocks(siliconBlock)
    if highestVersion ~= "tagless" then
        local data = highestVersion .. dataString
        return data
    end
    return dataString
end