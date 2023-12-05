dofile "../util/util.lua"

function FastLogicRunner.updateDisplays(self)
    local addIdsAndPositions = {}
    local destroyIds = {}
    for id, block in pairs(self.data) do
        if (block.type == "vanilla light" or block.color == "420420") then
            local state = self.blockStates[id]
            if (sm.exists(block.shape) and #addIdsAndPositions < 1000) then
                local wantedDisplayPos = block.shape:getWorldPosition() + sm.vec3.new(0, 0, -0.4 / 4)
                if (state and self.openDisplays[id] == nil) then
                    addIdsAndPositions[#addIdsAndPositions + 1] = {
                        pos = wantedDisplayPos,
                        id = id
                    }
                    self.openDisplays[id] = wantedDisplayPos
                end
                if (#destroyIds < 1000 and self.openDisplays[id] ~= nil and sm.vec3.length(self.openDisplays[id] - wantedDisplayPos) > 0.01) then
                    destroyIds[#destroyIds + 1] = id
                    addIdsAndPositions[#addIdsAndPositions + 1] = {
                        pos = wantedDisplayPos,
                        id = id
                    }
                    self.openDisplays[id] = wantedDisplayPos
                end
            end
            if (self.openDisplays[id] ~= nil and (not state) and #destroyIds < 1000) then
                destroyIds[#destroyIds + 1] = id
                self.openDisplays[id] = nil
            end
        elseif (self.openDisplays[id] ~= nil and #destroyIds < 1000) then
            destroyIds[#destroyIds + 1] = id
            self.openDisplays[id] = nil
        end
    end
    self:displayStates(destroyIds, addIdsAndPositions)
end

function FastLogicRunner.displayStates(self, destroyIds, positions)
    self.network:sendToClients("clients_clearDisplays", destroyIds)
    self.network:sendToClients("clients_displayStates", positions)
end

function FastLogicRunner.clients_clearDisplays(self, ids)
    for _, id in pairs(ids) do
        local gui = self.displayGUIs[id]
        if (gui ~= nil) then
            self:clients_clearDisplay(gui)
        end
    end
    for gui in values(self.displayGUIs) do
        if (not gui.gui:isActive()) then
            self:clients_clearDisplay(gui)
        end
    end
end

function FastLogicRunner.clients_clearDisplay(self, gui)
    gui.gui:destroy()
    self.displayGUIs[gui.id] = nil
end

function FastLogicRunner.clients_displayStates(self, positions)
    for pos in values(positions) do
        self:clients_displayState(pos)
    end
end

function FastLogicRunner.clients_displayState(self, pos)
    local gui = sm.gui.createNameTagGui()
    gui:setText("Text", "[I]")
    gui:setWorldPosition(pos.pos)
    gui:open()
    self.displayGUIs[pos.id] = { gui = gui, id = pos.id }
end
