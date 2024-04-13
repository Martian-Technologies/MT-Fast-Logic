dofile "BaseFastLogicBlock.lua"
dofile "../util/util.lua"

FastLight = table.deepCopyTo(BaseFastLogicBlock, (FastLight or class()))
FastLight.maxParentCount = 1
FastLight.maxChildCount = 0
FastLight.connectionInput = sm.interactable.connectionType.logic
FastLight.connectionOutput = nil
FastLight.poseWeightCount = 1

function FastLight.getData2(self)
    self.creation.FastLights[self.id] = self
end

function FastLight.server_onCreate2(self)
    self.type = "Light"
    self.data = self.data or {}
    if self.storage:load() ~= nil then
        self.data.luminance = self.storage:load().luminance or 50
    else
        self.data.luminance = 50
    end
    self:server_saveLuminance(self.data.luminance)
    self.network:setClientData({ luminance = self.data.luminance })
end

function FastLight.server_onDestroy2(self)
    self.creation.FastLights[self.id] = nil
end

function FastLight.client_onCreate2(self)
end

function FastLight.client_onDestroy2(self)
    -- if self.gui then
    --     self.gui:destroy()
    -- end
end

-- function FastLight.gui_init(self)
--     if self.gui == nil then
--         self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Interactable_FastLight.layout")
--         self.guimodes = {
--             { name = "And",  description = "Active if all of the linked triggers are active" },
--             { name = "Or",   description = "Active if any of the linked triggers are active" },
--             { name = "Xor",  description = "Active if an odd number of linked triggers are active" },
--             { name = "Nand", description = "Active if any of the linked triggers are inactive" },
--             { name = "Nor",  description = "Active if all of the linked triggers are inactive" },
--             { name = "Xnor", description = "Active if an even number of linked triggers are active" }
--         }
--         local btnNames = { "And", "Or", "Xor", "Nand", "Nor", "Xnor" }
--         for _, btnName in pairs(btnNames) do
--             self.gui:setButtonCallback(btnName, "gui_buttonCallback")
--         end
--     end
-- end

-- function FastLight.gui_buttonCallback(self, btnName)
--     for i = 1, #self.guimodes do
--         local name = self.guimodes[i].name
--         self.gui:setButtonState(name, name == btnName)
--         if name == btnName then
--             self.client_mode = i - 1
--             self.gui:setText("DescriptionText", self.guimodes[i].description)
--         end
--     end
--     self.network:sendToServer("server_saveMode", self.client_mode)
-- end

-- function FastLight.client_onInteract(self, character, state)
--     if state then
--         self:gui_init()
--         local btnNames = { "And", "Or", "Xor", "Nand", "Nor", "Xnor" }
--         self:gui_buttonCallback(btnNames[self.client_mode + 1])
--         self.gui:open()
--     end
-- end

function FastLight.client_onClientDataUpdate(self, data)
    self.client_luminance = data.luminance
    self:client_updateTexture()
end

function FastLight.client_updateTexture(self)
    if self.interactable.active then
        self.interactable:setPoseWeight(0, 1)
    else
        self.interactable:setPoseWeight(0, 0)
    end
end

function FastLight.server_saveLuminance(self, luminance)
    self.data.luminance = luminance
    self.network:setClientData({ luminance = self.data.luminance })
    self.storage:save({ luminance = self.data.luminance })
end
