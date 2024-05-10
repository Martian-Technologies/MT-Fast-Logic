dofile "../util/util.lua"
local string = string
local table = table


function FastLogicAllBlockMannager.doFixOnBlock(self, uuid)
    -- local block = self.blocks[uuid]
    -- if block ~= nil then
    --     -- inputs
    --     local inputHash = {}
    --     local i = 1
    --     while i <= #block.inputs do
    --         local inputUuid = block.inputs[i]
    --         if inputHash[inputUuid] ~= nil then
    --             table.remove(block.inputs, i)
    --         elseif self.blocks[inputUuid] == nil then
    --             self:removeOutput(inputUuid, uuid)
    --         else
    --             inputHash[inputUuid] = true
    --             if not table.contains(self.blocks[inputUuid].outputs, uuid) then
    --                 self:addOutput(inputUuid, uuid)
    --             end
    --             i = i + 1
    --         end
    --     end
    --     -- outputs
    --     local outputHash = {}
    --     i = 1
    --     while i <= #block.outputs do
    --         local outputUuid = block.outputs[i]
    --         if outputHash[outputUuid] ~= nil then
    --             table.remove(block.outputs, i)
    --         elseif self.blocks[outputUuid] == nil then
    --             self:removeOutput(uuid, outputUuid)
    --         else
    --             outputHash[outputUuid] = true
    --             if not table.contains(self.blocks[outputUuid].inputs, uuid) then
    --                 self:addOutput(uuid, outputUuid)
    --             end
    --             i = i + 1
    --         end
    --     end
    -- end
end
