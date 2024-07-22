BackupMenu = {}

function BackupMenu.inject(multitool)
    multitool.BackupMenu = {}
    local self = multitool.BackupMenu
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
                return "No backups found :("
                -- {
                --     text = "No backups found :(",
                --     color = sm.color.new(1, 0, 0)
                -- }
            end
        })
    else
        for i = 1, math.min(30, #backups) do
            local backupFilename = backups[#backups - i + 1]
            local backup = sm.MTBackupEngine.cl_getBackupData(backupFilename)
            local timeNow = os.time()
            local timeDiff = timeNow - backup.timeCreated
            local backupString = backup.name .. " - " .. backup.description .. " - created " .. timeDiff .. " seconds ago"
            table.insert(hUI.elements, {
                name = "backup_" .. i,
                type = "button",
                text = backupString,
                position = { a = 0, e = (1 + math.min(30, #backups) - i) * 0.07 /2 * fovMult },
                angleBoundHorizontal = 0.1 * fovMult,
                angleBoundVertical = 0.035 / 2 * fovMult,
                color = sm.color.new(1, 1, 1),
                onclick = function()
                    multitool.network:sendToServer("sv_loadBackup", backupFilename)
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