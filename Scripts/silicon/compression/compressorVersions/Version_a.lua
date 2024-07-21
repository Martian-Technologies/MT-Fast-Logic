dofile "../../../util/compressionUtil/compressionUtil.lua"

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.SiliconCompressor = sm.MTFastLogic.SiliconCompressor or {}
sm.MTFastLogic.SiliconCompressor.Versions = sm.MTFastLogic.SiliconCompressor.Versions or {}
sm.MTFastLogic.SiliconCompressor.Versions["a"] = {}
local compressor = sm.MTFastLogic.SiliconCompressor.Versions["a"]

compressor.compressBlocks = function (siliconBlock)
    local dataString = sm.MTFastLogic.SiliconCompressor.Versions["tagless"].compressBlocks(siliconBlock)
    local compressedData = sm.MTFastLogic.CompressionUtil.LibDeflate:CompressDeflate(dataString)
    local data = sm.MTFastLogic.CompressionUtil.LibDeflate:EncodeForPrint(compressedData)
    return data
end

compressor.decompressBlockData = function(siliconBlock, rawData)
    local decodedData = sm.MTFastLogic.CompressionUtil.LibDeflate:DecodeForPrint(rawData)
    local blockData = sm.MTFastLogic.CompressionUtil.LibDeflate:DecompressDeflate(decodedData)
    return sm.MTFastLogic.SiliconCompressor.Versions["tagless"].decompressBlockData(siliconBlock, blockData)
end