SaveFile = {}

function SaveFile.getSavePath(idx)
    local playerUsername = sm.localPlayer.getPlayer():getName()
    local allowedCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
    local saveFile = "$CONTENT_DATA/MTMultitoolSavefile_"
    for i = 1, #playerUsername do
        local char = string.sub(playerUsername, i, i)
        if string.find(allowedCharacters, char) then
            saveFile = saveFile .. char
        end
    end
    saveFile = saveFile .. idx .. ".json"
    return saveFile
end

local defaultSave = {
    modeStates = {
        ["SiliconConverter"] = false,
    },
    config = {},
    backups = {},
    ["version"] = 1
}

function SaveFile.getSaveData(idx)
    local path = SaveFile.getSavePath(idx)
    if not sm.json.fileExists(path) then
        return table.deepCopy(defaultSave)
    end
    local data = sm.json.open(path)
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
    return data
end

function SaveFile.setSaveData(idx, data)
    local path = SaveFile.getSavePath(idx)
    sm.json.save(data, path)
end