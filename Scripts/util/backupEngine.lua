dofile "compressionUtil/compressionUtil.lua"
dofile "../allCreationStuff/CreationUtil.lua"

sm.MTBackupEngine = sm.MTBackupEngine or {}

local cleanNeedCountDown = 10

local allowedCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
local allCharacters = {}
for i = 1, #allowedCharacters do
    allCharacters[string.sub(allowedCharacters, i, i)] = true
end

local playerNameHash = {}
local function getPlayerName()
    local playerUsername = sm.MTBackupEngine.username
    if playerNameHash[playerUsername] ~= nil then
        return playerNameHash[playerUsername]
    end
    local name = ""
    for i = 1, #playerUsername do
        local char = string.sub(playerUsername, i, i)
        if allCharacters[char] then
            name = name .. char
        end
    end
    playerNameHash[playerUsername] = name
    return name
end

local function getBCUCfilenameOLD()
    local backupsCoordinatorFilename = "$CONTENT_DATA/Backups/BackupCoordinator_"
    return backupsCoordinatorFilename .. getPlayerName() ..  ".json"
end

local coordinatorFileName = "$CONTENT_DATA/Backups/AllBackupCoordinator.json"

local function saveCoordinator(data)
    sm.json.save(data, coordinatorFileName)
end

local function loadCoordinator()
    local allData
    if not sm.json.fileExists(coordinatorFileName) then
        local filenameBCUC = getBCUCfilenameOLD()
        if sm.json.fileExists(filenameBCUC) then
            allData = {
                version = 1,
                players = {
                    [getPlayerName()] = sm.json.open(filenameBCUC)
                }
            }
        else
            allData = {
                version = 1,
                players = {}
            }
        end
        saveCoordinator(allData)
    else
        allData = sm.json.open(coordinatorFileName)
    end
    return allData
end

local function savePlayerCoordinator(data)
    local allData = loadCoordinator()
    allData.players[getPlayerName()] = data
    saveCoordinator(allData)
end

local function correctOldVersions(playerData)
    if playerData.version == 1 then
        if playerData.unusedBackups == nil then
            playerData.unusedBackups = {}
        end
        if playerData.backupsInUse == nil then
            playerData.backupsInUse = {}
        end
        local newPlayerData = {
            version = 2,
            backups = {},
            unusedBackupFilenames = {}
        }
        for _, backupFilename in pairs(playerData.backupsInUse) do
            local backupData = sm.json.open(backupFilename)
            if not backupData.isPinned and os.time() - backupData.timeCreated > 604800 then
                table.insert(newPlayerData.unusedBackupFilenames, backupFilename)
            else
                table.insert(newPlayerData.backups, {
                    name = backupData.name,
                    description = backupData.description,
                    creationType = backupData.creationType,
                    timeCreated = backupData.timeCreated,
                    isPinned = backupData.isPinned,
                    backupFilename = backupFilename
                })
            end
        end
        for _, backupFilename in pairs(playerData.unusedBackups) do
            table.insert(newPlayerData.unusedBackupFilenames, backupFilename)
        end
        return newPlayerData, true
    end
    if playerData.backups == nil then
        playerData.backups = {}
    end
    if playerData.unusedBackupFilenames == nil then
        playerData.unusedBackupFilenames = {}
    end
    return playerData, false
end

local function loadPlayerCoordinator()
    local allData = loadCoordinator()
    if allData.players[getPlayerName()] == nil then
        allData.players[getPlayerName()] = {
            version = 2,
            backups = {},
            unusedBackupFilenames = {}
        }
        saveCoordinator(allData)
    end
    local playerData, doSave = correctOldVersions(allData.players[getPlayerName()])
    if doSave then
        allData.players[getPlayerName()] = playerData
        saveCoordinator(allData)
    end
    return playerData
end

function sm.MTBackupEngine.sv_backupCreation(data)
    local creationData
    local body = data.body
    if data.hasCreationData then
        creationData = data.creationData
    else
        creationData = sm.creation.exportToTable(body, true, true)
    end
    local backupsCoordinator = loadPlayerCoordinator()
    local backupFilename
    if #backupsCoordinator.unusedBackupFilenames == 0 then
        backupFilename = "$CONTENT_DATA/Backups/Backup_" .. tostring(sm.uuid.new()) .. ".json"
    else
        backupFilename = backupsCoordinator.unusedBackupFilenames[#backupsCoordinator.unusedBackupFilenames]
        table.remove(backupsCoordinator.unusedBackupFilenames, #backupsCoordinator.unusedBackupFilenames)
    end
    table.insert(backupsCoordinator.backups, {
        name = data.name or "Unnamed",
        description = data.description or "No description",
        creationType = data.creationType or "Unknown",
        timeCreated = os.time(),
        isPinned = data.isPinned or false,
        backupFilename = backupFilename,
        creationId = sm.MTFastLogic.CreationUtil.getCreationId(body)
    })
    savePlayerCoordinator(backupsCoordinator)
    -- local backupData = {
    --     version = 1,
    --     name = data.name or "Unnamed",
    --     description = data.description or "No description",
    --     creationType = data.creationType or "Unknown",
    --     timeCreated = os.time(),
    --     isPinned = data.isPinned or false,
    --     creationData = creationData
    -- }
    local stringifiedCreationData = sm.json.writeJsonString(creationData)
    local compressedCreationData = sm.MTFastLogic.CompressionUtil.LibDeflate:EncodeForPrint(sm.MTFastLogic.CompressionUtil
    .LibDeflate:CompressDeflate(stringifiedCreationData))
    local backupData = {
        version = 2,
        creationData = compressedCreationData
    }
    sm.json.save(backupData, backupFilename)
    if cleanNeedCountDown == 0 then
        cleanNeedCountDown = 10
        sm.MTBackupEngine.sv_deleteOldBackups()
    else
        cleanNeedCountDown = cleanNeedCountDown - 1
    end
end

function sm.MTBackupEngine.cl_setUsername()
    local playerUsername = sm.localPlayer.getPlayer():getName()
    sm.MTBackupEngine.username = playerUsername
end

function sm.MTBackupEngine.sv_deleteBackup(uuid)
    -- we cannot actually delete files, but we can mark them as unused
    local backupsCoordinator = loadPlayerCoordinator()
    local backupFilename = "$CONTENT_DATA/Backups/Backup_" .. uuid .. ".json"
    for i, backup in pairs(backupsCoordinator.backupsInUse) do
        if backup == backupFilename then
            table.remove(backupsCoordinator.backupsInUse, i)
            table.insert(backupsCoordinator.unusedBackupFilenames, backupFilename)
            savePlayerCoordinator(backupsCoordinator)
            return
        end
    end
    error("Backup not found")
end

function sm.MTBackupEngine.sv_deleteOldBackups()
    -- delete all unpinned backups older than 1 week
    local backupsCoordinator = loadPlayerCoordinator()
    local currentTime = os.time()
    local backupCreationIdUpdateHash = {}
    for i = #backupsCoordinator.backups, 1, -1 do
        local backup = backupsCoordinator.backups[i]
        if not backup.isPinned then
            if currentTime - backup.timeCreated > 604800 then
                table.remove(backupsCoordinator.backups, i)
                table.insert(backupsCoordinator.unusedBackupFilenames, backup.backupFilename)
                goto continue
            end
            if backup.creationId ~= nil then -- only keep backups of the same creation every 2 min
                if backupCreationIdUpdateHash[backup.creationId] ~= nil then
                    local timeDif = backupCreationIdUpdateHash[backup.creationId] - backup.timeCreated
                    if timeDif < 120 and timeDif >= 0 then -- > 0 just in case
                        table.remove(backupsCoordinator.backups, i)
                        table.insert(backupsCoordinator.unusedBackupFilenames, backup.backupFilename)
                        goto continue
                    end
                    backupCreationIdUpdateHash[backup.creationId] = backup.timeCreated
                else
                    backupCreationIdUpdateHash[backup.creationId] = backup.timeCreated
                end
            end
            -- local backupFilename = backupsCoordinator.backupsInUse[i]
            -- local backupData = sm.json.open(backupFilename)
            -- if not backupData.isPinned and currentTime - backupData.timeCreated > 604800 then
            --     table.remove(backupsCoordinator.backupsInUse, i)
            --     table.insert(backupsCoordinator.unusedBackups, backupFilename)
            -- end
        end
        ::continue::
    end
    savePlayerCoordinator(backupsCoordinator)
end

function sm.MTBackupEngine.cl_getBackups()
    if not sm.isHost then
        return {}
    end
    sm.MTBackupEngine.sv_deleteOldBackups()
    return loadPlayerCoordinator().backups
end

function sm.MTBackupEngine.sv_loadBackup(multitool, backupFilename)
    local backupData = sm.json.open(backupFilename)
    local creationData = nil
    if backupData.version == 1 then
        creationData = backupData.creationData
    elseif backupData.version == 2 then
        local compressedCreationData = backupData.creationData
        local stringifiedCreationData = sm.MTFastLogic.CompressionUtil.LibDeflate:DecompressDeflate(
            sm.MTFastLogic.CompressionUtil.LibDeflate:DecodeForPrint(compressedCreationData))
        creationData = sm.json.parseJsonString(stringifiedCreationData)
    end
    local character = multitool.tool:getOwner().character
    local creationBodies = sm.creation.importFromString(character:getWorld(), sm.json.writeJsonString(creationData),
        character:getWorldPosition() + character:getDirection() * 8, sm.quat.new(0, 0, 0, 1))
    for _, body in pairs(creationBodies) do
        body:setDestructable(true)
    end
end