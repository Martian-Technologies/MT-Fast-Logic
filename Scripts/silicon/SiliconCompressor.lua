SiliconCompressor = SiliconCompressor or {
    Versions = {}
}

dofile "compressorVersions/Version1.lua"
dofile "compressorVersions/Version2.lua"

local highestVersion = "a"

function SiliconCompressor.decompressBlockData(siliconBlock, blockData)
    if blockData == nil then return {} end
    local firstChar = string.sub(blockData, 1, 1)
    print(firstChar)
    local version = SiliconCompressor.Versions[firstChar]
    print(version)
    if version == nil then
        version = SiliconCompressor.Versions["default"]
    else
        blockData = string.sub(blockData, 2)
    end
    return version.decompressBlockData(siliconBlock, blockData)
end

function SiliconCompressor.compressBlocks(siliconBlock)
    local dataString = SiliconCompressor.Versions[highestVersion].compressBlocks(siliconBlock)
    if highestVersion ~= "default" then
        local data = highestVersion .. dataString
        return data
    end
    return dataString
end