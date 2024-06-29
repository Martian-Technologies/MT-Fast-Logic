LogicConverter = {}

function LogicConverter.inject(multitool)
    multitool.LogicConverter = {}
    local self = multitool.LogicConverter
    self.confirming = nil
    self.confirmingType = nil
end

function LogicConverter.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    local self = multitool.LogicConverter
    multitool.BlockSelector.enabled = false
    -- shoot raycast to get the hit position
    if self.confirming == nil then
        local origin = sm.camera.getPosition()
        local direction = sm.camera.getDirection()
        local hit, res = sm.physics.raycast(sm.camera.getPosition(),
        sm.camera.getPosition() + sm.camera.getDirection() * 128, sm.localPlayer.getPlayer().character)
        -- print(res.type)
        local body = nil
        if hit and res.type == "body" then
            body = res:getBody()
            -- print(body)
        end
        if hit and res.type == "joint" then
            body = res:getJoint().shapeA.body
        end
        if hit and res.type == "character" then
            sm.gui.setInteractionText("No.. you can't just convert your friend to fast logic and expect him to get smarter.", "", "")
        end
        if body == nil then
            sm.gui.setInteractionText("Aim at a creation", "", "")
            return
        end
        if body:isOnLift() then
            sm.gui.setInteractionText("Take the creation off the lift", "", "")
            return
        elseif primaryState == 1 then
            self.confirming = body
            self.confirmingType = "FastLogic"
            -- multitool.network:sendToServer("server_convertBody", {
            --     body = body,
            --     wantedType = "FastLogic"
            -- })
        elseif secondaryState == 1 then
            self.confirming = body
            self.confirmingType = "VanillaLogic"
            -- multitool.network:sendToServer("server_convertBody", {
            --     body = body,
            --     wantedType = "VanillaLogic"
            -- })
        end
        
        sm.visualization.setCreationBodies(body:getCreationBodies())
        sm.visualization.setCreationFreePlacement( false )
        sm.visualization.setCreationValid( true, true )
        sm.visualization.setLiftValid( true )
        sm.visualization.setCreationVisible(true)
        
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Convert to FastLogic     ", sm.gui.getKeyBinding("Attack", true), "Convert to Vanilla Logic")
        -- sm.gui.setInteractionText("")
    else
        -- check if the body is still valid
        if not sm.exists(self.confirming) then
            self.confirming = nil
            self.confirmingType = nil
            return
        end
        if self.confirming:isOnLift() then
            sm.gui.setInteractionText("Take the creation off the lift", "", "")
            self.confirming = nil
            self.confirmingType = nil
            return
        end
        if not sm.exists(self.confirming) then
            sm.gui.setInteractionText("Body is invalid", "", "")
            self.confirming = nil
            self.confirmingType = nil
            return
        end
        sm.visualization.setCreationBodies(self.confirming:getCreationBodies())
        sm.visualization.setCreationFreePlacement( false )
        sm.visualization.setCreationValid( true, true )
        sm.visualization.setLiftValid( true )
        sm.visualization.setCreationVisible(true)
        if self.confirmingType == "FastLogic" then
            sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Confirm convert to Fast Logic     ",
                sm.gui.getKeyBinding("Attack", true), "Cancel")
            if primaryState == 1 then
                -- BackupEngine.backupCreation(multitool, self.confirming, "ConvertLogicToFast",
                --     CallbackEngine.client_registerCallback(multitool, function(multitool)
                --     local self = multitool.LogicConverter
                --     multitool.network:sendToServer("server_convertBody", {
                --         body = self.confirming,
                --         wantedType = "FastLogic",
                --     })
                --     self.confirming = nil
                --     self.confirmingType = nil
                -- end, multitool))
                multitool.network:sendToServer("server_convertBody", {
                    body = self.confirming,
                    wantedType = "FastLogic",
                })
                self.confirming = nil
                self.confirmingType = nil
            end
            if secondaryState == 1 then
                self.confirming = nil
                self.confirmingType = nil
            end
        elseif self.confirmingType == "VanillaLogic" then
            sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Cancel     ", sm.gui.getKeyBinding("Attack", true), "Confirm convert to Vanilla Logic")
            if secondaryState == 1 then
                -- BackupEngine.backupCreation(multitool, self.confirming, "ConvertLogicToVanilla",
                --     CallbackEngine.client_registerCallback(multitool, function(multitool)
                --     local self = multitool.LogicConverter
                --     multitool.network:sendToServer("server_convertBody", {
                --         body = self.confirming,
                --         wantedType = "VanillaLogic"
                --     })
                --     self.confirming = nil
                --     self.confirmingType = nil
                -- end, multitool))
                multitool.network:sendToServer("server_convertBody", {
                    body = self.confirming,
                    wantedType = "VanillaLogic"
                })
                self.confirming = nil
                self.confirmingType = nil
            end
            if primaryState == 1 then
                self.confirming = nil
                self.confirmingType = nil
            end
        end
    end
end