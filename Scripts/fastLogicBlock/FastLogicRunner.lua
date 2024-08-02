dofile "../util/util.lua"
local string = string
local table = table
local type = type
local pairs = pairs

FastLogicRunner = FastLogicRunner or {}

dofile "BlockManager.lua"
dofile "FastLogicRunnerLoop.lua"
dofile "BalancedLogicFinder.lua"
dofile "LogicOptimizer.lua"

function FastLogicRunner.getNew(creationId)
    print("new logic runner")
    local new = table.deepCopy(FastLogicRunner)
    new.creationId = creationId
    new.getNew = nil
    new.isNew = 5
    return new
end

function FastLogicRunner.init(self)
    self.creation = sm.MTFastLogic.Creations[self.creationId]
    self.numberOfUpdatesPerTick = self.numberOfUpdatesPerTick or 1
    self.updateTicks = self.updateTicks or 0
    self.blocksOptimized = self.blocksOptimized or -100
    if self.hashData == nil then
        self:makeDataArrays()
    end
end

function FastLogicRunner.makeDataArrays(self)
    -- setUpHassStuff
    self.hashData = table.makeConstantKeysOnlyHash({})
    self.unhashedLookUp = self.hashData.unhashedLookUp
    self.hashedLookUp = self.hashData.hashedLookUp
    -- make arrays
    self.blocksRan = 0
    self.lastTimerOutputWait = 0
    self.blockStates = table.makeArrayForHash(self.hashData)
    self.blockInputs = table.makeArrayForHash(self.hashData)
    self.lastBlockStates = table.makeArrayForHash(self.hashData, 0)
    self.blockInputsHash = {}
    self.runnableBlockPaths = table.makeArrayForHash(self.hashData)
    self.blockOutputs = table.makeArrayForHash(self.hashData)
    self.blockOutputsHash = {}
    self.numberOfBlockInputs = table.makeArrayForHash(self.hashData)
    self.numberOfOtherInputs = table.makeArrayForHash(self.hashData)
    self.numberOfBlockOutputs = table.makeArrayForHash(self.hashData)
    self.countOfOnInputs = table.makeArrayForHash(self.hashData)
    self.countOfOnOtherInputs = table.makeArrayForHash(self.hashData)
    self.timerData = {}
    self.timerLengths = table.makeArrayForHash(self.hashData)
    self.timerInputStates = table.makeArrayForHash(self.hashData)
    self.runnableBlockPathIds = table.makeArrayForHash(self.hashData)
    self.longestTimer = 0
    self.altBlockData = table.makeArrayForHash(self.hashData)
    self.multiBlockData = table.makeArrayForHash(self.hashData)
    self.numberOfTimesRun = table.makeArrayForHash(self.hashData, 0)
    self.nonFastBlocks = {}
    self.pathNames = {
        "EndTickButtons",            -- 1
        "lightBlocks",               -- 2
        "throughBlocks",             -- 3
        "norThroughBlocks",          -- 4
        "timerBlocks",               -- 5
        "andBlocks",                 -- 6
        "none",                      -- 7
        "orBlocks",                  -- 8
        "none",                      -- 9
        "xorBlocks",                 -- 10
        "nandBlocks",                -- 11
        "none",                      -- 12
        "norBlocks",                 -- 13
        "none",                      -- 14
        "xnorBlocks",                -- 15
        "multiBlocks",               -- 16
        "throughMultiBlockInput",    -- 17
        "norThroughMultiBlockInput", -- 18
        "andMultiBlockInput",        -- 19
        "orMultiBlockInput",         -- 20
        "xorMultiBlockInput",        -- 21
        "nandMultiBlockInput",       -- 22
        "norMultiBlockInput",        -- 23
        "xnorMultiBlockInput",       -- 24
        "blockStateSetterBlocks",    -- 25
    }
    self.pathIndexs = {}
    for index, path in pairs(self.pathNames) do
        self.pathIndexs[path] = index
    end
    self.nextRunningBlocks = table.makeArrayForHash(self.hashData, 0)
    self.nextRunningIndex = 1
    self.runningBlocks = {}
    self.runningBlockLengths = {}
    self.blocksSortedByPath = {}
    for _, pathId in pairs(self.pathIndexs) do
        self.runningBlocks[pathId] = {}
        self.runningBlockLengths[pathId] = 0
        self.blocksSortedByPath[pathId] = {}
    end
    self.toMultiBlockInput = {
        false, -- 1
        false, -- 2
        17,    -- 3
        18,    -- 4
        false, -- 5
        19,    -- 6
        19,    -- 7
        20,    -- 8
        20,    -- 9
        21,    -- 10
        22,    -- 11
        22,    -- 12
        23,    -- 13
        23,    -- 14
        24,    -- 15
        false, -- 16
        false, -- 17
        false, -- 18
        false, -- 19
        false, -- 20
        false, -- 21
        false, -- 22
        false, -- 23
        false, -- 24
        false, -- 25
    }
    self:updateLongestTimer()
end

function FastLogicRunner.doLastTickUpdates(self)
    local multiBlocks = self.blocksSortedByPath[16]
    blockOutputs = self.blockOutputs
    blockStates = self.blockStates
    multiBlockData = self.multiBlockData
    runnableBlockPathIds = self.runnableBlockPathIds
    for i = 1, #multiBlocks do
        local multiBlockId = multiBlocks[i]
        local data = self:internalGetLastMultiBlockInternalStates(multiBlockId)
        local idStatePairs = data[2]
        local lastIdStatePairs = data[1]
        if idStatePairs == nil then
            idStatePairs = self:internalGetMultiBlockInternalStates(multiBlockId)
        end
        local blocks = multiBlockData[multiBlockId][2]
        for j = 1, #lastIdStatePairs do
            local outputs = blockOutputs[lastIdStatePairs[j][1]]
            local state = lastIdStatePairs[j][2]
            for k = 1, #outputs do
                local id = outputs[k]
                if runnableBlockPathIds[id] == 2 then
                    blockStates[id] = state
                end
            end
        end
        self:internalSetBlockStates(idStatePairs, false)
    end
end
