-- Runs NewTool mutations on the server in small, acknowledged batches.
-- Operation handlers are registered by NewTool-owned features.

NewToolOperationManager = {}

local batchSize = 64
local maximumItems = 8192

function NewToolOperationManager.serverInit(host)
    host.ServerOperationManager = {}
    local self = host.ServerOperationManager
    local handlers = {}
    local operations = {}

    local function reply(player, data)
        host.network:sendToClient(player, "cl_operationBatchResult", data)
    end

    local function reject(player, operationId, batchIndex, message)
        reply(player, {
            operationId = operationId,
            batchIndex = batchIndex,
            accepted = false,
            done = true,
            error = message
        })
    end

    function self.register(kind, handler)
        assert(type(kind) == "string" and kind ~= "", "Operation kind is required")
        assert(type(handler) == "function", "Operation handler is required")
        handlers[kind] = handler
    end

    function self.receive(data, player)
        if type(data) ~= "table" then
            reject(player, nil, nil, "Invalid operation packet")
            return
        end
        if type(data.operationId) ~= "string" or #data.operationId > 64 or
            type(data.kind) ~= "string" or #data.kind > 64 or
            type(data.batchIndex) ~= "number" or data.batchIndex < 1 or
            data.batchIndex ~= math.floor(data.batchIndex) or type(data.items) ~= "table" then
            reject(player, data.operationId, data.batchIndex, "Invalid operation packet")
            return
        end

        local handler = handlers[data.kind]
        if handler == nil then
            reject(player, data.operationId, data.batchIndex, "Unknown operation")
            return
        end

        local itemCount = #data.items
        if itemCount < 1 or itemCount > batchSize then
            reject(player, data.operationId, data.batchIndex, "Invalid batch size")
            return
        end

        local operationKey = tostring(player:getId())
        local operation = operations[operationKey]
        if operation == nil then
            if data.batchIndex ~= 1 then
                reject(player, data.operationId, data.batchIndex, "Unexpected first batch")
                return
            end
            operation = { id = data.operationId, kind = data.kind, nextBatch = 1, itemCount = 0 }
            operations[operationKey] = operation
        elseif operation.id ~= data.operationId then
            reject(player, data.operationId, data.batchIndex, "Another operation is still active")
            return
        end

        if operation.kind ~= data.kind or operation.nextBatch ~= data.batchIndex then
            operations[operationKey] = nil
            reject(player, data.operationId, data.batchIndex, "Unexpected operation batch")
            return
        end
        if operation.itemCount + itemCount > maximumItems then
            operations[operationKey] = nil
            reject(player, data.operationId, data.batchIndex, "Operation is too large")
            return
        end

        local applied = 0
        local skipped = 0
        for _, item in ipairs(data.items) do
            local ok, result = pcall(handler, item, player)
            if ok and result == true then
                applied = applied + 1
            else
                skipped = skipped + 1
                if not ok then
                    print("NewTool operation item failed: " .. tostring(result))
                end
            end
        end

        operation.itemCount = operation.itemCount + itemCount
        operation.nextBatch = operation.nextBatch + 1
        local done = data.last == true
        if done then operations[operationKey] = nil end

        reply(player, {
            operationId = data.operationId,
            batchIndex = data.batchIndex,
            accepted = true,
            done = done,
            applied = applied,
            skipped = skipped
        })
    end
end

function NewToolOperationManager.clientInit(host)
    host.OperationManager = {}
    local self = host.OperationManager
    local nextId = 1
    local queue = {}
    local statuses = {}

    function self.submit(kind, items)
        if type(kind) ~= "string" or kind == "" then return nil, "Operation kind is required" end
        if type(items) ~= "table" or #items < 1 then return nil, "Nothing to do" end
        if #items > maximumItems then return nil, "Operation is too large" end

        local operationId = tostring(sm.game.getCurrentTick()) .. ":" .. tostring(nextId)
        nextId = nextId + 1
        local batches = {}
        for first = 1, #items, batchSize do
            local batch = {}
            for index = first, math.min(first + batchSize - 1, #items) do
                batch[#batch + 1] = items[index]
            end
            batches[#batches + 1] = batch
        end

        local operation = {
            id = operationId,
            kind = kind,
            total = #items,
            applied = 0,
            skipped = 0,
            complete = false,
            batchIndex = 1,
            batches = batches,
            waiting = false
        }
        statuses[operationId] = operation
        queue[#queue + 1] = operation
        return operationId
    end

    function self.client_onUpdate()
        local operation = queue[1]
        if operation == nil or operation.waiting then return end

        local batch = operation.batches[operation.batchIndex]
        if batch == nil then return end
        operation.waiting = true
        host.network:sendToServer("sv_runOperationBatch", {
            operationId = operation.id,
            kind = operation.kind,
            batchIndex = operation.batchIndex,
            items = batch,
            last = operation.batchIndex == #operation.batches
        })
    end

    function self.receiveResult(data)
        local operation = queue[1]
        if operation == nil or type(data) ~= "table" or
            data.operationId ~= operation.id or data.batchIndex ~= operation.batchIndex then
            return
        end

        operation.waiting = false
        if data.accepted ~= true then
            operation.complete = true
            operation.error = tostring(data.error or "Operation rejected")
            operation.batches = nil
            table.remove(queue, 1)
            return
        end

        operation.applied = operation.applied + math.max(tonumber(data.applied) or 0, 0)
        operation.skipped = operation.skipped + math.max(tonumber(data.skipped) or 0, 0)
        if data.done == true then
            operation.complete = true
            operation.batches = nil
            table.remove(queue, 1)
        else
            operation.batchIndex = operation.batchIndex + 1
        end
    end

    function self.getStatus(operationId)
        return statuses[operationId]
    end

    function self.forget(operationId)
        local operation = statuses[operationId]
        if operation == nil or not operation.complete then return false end
        statuses[operationId] = nil
        return true
    end
end
