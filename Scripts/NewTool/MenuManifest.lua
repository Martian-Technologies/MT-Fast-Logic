NewToolMenuManifest = {}

local iconRoot = "$CONTENT_DATA/Scripts/NewTool/images/generated/"

local function icon(name)
    return iconRoot .. name .. ".json"
end

local function selectGoal(goalId)
    return {
        type = "selectSwitcher",
        switcher = "goal_actions",
        child = goalId
    }
end

NewToolMenuManifest.main = {
    id = "main",
    kind = "hub",
    layout = {
        widgets = {
            {
                kind = "tileStack",
                id = "goals",
                slot = "left",
                direction = "vertical",
                tileSize = "goal",
                items = {
                    {
                        id = "connect",
                        label = "Connect",
                        description = "Wire logic together and generate connected helper structures.",
                        icon = icon("connect"),
                        selectedIcon = icon("connect_selected"),
                        onSelect = selectGoal("connect")
                    },
                    {
                        id = "edit",
                        label = "Edit",
                        description = "Create, change, convert, delete, or rearrange existing creation content.",
                        icon = icon("modify"),
                        selectedIcon = icon("modify_selected"),
                        onSelect = selectGoal("edit")
                    },
                    {
                        id = "utility",
                        label = "Utility",
                        description = "Inspect creations and manage NewTool behavior.",
                        icon = icon("manage"),
                        selectedIcon = icon("manage_selected"),
                        onSelect = selectGoal("utility")
                    }
                }
            },
            {
                kind = "switcher",
                id = "goal_actions",
                slot = "right",
                initialChild = "connect",
                align = "center",
                children = {
                    connect = {
                        kind = "tileGrid",
                        id = "connect_actions",
                        columns = 3,
                        tileSize = "actionGrid",
                        columnGap = 0.5,
                        rowGap = 0.45,
                        items = {
                            { actionId = "multipoint_connect" },
                            { actionId = "series_connect" },
                            { actionId = "n_to_n_connect" },
                            { actionId = "parallel_connect" },
                            { actionId = "tensor_connect" },
                            { actionId = "decoder_maker" }
                        }
                    },
                    edit = {
                        kind = "tileGrid",
                        id = "edit_actions",
                        columns = 3,
                        tileSize = "actionGrid",
                        columnGap = 0.5,
                        rowGap = 0.45,
                        items = {
                            { actionId = "volume_placer" },
                            { actionId = "volume_deleter" },
                            { actionId = "copy_paste" },
                            { actionId = "colorizer" },
                            { actionId = "mode_changer" },
                            { actionId = "logic_converter" },
                            { actionId = "silicon_converter" },
                            { actionId = "merger" }
                        }
                    },
                    utility = {
                        kind = "tileGrid",
                        id = "utility_actions",
                        columns = 3,
                        tileSize = "actionGrid",
                        columnGap = 0.5,
                        rowGap = 0.45,
                        items = {
                            { actionId = "heatmap" },
                            { actionId = "settings" }
                        }
                    }
                }
            }
        }
    }
}

NewToolMenuManifest.radial = {
    id = "radial",
    kind = "radial",
    slotCount = 8,
    menuDistance = 20,
    radiusAngle = math.pi / 14,
    iconSize = 3,
    hoverDistanceScale = 0.75,
    hoverDirectionLerp = 0.9,
    emptyIcon = "$CONTENT_DATA/Scripts/NewTool/images/cancel.json",
    pinnedTools = {
        "multipoint_connect",
        "series_connect",
        "parallel_connect",
        "tensor_connect"
    },
    commands = {
        "toggle_flight"
    }
}
