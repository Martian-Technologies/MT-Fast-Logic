Settings = {}

function Settings.inject(multitool)
    multitool.Settings = {}
    local self = multitool.Settings
end

local function injectElements(multitool)
    local fovMult = sm.camera.getFov() / 90

    local hUI = multitool.HoveringUI

    hUI.elements = {}

    local v = 0
    for i = 1, #MTMultitool.internalModes do
        local mode = MTMultitool.internalModes[i]
        if mode == "Settings" then goto continue end
        v = v + 1
        table.insert(hUI.elements, {
            name = "toolToggle_" .. mode,
            type = "toggleButton",
            position = { a = 0, e = (#MTMultitool.internalModes-v) * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
            color = {
                on = sm.color.new(0.2, 0.9, 0.2),
                off = sm.color.new(0.9, 0.2, 0.2)
            },
            text = MTMultitool.modes[i],
            angleBoundHorizontal = 0.1 * fovMult,
            angleBoundVertical = math.pi / 90 / 2 * fovMult,
            getState = function()
                return multitool.enabledModes[i]
            end,
            onclick = function()
                multitool.enabledModes[i] = not multitool.enabledModes[i]
                local saveData = SaveFile.getSaveData(multitool.saveIdx)
                saveData.modeStates[mode] = multitool.enabledModes[i]
                SaveFile.setSaveData(multitool.saveIdx, saveData)
            end,
        })
        ::continue::
    end

    table.insert(hUI.elements, {
        name = "saveIndexDisplay",
        type = "indicator",
        position = { a = -math.pi/8 * fovMult, e = 2 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.2, 0.2, 0.9),
        getText = function()
            return "Save Index: " .. tostring(multitool.saveIdx)
        end,
    })

    table.insert(hUI.elements, {
        name = "saveIndexIncrease",
        type = "button",
        position = { a = -math.pi/8 * fovMult, e = 3 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.2, 0.2, 0.9),
        text = "↑",
        angleBoundHorizontal = 0.03 * fovMult,
        angleBoundVertical = 0.03 * fovMult,
        onclick = function()
            if multitool.saveIdx == 5 then
                multitool.saveIdx = 1
            else
                multitool.saveIdx = multitool.saveIdx + 1
            end
            MTMultitool.repullSettings(multitool)
        end,
    })

    table.insert(hUI.elements, {
        name = "saveIndexDecrease",
        type = "button",
        position = { a = -math.pi/8 * fovMult, e = 1 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.2, 0.2, 0.9),
        text = "↓",
        angleBoundHorizontal = 0.03 * fovMult,
        angleBoundVertical = 0.03 * fovMult,
        onclick = function()
            if multitool.saveIdx == 1 then
                multitool.saveIdx = 5
            else
                multitool.saveIdx = multitool.saveIdx - 1
            end
            MTMultitool.repullSettings(multitool)
        end,
    })

    table.insert(hUI.elements, {
        name = "flyModeToggle",
        type = "customButton",
        position = { a = math.pi / 8 * fovMult, e = 2 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        getrender = function(hovering)
            local isFlying = multitool.MTFlying.flying
            local text = "Fly Mode: " .. (isFlying and "On" or "Off")
            local color = isFlying and sm.color.new(0.2, 0.9, 0.2) or sm.color.new(0.9, 0.2, 0.2)
            if hovering then
                text = "[ " .. text .. " ]"
            end
            return {
                text = text,
                color = color,
            }
        end,
        onclick = function()
            MTFlying.toggleFlying(multitool)
        end,
    })

    table.insert(hUI.elements, {
        name = "connectionDisplayLimit",
        type = "customButton",
        position = { a = math.pi / 8 * fovMult, e = 3 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        angleBoundHorizontal = 0.1,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        getrender = function()
            local text = "Connection Display Limit: " .. multitool.ConnectionManager.connectionDisplayLimit
            return {
                text = text,
                color = sm.color.new(0.2, 0.2, 0.9),
            }
        end,
        onclick = function()
            local options = { 128, 256, 512, 1024, 2048, 4096, 8194, 16384, "unlimited" }
            local idx = table.find(options, multitool.ConnectionManager.connectionDisplayLimit)
            local newLimit = options[1]
            if idx ~= #options then
                newLimit = options[idx + 1]
            end
            ConnectionManager.updateConnectionLimitDisplay(multitool, newLimit)
        end,
    })

    table.insert(hUI.elements, {
        name = "showConnections",
        type = "toggleButton",
        position = { a = math.pi / 8 * fovMult, e = 6 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = {
            on = sm.color.new(0.2, 0.9, 0.2),
            off = sm.color.new(0.9, 0.2, 0.2)
        },
        text = "Show Connections",
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        getState = function()
            return multitool.ConnectionShower.enabled
        end,
        onclick = function()
            ConnectionShower.toggle(multitool)
        end,
    })

    table.insert(hUI.elements, {
        name = "hideOnPanAway",
        type = "toggleButton",
        position = { a = math.pi / 8 * fovMult, e = 5 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = {
            on = sm.color.new(0.2, 0.9, 0.2),
            off = sm.color.new(0.9, 0.2, 0.2)
        },
        text = "Hide on Pan Away",
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        getState = function()
            return multitool.ConnectionShower.hideOnPanAway
        end,
        onclick = function()
            ConnectionShower.toggleHideOnPanAway(multitool)
        end,
    })

    table.insert(hUI.elements, {
        name = "importCreation",
        type = "button",
        position = { a = math.pi / 8 * fovMult, e = 9 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.2, 0.2, 0.9),
        text = "Import Creation",
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        onclick = function()
            BlueprintSpawner.cl_spawn(multitool)
        end,
    })
    table.insert(hUI.elements, {
        name = "importCreationCaption",
        type = "indicator",
        position = { a = math.pi / 8 * fovMult, e = 8 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.2, 0.2, 0.9),
        getText = function()
            return "from Scrap Mechanic/Data/blueprint.json"
        end,
    })

    table.insert(hUI.elements, {
        name = "doMeleeState",
        type = "toggleButton",
        position = { a = math.pi / 8 * fovMult, e = 11 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = {
            on = sm.color.new(0.2, 0.9, 0.2),
            off = sm.color.new(0.9, 0.2, 0.2)
        },
        text = "Hammer One Tick (fast logic)",
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        getState = function()
            return multitool.DoMeleeState.enabled
        end,
        onclick = function()
            DoMeleeState.toggle(multitool)
        end,
    })
end

function Settings.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    if HoveringUI.elements == nil then
        injectElements(multitool)
    end
    HoveringUI.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
end

function Settings.cleanUp(multitool)
    HoveringUI.cleanUp(multitool)
end