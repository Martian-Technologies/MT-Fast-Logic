-- NewTool-owned connection mutations built on OperationManager.

NewToolConnectionOperations = {}

local function sameCreation(fromBody, toBody)
    if fromBody == toBody then return true end
    for _, body in ipairs(fromBody:getCreationBodies()) do
        if body == toBody then return true end
    end
    return false
end

local function applyConnection(item, action)
    if type(item) ~= "table" then return false end
    local fromShape = item[1]
    local toShape = item[2]
    if fromShape == nil or toShape == nil or not sm.exists(fromShape) or not sm.exists(toShape) then
        return false
    end

    local fromBody = fromShape:getBody()
    local toBody = toShape:getBody()
    if fromBody == nil or toBody == nil or not sameCreation(fromBody, toBody) then return false end

    local fromInteractable = fromShape:getInteractable()
    local toInteractable = toShape:getInteractable()
    if fromInteractable == nil or toInteractable == nil then return false end

    if action == "connect" then
        fromInteractable:connect(toInteractable)
    else
        fromInteractable:disconnect(toInteractable)
    end
    return true
end

function NewToolConnectionOperations.serverInit(host)
    host.ServerOperationManager.register("connect", function(item)
        return applyConnection(item, "connect")
    end)
    host.ServerOperationManager.register("disconnect", function(item)
        return applyConnection(item, "disconnect")
    end)
end

function NewToolConnectionOperations.clientInit(host)
    host.ConnectionOperations = {}
    local self = host.ConnectionOperations

    function self.submit(action, connections)
        if action ~= "connect" and action ~= "disconnect" then
            return nil, "Unknown connection action"
        end

        local items = {}
        for _, connection in ipairs(connections or {}) do
            items[#items + 1] = { connection.from, connection.to }
        end
        return host.OperationManager.submit(action, items)
    end
end
