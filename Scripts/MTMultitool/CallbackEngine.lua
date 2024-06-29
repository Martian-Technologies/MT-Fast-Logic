CallbackEngine = {}

function CallbackEngine.inject(multitool)
    multitool.CallbackEngine = {}
    local self = multitool.CallbackEngine
    self.callbacks = {}
end

function CallbackEngine.client_registerCallback(multitool, func, passOn)
    local id = tostring(sm.uuid.generateRandom())
    multitool.CallbackEngine.callbacks[id] = {
        func = func,
        passOn = passOn
    }
    local player = sm.localPlayer.getPlayer()
    return {
        id = id,
        player = player
    }
end

function CallbackEngine.client_callCallback(callback, ...)
    local id = callback.id
    local player = callback.player
    if player ~= sm.localPlayer.getPlayer() then
        callback.network:sendToServer("server_callCallbackTrigger", {
            callback = callback,
            data = { ... }
        })
    else
        local callbackData = ThisMultitool.CallbackEngine.callbacks[id]
        if callbackData then
            callbackData.func(callbackData.passOn, ...)
        end
        ThisMultitool.CallbackEngine.callbacks[id] = nil
    end
end

function CallbackEngine.server_callCallback(callback, ...)
    callback.network:sendToClients("client_callCallbackFromServer", { callback = callback, data = { ... } })
end

function CallbackEngine.server_callCallbackTrigger(self, data)
    CallbackEngine.server_callCallback(
        data.callback,
        table.unpack(data.data)
    )
end

function CallbackEngine.client_callCallbackFromServer(self, data)
    if data.callback.player == sm.localPlayer.getPlayer() then
        CallbackEngine.client_callCallback(
            data.callback,
            table.unpack(data.data)
        )
    end
end