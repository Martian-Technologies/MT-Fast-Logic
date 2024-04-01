SiliconConverter = SiliconConverter or {}

function SiliconConverter.convertToSilicon(creationId, blockIds) -- only for FastLogicGates
    local creation = sm.MTFastLogic.Creations[creationId]
    local blocks = creation.blocks
    for _, id in ipairs(blockIds) do
        local block = blocks[id]
        if not block.isSilicon then
            if creation.AllFastBlocks[id].type == "LogicGate" then
                block.isSilicon = true
                creation.AllFastBlocks[id].shape:getBody():createBlock(
                    sm.uuid.new("772eccc1-7a99-42ef-9957-6e19977a545f"),
                    sm.vec3.new(1, 1, 1),
                    block.pos - sm.vec3.new(0.5, 0.5, 0.5),
                    true
                )
                creation.AllFastBlocks[id]:remove(false)
            end
        end
    end
end

function SiliconConverter.convertFromSilicon(creationId, body, blockIds) -- only for FastLogicGates
    -- local creation = sm.MTFastLogic.Creations[creationId]
    -- local allBlockMannager = creation.FastLogicAllBlockMannager
    -- local blocks = creation.blocks
    -- for _, id in ipairs(blockIds) do
    --     local block = blocks[id]
    --     if block.isSilicon then
    --         block.isSilicon = false
    --         creation.FastLogicRealBlockMannager:createPartWithData(body, block)
    --         creation.FastLogicAllBlockMannager:removeBlock(id)
    --     end
    --     -- local keyPos = (
    --     --     tostring(math.floor(block.pos.x)) .. "," ..
    --     --     tostring(math.floor(block.pos.y)) .. "," ..
    --     --     tostring(math.floor(block.pos.z))
    --     -- )
    -- end
end
