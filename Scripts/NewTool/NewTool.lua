NewTool = class()

print("loading NewTool.lua")

dofile("$GAME_DATA/Scripts/game/AnimationUtil.lua")

dofile("../util/util.lua")
dofile("$CONTENT_DATA/Scripts/Flight/FlightController.lua")

dofile("$CONTENT_DATA/Scripts/NewTool/ImRend.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/LineRend.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/CreationSpatialIndex.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/TargetingService.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/SelectionRenderer.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/BlockSelection.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/RowSelectionView.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/RowSelection.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/ParallelConnect.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/HologramText.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/MenuRenderer.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/PromptPresenter.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/ActionRegistry.lua")
local newToolActionRegistry = NewToolActionRegistry
dofile("$CONTENT_DATA/Scripts/NewTool/MenuManifest.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/MenuLayout.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/HubMenuView.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/RadialMenuView.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/ToolModeManager.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/MenuManager.lua")
dofile("$CONTENT_DATA/Scripts/NewTool/ActionManager.lua")

dofile("$CONTENT_DATA/Scripts/NewTool/RadialMenu.lua")

local toolModelRends = { "$CONTENT_DATA/Objects/Textures/Char_liftremote/char_liftremote.rend" }
local toolAnimsThirdPerson = { "$CONTENT_DATA/Objects/Textures/Char_liftremote/char_liftremote_tp_animlist.rend" }
local toolAnimsFirstPerson = { "$CONTENT_DATA/Objects/Textures/Char_liftremote/char_liftremote_fp_animlist.rend" }

sm.tool.preloadRenderables( toolModelRends )
sm.tool.preloadRenderables( toolAnimsThirdPerson )
sm.tool.preloadRenderables( toolAnimsFirstPerson )

function NewTool:server_onCreate()
    MTFlight.sv_inject(self)
end

function NewTool:client_onCreate()
    self.lastTime = os.clock()

    MTFlight.inject(self)
    ImRend.init(self)
    LineRend.init(self)
    CreationSpatialIndex.init(self)
    TargetingService.init(self, self.CreationSpatialIndex)
    SelectionRenderer.init(self)
    PromptPresenter.init(self)
    self.SelectionContext = {
        targeting = self.TargetingService,
        spatialIndex = self.CreationSpatialIndex,
        renderer = self.SelectionRenderer,
        lineRenderer = self.LineRend,
        prompts = self.PromptPresenter
    }
    HologramText.init(self)
    self.SelectionContext.textRenderer = self.HologramText
    MenuRenderer.init(self)
    MenuLayout.configure({ actionRegistry = newToolActionRegistry })
    MenuLayout.validateAll(NewToolMenuManifest, self.HologramText)
    HubMenuView.init(self, MenuLayout)
    RadialMenuView.init(self)
    ToolModeManager.init(self)
    MenuManager.init(self, NewToolMenuManifest, MenuLayout, self.HubMenuView)
    ActionManager.init(self, newToolActionRegistry)
    RadialMenu.init(self, NewToolMenuManifest.radial, MenuLayout, self.RadialMenuView)

    self.tool:setCrossHairAlpha(0.3)
    self.tool:setDispersionFraction(0)
    return true
end

function NewTool:client_onUpdate(dt)
    if self.tool:isLocal() then
        self.LineRend.client_onUpdate(dt)
        if not self.tool:isEquipped() then
            self.LineRend.beginFrame()
            self.ToolModeManager.render(self.SelectionContext)
        end
    end

    MTFlight.cl_onUpdate(self, dt)
    self:cl_handleAnimationsOnUpdate(dt)
    return true
end

function NewTool:server_onFixedUpdate(dt)
    MTFlight.server_onFixedUpdate(self, dt)
end

function NewTool:client_onReload()
    return true
end

function NewTool:client_onDestroy()
    if self.tool:isLocal() then
        self.MenuManager.close()
        self.RadialMenu.unequip()
        self.MenuRenderer.clearAll()
        self.ToolModeManager.clear("destroyed")
        self.PromptPresenter.clear()
        self.LineRend.suspend()
    end
end

function NewTool:client_onEquip(animate)
    if self.tool:isLocal() then
        self.lastTime = os.clock()
        self.LineRend.resume()
        self.ToolModeManager.wake()
    end
    self:cl_handleAnimationsOnEquip(animate)
end

function NewTool:client_onUnequip(animate)
    if self.tool:isLocal() then
        self.MenuManager.close()
        self.RadialMenu.unequip()
        self.ToolModeManager.sleep()
        self.PromptPresenter.clear()
    end

    self:cl_handleAnimationsOnUnequip(animate)
end

function NewTool:client_onToggle()
    -- MTFlight.toggleFlying(self) maybe bring back later, but i have other ideas for rotating actually
    return true
end

function NewTool:executeAction(action)
    self.ActionManager.executeAction(action)
end

function NewTool:cl_notifyFlying(data)
    MTFlight.cl_notifyFlying(self, data)
end

function NewTool:sv_toggleFlying(data, player)
    MTFlight.sv_toggleFlying(self, data, player)
end

function NewTool:client_onEquippedUpdate(primaryState, secondaryState, forceBuild)
    local currentTime = os.clock()
    local dt = currentTime - self.lastTime
    self.lastTime = currentTime
    -- print(primaryState, secondaryState, forceBuild)
    if self.tool:isLocal() then
        self.LineRend.beginFrame()
        self.SelectionRenderer.beginFrame()
        self.PromptPresenter.beginFrame()
        if self.MenuManager.run(dt, primaryState, secondaryState, forceBuild) then goto done end
        if self.RadialMenu.run(dt, primaryState, secondaryState, forceBuild) then goto done end

        local input = {
            dt = dt,
            primaryState = primaryState,
            secondaryState = secondaryState,
            forceBuild = forceBuild
        }
        if self.ToolModeManager.run(self.SelectionContext, input) then goto done end
    end
    ::done::
    if self.tool:isLocal() then self.PromptPresenter.flush() end
    return true, true
end

function NewTool:cl_handleAnimationsOnUpdate(dt)
    local isSprinting = self.tool:isSprinting()
    if self.tool:isLocal() then
        if self.equipped then
            if isSprinting and self.firstPersonAnimations.currentAnimation ~= "sprintInto" and self.firstPersonAnimations.currentAnimation ~= "sprintIdle" then
                swapFpAnimation(self.firstPersonAnimations, "sprintExit", "sprintInto", 0.0)
            elseif not isSprinting and (self.firstPersonAnimations.currentAnimation == "sprintIdle" or self.firstPersonAnimations.currentAnimation == "sprintInto") then
                swapFpAnimation(self.firstPersonAnimations, "sprintInto", "sprintExit", 0.0)
            end
        end
    end
    updateFpAnimations(self.firstPersonAnimations, self.equipped, dt)

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

function NewTool:cl_handleAnimationsOnEquip(animate)
    if animate then
        sm.audio.play("PaintTool - Equip", self.tool:getPosition())
    end
    self.wantEquipped = true
    local currentThirdPersonRends = table.concatTables(toolAnimsThirdPerson, toolModelRends)
    local currentFirstPersonRends = table.concatTables(toolAnimsFirstPerson, toolModelRends)
    self.tool:setTpRenderables(currentThirdPersonRends)
    self:loadAnimations()
    if not self.tool:isLocal() then
        return
    end
    self.tool:setFpRenderables(currentFirstPersonRends)
    swapFpAnimation(self.firstPersonAnimations, "unequip", "equip", 0.2)
end

function NewTool:cl_handleAnimationsOnUnequip(animate)
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

function NewTool:loadAnimations()
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
    return true
end
