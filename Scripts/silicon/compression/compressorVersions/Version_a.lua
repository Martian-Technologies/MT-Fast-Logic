dofile "../../../util/compressionUtil/compressionUtil.lua"

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.SiliconCompressor = sm.MTFastLogic.SiliconCompressor or {}
sm.MTFastLogic.SiliconCompressor.Versions = sm.MTFastLogic.SiliconCompressor.Versions or {}
sm.MTFastLogic.SiliconCompressor.Versions["a"] = {}
local compressor = sm.MTFastLogic.SiliconCompressor.Versions["a"]

compressor.compressBlocks = function (siliconBlock)
    if siliconBlock.data.blocks == nil then return {} end
    local blocks = table.makeArray(siliconBlock.size[1] * siliconBlock.size[2] * siliconBlock.size[3])
    local colorHash = {}
    local colorIndex = 1
    for i = 1, #siliconBlock.data.blocks do
        local block = siliconBlock.data.blocks[i]
        local color = block.color:getHexStr()
        if colorHash[color] == nil then
            colorHash[color] = colorIndex
            colorIndex = colorIndex + 1
        end
        local inputs = table.copy(block.inputs)
        if siliconBlock.creation ~= nil then
            local j = 1
            while j <= #inputs do
                if siliconBlock.creation.blocks[inputs[j]] ~= nil and siliconBlock.creation.blocks[inputs[j]].isSilicon then
                    table.remove(inputs, j)
                else
                    j = j + 1
                end
            end
        end
        local rotNumber = sm.MTFastLogic.CompressionUtil.rotationToNumber[tostring(block.rot[1].x) .. tostring(block.rot[1].y) .. tostring(block.rot[1].z) .. tostring(block.rot[3].x) .. tostring(block.rot[3].y) .. tostring(block.rot[3].z)]
        blocks[(block.pos.x - 0.5) + (block.pos.y - 0.5) * siliconBlock.size[1] + (block.pos.z - 0.5) * siliconBlock.size[2] * siliconBlock.size[1] + 1] = {
            rotNumber * 6 + sm.MTFastLogic.CompressionUtil.typeToNumber[block.type],
            block.uuid,
            inputs,
            block.outputs,
            colorHash[color],
            block.connectionColorId or 25
        }
    end
    local colorIndexHash = {}
    for color, index in pairs(colorHash) do
        colorIndexHash[index] = color
    end
    local dataString = sm.MTFastLogic.CompressionUtil.tableToString({ blocks, colorIndexHash })
    local compressedData = sm.MTFastLogic.CompressionUtil.LibDeflate:CompressDeflate(dataString)
    local data = sm.MTFastLogic.CompressionUtil.LibDeflate:EncodeForPrint(compressedData)
    return data
end

compressor.decompressBlockData = function(siliconBlock, rawData)
    local decodedData = sm.MTFastLogic.CompressionUtil.LibDeflate:DecodeForPrint(rawData)
    local blockData = sm.MTFastLogic.CompressionUtil.LibDeflate:DecompressDeflate(decodedData)
    if blockData == nil then return {} end
    blockData = sm.MTFastLogic.CompressionUtil.stringToTable(blockData)
    if blockData == nil then return {} end
    local colorIndexHash = blockData[2]
    local onlyBlockData = blockData[1]
    local blocks = {}
    for i = 1, #onlyBlockData do
        local block = onlyBlockData[i]
        if block ~= nil and block ~= false then
            blocks[#blocks + 1] = {
                type = sm.MTFastLogic.CompressionUtil.numberToType[math.fmod(block[1], 6)],
                uuid = block[2],
                pos = sm.vec3.new(
                    math.fmod(i - 1, siliconBlock.size[1]) + 0.5,
                    math.floor(math.fmod(i - 1, siliconBlock.size[2] * siliconBlock.size[1]) / siliconBlock.size[1]) +
                    0.5,
                    math.floor((i - 1) / (siliconBlock.size[2] * siliconBlock.size[1])) + 0.5
                ),
                rot = sm.MTFastLogic.CompressionUtil.numberToRotation[math.floor(block[1] / 6)],
                inputs = block[3],
                outputs = block[4],
                state = false,
                color = sm.color.new(colorIndexHash[block[5]]),
                connectionColorId = block[6],
            }
        end
    end
    return blocks
end