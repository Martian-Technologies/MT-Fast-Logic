-- Stores NewTool settings separately from MTMultitool settings.

NewToolSettingsStore = {}

local defaults = {
    version = 1,
    connectionShower = false,
    stateDisplay = false
}

local function copyDefaults()
    return {
        version = defaults.version,
        connectionShower = defaults.connectionShower,
        stateDisplay = defaults.stateDisplay
    }
end

local function settingsPath()
    local player = sm.localPlayer.getPlayer()
    local name = player and player:getName() or "player"
    local safeName = string.gsub(name, "[^%w_-]", "")
    if safeName == "" then safeName = "player" end
    return "$CONTENT_DATA/NewToolSettings_" .. safeName .. ".json"
end

function NewToolSettingsStore.init(tool)
    tool.SettingsStore = {}
    local self = tool.SettingsStore
    local path = nil
    local data = copyDefaults()

    if tool.tool:isLocal() then
        path = settingsPath()
        if sm.json.fileExists(path) then
            local ok, loaded = pcall(sm.json.open, path)
            if ok and type(loaded) == "table" then data = loaded end
        end
    end

    data.version = defaults.version
    if type(data.connectionShower) ~= "boolean" then data.connectionShower = defaults.connectionShower end
    if type(data.stateDisplay) ~= "boolean" then data.stateDisplay = defaults.stateDisplay end

    local function save()
        if path == nil then return end
        local ok, saveError = pcall(sm.json.save, data, path)
        if not ok then print("Could not save NewTool settings: " .. tostring(saveError)) end
    end

    function self.get(key)
        return data[key]
    end

    function self.set(key, value)
        if defaults[key] == nil or type(value) ~= "boolean" then return false end
        data[key] = value
        save()
        return true
    end

    function self.toggle(key)
        if type(data[key]) ~= "boolean" then return nil end
        data[key] = not data[key]
        save()
        return data[key]
    end
end
