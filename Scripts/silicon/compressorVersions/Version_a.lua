dofile "../../util/stringCompression/LibDeflate.lua"
dofile "../../util/dataUtil.lua"

SiliconCompressor.Versions["a"] = {}

SiliconCompressor.Versions["a"].compressBlocks = function (siliconBlock)
    if siliconBlock.data.blocks == nil then return {} end
    local blocks = table.makeArray(siliconBlock.size[1] * siliconBlock.size[2] * siliconBlock.size[3])
    local colorHash = {}
    local colorIndex = 1
    for i = 1, #siliconBlock.data.blocks do
        local block = siliconBlock.data.blocks[i]
        if colorHash[block.color] == nil then
            colorHash[block.color] = colorIndex
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
        local rotNumber = DataUtil.rotationToNumber[tostring(block.rot[1].x) .. tostring(block.rot[1].y) .. tostring(block.rot[1].z) .. tostring(block.rot[3].x) .. tostring(block.rot[3].y) .. tostring(block.rot[3].z)]
        blocks[(block.pos.x - 0.5) + (block.pos.y - 0.5) * siliconBlock.size[1] + (block.pos.z - 0.5) * siliconBlock.size[2] * siliconBlock.size[1] + 1] = {
            rotNumber * 6 + DataUtil.typeToNumber[block.type],
            block.uuid,
            inputs,
            block.outputs,
            colorHash[block.color],
            block.connectionColorId or 25
        }
    end
    local colorIndexHash = {}
    for color, index in pairs(colorHash) do
        colorIndexHash[index] = color
    end
    local dataString = DataUtil.tableToString({ blocks, colorIndexHash })
    local compressedData = LibDeflate:CompressDeflate(dataString)
    local data = LibDeflate:EncodeForPrint(compressedData)
    return data
end

SiliconCompressor.Versions["a"].decompressBlockData = function(siliconBlock, rawData)
    local decodedData = LibDeflate:DecodeForPrint(rawData)
    local blockData = LibDeflate:DecompressDeflate(decodedData)
    if blockData == nil then return {} end
    blockData = DataUtil.stringToTable(blockData)
    if blockData == nil then return {} end
    local colorIndexHash = blockData[2]
    local onlyBlockData = blockData[1]
    local blocks = {}
    for i = 1, #onlyBlockData do
        local block = onlyBlockData[i]
        if block ~= nil and block ~= false then
            blocks[#blocks + 1] = {
                type = DataUtil.numberToType[math.fmod(block[1], 6)],
                uuid = block[2],
                pos = sm.vec3.new(
                    math.fmod(i - 1, siliconBlock.size[1]) + 0.5,
                    math.floor(math.fmod(i - 1, siliconBlock.size[2] * siliconBlock.size[1]) / siliconBlock.size[1]) +
                    0.5,
                    math.floor((i - 1) / (siliconBlock.size[2] * siliconBlock.size[1])) + 0.5
                ),
                rot = DataUtil.numberToRotation[math.floor(block[1] / 6)],
                inputs = block[3],
                outputs = block[4],
                state = false,
                color = colorIndexHash[block[5]],
                connectionColorId = block[6],
            }
        end
    end
    return blocks
end