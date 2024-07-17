dofile "../util/util.lua"

local string = string
local table = table
local type = type
local pairs = pairs

FastLogicRealBlockManager = FastLogicRealBlockManager or {}

dofile "DisplayCode.lua"
dofile "NewRealStuffChecker.lua"

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.dataToSet = sm.MTFastLogic.dataToSet or {}

function FastLogicRealBlockManager.getNew(creationId)
    local new = table.deepCopy(FastLogicRealBlockManager)
    new.getNew = nil
    new.creationId = creationId
    return new
end

function FastLogicRealBlockManager.init(self)
    self.creation = sm.MTFastLogic.Creations[self.creationId]
    self.FastLogicRunner = self.creation.FastLogicRunner
    self.FastLogicAllBlockManager = self.creation.FastLogicAllBlockManager
    self.displayedBlockStates = {}
    self.blocksWithData = {}
    self.scanNext = {}
    self.needDisplayUpdate = {}
end

function FastLogicRealBlockManager.update(self)
    -- sm.MTUtil.Profiler.Time.on("update" .. tostring(self.creationId))
    -- check if body updated
    self:addAllNewBlocks()
    self:checkForBodyUpdate()
    self.creation.lastBodyUpdate = sm.game.getCurrentTick()
    -- check switches and other inputs
    self:checkForNewInputs()

    -- run
    local updatedGates = self.FastLogicAllBlockManager:update()
    table.appendTable(updatedGates, self.needDisplayUpdate)
    self.needDisplayUpdate = {}
    -- update states of fast gates
    self:updateDisplay(updatedGates)
    -- sm.MTUtil.Profiler.Time.off("update" .. tostring(self.creationId))
    -- print("update" .. tostring(self.creationId) .. ": " .. tostring(sm.MTUtil.Profiler.Time.get("update" .. tostring(self.creationId))))
    -- sm.MTUtil.Profiler.Time.reset("update" .. tostring(self.creationId))
end

function FastLogicRealBlockManager.addAllNewBlocks(self)
    for i = 1, #self.creation.BlocksToScan do
        local block = self.creation.BlocksToScan[i]
        if block.isFastLogic == true then
            self.FastLogicAllBlockManager:addBlock(block)
            self.scanNext[block.data.uuid] = block
        elseif block.isSilicon == true then
            for _, siliconBlock in ipairs(block.data.blocks) do
                self.FastLogicAllBlockManager:addSiliconBlock(
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

function FastLogicRealBlockManager.createPartWithData(self, block, body)
    local pos = block.pos - (block.rot[1] + block.rot[2] + block.rot[3]) * 0.5
    if block.connectionColorId == nil then
        block.connectionColorId = 0
    end

    local blockId = table.afind(FastLogicAllBlockManager.blockUuidToConnectionColorID, block.connectionColorId)
    if blockId == nil then
        blockId = table.afind(FastLogicAllBlockManager.blockUuidToConnectionColorID, 0)
    end
    local shape = body:createPart(sm.uuid.new(blockId), pos, block.rot[3], block.rot[1], true)
    shape.color = block.color
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

function FastLogicRealBlockManager.setData(self, block, data)
    block.data.uuid = data.uuid
    sm.MTFastLogic.FastLogicBlockLookUp[block.data.uuid] = block
    for _, v in pairs(data.inputs) do
        local inputBlock = sm.MTFastLogic.FastLogicBlockLookUp[v]
        if inputBlock ~= nil then
            inputBlock.interactable:connect(block.interactable)
        end
    end
    for _, v in pairs(data.outputs) do
        local outputBlock = sm.MTFastLogic.FastLogicBlockLookUp[v]
        if outputBlock ~= nil then
            block.interactable:connect(outputBlock.interactable)
        elseif self.creation.blocks[v] ~= nil and self.creation.blocks[v].isSilicon == true then
            sm.event.sendToInteractable(self.creation.SiliconBlocks[self.creation.blocks[v].siliconBlockId].interactable,
                "server_resave")
        end
    end
    local parents = data.nonFastLogicInputs
    local children = data.nonFastLogicOutputs
    if parents ~= nil then
        for _, v in pairs(parents) do
            if sm.exists(v) then
                v:connect(block.interactable)
                if self.creation.AllNonFastBlocks[v.id] ~= nil then
                    if table.contains(self.creation.AllNonFastBlocks[v.id]["outputs"], block.data.uuid) then
                        if block.activeInputs == nil then
                            block.activeInputs = {}
                        end
                        block.activeInputs[v.id] = self.creation.AllNonFastBlocks[v.id]["currentState"]
                    end
                end
            end
        end
    end
    if children ~= nil then
        for _, v in pairs(children) do
            if sm.exists(v) then
                block.interactable:connect(v)
            end
        end
    end
    sm.event.sendToInteractable(block.interactable, "server_saveMode", typeToNumber[data.type])
    block.data.mode = typeToNumber[data.type]
    self.needDisplayUpdate[#self.needDisplayUpdate+1] = block.data.uuid
    self.displayedBlockStates[block.data.uuid] = nil
end

function FastLogicRealBlockManager.changeConnectionColor(self, id, connectionColorId)
    local uuid = self.creation.uuids[id]
    local block = self.creation.blocks[uuid]
    if (
        #creation.AllFastBlocks[uuid].shape:getJoints() == 0 or
        block.connectionColorId == connectionColorId or
        block == nil or
        (
            block.type ~= "andBlocks" and
            block.type ~= "orBlocks" and
            block.type ~= "xorBlocks" and
            block.type ~= "nandBlocks" and
            block.type ~= "norBlocks" and
            block.type ~= "xnorBlocks"
        )
    ) then return end
    self.FastLogicAllBlockManager:changeConnectionColor(uuid, connectionColorId)
    local realBlock = sm.MTFastLogic.FastLogicBlockLookUp[uuid]
    if realBlock == nil then
        print("Block not found ope")
        advPrint(sm.MTFastLogic.FastLogicBlockLookUp, 2)
        print(uuid)
        print(id)
    end
    local body = realBlock.shape:getBody()
    realBlock:remove(false)
    local parents = realBlock.interactable:getParents()
    local children = realBlock.interactable:getChildren()
    local blockdata = {
        type = block.type,
        uuid = block.uuid,
        pos = block.pos,
        rot = block.rot,
        inputs = table.copy(block.inputs),
        outputs = table.copy(block.outputs),
        state = block.state,
        color = block.color,
        connectionColorId = connectionColorId,
        nonFastLogicInputs = parents,
        nonFastLogicOutputs = children,
    }
    self.creation.FastLogicRealBlockManager:createPartWithData(blockdata, body)
end
