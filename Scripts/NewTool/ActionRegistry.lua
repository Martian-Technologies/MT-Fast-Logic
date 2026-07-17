NewToolActionRegistry = {}

local iconRoot = "$CONTENT_DATA/Scripts/NewTool/images/generated/"

local function icon(name)
    return iconRoot .. name .. ".json"
end

local function toolMode(id, label, description, iconName, create)
    return {
        id = id,
        kind = "tool",
        label = label,
        description = description,
        icon = icon(iconName or id),
        create = create or function(tool, registeredAction)
            return {
                id = registeredAction.id,
                label = registeredAction.label,
                description = registeredAction.description
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
        "Toggle NewTool flight without changing the selected tool mode.",
        "toggle_flight",
        "keep",
        function(tool)
            MTFlight.toggleFlying(tool)
        end
    ),

    multipoint_connect = toolMode(
        "multipoint_connect",
        "Multipoint Connect",
        "Connect or disconnect source and destination groups.",
        "single_connect",
        function(tool, action)
            return NewToolMultipointConnect.new(tool, action)
        end
    ),
    series_connect = toolMode(
        "series_connect",
        "Series Connect",
        "Connect each gate in a straight row to the next gate.",
        "series_connect",
        function(tool, action)
            return NewToolSeriesConnect.new(tool, action)
        end
    ),
    n_to_n_connect = toolMode("n_to_n_connect", "N-to-N Connect", "Dummy mode for matching multiple sources to multiple targets.", "n_to_n_connect"),
    parallel_connect = toolMode(
        "parallel_connect",
        "Parallel Connect",
        "Select two rows of gates to connect in parallel.",
        "parallel_connect",
        function(tool, action)
            return NewToolParallelConnect.new(tool, action)
        end
    ),
    tensor_connect = toolMode("tensor_connect", "Tensor Connect", "Dummy mode for high-dimensional bulk connection work.", "tensor_connect"),

    volume_placer = toolMode("volume_placer", "Volume Placer", "Dummy mode for placing volumes of logic.", "volume_placer"),
    decoder_maker = toolMode("decoder_maker", "Decoder Maker", "Dummy mode for building decoder structures.", "decoder_maker"),

    logic_converter = toolMode("logic_converter", "Logic Converter", "Dummy mode for converting logic gates to fast logic.", "logic_converter"),
    silicon_converter = toolMode("silicon_converter", "Silicon Converter", "Dummy mode for converting logic into silicon.", "silicon_converter"),
    merger = toolMode("merger", "Merger", "Dummy mode for merge/conversion work.", "merger"),

    mode_changer = toolMode("mode_changer", "Mode Changer", "Dummy mode for changing logic mode settings.", "mode_changer"),
    volume_deleter = toolMode("volume_deleter", "Volume Deleter", "Dummy mode for deleting selected volumes.", "volume_deleter"),
    colorizer = toolMode("colorizer", "Colorizer", "Dummy mode for changing connection dot colors.", "colorizer"),
    copy_paste = toolMode("copy_paste", "Copy Paste", "Dummy mode for copy/paste modification work.", "copy_paste"),

    heatmap = toolMode("heatmap", "Heatmap", "Dummy mode for inspecting logic activity.", "heatmap"),

    settings = toolMode("settings", "Settings", "Dummy mode for NewTool settings and management.", "settings")
}

function NewToolActionRegistry.get(id)
    return NewToolActionRegistry.actions[id]
end
