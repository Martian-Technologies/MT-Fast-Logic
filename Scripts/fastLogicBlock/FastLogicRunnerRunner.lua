print("loading FastLogicRunnerRunner")

FastLogicRunnerRunner = FastLogicRunnerRunner or class()

dofile "../util/util.lua"
dofile "LogicConverter.lua"

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.Creations = sm.MTFastLogic.Creations or {}

function FastLogicRunnerRunner.server_onFixedUpdate(self)
    if self.run then
        self.changedIds = {}
        for k, v in pairs(sm.MTFastLogic.Creations) do
            v.FastLogicRunner:update()
        end
        -- print(#self.changedIds)
        if #self.changedIds > 0 then
            self.network:sendToClients("client_updateTextures", self.changedIds)
        end
    end
end

function FastLogicRunnerRunner.client_updateTextures(self, changedIds)
    for i = 1, #changedIds do
        local block = sm.MTFastLogic.FastLogicBlockLookUp[changedIds[i]]
        if block ~= nil then
            block:client_updateTexture()
        end
    end
end

function FastLogicRunnerRunner.server_onCreate(self)
    if sm.isHost then
        sm.MTFastLogic.FastLogicRunnerRunner = self
        self.run = true
    else
        self.run = false
    end
end

function FastLogicRunnerRunner.server_onDestroy(self)
end

function FastLogicRunnerRunner.server_onRefresh(self)
    self:server_onCreate()
end

function FastLogicRunnerRunner.client_onCreate(self)
end

function FastLogicRunnerRunner.client_onDestroy(self)
end

function FastLogicRunnerRunner.client_onRefresh(self)
    self:client_onCreate()
end

function FastLogicRunnerRunner.client_sendMessage(self, message)
    sm.gui.chatMessage( message )
end

