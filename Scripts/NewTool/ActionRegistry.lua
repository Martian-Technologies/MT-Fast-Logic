NewToolActionRegistry = {}

local iconRoot = "$CONTENT_DATA/Scripts/NewTool/images/generated/"

local function icon(name)
    return iconRoot .. name .. ".json"
end

local function dummyTool(id, label, description, iconName)
    return {
        id = id,
        kind = "tool",
        label = label,
        description = description,
        icon = icon(iconName or id),
        create = function(tool, action)
            return {
                id = action.id,
                label = action.label,
                description = action.description
            }
        end
    }
end

local function command(id, label, description, iconName, activePolicy, run)
    return {
        id = id,
        kind = "command",
        label = label,
        description = description,
        icon = icon(iconName or id),
        activePolicy = activePolicy or "keep",
        run = run
    }
end

NewToolActionRegistry.actions = {
    toggle_flight = command(
        "toggle_flight",
        "Toggle Flight",
        "Toggle NewTool flight without changing the active workflow.",
        "toggle_flight",
        "keep",
        function(tool)
            MTFlight.toggleFlying(tool)
        end
    ),

    single_connect = dummyTool("single_connect", "Single Connect", "Dummy workflow for one-to-one connection work.", "single_connect"),
    series_connect = dummyTool("series_connect", "Series Connect", "Dummy workflow for connecting a sequence of gates.", "series_connect"),
    nto_n_connect = dummyTool("nto_n_connect", "N-to-N Connect", "Dummy workflow for matching multiple sources to multiple targets.", "nto_n_connect"),
    parallel_connect = dummyTool("parallel_connect", "Parallel Connect", "Dummy workflow for connecting rows in parallel.", "parallel_connect"),
    tensor_connect = dummyTool("tensor_connect", "Tensor Connect", "Dummy workflow for high-dimensional bulk connection work.", "tensor_connect"),

    volume_placer = dummyTool("volume_placer", "Volume Placer", "Dummy workflow for placing volumes of logic.", "volume_placer"),
    decoder_maker = dummyTool("decoder_maker", "Decoder Maker", "Dummy workflow for building decoder structures.", "decoder_maker"),

    logic_converter = dummyTool("logic_converter", "Logic Converter", "Dummy workflow for converting logic gates to fast logic.", "logic_converter"),
    silicon_converter = dummyTool("silicon_converter", "Silicon Converter", "Dummy workflow for converting logic into silicon.", "silicon_converter"),
    merger = dummyTool("merger", "Merger", "Dummy workflow for merge/conversion work.", "merger"),

    mode_changer = dummyTool("mode_changer", "Mode Changer", "Dummy workflow for changing logic mode settings.", "mode_changer"),
    volume_deleter = dummyTool("volume_deleter", "Volume Deleter", "Dummy workflow for deleting selected volumes.", "volume_deleter"),
    colorizer = dummyTool("colorizer", "Colorizer", "Dummy workflow for changing connection dot colors.", "colorizer"),
    copy_paste = dummyTool("copy_paste", "Copy Paste", "Dummy workflow for copy/paste modification work.", "copy_paste"),

    heatmap = dummyTool("heatmap", "Heatmap", "Dummy workflow for inspecting logic activity.", "heatmap"),

    settings = dummyTool("settings", "Settings", "Dummy workflow for NewTool settings and management.", "settings")
}

function NewToolActionRegistry.get(id)
    return NewToolActionRegistry.actions[id]
end
