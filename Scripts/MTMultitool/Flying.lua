MTFlying = {}

MTFlying.playersFlying = {}

MTFlying.modes = {
    off = 0,
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
    local flyMode = MTFlying.modes.swimPermadive
    local previousFlyMode = flyMode
    if sm.isHost then
        flyMode = MTFlying.modes.swimSmart
    end
    if not self.flying then
        flyMode = MTFlying.modes.off
    end
    multitool.network:sendToServer("sv_toggleFlying", {
        flyMode = flyMode,
        previousFlyMode = previousFlyMode
    })
end

function MTFlying.cl_notifyFlying(self, data)
    self.MTFlying.flying = data[1]
end

function MTFlying.sv_toggleFlying(multitool, data)
    local self = multitool.MTFlying
    self.flyMode = data.flyMode
    local previousFlyMode = data.previousFlyMode

    local character = multitool.tool:getOwner().character
    MTFlying.playersFlying[character.id] = { flying = self.flying, flyMode = self.flyMode }
    if character == nil or not sm.exists(character) then
        return
    end

    if previousFlyMode == MTFlying.modes.swimSmart then
        character.movementSpeedFraction = 1
        character.publicData.waterMovementSpeedFraction = 1
        character:setSwimming(false)
        character:setDiving(false)
    elseif previousFlyMode == MTFlying.modes.swimPermadive then
        character.movementSpeedFraction = 1
        character.publicData.waterMovementSpeedFraction = 1
        character:setSwimming(false)
        character:setDiving(false)
    elseif previousFlyMode == MTFlying.modes.impulseModulation then
        character.movementSpeedFraction = 1
    end

    if self.flying then
        if self.flyMode == MTFlying.modes.swimSmart then
            character.movementSpeedFraction = 3.5
            character:setSwimming(true)
        elseif self.flyMode == MTFlying.modes.swimPermadive then
            character.movementSpeedFraction = 3.5
            character:setSwimming(true)
            character:setDiving(true)
        elseif self.flyMode == MTFlying.modes.impulseModulation then
            self.previousVelocity = nil
            character.movementSpeedFraction = 3.5
        end
    end
end

function MTFlying.cl_onUpdate(multitool, dt)
    local self = multitool.MTFlying
    local character = multitool.tool:getOwner().character
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
    if status == nil then
        return
    end
    if character == nil then
        return
    end

    local flyMode = status.flyMode
    if flyMode == MTFlying.modes.swimSmart then
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
    elseif flyMode == MTFlying.modes.swimPermadive then
        character.movementSpeedFraction = 3.5
        if character:isSprinting() then
            character.movementSpeedFraction = 20.0
        end
        if character.publicData then
            character.publicData.waterMovementSpeedFraction = character.movementSpeedFraction
        end
    elseif flyMode == MTFlying.modes.impulseModulation then
        character.movementSpeedFraction = 3.5
        local mass = character:getMass()
        local velocity = character:getVelocity()
        local force = sm.vec3.new(0, 0, 0)
        -- local force = force - velocity * 0.3
        force = force + sm.vec3.new(0, 0, 0.5)
        force = force * mass
        -- print(character.worldPosition)
        sm.physics.applyImpulse(character, force, true)
    end
end