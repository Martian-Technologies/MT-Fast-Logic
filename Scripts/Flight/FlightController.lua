MTFlight = MTFlight or {}

MTFlight.playersFlying = MTFlight.playersFlying or {}
MTFlight.localState = MTFlight.localState or {
    flying = false,
    flyMode = 0,
    flyReset = false
}

MTFlight.modes = {
    off = 0,
    swimSmart = 1,
    swimPermadive = 2,
    impulseModulation = 3
}

MTFlight.defaultSpeed = MTFlight.defaultSpeed or 3.5
MTFlight.sprintMultiplier = MTFlight.sprintMultiplier or 6.0

local function getCharacter(toolScript, player)
    local ok, character

    if player ~= nil then
        ok, character = pcall(function() return player:getCharacter() end)
        if ok and character ~= nil then return character end

        ok, character = pcall(function() return player.character end)
        if ok and character ~= nil then return character end
    end

    if toolScript == nil or toolScript.tool == nil then return nil end

    local owner
    ok, owner = pcall(function() return toolScript.tool:getOwner() end)
    if not ok or owner == nil then return nil end

    ok, character = pcall(function() return owner:getCharacter() end)
    if ok and character ~= nil then return character end

    ok, character = pcall(function() return owner.character end)
    if ok and character ~= nil then return character end

    return nil
end

local function getOwner(toolScript)
    if toolScript == nil or toolScript.tool == nil then return nil end
    local ok, owner = pcall(function() return toolScript.tool:getOwner() end)
    if ok then return owner end
    return nil
end

local function characterExists(character)
    return character ~= nil and sm.exists(character)
end

local function characterId(character)
    if character == nil then return nil end
    return character.id
end

local function publicData(character)
    if character == nil then return nil end
    return character.publicData
end

local function clientPublicData(character)
    if character == nil then return nil end
    return character.clientPublicData
end

function MTFlight.inject(toolScript)
    toolScript.MTFlying = MTFlight.localState
    toolScript.MTFlight = MTFlight.localState
end

function MTFlight.sv_inject(toolScript)
    toolScript.MTFlying = {
        flying = false,
        flyMode = MTFlight.modes.off,
        flyReset = false
    }
    toolScript.MTFlight = toolScript.MTFlying
end

function MTFlight.getDefaultFlyMode()
    if sm.isHost then
        return MTFlight.modes.swimSmart
    end
    return MTFlight.modes.swimPermadive
end

function MTFlight.getSpeed(character, flying)
    if not flying then return 1 end
    if character ~= nil and character:isSprinting() then
        return MTFlight.defaultSpeed * MTFlight.sprintMultiplier
    end
    return MTFlight.defaultSpeed
end

function MTFlight.applyClientState(character, state)
    if not characterExists(character) or state == nil then return end

    local speed = MTFlight.getSpeed(character, state.flying)
    local data = clientPublicData(character)
    if data ~= nil then
        data.waterMovementSpeedFraction = speed
        data.MTFlightFlying = state.flying == true
        data.MTFlightMode = state.flyMode or MTFlight.modes.off
    end
end

function MTFlight.applyServerState(character, state)
    if not characterExists(character) or state == nil then return end

    local flying = state.flying == true
    local flyMode = state.flyMode or MTFlight.modes.off
    local speed = MTFlight.getSpeed(character, flying)

    if not flying or flyMode == MTFlight.modes.off then
        character:setSwimming(false)
        character:setDiving(false)
        speed = 1
    elseif flyMode == MTFlight.modes.swimSmart then
        character:setSwimming(true)
        character:setDiving(character:isSprinting())
    elseif flyMode == MTFlight.modes.swimPermadive then
        character:setSwimming(true)
        character:setDiving(true)
    elseif flyMode == MTFlight.modes.impulseModulation then
        local mass = character:getMass()
        local force = sm.vec3.new(0, 0, 0.5) * mass
        sm.physics.applyImpulse(character, force, true)
    end

    character.movementSpeedFraction = speed

    local data = publicData(character)
    if data ~= nil then
        data.waterMovementSpeedFraction = speed
        data.MTFlightFlying = flying
        data.MTFlightMode = flyMode
    end
end

function MTFlight.getState(toolScript)
    if toolScript.MTFlying == nil then
        MTFlight.inject(toolScript)
    end
    return toolScript.MTFlying
end

function MTFlight.toggleFlying(toolScript)
    local state = MTFlight.getState(toolScript)
    local character = getCharacter(toolScript)

    state.flying = not state.flying
    state.flyMode = state.flying and MTFlight.getDefaultFlyMode() or MTFlight.modes.off
    state.flyReset = true

    MTFlight.localState.flying = state.flying
    MTFlight.localState.flyMode = state.flyMode
    MTFlight.localState.flyReset = true

    MTFlight.applyClientState(character, state)

    if toolScript.network ~= nil then
        toolScript.network:sendToServer("sv_toggleFlying", {
            flying = state.flying,
            flyMode = state.flyMode
        })
    end
end

function MTFlight.cl_notifyFlying(toolScript, data)
    data = data or {}
    local state = MTFlight.getState(toolScript)
    local flying = data.flying
    if flying == nil then flying = data[1] end

    local flyMode = data.flyMode
    if flyMode == nil then flyMode = data[2] end
    if flyMode == nil then flyMode = flying and MTFlight.getDefaultFlyMode() or MTFlight.modes.off end

    state.flying = flying == true
    state.flyMode = flyMode
    state.flyReset = true

    MTFlight.localState.flying = state.flying
    MTFlight.localState.flyMode = state.flyMode
    MTFlight.localState.flyReset = true

    local character = getCharacter(toolScript)
    MTFlight.applyClientState(character, state)

    sm.gui.displayAlertText("Flight: " .. (state.flying and "On" or "Off"), 2)
end

function MTFlight.sv_toggleFlying(toolScript, data, player)
    data = data or {}
    if toolScript.MTFlying == nil then
        MTFlight.sv_inject(toolScript)
    end

    local character = getCharacter(toolScript, player)
    if not characterExists(character) then return end

    local id = characterId(character)
    if id == nil then return end

    local flying = data.flying
    if flying == nil then
        local previous = MTFlight.playersFlying[id]
        flying = not (previous ~= nil and previous.flying == true)
    end

    local flyMode = data.flyMode
    if flyMode == nil then flyMode = flying and MTFlight.modes.swimSmart or MTFlight.modes.off end
    if not flying then flyMode = MTFlight.modes.off end

    local state = {
        flying = flying == true,
        flyMode = flyMode
    }

    toolScript.MTFlying.flying = state.flying
    toolScript.MTFlying.flyMode = state.flyMode

    MTFlight.applyServerState(character, state)

    if state.flying then
        MTFlight.playersFlying[id] = state
    else
        MTFlight.playersFlying[id] = nil
    end

    local targetPlayer = player or getOwner(toolScript)
    if targetPlayer ~= nil and toolScript.network ~= nil then
        toolScript.network:sendToClient(targetPlayer, "cl_notifyFlying", {
            flying = state.flying,
            flyMode = state.flyMode
        })
    end
end

function MTFlight.cl_onUpdate(toolScript, dt)
    if toolScript == nil or toolScript.tool == nil then return end

    local ok, isLocal = pcall(function() return toolScript.tool:isLocal() end)
    if not ok or not isLocal then return end

    local state = MTFlight.getState(toolScript)
    local character = getCharacter(toolScript)
    if not characterExists(character) then return end

    if state.flying then
        state.flyReset = true
        MTFlight.applyClientState(character, state)

        local carryOk, carry = pcall(function() return sm.localPlayer.getCarry() end)
        if carryOk and carry ~= nil then
            local emptyOk, isEmpty = pcall(function() return carry:isEmpty() end)
            if emptyOk and not isEmpty then
                MTFlight.toggleFlying(toolScript)
                sm.gui.displayAlertText("Carrying while flying can get you stuck. Flight disabled.", 4)
            end
        end
    elseif state.flyReset then
        MTFlight.applyClientState(character, state)
        state.flyReset = false
    end
end

function MTFlight.server_onFixedUpdate(toolScript, dt)
    local character = getCharacter(toolScript)
    if not characterExists(character) then return end

    local id = characterId(character)
    if id == nil then return end

    local state = MTFlight.playersFlying[id]
    if state == nil or not state.flying then return end

    MTFlight.applyServerState(character, state)
end

MTFlying = MTFlight
