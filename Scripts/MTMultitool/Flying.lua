MTFlying = {playersFlying = {}}

MTFlying.modes = {
    swimSmart = 1,
    swimPermadive = 2,
    impulseModulation = 3
}

function MTFlying.inject(multitool)
    multitool.MTFlying = {}
    local self = multitool.MTFlying
    self.flying = false
end

function MTFlying.toggleFlying(multitool)
    local self = multitool.MTFlying
    self.flying = not self.flying
    multitool.network:sendToServer("sv_toggleFlying", { self.flying, sm.isHost })
end

function MTFlying.cl_notifyFlying(self, data)
    self.MTFlying.flying = data[1]
end

function MTFlying.sv_toggleFlying(multitool, data)
    local self = multitool.MTFlying
    self.flying = data[1]
    local clientIsHost = data[2]
    print(clientIsHost)
    local character = multitool.tool:getOwner().character
    MTFlying.playersFlying[character.id] = {flying = self.flying, isHost = clientIsHost}
	if character ~= nil then
        if sm.exists(character) then
            character:setSwimming(self.flying)
			if self.flying == false then
				character.publicData.waterMovementSpeedFraction = 1
				character.publicData.MovementSpeedFraction = 1
                character:setDiving(false)
            else
                character:setDiving(not clientIsHost)
            end
		end
	end
end

function MTFlying.sv_inject(multitool)
    multitool.MTFlying = {}
    local self = multitool.MTFlying
    self.flying = false
end

function MTFlying.server_onFixedUpdate(multitool, dt)
    local self = multitool.MTFlying
    local character = multitool.tool:getOwner().character
    local status = MTFlying.playersFlying[character.id]
    if status ~= nil then
        if MTFlying.playersFlying[character.id].flying then
            if character ~= nil then
                character.movementSpeedFraction = 3.5
                if character:isSprinting() then
                    if MTFlying.playersFlying[character.id].isHost then
                        character:setDiving(true)
                    end
                    character.movementSpeedFraction = 20.0
                else
                    if MTFlying.playersFlying[character.id].isHost then
                        character:setDiving(false)
                    end
                end
                if character.publicData then
                    character.publicData.waterMovementSpeedFraction = character.movementSpeedFraction
                end
            end
        end
    end
end