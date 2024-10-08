dofile "../../../util/compressionUtil/compressionUtil.lua"


sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.SiliconCompressor = sm.MTFastLogic.SiliconCompressor or {}
sm.MTFastLogic.SiliconCompressor.Versions = sm.MTFastLogic.SiliconCompressor.Versions or {}
sm.MTFastLogic.SiliconCompressor.Versions["tagless"] = {}
local compressor = sm.MTFastLogic.SiliconCompressor.Versions["tagless"]

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
        local dataAtPos = blocks[(block.pos.x - 0.5) + (block.pos.y - 0.5) * siliconBlock.size[1] + (block.pos.z - 0.5) * siliconBlock.size[2] * siliconBlock.size[1] + 1]
        if dataAtPos == nil or dataAtPos == false then
            blocks[(block.pos.x - 0.5) + (block.pos.y - 0.5) * siliconBlock.size[1] + (block.pos.z - 0.5) * siliconBlock.size[2] * siliconBlock.size[1] + 1] = {
                rotNumber * 6 + sm.MTFastLogic.CompressionUtil.typeToNumber[block.type],
                block.uuid,
                inputs,
                block.outputs,
                colorHash[color],
                block.connectionColorId or 25
            }
        elseif type(dataAtPos[1]) == "number" then
            blocks[(block.pos.x - 0.5) + (block.pos.y - 0.5) * siliconBlock.size[1] + (block.pos.z - 0.5) * siliconBlock.size[2] * siliconBlock.size[1] + 1] = {
                dataAtPos,
                {
                    rotNumber * 6 + sm.MTFastLogic.CompressionUtil.typeToNumber[block.type],
                    block.uuid,
                    inputs,
                    block.outputs,
                    colorHash[color],
                    block.connectionColorId or 25
                }
            }
        else
            blocks[(block.pos.x - 0.5) + (block.pos.y - 0.5) * siliconBlock.size[1] + (block.pos.z - 0.5) * siliconBlock.size[2] * siliconBlock.size[1] + 1][#dataAtPos + 1] = {
                rotNumber * 6 + sm.MTFastLogic.CompressionUtil.typeToNumber[block.type],
                block.uuid,
                inputs,
                block.outputs,
                colorHash[color],
                block.connectionColorId or 25
            }
        end
    end
    local colorIndexHash = {}
    for color, index in pairs(colorHash) do
        colorIndexHash[index] = color
    end
    return sm.MTFastLogic.CompressionUtil.tableToString({ blocks, colorIndexHash })
end

compressor.decompressBlockData = function(siliconBlock, blockData)
    if blockData == nil then return {} end
    blockData = sm.MTFastLogic.CompressionUtil.stringToTable(blockData)
    if blockData == nil then return {} end
    local colorIndexHash = blockData[2]
    local onlyBlockData = blockData[1]
    local blocks = {}
    for i = 1, #onlyBlockData do
        local block = onlyBlockData[i]
        if block ~= nil and block ~= false then
            if type(block[1]) == "number" then
                blocks[#blocks + 1] = {
                    type = sm.MTFastLogic.CompressionUtil.numberToType[math.fmod(block[1], 6)],
                    uuid = block[2],
                    pos = sm.vec3.new(
                        math.fmod(i - 1, siliconBlock.size[1]) + 0.5,
                        math.floor(math.fmod(i - 1, siliconBlock.size[2] * siliconBlock.size[1]) / siliconBlock.size[1]) + 0.5,
                        math.floor((i - 1) / (siliconBlock.size[2] * siliconBlock.size[1])) + 0.5
                    ),
                    rot = sm.MTFastLogic.CompressionUtil.numberToRotation[math.floor(block[1] / 6)],
                    inputs = block[3],
                    outputs = block[4],
                    state = false,
                    color = sm.color.new(colorIndexHash[block[5]]),
                    connectionColorId = block[6] or 25,
                }
            else
                for j = 1, #block do
                    local subBlock = block[j]
                    blocks[#blocks + 1] = {
                        type = sm.MTFastLogic.CompressionUtil.numberToType[math.fmod(subBlock[1], 6)],
                        uuid = subBlock[2],
                        pos = sm.vec3.new(
                            math.fmod(i - 1, siliconBlock.size[1]) + 0.5,
                            math.floor(math.fmod(i - 1, siliconBlock.size[2] * siliconBlock.size[1]) / siliconBlock.size[1]) + 0.5,
                            math.floor((i - 1) / (siliconBlock.size[2] * siliconBlock.size[1])) + 0.5
                        ),
                        rot = sm.MTFastLogic.CompressionUtil.numberToRotation[math.floor(subBlock[1] / 6)],
                        inputs = subBlock[3],
                        outputs = subBlock[4],
                        state = false,
                        color = sm.color.new(colorIndexHash[subBlock[5]]),
                        connectionColorId = subBlock[6] or 25,
                    }
                end
            end
        end
    end
    return blocks
end