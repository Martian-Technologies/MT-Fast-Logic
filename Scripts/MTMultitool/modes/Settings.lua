Settings = {}

function Settings.inject(multitool)
    multitool.Settings = {}
    local self = multitool.Settings
end

local modesAndTheirFunctions = {
    ["LogicConverter"] = "mt.settings.desc.logic_converter",
    ["SiliconConverter"] = "mt.settings.desc.silicon_converter",
    ["ModeChanger"] = "mt.settings.desc.mode_changer",
    ["VolumePlacer"] = "mt.settings.desc.volume_placer",
    ["Merger"] = "mt.settings.desc.merger",
    ["VolumeDeleter"] = "mt.settings.desc.volume_deleter",
    ["Heatmap"] = "mt.settings.desc.heatmap",
    ["Colorizer"] = "mt.settings.desc.colorizer",
    ["DecoderMaker"] = "mt.settings.desc.decoder_maker",
    ["SingleConnect"] = "mt.settings.desc.single_connect",
    ["SeriesConnect"] = "mt.settings.desc.series_connect",
    ["NtoNConnect"] = "mt.settings.desc.nto_n_connect",
    ["ParallelConnect"] = "mt.settings.desc.parallel_connect",
    ["TensorConnect"] = "mt.settings.desc.tensor_connect",
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
            return tr("mt.settings.save_index", { index = multitool.saveIdx })
        end,
        tooltip = function()
            return "mt.settings.save_index_tooltip"
        end,
    })

    table.insert(hUI.elements, {
        name = "saveIndexIncrease",
        type = "button",
        position = { a = -math.pi/8 * fovMult, e = 3 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.2, 0.2, 0.9),
        text = "/\\",
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
            return "mt.settings.increment_save_index"
        end,
    })

    table.insert(hUI.elements, {
        name = "saveIndexDecrease",
        type = "button",
        position = { a = -math.pi/8 * fovMult, e = 1 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.2, 0.2, 0.9),
        text = "\\/",
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
            return "mt.settings.decrement_save_index"
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
            local text = tr("mt.settings.fly_mode", { state = isFlying and tr("mt.common.on") or tr("mt.common.off") })
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
            return "mt.settings.fly_tooltip"
        end,
    })

    table.insert(hUI.elements, {
        name = "connectionDisplayLimit",
        type = "customButton",
        position = { a = math.pi / 8 * fovMult, e = 3 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        angleBoundHorizontal = 0.1,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        getrender = function(hover)
            local text = tr("mt.settings.connection_display_limit", { limit = multitool.ConnectionManager.connectionDisplayLimit })
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
            return "mt.settings.connection_display_limit_tooltip"
        end,
    })

    table.insert(hUI.elements, {
        name = "showConnections",
        type = "toggleButton",
        position = { a = math.pi / 8 * fovMult, e = 7 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = {
            on = sm.color.new(0.2, 0.9, 0.2),
            off = sm.color.new(0.9, 0.2, 0.2)
        },
        text = "mt.settings.show_connections",
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        getState = function()
            return multitool.ConnectionShower.enabled
        end,
        onclick = function()
            ConnectionShower.toggle(multitool)
        end,
        tooltip = function()
            return "mt.settings.show_connections_tooltip"
        end,
    })

    table.insert(hUI.elements, {
        name = "hideOnPanAway",
        type = "toggleButton",
        position = { a = math.pi / 8 * fovMult, e = 6 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = {
            on = sm.color.new(0.2, 0.9, 0.2),
            off = sm.color.new(0.9, 0.2, 0.2)
        },
        text = "mt.settings.hide_connection",
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        getState = function()
            return multitool.ConnectionShower.hideOnPanAway
        end,
        onclick = function()
            ConnectionShower.toggleHideOnPanAway(multitool)
        end,
        tooltip = function()
            return "mt.settings.hide_connection_tooltip"
        end,
    })

    table.insert(hUI.elements, {
        name = "showGateState",
        type = "toggleButton",
        position = { a = math.pi / 8 * fovMult, e = 5 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = {
            on = sm.color.new(0.2, 0.9, 0.2),
            off = sm.color.new(0.9, 0.2, 0.2)
        },
        text = "mt.settings.show_gate_states",
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        getState = function()
            return multitool.StateDisplay.enabled
        end,
        onclick = function()
            StateDisplay.toggle(multitool)
        end,
        tooltip = function()
            return "mt.settings.show_gate_states_tooltip"
        end,
    })

    table.insert(hUI.elements, {
        name = "importCreation",
        type = "button",
        position = { a = math.pi / 8 * fovMult, e = 10 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.2, 0.2, 0.9),
        text = "mt.settings.import_creation",
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        onclick = function()
            BlueprintSpawner.cl_spawn(multitool)
        end,
        tooltip = function()
            return "mt.settings.import_creation_tooltip"
        end,
    })
    table.insert(hUI.elements, {
        name = "importCreationCaption",
        type = "indicator",
        position = { a = math.pi / 8 * fovMult, e = 9 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = sm.color.new(0.2, 0.2, 0.9),
        getText = function()
            return "mt.settings.import_caption"
        end,
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        tooltip = function()
            return "mt.settings.import_caption_tooltip"
        end,
    })

    table.insert(hUI.elements, {
        name = "doMeleeState",
        type = "toggleButton",
        position = { a = math.pi / 8 * fovMult, e = 12 * math.pi / 90 * fovMult }, -- a = azimuth, e = elevation
        color = {
            on = sm.color.new(0.2, 0.9, 0.2),
            off = sm.color.new(0.9, 0.2, 0.2)
        },
        text = "mt.settings.hammer_one_tick",
        angleBoundHorizontal = 0.1 * fovMult,
        angleBoundVertical = math.pi / 90 / 2 * fovMult,
        getState = function()
            return multitool.DoMeleeState.enabled
        end,
        onclick = function()
            DoMeleeState.toggle(multitool)
        end,
        tooltip = function()
            return "mt.settings.hammer_one_tick_tooltip"
        end,
    })

    if sm.isHost then
        table.insert(hUI.elements, {
            name = "goToBackupMenu",
            type = "button",
            position = { a = math.pi / 8 * fovMult, e = 14 * math.pi / 90 * fovMult },
            color = sm.color.new(0.2, 0.2, 0.9),
            text = "mt.settings.open_backup_menu",
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