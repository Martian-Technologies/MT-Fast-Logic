-- quickGateConverter.lua by HerrVincling
-- moddifed
dofile "../util/util.lua"
dofile "../allCreationStuff/CreationUtil.lua"
dofile "../util/backupEngine.lua"
local string = string
local table = table
local type = type
local pairs = pairs

local letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local vlightsToFlights = {
    ["e91b0bf2-dafa-439e-a503-286e91461bb0"] = "f36e03b4-eea7-4c0a-842d-225ed50e5635",
    ["1e2485d7-f600-406e-b348-9f0b7c1f5077"] = "da2a1835-8ef3-4bef-a16c-c3d38ffe3b34",
    ["7b2c96af-a4a1-420e-9370-ea5b58f23a7e"] = "767a4a08-7471-465a-9dda-6e3c246fe3b1",
    ["5e3dff9b-2450-44ae-ad46-d2f6b5148cbf"] = "dcb72c88-76cc-4fb2-87b7-b8a6b83f898b",
    ["16ba2d22-7b96-4c5e-9eb7-f6422ed80ad4"] = "e5b00d9a-e27f-4aff-ae74-612ac9edae07",
    ["85339a1d-e67f-4c63-94fd-4a1cf8c25810"] = "6efc9636-e380-4c6e-ad95-79f1919ac1dc",
    ["ed27f5e2-cac5-4a32-a5d9-49f116acc6af"] = "31eac728-a2db-420a-8034-835229f42d4c",
    ["695d66c8-b937-472d-8bc2-f3d72dd92879"] = "85caeefe-9935-42ae-83a4-8c1df6528758"
}
local flightsToVlights = {}
for v,f in pairs(vlightsToFlights) do
    flightsToVlights[f] = v
end

function FastLogicRunnerRunner.server_convertBody(self, data)
    --"FastLogic" or "VanillaLogic"
    local body = data.body
    local wantedType = data.wantedType
    if wantedType == "VanillaLogic" then
        local creation = sm.MTFastLogic.Creations[sm.MTFastLogic.CreationUtil.getCreationId(data.body)]
        if creation ~= nil then
            local i = 0
            for _, block in pairs(creation.AllFastBlocks) do
                i = i + 1
                local s = sm.event.sendToInteractable(block.interactable, "removeUuidData")
                if s == false then
                end
            end
            if sm.MTFastLogic.FastLogicRunnerRunner.bodiesToConvert[2] == nil then
                sm.MTFastLogic.FastLogicRunnerRunner.bodiesToConvert[2] = {}
            end
            sm.MTFastLogic.FastLogicRunnerRunner.bodiesToConvert[2][#sm.MTFastLogic.FastLogicRunnerRunner.bodiesToConvert[2]+1] = data
        end
    else
        sm.MTFastLogic.FastLogicRunnerRunner:convertBodyInternal(body, wantedType)
    end
end

function FastLogicRunnerRunner.convertBodyInternal(self, body, wantedType)
    local jsontable = sm.creation.exportToTable(body, true, false) --'true, false' fix for qtimer reset bug?
    sm.MTBackupEngine.sv_backupCreation({
        hasCreationData = false,
        body = body,
        name = "Conversion Backup",
        description = "Backup created by LogicConverter.lua. Converting to " .. wantedType,
    })
    if wantedType == "FastLogic" then
        for i = 1, #jsontable.bodies do
            for j = 1, #jsontable.bodies[i].childs do
                if jsontable.bodies[i].childs[j].shapeId == "9f0f56e8-2c31-4d83-996c-d00a9b296c3f" then --Vanilla Gate
                    jsontable.bodies[i].childs[j].shapeId = "6a9dbff5-7562-4e9a-99ae-3590ece88112"

                    local mode = jsontable.bodies[i].childs[j].controller.mode
                    local childdata
                    if mode == 0 then
                        childdata = "gExVQQAAAAEFBQDAAgAAAAIAbW9kZQgA"
                    elseif mode == 1 then
                        childdata = "gExVQQAAAAEFBQDAAgAAAAIAbW9kZQgB"
                    elseif mode == 2 then
                        childdata = "gExVQQAAAAEFBQDAAgAAAAIAbW9kZQgC"
                    elseif mode == 3 then
                        childdata = "gExVQQAAAAEFBQDAAgAAAAIAbW9kZQgD"
                    elseif mode == 4 then
                        childdata = "gExVQQAAAAEFBQDAAgAAAAIAbW9kZQgE"
                    elseif mode == 5 then
                        childdata = "gExVQQAAAAEFBQDAAgAAAAIAbW9kZQgF"
                    end

                    jsontable.bodies[i].childs[j].controller.data = childdata
                    jsontable.bodies[i].childs[j].controller.mode = nil
                    jsontable.bodies[i].childs[j].controller.active = nil
                elseif jsontable.bodies[i].childs[j].shapeId == "8f7fd0e7-c46e-4944-a414-7ce2437bb30f" then --Vanilla Timer
                    jsontable.bodies[i].childs[j].shapeId = "db0bc11b-c083-4a6a-843f-73ac1033e6fe"

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

                    local seconds = 4 + jsontable.bodies[i].childs[j].controller.seconds
                    for i = 5, 10 do
                        if bit.band(seconds, 2 ^ (i - 5)) > 0 then
                            binarr[i] = 1
                        else
                            binarr[i] = 0
                        end
                    end
                    local ticks = 16 + jsontable.bodies[i].childs[j].controller.ticks
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

                    jsontable.bodies[i].childs[j].controller.data = newchilddata
                    jsontable.bodies[i].childs[j].controller.active = nil
                    jsontable.bodies[i].childs[j].controller.seconds = nil
                    jsontable.bodies[i].childs[j].controller.ticks = nil
                elseif vlightsToFlights[jsontable.bodies[i].childs[j].shapeId] ~= nil then --Vanilla Light
                    jsontable.bodies[i].childs[j].shapeId = vlightsToFlights[jsontable.bodies[i].childs[j].shapeId]
                    local childdata = nil
                    local luminance = jsontable.bodies[i].childs[j].controller.luminance
                    if luminance == 10 then
                        childdata = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQgK"
                    elseif luminance == 20 then
                        childdata = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQgU"
                    elseif luminance == 30 then
                        childdata = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQge"
                    elseif luminance == 40 then
                        childdata = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQgo"
                    elseif luminance == 50 then
                        childdata = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQgy"
                    elseif luminance == 60 then
                        childdata = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQg8"
                    elseif luminance == 70 then
                        childdata = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQhG"
                    elseif luminance == 80 then
                        childdata = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQhQ"
                    elseif luminance == 90 then
                        childdata = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQha"
                    elseif luminance == 100 then
                        childdata = "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQhk"
                    end
                    jsontable.bodies[i].childs[j].controller.data = childdata
                    jsontable.bodies[i].childs[j].controller.coneAngle = nil
                    jsontable.bodies[i].childs[j].controller.luminance = nil
                end
            end
        end
    elseif wantedType == "VanillaLogic" then
        for i = 1, #jsontable.bodies do
            for j = 1, #jsontable.bodies[i].childs do
                if table.contains(FastLogicAllBlockManager.fastLogicGateBlockUuids, jsontable.bodies[i].childs[j].shapeId) then
                    local childdata = jsontable.bodies[i].childs[j].controller.data
                    local mode
                    if childdata == "gExVQQAAAAEFBQDAAgAAAAIAbW9kZQgA" then
                        mode = 0
                    elseif childdata == "gExVQQAAAAEFBQDAAgAAAAIAbW9kZQgB" then
                        mode = 1
                    elseif childdata == "gExVQQAAAAEFBQDAAgAAAAIAbW9kZQgC" then
                        mode = 2
                    elseif childdata == "gExVQQAAAAEFBQDAAgAAAAIAbW9kZQgD" then
                        mode = 3
                    elseif childdata == "gExVQQAAAAEFBQDAAgAAAAIAbW9kZQgE" then
                        mode = 4
                    elseif childdata == "gExVQQAAAAEFBQDAAgAAAAIAbW9kZQgF" then
                        mode = 5
                    else
                        -- sm.gui.chatMessage("#ff0000Fatal error while converting Fast Gates, please send a screenshot of this to ItchyTrack")
                        -- sm.gui.chatMessage(childdata)
                        goto continue
                    end

                    jsontable.bodies[i].childs[j].shapeId = "9f0f56e8-2c31-4d83-996c-d00a9b296c3f"
                    jsontable.bodies[i].childs[j].controller.mode = mode
                    jsontable.bodies[i].childs[j].controller.active = false
                    jsontable.bodies[i].childs[j].controller.data = nil
                elseif jsontable.bodies[i].childs[j].shapeId == "db0bc11b-c083-4a6a-843f-73ac1033e6fe" then --fasttimer
                    -- LOTS of base64 converting and extracting corresponding bits of seconds & ticks

                    local childdata = jsontable.bodies[i].childs[j].controller.data

                    --WORKING 8BhMVUEAAAABBQAAAAICAAAAA4BzZWNvbmRzCAAEAAAABXRpY2tzCAg
                    --WORKING 8BhMVUEAAAABBQAAAAICAAAAA4BzZWNvbmRzCAAEAAAABXRpY2tzCBk
                    --NOT WORK 0ExVQQAAAAEFAAAAAgIFAPAHgHRpY2tzCAAEAAAAB3NlY29uZHMIAA
                    --NOT WORK 0ExVQQAAAAEFAAAAAgIFAPAHgHRpY2tzCAAEAAAAB3NlY29uZHMIAA
                    --childdata = string.sub(childdata, 1, -1)
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
                    --local secondbinstr = string.sub(binstr, 5, 10)
                    --local tickbinstr = string.sub(binstr, 117, 122)

                    -- Everything in tables
                    local seconds
                    local ticks
                    if string.sub(childdata, 1, 37) == '8BhMVUEAAAABBQAAAAICAAAAA4BzZWNvbmRzC' then
                        --8BhMVUEAAAABBQAAAAICAAAAA4BzZWNvbmRzC_AAEAAAABXRpY2tzCAg
                        --8BhMVUEAAAABBQAAAAICAAAAA4BzZWNvbmRzC_DAEAAAABXRpY2tzCCA
                        --8BhMVUEAAAABBQAAAAICAAAAA4BzZWNvbmRzC_DsEAAAABXRpY2tzCCg
                        --identical_different
                        seconds = 0
                        for i = 99, 104 do                       -- used to be bits 5-10    |   99-104
                            if binarr[i] == 1 then
                                seconds = seconds + 2 ^ (i - 99) --used to be i - 5   |   i - 99
                            end
                        end
                        seconds = seconds - 16              --remove Offset
                        ticks = 0
                        for i = 3, 8 do                     -- used to be bits 117-122       |    3-8
                            if binarr[i] == 1 then
                                ticks = ticks + 2 ^ (i - 3) --used to be i - 117     |    i - 3
                            end
                        end
                        ticks = ticks - 16 --remove Offset --used to be -16
                    elseif string.sub(childdata, 1, 33) == '0ExVQQAAAAEFAAAAAgIFAPAHgHRpY2tzC' then
                        --0ExVQQAAAAEFAAAAAgIFAPAHgHRpY2tzC_AAEAAAAB3NlY29uZHMIAA
                        --0ExVQQAAAAEFAAAAAgIFAPAHgHRpY2tzC_CgEAAAAB3NlY29uZHMIOw
                        seconds = 0
                        for i = 5, 10 do                        -- used to be bits 5-10    |   99-104
                            if binarr[i] == 1 then
                                seconds = seconds + 2 ^ (i - 5) --used to be i - 5   |   i - 99
                            end
                        end
                        seconds = seconds - 4                 --remove Offset
                        ticks = 0
                        for i = 117, 122 do                   -- used to be bits 117-122       |    3-8
                            if binarr[i] == 1 then
                                ticks = ticks + 2 ^ (i - 117) --used to be i - 117     |    i - 3
                            end
                        end
                        ticks = ticks - 16 --remove Offset --used to be -16
                    else
                        -- sm.gui.chatMessage("#ff0000Fatal error while converting Fast Timers, please send a screenshot of this to ItchyTrack")
                        -- sm.gui.chatMessage(childdata)
                        goto continue
                    end

                    if (seconds < 0) or (seconds > 59) or (ticks < 0) or (ticks > 40) then
                        sm.gui.chatMessage("#ff0000Fatal error while converting Fast Timers, please send a screenshot of this to ItchyTrack")
                        sm.gui.chatMessage(childdata .. " " .. seconds .. " " .. ticks)
                        return
                    end
                    jsontable.bodies[i].childs[j].shapeId = "8f7fd0e7-c46e-4944-a414-7ce2437bb30f"
                    jsontable.bodies[i].childs[j].controller.data = nil
                    jsontable.bodies[i].childs[j].controller.active = false
                    jsontable.bodies[i].childs[j].controller.seconds = seconds
                    jsontable.bodies[i].childs[j].controller.ticks = ticks
                elseif flightsToVlights[jsontable.bodies[i].childs[j].shapeId] ~= nil then --Fast Light
                    local luminance = 50
                    local childdata = jsontable.bodies[i].childs[j].controller.data
                    if childdata == "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQgK" then
                        luminance = 10
                    elseif childdata == "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQgU" then
                        luminance = 20
                    elseif childdata == "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQge" then
                        luminance = 30
                    elseif childdata == "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQgo" then
                        luminance = 40
                    elseif childdata == "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQgy" then
                        luminance = 50
                    elseif childdata == "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQg8" then
                        luminance = 60
                    elseif childdata == "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQhG" then
                        luminance = 70
                    elseif childdata == "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQhQ" then
                        luminance = 80
                    elseif childdata == "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQha" then
                        luminance = 90
                    elseif childdata == "gExVQQAAAAEFBQDwAgIAAAAEgGx1bWluYW5jZQhk" then
                        luminance = 100
                    else
                        -- sm.gui.chatMessage("#ff0000Fatal error while converting Fast Warehouse Square Lights, please send a screenshot of this to ItchyTrack")
                        -- sm.gui.chatMessage(childdata)
                        goto continue
                    end
                    jsontable.bodies[i].childs[j].shapeId = flightsToVlights[jsontable.bodies[i].childs[j].shapeId]
                    jsontable.bodies[i].childs[j].controller.luminance = luminance
                    jsontable.bodies[i].childs[j].controller.data = nil
                end
                ::continue::
            end
        end
    end

    -- removing old body & spawning the new one
    local worldpos = body.worldPosition
    local worldrot = body.worldRotation
    local world = body:getWorld()

    local shapes = body:getCreationShapes()
    for _, shape in pairs(shapes) do
        shape:destroyShape()
    end

    local jsonstring = sm.json.writeJsonString(jsontable)
    sm.creation.importFromString(world, jsonstring, worldpos, worldrot, false)
end
