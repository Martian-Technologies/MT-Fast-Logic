BackupMenu = {}

function BackupMenu.inject(multitool)
    multitool.BackupMenu = {}
    local self = multitool.BackupMenu
end

local function localizeVars(vars)
    if vars == nil then
        return nil
    end

    local localized = {}
    for key, value in pairs(vars) do
        if MTLocalization ~= nil then
            localized[key] = MTLocalization.resolve(value)
        else
            localized[key] = value
        end
    end
    return localized
end

local function localizeBackupText(id, vars, fallback)
    if id ~= nil then
        return tr(id, localizeVars(vars))
    end
    if fallback ~= nil then
        return fallback
    end
    return ""
end

local function getRussianPluralSuffix(value)
    local lastTwo = value % 100
    if lastTwo >= 11 and lastTwo <= 14 then
        return "many"
    end

    local last = value % 10
    if last == 1 then
        return "one"
    elseif last >= 2 and last <= 4 then
        return "few"
    end
    return "many"
end

local function formatAge(seconds)
    if MTLocalization ~= nil and MTLocalization.isLanguage("Russian") then
        return tr("mt.backup.age.seconds_" .. getRussianPluralSuffix(seconds), { count = seconds })
    end
    if seconds == 1 then
        return tr("mt.backup.age.seconds_one", { count = seconds })
    end
    return tr("mt.backup.age.seconds_many", { count = seconds })
end

local function injectElements(multitool)
    local fovMult = sm.camera.getFov() / 90
    local self = multitool.BackupMenu
    local hUI = multitool.HoveringUI
    hUI.elements = {}
    local backups = sm.MTBackupEngine.cl_getBackups()
    if #backups == 0 then
        table.insert(hUI.elements, {
            name = "noBackups",
            type = "indicator",
            position = { a = 0, e = 0.07 * fovMult },
            color = sm.color.new(1, 0, 0),
            getText = function()
                return "mt.backup.none"
            end
        })
    else
        for i = 1, math.min(30, #backups) do
            local backup = backups[#backups - i + 1]
            local timeNow = os.time()
            local timeDiff = timeNow - backup.timeCreated
            local backupString = tr("mt.backup.entry", {
                name = localizeBackupText(backup.nameId, backup.nameVars, backup.name),
                description = localizeBackupText(backup.descriptionId, backup.descriptionVars, backup.description),
                age = formatAge(timeDiff)
            })
            table.insert(hUI.elements, {
                name = "backup_" .. i,
                type = "button",
                text = backupString,
                position = { a = 0, e = (1 + math.min(30, #backups) - i) * 0.07 /2 * fovMult },
                angleBoundHorizontal = 0.1 * fovMult,
                angleBoundVertical = 0.035 / 2 * fovMult,
                color = sm.color.new(1, 1, 1),
                onclick = function()
                    multitool.network:sendToServer("sv_loadBackup", backup.backupFilename)
                end
            })
        end
    end
end

function BackupMenu.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.BackupMenu
    multitool.BlockSelector.enabled = false
    multitool.VolumeSelector.enabled = false
    if multitool.HoveringUI.elements == nil then
        injectElements(multitool)
    end
    HoveringUI.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
end
