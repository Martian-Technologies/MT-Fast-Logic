NewToolInputGlyph = {}

local bindings = {
    attack = "Attack",
    rightclick = "Attack",
    rmb = "Attack",
    secondary = "Attack",

    create = "Create",
    leftclick = "Create",
    lmb = "Create",
    primary = "Create",

    forcebuild = "ForceBuild",
    menu = "ForceBuild",
    reload = "Reload",
    rotate = "NextCreateRotation",
    nextcreaterotation = "NextCreateRotation",
    crouch = "Crawl",
    use = "Use"
}

local function normalize(name)
    return tostring(name or ""):lower():gsub("[^%w]", "")
end

function NewToolInputGlyph.get(name)
    local binding = bindings[normalize(name)]
    assert(binding ~= nil, "Unknown NewTool input: " .. tostring(name))
    return sm.gui.getKeyBinding(binding, true)
end
