dofile "../util/util.lua"
local string = string
local table = table
local type = type
local pairs = pairs
local sm = sm

FastLogicRunner = FastLogicRunner or {}

dofile "BlockManager.lua"
dofile "MultiBlockManager.lua"
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
    self.multiBlockInputMultiBlockId = table.makeArrayForHash(self.hashData)
    self.numberOfTimesRun = table.makeArrayForHash(self.hashData, 0)
    self.ramBlockData = table.makeArrayForHash(self.hashData)
    self.ramBlockOtherData = table.makeArrayForHash(self.hashData)
    self.nonFastBlocks = {}
    self.interfacesToMake = {}
    self.interfacesToMakeHash = {}
    self.pathNames = {
        "EndTickButtons",            -- 1
        "lightBlocks",               -- 2
        "throughBlocks",             -- 3
        "norThroughBlocks",          -- 4
        "timerBlocks",               -- 5
        "andBlocks",                 -- 6
        "Address",                   -- 7
        "orBlocks",                  -- 8
        "DataIn",                    -- 9
        "xorBlocks",                 -- 10
        "nandBlocks",                -- 11
        "DataOut",                   -- 12
        "norBlocks",                 -- 13
        "WriteData",                 -- 14
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
        "stateSetterBlocks",         -- 25
        "BlockMemory",               -- 26
        "interfaceMultiBlockInput"   -- 27
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
        27,    -- 7
        20,    -- 8
        27,    -- 9
        21,    -- 10
        22,    -- 11
        false, -- 12
        23,    -- 13
        27,    -- 14
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
        false, -- 26
        false, -- 27
    }
    self:updateLongestTimer()
end

local doLastTickDecompress = {
    true,
    true,
    false,
    false,
    false,
}

function FastLogicRunner.doLastTickUpdates(self)
    local multiBlocks = self.blocksSortedByPath[16]
    local blockOutputs = self.blockOutputs
    local blockStates = self.blockStates
    local multiBlockData = self.multiBlockData
    local runnableBlockPathIds = self.runnableBlockPathIds
    local timerData = self.timerData
    for j = 1, #multiBlocks do
        local multiBlockId = multiBlocks[j]
        local multiData = multiBlockData[multiBlockId]
        local multiBlockType = multiData[1]
        if doLastTickDecompress[multiBlockType] then
            if multiData[1] == 1 or multiData[1] == 2 then
                local state = blockStates[multiData[3][1]]
                local endBlockId = multiData[4][1]
                for i = 2, multiData[6] do
                    local id = multiData[2][i]
                    local timeDataAtTime = timerData[multiData[6]-i+1]
                    for k = 1, #timeDataAtTime do
                        local item = timeDataAtTime[k]
                        if type(item) ~= "number" and item[2] == endBlockId then
                            state = not state
                            break
                        end
                    end
                    if runnableBlockPathIds[id] == 4 then
                        state = not state
                    end
                    blockStates[id] = state
                    local outputs = blockOutputs[multiData[2][i-1]]
                    for k = 1, #outputs do
                        local id = outputs[k]
                        if runnableBlockPathIds[id] == 2 then
                            blockStates[id] = state
                        end
                    end
                    if self.nextRunningBlocks[id] >= self.nextRunningIndex - 1 then
                        break
                    end
                end
            else
                local lastIdStatePairs, idStatePairs = self:internalGetLastMultiBlockInternalStates(multiBlockId)
                if idStatePairs == nil then
                    idStatePairs = self:internalGetMultiBlockInternalStates(multiBlockId)
                end
                local blocks = multiData[2]
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
    end
end
