dofile "../util/util.lua"
local string = string
local table = table
local type = type
local pairs = pairs

FastLogicRealBlockMannager = FastLogicRealBlockMannager or {}

dofile "DisplayCode.lua"
dofile "NewRealStuffChecker.lua"

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.dataToSet = sm.MTFastLogic.dataToSet or {}

function FastLogicRealBlockMannager.getNew(creationId)
    local new = table.deepCopy(FastLogicRealBlockMannager)
    new.getNew = nil
    new.creationId = creationId
    return new
end

function FastLogicRealBlockMannager.init(self)
    self.creation = sm.MTFastLogic.Creations[self.creationId]
    self.FastLogicRunner = self.creation.FastLogicRunner
    self.FastLogicAllBlockMannager = self.creation.FastLogicAllBlockMannager
    self.displayedBlockStates = {}
    self.blocksWithData = {}
    self.scanNext = {}
end

function FastLogicRealBlockMannager.update(self)
    -- check if body updated
    self:addAllNewBlocks()
    self:checForBodyUpdate()

    -- check switches and other inputs
    self:checkForNewInputs()

    -- run
    local updatedGates = self.FastLogicAllBlockMannager:update()

    -- update states of fast gates
    self:updateDisplay(updatedGates)
end

function FastLogicRealBlockMannager.addAllNewBlocks(self)
    for i = 1, #self.creation.BlocksToScan do
        local block = self.creation.BlocksToScan[i]
        if block.isFastLogic == true then
            self.FastLogicAllBlockMannager:addBlock(block)
            self.scanNext[block.data.uuid] = block
        elseif block.isSilicon == true then
            for _, siliconBlock in ipairs(block.data.blocks) do
                self.FastLogicAllBlockMannager:addSiliconBlock(
                    siliconBlock.type,
                    siliconBlock.uuid,
                    siliconBlock.pos,
                    siliconBlock.rot,
                    table.copy(siliconBlock.inputs),
                    table.copy(siliconBlock.outputs),
                    siliconBlock.state,
                    siliconBlock.timerLength
                )
            end
        end
    end
    self.creation.BlocksToScan = {}
end

function FastLogicRealBlockMannager.createPartWithData(self, block, body)
    local rot = {xAxis=block.rot[1], yAxis=block.rot[2], zAxis=block.rot[3]}
    local pos = block.pos - (block.rot[1] + block.rot[2] + block.rot[3]) * 0.5-- + sm.MTUtil.getOffset(rot)
    local shape = body:createPart(sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88112"), pos, block.rot[3], block.rot[1], true)
    shape.color = sm.color.new(block.color)
    sm.MTFastLogic.dataToSet[shape:getInteractable().id] = table.deepCopy(block)
end

local typeToNumber = {
    andBlocks=0,
    orBlocks=1,
    xorBlocks=2,
    nandBlocks=3,
    norBlocks=4,
    xnorBlocks=5,
}

function FastLogicRealBlockMannager.setData(self, uuid, data)
    local block = sm.MTFastLogic.FastLogicBlockLookUp[uuid]
    block.data.uuid = data.uuid
    sm.MTFastLogic.FastLogicBlockLookUp[uuid] = nil
    sm.MTFastLogic.FastLogicBlockLookUp[block.data.uuid] = block
    for _,v in pairs(data.inputs) do
        local inputBlock = sm.MTFastLogic.FastLogicBlockLookUp[v]
        if inputBlock ~= nil then
            inputBlock.interactable:connect(block.interactable)
        end
    end
    for _,v in pairs(data.outputs) do
        local outputBlock = sm.MTFastLogic.FastLogicBlockLookUp[v]
        if outputBlock ~= nil then
            block.interactable:connect(outputBlock.interactable)
        elseif self.creation.blocks[v] ~= nil and self.creation.blocks[v].isSilicon == true then
            sm.event.sendToInteractable(self.creation.SiliconBlocks[self.creation.blocks[v].siliconBlockId].interactable, "server_resave")
        end
    end
    sm.event.sendToInteractable(block.interactable, "server_saveMode", typeToNumber[data.type])
    block.data.mode = typeToNumber[data.type]
    block:getData()
end