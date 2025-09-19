NeoTool = class()

local toolModelRends = { "$CONTENT_DATA/Objects/Textures/Char_liftremote/char_liftremote.rend" }
local toolAnimsThirdPerson = { "$CONTENT_DATA/Objects/Textures/Char_liftremote/char_liftremote_tp_animlist.rend" }
local toolAnimsFirstPerson = { "$CONTENT_DATA/Objects/Textures/Char_liftremote/char_liftremote_fp_animlist.rend" }

sm.tool.preloadRenderables( toolModelRends )
sm.tool.preloadRenderables( toolAnimsThirdPerson )
sm.tool.preloadRenderables( toolAnimsFirstPerson )

function NeoTool:server_onCreate()

end

function NeoTool:client_onCreate()

end

function NeoTool:client_onRefresh()
    self:client_onCreate()
end

function NeoTool:client_onUpdate(dt)
    if self.tool:isLocal() then
        if self.equipped then
            if isSprinting and self.firstPersonAnimations.currentAnimation ~= "sprintInto" and self.firstPersonAnimations.currentAnimation ~= "sprintIdle" then
                swapFpAnimation(self.firstPersonAnimations, "sprintExit", "sprintInto", 0.0)
            elseif not self.tool:isSprinting() and (self.firstPersonAnimations.currentAnimation == "sprintIdle" or self.firstPersonAnimations.currentAnimation == "sprintInto") then
                swapFpAnimation(self.firstPersonAnimations, "sprintInto", "sprintExit", 0.0)
            end
        end
        updateFpAnimations(self.firstPersonAnimations, self.equipped, dt)
    end
    if not self.equipped then
        if self.wantEquipped then
            self.wantEquipped = false
            self.equipped = true
        end
        return true
    end

    local totalWeight = 0.0
    for name, animation in pairs(self.thirdPersonAnimations.animations) do
        animation.time = animation.time + dt

        if name == self.thirdPersonAnimations.currentAnimation then
            animation.weight = math.min(animation.weight + (self.thirdPersonAnimations.blendSpeed * dt), 1.0)

            if animation.time >= animation.info.duration - self.blendTime then
                if name == "pickup" then
                    setTpAnimation(self.thirdPersonAnimations, "idle", 0.001)
                elseif animation.nextAnimation ~= "" then
                    setTpAnimation(self.thirdPersonAnimations, animation.nextAnimation, 0.001)
                end
            end
        else
            animation.weight = math.max(animation.weight - (self.thirdPersonAnimations.blendSpeed * dt), 0.0)
        end

        totalWeight = totalWeight + animation.weight
    end
end

function NeoTool:client_onReload()
end

function NeoTool:loadAnimations()
    self.thirdPersonAnimations = createTpAnimations(
        self.tool,
        {
            idle = { "weldtool_idle" },
            pickup = { "weldtool_pickup", { nextAnimation = "idle" } },
            putdown = { "weldtool_putdown" },
            useInto = { "weldtool_use_into" },
            useIdle = { "weldtool_use_idle" },
            useExit = { "weldtool_use_exit" },
            useError = { "weldtool_use_error" }
        }
    )
    local movementAnimations = {
        idle = "weldtool_idle",
        idleRelaxed = "weldtool_relaxed",

        sprint = "weldtool_sprint",
        runFwd = "weldtool_run_fwd",
        runBwd = "weldtool_run_bwd",

        jump = "weldtool_jump",
        jumpUp = "weldtool_jump_up",
        jumpDown = "weldtool_jump_down",

        land = "weldtool_jump_land",
        landFwd = "weldtool_jump_land_fwd",
        landBwd = "weldtool_jump_land_bwd",

        crouchIdle = "weldtool_crouch_idle",
        crouchFwd = "weldtool_crouch_fwd",
        crouchBwd = "weldtool_crouch_bwd"
    }

    for name, animation in pairs(movementAnimations) do
        self.tool:setMovementAnimation(name, animation)
    end

    setTpAnimation(self.thirdPersonAnimations, "idle", 5.0)

    if self.tool:isLocal() then
        self.firstPersonAnimations = createFpAnimations(
            self.tool,
            {
                equip = { "weldtool_pickup", { nextAnimation = "idle" } },
                unequip = { "weldtool_putdown" },

                idle = { "weldtool_idle", { looping = true } },

                sprintInto = { "weldtool_sprint_into", { nextAnimation = "sprintIdle", blendNext = 0.2 } },
                sprintExit = { "weldtool_sprint_exit", { nextAnimation = "idle", blendNext = 0 } },
                sprintIdle = { "weldtool_sprint_idle", { looping = true } }
            }
        )
    end
    self.blendTime = 0.2
end

function NeoTool:client_onEquip(animate)
    self.confirmed = 0

    if animate then
        sm.audio.play("PaintTool - Equip", self.tool:getPosition())
    end
    -- ConnectionRaycaster:cleanCache()
    self.wantEquipped = true

    local currentThirdPersonRends = {}
    table.appendTable(currentThirdPersonRends, toolAnimsThirdPerson)
    table.appendTable(currentThirdPersonRends, toolModelRends)
    local currentFirstPersonRends = {}
    table.appendTable(currentFirstPersonRends, toolAnimsFirstPerson)
    table.appendTable(currentFirstPersonRends, toolModelRends)

    self.tool:setTpRenderables( currentThirdPersonRends )

    self:loadAnimations()

    if not self.tool:isLocal() then
        return
	end
    -- Sets PotatoRifle renderable, change this to change the mesh
    self.tool:setFpRenderables( currentFirstPersonRends )
    swapFpAnimation( self.firstPersonAnimations, "unequip", "equip", 0.2 )
end

function NeoTool:client_onUnequip(animate)
    self.wantEquipped = false
    self.equipped = false
    if not sm.exists(self.tool) then
        return
    end
    if animate then
        sm.audio.play("PaintTool - Unequip", self.tool:getPosition())
    end
    setTpAnimation(self.thirdPersonAnimations, "putdown")
    if not self.tool:isLocal() then
        return
    end
    if self.firstPersonAnimations.currentAnimation ~= "unequip" then
        swapFpAnimation(self.firstPersonAnimations, "equip", "unequip", 0.2)
    end
end

function NeoTool:client_onEquippedUpdate(primaryState, secondaryState, forceBuild)
	return false, true
end