-- quickGateConverter.lua by HerrVincling
-- moddifed
dofile "../util/util.lua"
dofile "../allCreationStuff/CreationUtil.lua"
dofile "../util/backupEngine.lua"
local string = string
local table = table
local type = type
local pairs = pairs
local sm = sm

sm.MTFastLogic = sm.MTFastLogic or {}
sm.MTFastLogic.LogicConverter = sm.MTFastLogic.LogicConverter or {}

local letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local vLightsToFLights = {
    ["e91b0bf2-dafa-439e-a503-286e91461bb0"] = "f36e03b4-eea7-4c0a-842d-225ed50e5635",
    ["1e2485d7-f600-406e-b348-9f0b7c1f5077"] = "da2a1835-8ef3-4bef-a16c-c3d38ffe3b34",
    ["7b2c96af-a4a1-420e-9370-ea5b58f23a7e"] = "767a4a08-7471-465a-9dda-6e3c246fe3b1",
    ["5e3dff9b-2450-44ae-ad46-d2f6b5148cbf"] = "dcb72c88-76cc-4fb2-87b7-b8a6b83f898b",
    ["16ba2d22-7b96-4c5e-9eb7-f6422ed80ad4"] = "e5b00d9a-e27f-4aff-ae74-612ac9edae07",
    ["85339a1d-e67f-4c63-94fd-4a1cf8c25810"] = "6efc9636-e380-4c6e-ad95-79f1919ac1dc",
    ["ed27f5e2-cac5-4a32-a5d9-49f116acc6af"] = "31eac728-a2db-420a-8034-835229f42d4c",
    ["695d66c8-b937-472d-8bc2-f3d72dd92879"] = "85caeefe-9935-42ae-83a4-8c1df6528758"
}
local fLightsToVLights = {}
for k, v in pairs(vLightsToFLights) do
    fLightsToVLights[v] = k
end

sm.MTFastLogic.LogicConverter.vGateModesToFGateModes = {
    [0] = "4ExVQQAAAAEEAAAAAiww",
    [1] = "4ExVQQAAAAEEAAAAAiwx",
    [2] = "4ExVQQAAAAEEAAAAAiwy",
    [3] = "4ExVQQAAAAEEAAAAAiwz",
    [4] = "4ExVQQAAAAEEAAAAAiw0",
    [5] = "4ExVQQAAAAEEAAAAAiw1",
}
local fGateModesToVGateModes = {}
for k, v in pairs(sm.MTFastLogic.LogicConverter.vGateModesToFGateModes) do
    fGateModesToVGateModes[v] = k
end

sm.MTFastLogic.LogicConverter.vLightLumsToFLightLums = {
    [10] = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQgK",
    [20] = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQgU",
    [30] = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQge",
    [40] = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQgo",
    [50] = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQgy",
    [60] = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQg8",
    [70] = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQhG",
    [80] = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQhQ",
    [90] = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQha",
    [100] = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQhk",
}
local fLightLumsToVLightLums = {}
for k, v in pairs(sm.MTFastLogic.LogicConverter.vLightLumsToFLightLums) do
    fLightLumsToVLightLums[v] = k
end

local fLogicGatesUuidHash = FastLogicAllBlockManager.blockUuidToConnectionColorID

function FastLogicRunnerRunner.server_convertBody(self, data)
    --"FastLogic" or "VanillaLogic"
    local body = data.body
    local wantedType = data.wantedType
    if wantedType == "VanillaLogic" and data.overrideUuidClear ~= true then
        local creation = sm.MTFastLogic.Creations[sm.MTFastLogic.CreationUtil.getCreationId(data.body)]
        if creation ~= nil then
            for _, block in pairs(creation.AllFastBlocks) do
                sm.event.sendToInteractable(block.interactable, "removeUuidData")
            end
            if sm.MTFastLogic.FastLogicRunnerRunner.bodiesToConvert[2] == nil then
                sm.MTFastLogic.FastLogicRunnerRunner.bodiesToConvert[2] = {}
            end
            sm.MTFastLogic.FastLogicRunnerRunner.bodiesToConvert[2][#sm.MTFastLogic.FastLogicRunnerRunner.bodiesToConvert[2] + 1] =
            data
        end
    else
        sm.MTBackupEngine.sv_backupCreation({
            hasCreationData = false,
            body = body,
            name = "Conversion Backup",
            description = "Backup created by LogicConverter.lua. Converting to " .. wantedType,
        })
        if wantedType == "FastLogic" then
            sm.MTFastLogic.FastLogicRunnerRunner:convertToFastInternal(body)
        else
            sm.MTFastLogic.FastLogicRunnerRunner:convertToVanillaInternal(body)
        end
    end
end

function FastLogicRunnerRunner.convertBodyInternal(self, body, wantedType)
    sm.MTBackupEngine.sv_backupCreation({
        hasCreationData = false,
        body = body,
        name = "Conversion Backup",
        description = "Backup created by LogicConverter.lua. Converting to " .. wantedType,
    })
    if wantedType == "FastLogic" then
        sm.MTFastLogic.FastLogicRunnerRunner:convertToFastInternal(body)
    else
        sm.MTFastLogic.FastLogicRunnerRunner:convertToVanillaInternal(body)
    end
end

function FastLogicRunnerRunner.convertTimerDelayToData(secondsUnprocessed, ticksUnprocessed)
    local childdata = "0ExVQQAAAAEFAAAAAgIFAPAHgHRpY2tzCAAEAAAAB3NlY29uZHMIAA"
    local binarr = {}
    local bincount = 1
    for k = #childdata, 1, -1 do
        local char = string.sub(childdata, k, k)
        local index, _ = string.find(letters, char)
        for l = 0, 5 do
            if bit.band(index, 2 ^ l) > 0 then
                binarr[bincount] = 1
                bincount = bincount + 1
            else
                binarr[bincount] = 0
                bincount = bincount + 1
            end
        end
    end

    local seconds = 4 + secondsUnprocessed
    for i = 5, 10 do
        if bit.band(seconds, 2 ^ (i - 5)) > 0 then
            binarr[i] = 1
        else
            binarr[i] = 0
        end
    end
    local ticks = 16 + ticksUnprocessed
    for i = 117, 122 do
        if bit.band(ticks, 2 ^ (i - 117)) > 0 then
            binarr[i] = 1
        else
            binarr[i] = 0
        end
    end

    local newchilddata = childdata
    bincount = 1
    for k = #childdata, 1, -1 do
        local index = 0
        for l = 0, 5 do
            if binarr[bincount] == 1 then
                index = index + 2 ^ l
            end
            bincount = bincount + 1
        end
        --childdata[k] = b[index]
        local char = string.sub(letters, index, index)
        newchilddata = string.replace_char(k, newchilddata, char)
    end
    return newchilddata
end

function FastLogicRunnerRunner.convertToVanillaInternal(self, bodyToGetData)
    local creationJson = sm.creation.exportToTable(bodyToGetData, true)
    for i = 1, #creationJson.bodies do
        local body = creationJson.bodies[i]
        for j = 1, #body.childs do
            local child = body.childs[j]
            if fLogicGatesUuidHash[child.shapeId] ~= nil then -- Fast Gate
                local mode = fGateModesToVGateModes[child.controller.data]
                if mode == nil then
                    goto continue
                end
                child.shapeId = "9f0f56e8-2c31-4d83-996c-d00a9b296c3f"
                child.controller.mode = mode
                child.controller.active = false
                child.controller.data = nil
            elseif child.shapeId == "db0bc11b-c083-4a6a-843f-73ac1033e6fe" then --Fast Timer
                -- LOTS of base64 converting and extracting corresponding bits of seconds & ticks

                local childdata = child.controller.data
                local binarr = {}
                local bincount = 1
                for k = #childdata, 1, -1 do
                    local char = string.sub(childdata, k, k)
                    local index, _ = string.find(letters, char)
                    for l = 0, 5 do
                        if bit.band(index, 2 ^ l) > 0 then
                            binarr[bincount] = 1
                            bincount = bincount + 1
                        else
                            binarr[bincount] = 0
                            bincount = bincount + 1
                        end
                    end
                end
                -- Everything in strings
                local binstr = table.concat(binarr)
                -- Everything in tables
                local seconds
                local ticks
                if string.sub(childdata, 1, 37) == '8BhMVUEAAAABBQAAAAICAAAAA4BzZWNvbmRzC' then
                    --identical_different
                    seconds = 0
                    for k = 99, 104 do
                        if binarr[k] == 1 then
                            seconds = seconds + 2 ^ (k - 99)
                        end
                    end
                    seconds = seconds - 16              --remove Offset
                    ticks = 0
                    for k = 3, 8 do
                        if binarr[k] == 1 then
                            ticks = ticks + 2 ^ (k - 3)
                        end
                    end
                    ticks = ticks - 16 --remove Offset
                elseif string.sub(childdata, 1, 33) == '0ExVQQAAAAEFAAAAAgIFAPAHgHRpY2tzC' then
                    seconds = 0
                    for k = 5, 10 do
                        if binarr[k] == 1 then
                            seconds = seconds + 2 ^ (k - 5)
                        end
                    end
                    seconds = seconds - 4                 --remove Offset
                    ticks = 0
                    for k = 117, 122 do
                        if binarr[k] == 1 then
                            ticks = ticks + 2 ^ (k - 117)
                        end
                    end
                    ticks = ticks - 16 --remove Offset
                else
                    goto continue
                end

                if (seconds < 0) or (seconds > 59) or (ticks < 0) or (ticks > 40) then
                    sm.gui.chatMessage("Fatal error while converting Fast Timers, please send a screenshot of this to ItchyTrack")
                    sm.gui.chatMessage(childdata .. " " .. seconds .. " " .. ticks)
                    return
                end
                child.shapeId = "8f7fd0e7-c46e-4944-a414-7ce2437bb30f"
                child.controller.data = nil
                child.controller.active = false
                child.controller.seconds = seconds
                child.controller.ticks = ticks
            elseif fLightsToVLights[child.shapeId] ~= nil then --Fast Light
                local luminance = fLightLumsToVLightLums[child.controller.data]
                if luminance == nil then
                    goto continue
                end
                child.shapeId = fLightsToVLights[child.shapeId]
                child.controller.luminance = luminance
                child.controller.data = nil
            end
            ::continue::
        end
    end
    -- save old body pos, rot, and, world
    local bodyPos = bodyToGetData.worldPosition
    local bodyRot = bodyToGetData.worldRotation
    local world = bodyToGetData:getWorld()
    -- destroy old body
    for _, shape in pairs(bodyToGetData:getCreationShapes()) do
        shape:destroyShape()
    end
    -- spawn new body
    sm.creation.importFromString(world, sm.json.writeJsonString(creationJson), bodyPos, bodyRot)
end

function FastLogicRunnerRunner.convertToFastInternal(self, bodyToGetData)
    local creationJson = sm.creation.exportToTable(bodyToGetData, true)
    for i = 1, #creationJson.bodies do
        local body = creationJson.bodies[i]
        for j = 1, #body.childs do
            local child = body.childs[j]
            if child.shapeId == "9f0f56e8-2c31-4d83-996c-d00a9b296c3f" then --Vanilla Gate
                child.shapeId = "6a9dbff5-7562-4e9a-99ae-3590ece88112"
                child.controller.data = sm.MTFastLogic.LogicConverter.vGateModesToFGateModes[child.controller.mode]
                child.controller.mode = nil
                child.controller.active = nil
            elseif child.shapeId == "8f7fd0e7-c46e-4944-a414-7ce2437bb30f" then --Vanilla Timer
                child.shapeId = "db0bc11b-c083-4a6a-843f-73ac1033e6fe"

                child.controller.data = FastLogicRunnerRunner.convertTimerDelayToData(child.controller.seconds, child.controller.ticks)
                child.controller.active = nil
                child.controller.seconds = nil
                child.controller.ticks = nil
            elseif vLightsToFLights[child.shapeId] ~= nil then --Vanilla Light
                child.shapeId = vLightsToFLights[child.shapeId]
                child.controller.data = sm.MTFastLogic.LogicConverter.vLightLumsToFLightLums[child.controller.luminance]
                child.controller.coneAngle = nil
                child.controller.luminance = nil
            -- elseif child.shapeId == "0eb09225-11c7-4178-b87a-9fdf7343f472" then -- Fast Ram
            --     self:convertQuickInterfacesAndRamFastLogic(bodyToGetData, creationJson, child.controller.id)
            end
        end
    end
    -- save old body pos, rot, and, world
    local bodyPos = bodyToGetData.worldPosition
    local bodyRot = bodyToGetData.worldRotation
    local world = bodyToGetData:getWorld()
    -- destroy old body
    for _, shape in pairs(bodyToGetData:getCreationShapes()) do
        shape:destroyShape()
    end
    -- spawn new body
    sm.creation.importFromString(world, sm.json.writeJsonString(creationJson), bodyPos, bodyRot)
end

function FastLogicRunnerRunner.convertQuickInterfacesAndRamFastLogic(self, bodyToGetData, creationJson, ramBlockId)
    
end

function FastLogicRunnerRunner.getBlocksJsonPosFromJsonWithIds(self, creationJson, idHash)
    for i = 1, #creationJson.bodies do
        local body = creationJson.bodies[i]
        for j = 1, #body.childs do
            if idHash[body.childs[j].controller.id] ~= nil then
                idHash[body.childs[j].controller.id] = {i, j}
            end
        end
    end
    return idHash
end

function FastLogicRunnerRunner.getFastInteractablesFromIds()
    
end

function FastLogicRunnerRunner.getQuickInteractablesFromIds()
    
end

