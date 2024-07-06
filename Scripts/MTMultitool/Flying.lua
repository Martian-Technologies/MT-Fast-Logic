MTFlying = MTFlying or {
    playersFlying = {}
}

function MTFlying.inject(multitool)
    multitool.MTFlying = {}
    local self = multitool.MTFlying
    self.flying = false
end

function MTFlying.toggleFlying(multitool)
    local self = multitool.MTFlying
    self.flying = not self.flying
    multitool.network:sendToServer("sv_toggleFlying", { self.flying })
end

function MTFlying.cl_notifyFlying(self, data)
    self.MTFlying.flying = data[1]
end

function MTFlying.sv_toggleFlying(multitool, data)
    local self = multitool.MTFlying
    self.flying = data[1]
    local character = multitool.tool:getOwner().character
    MTFlying.playersFlying[character.id] = self.flying
	if character ~= nil then
        if sm.exists(character) then
            character:setSwimming(self.flying)
			if self.flying == false then
				character.publicData.waterMovementSpeedFraction = 1
				character.publicData.MovementSpeedFraction = 1
                character:setDiving(false)
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
	if MTFlying.playersFlying[ character.id ] then
		if character ~= nil then
			character.movementSpeedFraction = 3.5
			if character:isSprinting() then
                character:setDiving(true)
				character.movementSpeedFraction = 20.0
            else
                character:setDiving(false)
            end
			if character.publicData then
				character.publicData.waterMovementSpeedFraction = character.movementSpeedFraction
			end
		end
	end
end