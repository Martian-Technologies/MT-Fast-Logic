print("loading FastLogicRealBlockMannager")


dofile "../util/util.lua"

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
        self.FastLogicAllBlockMannager:addBlock(self.creation.BlocksToScan[i])
    end
    self.creation.BlocksToScan = {}
end
