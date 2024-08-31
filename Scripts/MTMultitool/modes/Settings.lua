Settings = {}

function Settings.inject(multitool)
    multitool.Settings = {}
    local self = multitool.Settings
end

local modesAndTheirFunctions = {
    ["LogicConverter"] = "Lets you convert Vanilla Logic to Fast Logic and vice versa.",
    ["SiliconConverter"] =
    "Lets you convert Fast Logic to Silicon and vice versa. Silicon helps reduce lag and file size.",
    ["ModeChanger"] = "Lets you select a lot of gates and change their modes (AND/NOR/XOR/etc..) all at once",
    ["VolumePlacer"] = "Lets you place a cuboid of logic gates all at once",
    ["Merger"] =
    "Lets you merge gates. Merging takes all of a gates inputs and wires them into the gate's outputs deleting the gate.",
    ["VolumeDeleter"] = "Lets you delete a volumetric selection of gates, parts, and other shapes.",
    ["Heatmap"] = "Can show you the parts of your circuit that are using up the most compute.",
    ["Colorizer"] = "Changes the connection dot color of Fast Logic gates.",
    ["DecoderMaker"] = "Goofy tool that wires up decoders for you.",
    ["SingleConnect"] = "Allows you to select multiple source and destination gates and wire them together.",
    ["SeriesConnect"] = "Connects a row of gates in series, one into the next.",
    ["NtoNConnect"] = "Crosswires one row of gates into another.",
    ["ParallelConnect"] = "Wires two rows of gates of identical length together in parallel.",
    ["TensorConnect"] = "Lets you define two tensors of the same size and connect them together in parallel.",
}

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
            tooltip = function()
                if modesAndTheirFunctions[mode] then
                    return modesAndTheirFunctions[mode]
                else
                    return nil
                end
            end,
        })
        ::continue::
    end

    table.insert(hUI.elements, {
        name = "saveIndexDisplay",
        type = "indicator",
        position = { a = -math.pi/8 * fovMult, e = 2 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.2, 0.2, 0.9),
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = 0.03 * fovMult,
        getText = function()
            return "Save Index: " .. tostring(multitool.saveIdx)
        end,
        tooltip = function()
            return "The save index is used to store different settings profiles."
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
        tooltip = function()
            return "Increment the save index."
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
        tooltip = function()
            return "Decrement the save index."
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
        tooltip = function()
            return "Toggles flight mode for you. Not recommended for multiplayer."
        end,
    })

    table.insert(hUI.elements, {
        name = "connectionDisplayLimit",
        type = "customButton",
        position = { a = math.pi / 8 * fovMult, e = 3 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        angleBoundHorizontal = 0.1,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        getrender = function(hover)
            local text = "Connection Display Limit: " .. multitool.ConnectionManager.connectionDisplayLimit
            if hover then
                text = "[ " .. text .. " ]"
            end
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
        tooltip = function()
            return "The maximum number of connections that will be displayed in connection previews."
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
        tooltip = function()
            return "Toggles the display of connections between gates when looking at them with a connection tool."
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
        text = "Hide Connection on Look Away",
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        getState = function()
            return multitool.ConnectionShower.hideOnPanAway
        end,
        onclick = function()
            ConnectionShower.toggleHideOnPanAway(multitool)
        end,
        tooltip = function()
            return "Toggles if the connection display should hide when you look away from the gate."
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
        tooltip = function()
            return "Spawns the creation from the blueprint.json file in C:\\Program Files (x86)\\Steam\\steamapps\\common\\Scrap Mechanic\\Data"
        end,
    })
    table.insert(hUI.elements, {
        name = "importCreationCaption",
        type = "indicator",
        position = { a = math.pi / 8 * fovMult, e = 8 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.2, 0.2, 0.9),
        getText = function()
            return "from Scrap Mechanic\\Data\\blueprint.json"
        end,
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        tooltip = function()
            return "You can get here by browsing SM's local files on Steam, and then opening the Data folder. You will need to make the blueprint.json yourself."
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
        tooltip = function()
            return "Lets you smack the shit out of a Fast Logic gate with a hammer to pulse it for a tick."
        end,
    })

    if sm.isHost then
        table.insert(hUI.elements, {
            name = "goToBackupMenu",
            type = "button",
            position = { a = math.pi / 8 * fovMult, e = 13 * math.pi / 90 * fovMult },
            color = sm.color.new(0.2, 0.2, 0.9),
            text = "Open Backup Menu",
            angleBoundHorizontal = 0.1 * fovMult,
            angleBoundVertical = math.pi / 90 / 2 * fovMult,
            onclick = function()
                HoveringUI.cleanUp(multitool)
                multitool.mode = "BackupMenu"
            end,
        })
    end
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