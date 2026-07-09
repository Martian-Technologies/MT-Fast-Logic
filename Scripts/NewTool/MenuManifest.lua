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
                        description = "Wire logic together using single, series, N-to-N, parallel, or tensor workflows.",
                        icon = icon("connect"),
                        selectedIcon = icon("connect_selected"),
                        onSelect = selectGoal("connect")
                    },
                    {
                        id = "build",
                        label = "Build",
                        description = "Create new logic structures and helper constructions.",
                        icon = icon("build"),
                        selectedIcon = icon("build_selected"),
                        onSelect = selectGoal("build")
                    },
                    {
                        id = "convert",
                        label = "Convert",
                        description = "Transform existing logic into faster or more compact forms.",
                        icon = icon("convert"),
                        selectedIcon = icon("convert_selected"),
                        onSelect = selectGoal("convert")
                    },
                    {
                        id = "modify",
                        label = "Modify",
                        description = "Change existing creations without treating the action as a conversion.",
                        icon = icon("modify"),
                        selectedIcon = icon("modify_selected"),
                        onSelect = selectGoal("modify")
                    },
                    {
                        id = "inspect",
                        label = "Inspect",
                        description = "Understand, debug, and inspect existing logic creations.",
                        icon = icon("inspect"),
                        selectedIcon = icon("inspect_selected"),
                        onSelect = selectGoal("inspect")
                    },
                    {
                        id = "manage",
                        label = "Manage",
                        description = "Manage NewTool settings and tool-level behavior.",
                        icon = icon("manage"),
                        selectedIcon = icon("manage_selected"),
                        onSelect = selectGoal("manage")
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
                        kind = "tileStack",
                        id = "connect_actions",
                        direction = "vertical",
                        tileSize = "action",
                        items = {
                            { actionId = "single_connect" },
                            { actionId = "series_connect" },
                            { actionId = "nto_n_connect" },
                            { actionId = "parallel_connect" },
                            { actionId = "tensor_connect" }
                        }
                    },
                    build = {
                        kind = "tileStack",
                        id = "build_actions",
                        direction = "vertical",
                        tileSize = "action",
                        items = {
                            { actionId = "volume_placer" },
                            { actionId = "decoder_maker" }
                        }
                    },
                    convert = {
                        kind = "tileStack",
                        id = "convert_actions",
                        direction = "vertical",
                        tileSize = "action",
                        items = {
                            { actionId = "logic_converter" },
                            { actionId = "silicon_converter" },
                            { actionId = "merger" }
                        }
                    },
                    modify = {
                        kind = "tileStack",
                        id = "modify_actions",
                        direction = "vertical",
                        tileSize = "action",
                        items = {
                            { actionId = "mode_changer" },
                            { actionId = "volume_deleter" },
                            { actionId = "colorizer" },
                            { actionId = "copy_paste" }
                        }
                    },
                    inspect = {
                        kind = "tileStack",
                        id = "inspect_actions",
                        direction = "vertical",
                        tileSize = "action",
                        items = {
                            { actionId = "heatmap" }
                        }
                    },
                    manage = {
                        kind = "tileStack",
                        id = "manage_actions",
                        direction = "vertical",
                        tileSize = "action",
                        items = {
                            { actionId = "settings" }
                        }
                    }
                }
            }
        }
    }
}

NewToolMenuManifest.radial = {
    pinnedTools = {
        "single_connect",
        "series_connect",
        "parallel_connect",
        "tensor_connect"
    },
    commands = {
        "toggle_flight"
    }
}
