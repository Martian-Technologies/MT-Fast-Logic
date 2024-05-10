dofile "../util/util.lua"
local string = string
local table = table

FastLogicRealBlockMannager = FastLogicRealBlockMannager or {}

dofile "DisplayCode.lua"
dofile "NewRealStuffChecker.lua"

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
                    siliconBlock.inputs,
                    siliconBlock.outputs,
                    siliconBlock.state,
                    siliconBlock.timerLength
                )
            end
        end
    end
    self.creation.BlocksToScan = {}
end
