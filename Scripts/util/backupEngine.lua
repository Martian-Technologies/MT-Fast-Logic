sm.MTBackupEngine = sm.MTBackupEngine or {}

local function getBCUCfilename()local playerUsername = sm.MTBackupEngine.username
    local allowedCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
    local backupsCoordinatorFilename = "$CONTENT_DATA/Backups/BackupCoordinator_"
    for i = 1, #playerUsername do
        local char = string.sub(playerUsername, i, i)
        if string.find(allowedCharacters, char) then
            backupsCoordinatorFilename = backupsCoordinatorFilename .. char
        end
    end
    backupsCoordinatorFilename = backupsCoordinatorFilename .. ".json"
    return backupsCoordinatorFilename
end

local function saveBCUC(data)
    sm.json.save(data, getBCUCfilename())
end

local function loadBCUC()
    local filenameBCUC = getBCUCfilename()
    if not sm.json.fileExists(filenameBCUC) then
        saveBCUC({
            version = 1,
            backupsInUse = {},
            unusedBackups = {}
        })
    end
    local data = sm.json.open(filenameBCUC)
    if data.unusedBackups == nil then
        data.unusedBackups = {}
    end
    if data.backupsInUse == nil then
        data.backupsInUse = {}
    end
    return data
end

function sm.MTBackupEngine.sv_backupCreation(data)
    local creationData
    if data.hasCreationData then
        creationData = data.creationData
    else
        local body = data.body
        creationData = sm.creation.exportToTable(body, true, true)
    end
    local backupsCoordinator = loadBCUC()
    local backupFilename
    if #backupsCoordinator.unusedBackups == 0 then
        backupFilename = "$CONTENT_DATA/Backups/Backup_" .. tostring(sm.uuid.new()) .. ".json"
        table.insert(backupsCoordinator.backupsInUse, backupFilename)
    else
        backupFilename = backupsCoordinator.unusedBackups[#backupsCoordinator.unusedBackups]
        table.remove(backupsCoordinator.unusedBackups, #backupsCoordinator.unusedBackups)
        table.insert(backupsCoordinator.backupsInUse, backupFilename)
    end
    saveBCUC(backupsCoordinator)
    local backupData = {
        version = 1,
        name = data.name or "Unnamed",
        description = data.description or "No description",
        creationType = data.creationType or "Unknown",
        timeCreated = os.time(),
        isPinned = data.isPinned or false,
        creationData = creationData
    }
    sm.json.save(backupData, backupFilename)
end

function sm.MTBackupEngine.cl_setUsername()
    local playerUsername = sm.localPlayer.getPlayer():getName()
    sm.MTBackupEngine.username = playerUsername
end

function sm.MTBackupEngine.sv_deleteBackup(uuid)
    -- we cannot actually delete files, but we can mark them as unused
    local backupsCoordinator = loadBCUC()
    local backupFilename = "$CONTENT_DATA/Backups/Backup_" .. uuid .. ".json"
    for i, backup in pairs(backupsCoordinator.backupsInUse) do
        if backup == backupFilename then
            table.remove(backupsCoordinator.backupsInUse, i)
            table.insert(backupsCoordinator.unusedBackups, backupFilename)
            saveBCUC(backupsCoordinator)
            return
        end
    end
    error("Backup not found")
end

function sm.MTBackupEngine.sv_deleteOldBackups()
    -- delete all unpinned backups older than 1 week
    local backupsCoordinator = loadBCUC()
    local currentTime = os.time()
    for i = #backupsCoordinator.backupsInUse, 1, -1 do
        local backupFilename = backupsCoordinator.backupsInUse[i]
        local backupData = sm.json.open(backupFilename)
        if not backupData.isPinned and currentTime - backupData.timeCreated > 604800 then
            table.remove(backupsCoordinator.backupsInUse, i)
            table.insert(backupsCoordinator.unusedBackups, backupFilename)
        end
    end
    saveBCUC(backupsCoordinator)
end

function sm.MTBackupEngine.cl_getBackups()
    if not sm.isHost then
        return {}
    end
    sm.MTBackupEngine.sv_deleteOldBackups()
    return loadBCUC().backupsInUse
end

function sm.MTBackupEngine.cl_getBackupData(filename)
    return sm.json.open(filename)
end

function sm.MTBackupEngine.sv_loadBackup(multitool, backupFilename)
    local backupData = sm.json.open(backupFilename)
    local creationData = backupData.creationData
    local character = multitool.tool:getOwner().character
    local creationBodies = sm.creation.importFromString(character:getWorld(), sm.json.writeJsonString(creationData),
        character:getWorldPosition() + character:getDirection() * 8, sm.quat.new(0, 0, 0, 1))
    for _, body in pairs(creationBodies) do
        body:setDestructable(true)
    end
end