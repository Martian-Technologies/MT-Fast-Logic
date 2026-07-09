NewToolMenuManifest = {}

local iconRoot = "$CONTENT_DATA/Scripts/NewTool/images/generated/"

local function icon(name)
    return iconRoot .. name .. ".json"
end

NewToolMenuManifest.main = {
    goals = {
        {
            id = "connect",
            label = "Connect",
            description = "Wire logic together using single, series, N-to-N, parallel, or tensor workflows.",
            icon = icon("connect"),
            actions = {
                "single_connect",
                "series_connect",
                "nto_n_connect",
                "parallel_connect",
                "tensor_connect"
            }
        },
        {
            id = "build",
            label = "Build",
            description = "Create new logic structures and helper constructions.",
            icon = icon("build"),
            actions = {
                "volume_placer",
                "decoder_maker"
            }
        },
        {
            id = "convert",
            label = "Convert",
            description = "Transform existing logic into faster or more compact forms.",
            icon = icon("convert"),
            actions = {
                "logic_converter",
                "silicon_converter",
                "merger"
            }
        },
        {
            id = "modify",
            label = "Modify",
            description = "Change existing creations without treating the action as a conversion.",
            icon = icon("modify"),
            actions = {
                "mode_changer",
                "volume_deleter",
                "colorizer",
                "copy_paste"
            }
        },
        {
            id = "inspect",
            label = "Inspect",
            description = "Understand, debug, and inspect existing logic creations.",
            icon = icon("inspect"),
            actions = {
                "heatmap"
            }
        },
        {
            id = "manage",
            label = "Manage",
            description = "Manage NewTool settings and tool-level behavior.",
            icon = icon("manage"),
            actions = {
                "settings"
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
