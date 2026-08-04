SaveFile = {}

function SaveFile.getSavePath(idx)
    local playerUsername = sm.localPlayer.getPlayer():getName()
    local allowedCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
    local allCharacters = {}
    for i = 1, #allowedCharacters do
        allCharacters[string.sub(allowedCharacters, i, i)] = true
    end
    local saveFile = "$CONTENT_DATA/MTMultitoolSavefile_"
    for i = 1, #playerUsername do
        local char = string.sub(playerUsername, i, i)
        if allCharacters[char] then
            saveFile = saveFile .. char
        end
    end
    saveFile = saveFile .. idx .. ".json"
    return saveFile
end

local defaultSave = {
    modeStates = {
        -- ["SiliconConverter"] = false,
    },
    config = {},
    backups = {},
    ["version"] = 1
}

-- TEMPORARY: keep saved JSON authoritative in memory until sm.json.save invalidates the DCO cache again.
local saveDataCache = {}

function SaveFile.getSaveData(idx)
    local path = SaveFile.getSavePath(idx)
    if saveDataCache[path] ~= nil then
        return saveDataCache[path]
    end
    if not sm.json.fileExists(path) then
        saveDataCache[path] = table.deepCopy(defaultSave)
        return saveDataCache[path]
    end
    -- local data = sm.json.open(path)
    -- pcall instead
    local success, data = pcall(sm.json.open, path)
    if not success then
        saveDataCache[path] = table.deepCopy(defaultSave)
        return saveDataCache[path]
    end
    if data["version"] == nil then
        data["version"] = 1
    end
    if data["version"] < defaultSave["version"] then
        error("HUH VERSION MISMATCH")
    end
    if data["backups"] == nil then
        data["backups"] = {}
    end
    if data["config"] == nil then
        data["config"] = {}
    end
    if data["modeStates"] == nil then
        data["modeStates"] = {}
    end
    saveDataCache[path] = data
    return data
end

function SaveFile.setSaveData(idx, data)
    local path = SaveFile.getSavePath(idx)
    saveDataCache[path] = data
    sm.json.save(data, path)
end