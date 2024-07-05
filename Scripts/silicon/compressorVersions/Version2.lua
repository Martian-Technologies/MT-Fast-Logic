dofile "../../util/stringCompression/LibDeflate.lua"

SiliconCompressor.Versions["a"] = {}

local numberToRotation = {
    [1] = { sm.vec3.new(1, 0, 0), sm.vec3.new(0, 0, 1), sm.vec3.new(0, -1, 0) },
    [2] = { sm.vec3.new(1, 0, 0), sm.vec3.new(0, -1, 0), sm.vec3.new(0, 0, -1) },
    [3] = { sm.vec3.new(0, 1, 0), sm.vec3.new(0, 0, -1), sm.vec3.new(-1, 0, 0) },
    [4] = { sm.vec3.new(0, 1, 0), sm.vec3.new(1, 0, 0), sm.vec3.new(0, 0, -1) },
    [5] = { sm.vec3.new(0, 0, 1), sm.vec3.new(0, 1, 0), sm.vec3.new(-1, 0, 0) },
    [6] = { sm.vec3.new(0, 0, 1), sm.vec3.new(-1, 0, 0), sm.vec3.new(0, -1, 0) },
    [7] = { sm.vec3.new(0, -1, 0), sm.vec3.new(0, 0, -1), sm.vec3.new(1, 0, 0) },
    [8] = { sm.vec3.new(0, 0, -1), sm.vec3.new(0, 1, 0), sm.vec3.new(1, 0, 0) },
    [9] = { sm.vec3.new(0, 1, 0), sm.vec3.new(0, 0, 1), sm.vec3.new(1, 0, 0) },
    [10] = { sm.vec3.new(0, 0, 1), sm.vec3.new(0, -1, 0), sm.vec3.new(1, 0, 0) },
    [11] = { sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 0, 1), sm.vec3.new(0, 1, 0) },
    [12] = { sm.vec3.new(0, 0, -1), sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 1, 0) },
    [13] = { sm.vec3.new(1, 0, 0), sm.vec3.new(0, 0, -1), sm.vec3.new(0, 1, 0) },
    [14] = { sm.vec3.new(0, 0, 1), sm.vec3.new(1, 0, 0), sm.vec3.new(0, 1, 0) },
    [15] = { sm.vec3.new(-1, 0, 0), sm.vec3.new(0, -1, 0), sm.vec3.new(0, 0, 1) },
    [16] = { sm.vec3.new(0, -1, 0), sm.vec3.new(1, 0, 0), sm.vec3.new(0, 0, 1) },
    [17] = { sm.vec3.new(1, 0, 0), sm.vec3.new(0, 1, 0), sm.vec3.new(0, 0, 1) },
    [18] = { sm.vec3.new(0, 1, 0), sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 0, 1) },
    [19] = { sm.vec3.new(0, -1, 0), sm.vec3.new(0, 0, 1), sm.vec3.new(-1, 0, 0) },
    [20] = { sm.vec3.new(0, 0, -1), sm.vec3.new(0, -1, 0), sm.vec3.new(-1, 0, 0) },
    [21] = { sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 0, -1), sm.vec3.new(0, -1, 0) },
    [22] = { sm.vec3.new(0, 0, -1), sm.vec3.new(1, 0, 0), sm.vec3.new(0, -1, 0) },
    [23] = { sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 1, 0), sm.vec3.new(0, 0, -1) },
    [24] = { sm.vec3.new(0, -1, 0), sm.vec3.new(-1, 0, 0), sm.vec3.new(0, 0, -1) },
}

local rotationToNumber = {
    ["1000-10"] = 1,
    ["10000-1"] = 2,
    ["010-100"] = 3,
    ["01000-1"] = 4,
    ["001-100"] = 5,
    ["0010-10"] = 6,
    ["0-10100"] = 7,
    ["00-1100"] = 8,
    ["010100"] = 9,
    ["001100"] = 10,
    ["-100010"] = 11,
    ["00-1010"] = 12,
    ["100010"] = 13,
    ["001010"] = 14,
    ["-100001"] = 15,
    ["0-10001"] = 16,
    ["100001"] = 17,
    ["010001"] = 18,
    ["0-10-100"] = 19,
    ["00-1-100"] = 20,
    ["-1000-10"] = 21,
    ["00-10-10"] = 22,
    ["-10000-1"] = 23,
    ["0-1000-1"] = 24,
}

local typeToNumber = {
    andBlocks = 0,
    orBlocks = 1,
    xorBlocks = 2,
    nandBlocks = 3,
    norBlocks = 4,
    xnorBlocks = 5,
}

local numberToType = {
    [0] = "andBlocks",
    [1] = "orBlocks",
    [2] = "xorBlocks",
    [3] = "nandBlocks",
    [4] = "norBlocks",
    [5] = "xnorBlocks",
}

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
        local rotNumber = rotationToNumber[tostring(block.rot[1].x) .. tostring(block.rot[1].y) .. tostring(block.rot[1].z) .. tostring(block.rot[3].x) .. tostring(block.rot[3].y) .. tostring(block.rot[3].z)]
        blocks[(block.pos.x - 0.5) + (block.pos.y - 0.5) * siliconBlock.size[1] + (block.pos.z - 0.5) * siliconBlock.size[2] * siliconBlock.size[1] + 1] = {
            rotNumber * 6 + typeToNumber[block.type],
            block.uuid,
            inputs,
            block.outputs,
            colorHash[block.color]
        }
    end
    local colorIndexHash = {}
    for color, index in pairs(colorHash) do
        colorIndexHash[index] = color
    end
    local dataString = siliconBlock:tableToString({ blocks, colorIndexHash })
    return LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(dataString))
end

SiliconCompressor.Versions["a"].decompressBlockData = function(siliconBlock, rawData)
    local blockData = LibDeflate:DecompressDeflate(LibDeflate:DecodeForPrint(rawData))
    -- print(blockData)
    if blockData == nil then
        print("Failed to decompress, blockdata is nil")
        print(rawData)
    end
    if blockData == nil then return {} end
    blockData = siliconBlock:stringToTable(blockData)
    if blockData == nil then
        print("Failed to decompress AFTER decompression, blockdata is nil")
    end
    if blockData == nil then return {} end
    local colorIndexHash = blockData[2]
    local onlyBlockData = blockData[1]
    local blocks = {}
    for i = 1, #onlyBlockData do
        local block = onlyBlockData[i]
        if block ~= nil and block ~= false then
            blocks[#blocks + 1] = {
                type = numberToType[math.fmod(block[1], 6)],
                uuid = block[2],
                pos = sm.vec3.new(
                    math.fmod(i - 1, siliconBlock.size[1]) + 0.5,
                    math.floor(math.fmod(i - 1, siliconBlock.size[2] * siliconBlock.size[1]) / siliconBlock.size[1]) +
                    0.5,
                    math.floor((i - 1) / (siliconBlock.size[2] * siliconBlock.size[1])) + 0.5
                ),
                rot = numberToRotation[math.floor(block[1] / 6)],
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