dofile "../util/util.lua"

function FastLogicRunner.updateDisplays(self)
--     local addData = {}
--     local destroyIds = {}
--     for id, block in pairs(self.data) do
--         if (block.type == "vanilla light" or block.color == "420420") then
--             local state = self.blockStates[self.hashedLookUp[id]]
--             if (sm.exists(block.shape) and #addData < 1000) then
--                 local wantedDisplayPos = block.shape:getWorldPosition() + sm.vec3.new(0, 0, -0.4 / 4)
--                 if (#destroyIds < 1000 and self.openDisplays[id] ~= nil and sm.vec3.length(self.openDisplays[id] - wantedDisplayPos) > 0.01) then
--                     destroyIds[#destroyIds + 1] = id
--                     addData[#addData + 1] = self.createDataForDisplay(wantedDisplayPos, id, block)
--                     self.openDisplays[id] = wantedDisplayPos
                
--                 elseif (state and self.openDisplays[id] == nil) then
--                     addData[#addData + 1] = self.createDataForDisplay(wantedDisplayPos, id, block)
--                     self.openDisplays[id] = wantedDisplayPos
--                 end
                
--             end
--             if (self.openDisplays[id] ~= nil and (not state) and #destroyIds < 1000) then
--                 destroyIds[#destroyIds + 1] = id
--                 self.openDisplays[id] = nil
--             end
--         elseif (self.openDisplays[id] ~= nil and #destroyIds < 1000) then
--             destroyIds[#destroyIds + 1] = id
--             self.openDisplays[id] = nil
--         end
--     end
--     self:displayStates(destroyIds, addData)
end

-- function FastLogicRunner.createDataForDisplay(pos, id, block)
--     local color = "00CCFF"
--     if block.type == "vanilla light" then
--         color = block.color
--     end
--     return {
--         pos = pos,
--         id = id,
--         color = color
--     }
-- end

-- function FastLogicRunner.displayStates(self, destroyIds, addData)
--     self.network:sendToClients("clients_clearDisplays", destroyIds)
--     self.network:sendToClients("clients_displayStates", addData)
-- end

-- function FastLogicRunner.clients_clearDisplays(self, ids)
--     for _, id in pairs(ids) do
--         local gui = self.displayGUIs[id]
--         if (gui ~= nil) then
--             self:clients_clearDisplay(gui)
--         end
--     end
--     for gui in values(self.displayGUIs) do
--         if (not gui.gui:isActive()) then
--             self:clients_clearDisplay(gui)
--         end
--     end
-- end

-- function FastLogicRunner.clients_clearDisplay(self, gui)
--     gui.gui:destroy()
--     self.displayGUIs[gui.id] = nil
-- end

-- function FastLogicRunner.clients_displayStates(self, addData)
--     for data in values(addData) do
--         self:clients_displayState(data)
--     end
-- end

-- function FastLogicRunner.clients_displayState(self, data)
--     local gui = sm.gui.createNameTagGui()
--     gui:setText("Text", "#" .. data.color .. "[I]")
--     gui:setWorldPosition(data.pos)
--     gui:open()
--     self.displayGUIs[data.id] = { gui = gui, id = data.id }
-- end
