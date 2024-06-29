BackupEngine = {}

function BackupEngine.inject(multitool)
    multitool.BackupEngine = {}
    local self = multitool.BackupEngine
    self.knownBackups = {}
end

function BackupEngine.backupCreation(multitool, body, reason, callback)
    local id = tostring(sm.uuid.generateRandom())
    local backup = {
        id = id,
        reason = reason,
        filePath = "$CONTENT_DATA/Backups/" .. id .. ".json",
        time = os.time()
    }
    multitool.BackupEngine.knownBackups[id] = backup
    multitool.network:sendToServer("sv_backupCreation", {
        body = body,
        backup = backup,
        callback = callback
    })
    BackupEngine.syncSave(multitool)
    return id
end

function BackupEngine.sv_backupCreation(multitool, params)
    local body = params.body
    local backup = params.backup

    local blueprint = sm.creation.exportToTable(body)
    local data = {
        backup = backup,
        blueprint = blueprint,
        callback = params.callback
    }
    multitool.network:sendToClient(params.callback.player, "cl_saveBackup", data)
end

function BackupEngine.cl_saveBackup(multitool, data)
    local backup = data.backup
    local blueprint = data.blueprint
    local path = backup.filePath
    sm.json.save(blueprint, path)
    CallbackEngine.client_callCallback(data.callback, backup.id)
end

function BackupEngine.syncSave(multitool)
    local saveData = SaveFile.getSaveData()
    for id, backup in pairs(multitool.BackupEngine.knownBackups) do
        saveData.backups[id] = backup
    end
    while #multitool.BackupEngine.knownBackups > 0 do
        table.remove(multitool.BackupEngine.knownBackups)
    end
    SaveFile.setSaveData(saveData)
end