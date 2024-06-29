NametagManager = {}

function NametagManager.createController(multitool)
    local self = {}
    self.multitool = multitool
    self.nametags = {}
    self.nametagPositions = {}
    local function updateNametags(newNametags)
        if newNametags == nil then
            -- clear all nametags
            for i, nametag in pairs(self.nametags) do
                nametag:destroy()
            end
            self.nametags = {}
            return
        end
        local camPos = sm.camera.getPosition()
        while (#self.nametags > #newNametags) do
            local nametag = table.remove(self.nametags)
            nametag:destroy()
        end
        while (#self.nametags < #newNametags) do
            local nametag = sm.gui.createNameTagGui()
            nametag:open()
            table.insert(self.nametags, nametag)
        end
        for i, nametag in pairs(self.nametags) do
            local distance = (camPos - newNametags[i].pos):length()
            local newNametag = newNametags[i]
            nametag:setWorldPosition(newNametag.pos - RangeOffset.rangeOffset * distance)
            nametag:setText("Text", "#" .. NametagManager.toHexNoAlpha(newNametag.color) .. newNametag.txt)
        end
        self.nametagPositions = {}
        for i, nametag in pairs(newNametags) do
            self.nametagPositions[i] = nametag.pos
        end
    end

    local function refreshPositions()
        for i, nametag in pairs(self.nametags) do
            local distance = (sm.camera.getPosition() - self.nametagPositions[i]):length()
            nametag:setWorldPosition(self.nametagPositions[i] - RangeOffset.rangeOffset * distance)
        end
    end
    table.insert(multitool.subscriptions.client_onUpdate, refreshPositions)
    return updateNametags
end

function NametagManager.toHexNoAlpha(color)
    -- drop the last 2 chars of :getHexStr()
    return color:getHexStr():sub(1, -3)
end
