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

local legacyBackupNameIds = {
    ["Unnamed"] = "mt.backup.name.unnamed",
    ["Conversion Backup"] = "mt.backup.name.conversion",
    ["Silicon Conversion Backup"] = "mt.backup.name.silicon_conversion",
    ["Mode Changer Backup"] = "mt.backup.name.mode_changer",
    ["Block Merge Backup"] = "mt.backup.name.block_merge",
    ["Volume Deleter Backup"] = "mt.backup.name.volume_deleter",
    ["Volume Placer Backup"] = "mt.backup.name.volume_placer",
    ["Colorizer Backup"] = "mt.backup.name.colorizer",
    ["CopyPaste Backup"] = "mt.backup.name.copy_paste",
    ["Decoder Backup"] = "mt.backup.name.decoder"
}

local legacyBackupDescriptionIds = {
    ["No description"] = "mt.backup.description.none",
    ["Backup made by mode changer"] = "mt.backup.description.mode_changer",
    ["Backup made by block merge"] = "mt.backup.description.block_merge",
    ["Backup made by volume deleter"] = "mt.backup.description.volume_deleter",
    ["Backup made by volume placer"] = "mt.backup.description.volume_placer",
    ["Backup created by CopyPaste.lua"] = "mt.backup.description.copy_paste",
    ["Backup created by decoder maker"] = "mt.backup.description.decoder",
    ["Backup created by TensorConnect.trigger() in TensorConnect.lua."] = "mt.backup.description.tensor",
    ["Backup created by sv_connectTensors() in TensorConnect.lua."] = "mt.backup.description.tensor_previewless"
}

local function backupConversionTypeId(value)
    if value == "FastLogic" or value == "toFastLogic" then
        return "mt.backup.type.fast_logic"
    elseif value == "VanillaLogic" then
        return "mt.backup.type.vanilla_logic"
    elseif value == "toSilicon" then
        return "mt.backup.type.silicon"
    end
    return value
end

local function backupColorizerValueId(value)
    if value == "match" then
        return "mt.backup.color.match"
    elseif value == "invert" then
        return "mt.backup.color.invert"
    elseif value == "Connection" then
        return "mt.colorizer.connection"
    elseif value == "Block" then
        return "mt.colorizer.block"
    end
    return value
end

local function convertLegacyBackupName(name)
    if name == nil then
        return "mt.backup.name.unnamed", nil
    end

    local previewlessDims = string.match(name, "^Prieviewless (%d+)%-dim Tensor Connection Backup$") or
        string.match(name, "^Previewless (%d+)%-dim Tensor Connection Backup$")
    if previewlessDims ~= nil then
        return "mt.backup.name.tensor_previewless", { dimensions = previewlessDims }
    end

    local dims = string.match(name, "^(%d+)%-dim Tensor Connection Backup$")
    if dims ~= nil then
        return "mt.backup.name.tensor", { dimensions = dims }
    end

    return legacyBackupNameIds[name], nil
end

local function convertLegacyBackupDescription(description)
    if description == nil then
        return "mt.backup.description.none", nil
    end

    local logicType = string.match(description, "^Backup created by LogicConverter%.lua%. Converting to (.+)$")
    if logicType ~= nil then
        return "mt.backup.description.logic_conversion", { type = backupConversionTypeId(logicType) }
    end

    local siliconType = string.match(description, "^Backup created by convertSilicon%(%) in FastLogicRunnerRunner%.lua%. Converting to (.+)$")
    if siliconType ~= nil then
        return "mt.backup.description.silicon_conversion", { type = backupConversionTypeId(siliconType) }
    end

    local color, mode = string.match(description, "^Backup made by Colorizer %- (.+) %- (.+)$")
    if color ~= nil then
        return "mt.backup.description.colorizer", {
            color = backupColorizerValueId(color),
            mode = backupColorizerValueId(mode)
        }
    end

    return legacyBackupDescriptionIds[description], nil
end

local function normalizeBackupMetadata(backup)
    local changed = false

    if backup.nameId == nil then
        local id, vars = convertLegacyBackupName(backup.name)
        if id == nil then
            id = "mt.backup.name.custom"
            vars = { text = backup.name or "Unnamed" }
        end
        backup.nameId = id
        backup.nameVars = vars
        changed = true
    end
    if backup.name ~= nil then
        backup.name = nil
        changed = true
    end

    if backup.descriptionId == nil then
        local id, vars = convertLegacyBackupDescription(backup.description)
        if id == nil then
            id = "mt.backup.description.custom"
            vars = { text = backup.description or "No description" }
        end
        backup.descriptionId = id
        backup.descriptionVars = vars
        changed = true
    end
    if backup.description ~= nil then
        backup.description = nil
        changed = true
    end

    return changed
end

local function getBackupMetadata(data)
    local backup = {
        nameId = data.nameId,
        nameVars = data.nameVars,
        descriptionId = data.descriptionId,
        descriptionVars = data.descriptionVars,
        name = data.name,
        description = data.description
    }
    normalizeBackupMetadata(backup)
    return backup.nameId, backup.nameVars, backup.descriptionId, backup.descriptionVars
end

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
            version = 3,
            backups = {},
            unusedBackupFilenames = {}
        }
        for _, backupFilename in pairs(playerData.backupsInUse) do
            local backupData = sm.json.open(backupFilename)
            if not backupData.isPinned and os.time() - backupData.timeCreated > 604800 then
                table.insert(newPlayerData.unusedBackupFilenames, backupFilename)
            else
                local backup = {
                    name = backupData.name,
                    description = backupData.description,
                    creationType = backupData.creationType,
                    timeCreated = backupData.timeCreated,
                    isPinned = backupData.isPinned,
                    backupFilename = backupFilename
                }
                normalizeBackupMetadata(backup)
                table.insert(newPlayerData.backups, backup)
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
    local doSave = false
    if playerData.version ~= 3 then
        playerData.version = 3
        doSave = true
    end
    for _, backup in pairs(playerData.backups) do
        if normalizeBackupMetadata(backup) then
            doSave = true
        end
    end
    return playerData, doSave
end

local function loadPlayerCoordinator()
    local allData = loadCoordinator()
    if allData.players[getPlayerName()] == nil then
        allData.players[getPlayerName()] = {
            version = 3,
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

function sm.MTBackupEngine.cl_backupCreation(multitool, data, callback, callbackData)
    local player = sm.localPlayer.getPlayer()
    multitool.network:sendToServer("sv_backupCreationRequest", {
        player = player,
        data = data,
        callback = callback,
        callbackData = callbackData
    })
end

function sm.MTBackupEngine.sv_backupCreationRequest(multitool, data)
    local player = data.player
    sm.MTBackupEngine.sv_backupCreation(data.data)
    local callback = data.callback
    local callbackData = data.callbackData
    multitool.network:sendToClient(player, callback, callbackData)
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
    local nameId, nameVars, descriptionId, descriptionVars = getBackupMetadata(data)
    table.insert(backupsCoordinator.backups, {
        nameId = nameId,
        nameVars = nameVars,
        descriptionId = descriptionId,
        descriptionVars = descriptionVars,
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