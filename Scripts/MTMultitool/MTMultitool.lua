MTMultitool = class()

print("loading MTMultitool.lua")

dofile("../util/util.lua")

dofile("$GAME_DATA/Scripts/game/AnimationUtil.lua")

dofile("$CONTENT_DATA/Scripts/MTMultitool/SelectionModeController.lua")

dofile("$CONTENT_DATA/Scripts/MTMultitool/VertexRenderer.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/BlockSelector.lua")
dofile("$CONTENT_DATA/Scripts/util/util.lua")
dofile("$CONTENT_DATA/Scripts/util/mathUtil.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/lib.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/saveFile.lua")

dofile("$CONTENT_DATA/Scripts/MTMultitool/HoveringUI/HoveringUI.lua")

dofile("$CONTENT_DATA/Scripts/MTMultitool/BackupMenu.lua")

dofile("$CONTENT_DATA/Scripts/MTMultitool/BlueprintSpawner.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/DoMeleeState.lua")

dofile("$CONTENT_DATA/Scripts/MTMultitool/VolumeSelector.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/BetterVolumeSelector.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/ConnectionManager.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/NametagManager.lua")

dofile("$CONTENT_DATA/Scripts/MTMultitool/ConnectionShower.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/StateDisplay.lua")

dofile("$CONTENT_DATA/Scripts/MTMultitool/CallbackEngine.lua")

dofile("$CONTENT_DATA/Scripts/MTMultitool/Flying.lua")

dofile("$CONTENT_DATA/Scripts/MTMultitool/modes/LogicConverter.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/modes/SiliconConverter.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/modes/Settings.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/modes/ModeChanger.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/modes/VolumePlacer.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/modes/Merger.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/modes/VolumeDeleter.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/modes/Colorizer.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/modes/Heatmap.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/modes/DecoderMaker.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/modes/CopyPaste.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/modes/SingleConnect.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/modes/SeriesConnect.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/modes/NtoNConnect.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/modes/ParallelConnect.lua")
dofile("$CONTENT_DATA/Scripts/MTMultitool/modes/TensorConnect.lua")

function clamp(value, min, max) -- needed for the game's swapFpAnimation function because it was returning the error:
                                -- ----- Lua Error Traceback -----
                                -- $GAME_DATA/Scripts/game/AnimationUtil.lua:131: in function 'swapFpAnimation'
                                --     ...c976f4d/Scripts/MTMultitool/MTMultitool.lua:456: in function 'client_onUnequip' (Lua entered on line number: 424)
                                -- ERROR: Z:\Jenkins\workspace\sm\ContraptionCommon\LuaManager.cpp:1520 Lua call buffer - failed to call callback 'client_onUnequip'
                                -- ERROR: $GAME_DATA/Scripts/game/AnimationUtil.lua:131: attempt to call global 'clamp' (a nil value)
    if value < min then
        return min
    end
    if value > max then
        return max
    end
    return value
end

local toolModelRends = { "$CONTENT_DATA/Objects/Textures/Char_liftremote/char_liftremote.rend" }
local toolAnimsThirdPerson = { "$CONTENT_DATA/Objects/Textures/Char_liftremote/char_liftremote_tp_animlist.rend" }
local toolAnimsFirstPerson = { "$CONTENT_DATA/Objects/Textures/Char_liftremote/char_liftremote_fp_animlist.rend" }

sm.tool.preloadRenderables( toolModelRends )
sm.tool.preloadRenderables( toolAnimsThirdPerson )
sm.tool.preloadRenderables( toolAnimsFirstPerson )

local defaultEnabledModes = {
    true, -- Fast Logic Convert
    true, -- Silicon Convert
    true, -- Settings
    true, -- Mode Changer
    true, -- Volume Placer
    true,  -- Merger
    false, -- Deleter
    true, -- Colorizer
    false, -- Heatmap
    false, -- Decoder Maker
    true, -- Copy Paste
    true, -- Multipoint
    true, -- Series
    true, -- N to N
    true, -- Parallel
    true, -- Tensor
}

MTMultitool.modes = {
	"Fast Logic Convert",
	"Silicon Convert",
    "Settings",
    "Mode Changer",
    "Volume Placer",
    "Merger",
    "Deleter",
    "Colorizer",
    "Heatmap",
    "Decoder Maker",
    "Copy Paste",
    "Multipoint",
    "Series",
	"N to N",
    "Parallel",
    "Tensor"
}

MTMultitool.internalModes = {
    "LogicConverter",
    "SiliconConverter",
    "Settings",
    "ModeChanger",
    "VolumePlacer",
    "Merger",
    "VolumeDeleter",
    "Colorizer",
    "Heatmap",
    "DecoderMaker",
    "CopyPaste",
    "SingleConnect",
    "SeriesConnect",
    "NtoNConnect",
    "ParallelConnect",
    "TensorConnect",
}

MTMultitool.forceOn = {
	3,
}
MTMultitool.FastLogicModes = {
    -- 1,
    -- 2
}

function MTMultitool.server_onCreate(self)
    MTFlying.sv_inject(self)
end

function MTMultitool.client_onCreate(self)
    ThisMultitool = self
    self.subscriptions = {
        client_onUpdate = {}
    }

    self.saveIdx = 1

    CallbackEngine.inject(self)

    MTFlying.inject(self)
    ConnectionShower.inject(self)
    StateDisplay.inject(self)
    DoMeleeState.inject(self)

    HoveringUI.inject(self)

    SelectionModeController.inject(self)

    VolumeSelector.inject(self)
    BetterVolumeSelector.inject(self)

    LogicConverter.inject(self)
    SiliconConverterTool.inject(self)
    Settings.inject(self)
    ModeChanger.inject(self)
    VolumePlacer.inject(self)
    Merger.inject(self)
    VolumeDeleter.inject(self)
    Colorizer.inject(self)
    Heatmap.inject(self)
    DecoderMaker.inject(self)
    CopyPaste.inject(self)
    SingleConnect.inject(self)
    SeriesConnect.inject(self)
    NtoNConnect.inject(self)
    ParallelConnect.inject(self)
    TensorConnect.inject(self)

    BackupMenu.inject(self)

    BlockSelector.inject(self)
    VertexRenderer.inject(self)
    ConnectionManager.inject(self)
    RangeOffset.inject(self)

    VertexRenderer.subscribe(self, function() return BlockSelector.addVertexPoints(self) end)
    VertexRenderer.subscribe(self, ConnectionManager.createVertexSubsription(self))

    -- BlockSelector.tool = self.tool
    -- BlockSelector.client_onCreate()
    self.raycastMode = "DDA" -- connectionRaycast, blockRaycast, DDA
    self.enabledModes = {}
    for i = 1, #defaultEnabledModes do
        self.enabledModes[i] = defaultEnabledModes[i]
    end
    MTMultitool.repullSettings(self)
    self.mode = 1
    self.tool:setCrossHairAlpha(0.3)
    self.tool:setDispersionFraction(0)
    self.confirmed = 0
    self.forceBuildHeld = false
    self.lastSettingsRepull = 0
    return true
end

function MTMultitool.repullSettings(self)
    self.lastSettingsRepull = os.clock()
    local data = SaveFile.getSaveData(self.saveIdx)
    for i = 1, #defaultEnabledModes do
        self.enabledModes[i] = defaultEnabledModes[i]
    end
    for internalName, state in pairs(data.modeStates) do
        for i, modeName in pairs(MTMultitool.internalModes) do
            if modeName == internalName then
                self.enabledModes[i] = state
            end
        end
    end
    ConnectionManager.syncStorage(self)
    ConnectionShower.syncStorage(self)
    DoMeleeState.syncStorage(self)
end

function MTMultitool.handleForceBuild(self, forceBuild)
	local out = false
    if forceBuild and not self.forceBuildHeld then
        out = true
    end
	self.forceBuildHeld = forceBuild
	return out
end

function MTMultitool.client_onRefresh(self)
    self:client_onCreate()
	return true
end

local function unsafeOnUpdateStuff(self, dt)
	if MTMultitool.internalModes[self.mode] == "SingleConnect" then
    	SingleConnect.client_onUpdate(self)
	elseif MTMultitool.internalModes[self.mode] == "SeriesConnect" then
        SeriesConnect.client_onUpdate(self)
    elseif MTMultitool.internalModes[self.mode] == "NtoNConnect" then
		NtoNConnect.client_onUpdate(self)
	elseif MTMultitool.internalModes[self.mode] == "ParallelConnect" then
		ParallelConnect.client_onUpdate(self)
	elseif MTMultitool.internalModes[self.mode] == "TensorConnect" then
		TensorConnect.client_onUpdate(self)
	end
end

function MTMultitool.client_onUpdate(self, dt)
    if os.clock() - self.lastSettingsRepull > 1 then
        self:repullSettings()
    end
    for _, func in pairs(self.subscriptions["client_onUpdate"]) do
        func(self, dt)
    end
    for _, modeIndex in pairs(MTMultitool.forceOn) do
        self.enabledModes[modeIndex] = true
    end
    if sm.MTFastLogic ~= nil then
        for _, modeIndex in pairs(MTMultitool.FastLogicModes) do
            self.enabledModes[modeIndex] = true
        end
    else
        for _, modeIndex in pairs(MTMultitool.FastLogicModes) do
            if self.enabledModes[modeIndex] then
                self.enabledModes[modeIndex] = false
                SiliconConverterTool.cleanNametags(self)
            end
        end
    end
    -- MTFlying.cl_onUpdate(self, dt)
    -- VolumeSelector.client_onUpdate(self, dt)
    -- ConnectionShower.client_onUpdate(self)
    local success, result
    success, result = pcall(MTFlying.cl_onUpdate, self, dt)
    if not success then
        print("Error in MTFlying.cl_onUpdate: " .. result)
    end
    success, result = pcall(VolumeSelector.client_onUpdate, self, dt)
    if not success then
        print("Error in VolumeSelector.client_onUpdate: " .. result)
    end
    success, result = pcall(ConnectionShower.client_onUpdate, self, dt)
    if not success then
        print("Error in ConnectionShower.client_onUpdate: " .. result)
    end
    success, result = pcall(StateDisplay.client_onUpdate, self)
    if not success then
        print("Error in StateDisplay.client_onUpdate: " .. result)
    end
    success, result = pcall(unsafeOnUpdateStuff, self, dt)
    if not success then
        print("Error in unsafeOnUpdateStuff: " .. result)
    end
    -- BlockSelector.client_onUpdate(self)
    -- ConnectionManager.client_onUpdate(self)
    -- VertexRenderer.client_onUpdate(self)
    success, result = pcall(BlockSelector.client_onUpdate, self)
    if not success then
        print("Error in BlockSelector.client_onUpdate: " .. result)
    end
    success, result = pcall(ConnectionManager.client_onUpdate, self)
    if not success then
        print("Error in ConnectionManager.client_onUpdate: " .. result)
    end
    success, result = pcall(VertexRenderer.client_onUpdate, self)
    if not success then
        print("Error in VertexRenderer.client_onUpdate: " .. result)
    end
    success, result = pcall(Heatmap.client_onUpdate, self, dt)
    if not success then
        print("Error in Heatmap.client_onUpdate: " .. result)
    end

    local isSprinting = self.tool:isSprinting()

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
    return true
end

function MTMultitool.client_onReload(self)
    if self.internalModes[self.mode] == "CopyPaste" then
        CopyPaste.client_onReload(self)
    elseif self.internalModes[self.mode] == "SingleConnect" then
        SingleConnect.client_onReload(self)
    end
    return true
end

function MTMultitool.loadAnimations(self)
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

local function concatTables(t1, t2)
    local out = {}
    for _, v in pairs(t1) do
        table.insert(out, v)
    end
    for _, v in pairs(t2) do
        table.insert(out, v)
    end
    return out
end

function MTMultitool.client_onEquip(self, animate)
    self.confirmed = 0

    if animate then
        sm.audio.play("PaintTool - Equip", self.tool:getPosition())
    end
    -- ConnectionRaycaster:cleanCache()
    self.wantEquipped = true

    local currentThirdPersonRends = concatTables(toolAnimsThirdPerson, toolModelRends)
    local currentFirstPersonRends = concatTables(toolAnimsFirstPerson, toolModelRends)

    self.tool:setTpRenderables( currentThirdPersonRends )

    self:loadAnimations()

    if not self.tool:isLocal() then
        return
	end
    -- Sets PotatoRifle renderable, change this to change the mesh
    self.tool:setFpRenderables( currentFirstPersonRends )
    swapFpAnimation( self.firstPersonAnimations, "unequip", "equip", 0.2 )
end

function MTMultitool.client_onUnequip(self, animate)
    if self.mode == "BackupMenu" then
        self.mode = 3
    end
    -- for _, func in pairs(self.subscribtions["client_onUnequip"]) do
    --     func(self, animate)
    -- end
    if MTMultitool.internalModes[self.mode] == "SiliconConverter" then
        SiliconConverterTool.cleanNametags(self)
    elseif MTMultitool.internalModes[self.mode] == "Settings" then
        Settings.cleanUp(self)
    elseif MTMultitool.internalModes[self.mode] == "ModeChanger" then
        ModeChanger.cleanNametags(self)
    elseif MTMultitool.internalModes[self.mode] == "VolumePlacer" then
        VolumePlacer.cleanNametags(self)
    elseif MTMultitool.internalModes[self.mode] == "Merger" then
        Merger.cleanNametags(self)
    elseif MTMultitool.internalModes[self.mode] == "VolumeDeleter" then
        VolumeDeleter.cleanNametags(self)
    elseif MTMultitool.internalModes[self.mode] == "Colorizer" then
        Colorizer.cleanNametags(self)
    elseif MTMultitool.internalModes[self.mode] == "CopyPaste" then
        CopyPaste.cleanNametags(self)
    end
    HoveringUI.cleanUp(self)
	BlockSelector.client_onUnequip(self)
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

function MTMultitool.client_onToggle(self)
    HoveringUI.cleanUp(self)
    if self.mode == "BackupMenu" then
        self.mode = 3
        return true
    end
    if self.SingleConnect.readingRotate then
        self.SingleConnect.rotated = true
        return true
    else
        self.SingleConnect.rotated = false
    end
    if MTMultitool.internalModes[self.mode] == "SiliconConverter" then
        SiliconConverterTool.cleanUp(self)
    elseif MTMultitool.internalModes[self.mode] == "Settings" then
        Settings.cleanUp(self)
    elseif MTMultitool.internalModes[self.mode] == "ModeChanger" then
        ModeChanger.cleanUp(self)
    elseif MTMultitool.internalModes[self.mode] == "Merger" then
        Merger.cleanUp(self)
    elseif MTMultitool.internalModes[self.mode] == "Colorizer" then
        Colorizer.cleanUp(self)
    elseif MTMultitool.internalModes[self.mode] == "VolumePlacer" then
        VolumePlacer.cleanUp(self)
    elseif MTMultitool.internalModes[self.mode] == "DecoderMaker" then
        DecoderMaker.cleanUp(self)
    elseif MTMultitool.internalModes[self.mode] == "CopyPaste" then
        CopyPaste.cleanUp(self)
    elseif MTMultitool.internalModes[self.mode] == "SingleConnect" then
        SingleConnect.cleanUp(self)
    elseif MTMultitool.internalModes[self.mode] == "SeriesConnect" then
        SeriesConnect.cleanUp(self)
    elseif MTMultitool.internalModes[self.mode] == "NtoNConnect" then
        NtoNConnect.cleanUp(self)
    elseif MTMultitool.internalModes[self.mode] == "ParallelConnect" then
        ParallelConnect.cleanUp(self)
    elseif MTMultitool.internalModes[self.mode] == "TensorConnect" then
        TensorConnect.cleanUp(self)
    end
	local isCrouching =  self.tool:isCrouching()
    repeat
        if isCrouching then
            self.mode = self.mode - 1
        else
            self.mode = self.mode + 1
        end
        if self.mode > #self.modes then
            self.mode = 1
        end
        if self.mode < 1 then
            self.mode = #self.modes
        end
    until self.enabledModes[self.mode]
    return true
end

local function triggerTool(self, primaryState, secondaryState, forceBuild, lookingAt)
    SelectionModeController.trigger(self)
	if MTMultitool.internalModes[self.mode] == "LogicConverter" then
        LogicConverter.trigger(self, primaryState, secondaryState, forceBuild, lookingAt)
    elseif MTMultitool.internalModes[self.mode] == "SiliconConverter" then
		SiliconConverterTool.trigger(self, primaryState, secondaryState, forceBuild, lookingAt)
	elseif MTMultitool.internalModes[self.mode] == "Settings" then
        Settings.trigger(self, primaryState, secondaryState, forceBuild, lookingAt)
    elseif self.mode == "BackupMenu" then
        BackupMenu.trigger(self, primaryState, secondaryState, forceBuild, lookingAt)
    elseif MTMultitool.internalModes[self.mode] == "ModeChanger" then
        ModeChanger.trigger(self, primaryState, secondaryState, forceBuild, lookingAt)
    elseif MTMultitool.internalModes[self.mode] == "VolumePlacer" then
        VolumePlacer.trigger(self, primaryState, secondaryState, forceBuild, lookingAt)
    elseif MTMultitool.internalModes[self.mode] == "Merger" then
        Merger.trigger(self, primaryState, secondaryState, forceBuild, lookingAt)
    elseif MTMultitool.internalModes[self.mode] == "VolumeDeleter" then
        VolumeDeleter.trigger(self, primaryState, secondaryState, forceBuild, lookingAt)
    elseif MTMultitool.internalModes[self.mode] == "Colorizer" then
        Colorizer.trigger(self, primaryState, secondaryState, forceBuild, lookingAt)
    elseif MTMultitool.internalModes[self.mode] == "Heatmap" then
        Heatmap.trigger(self, primaryState, secondaryState, forceBuild, lookingAt)
    elseif MTMultitool.internalModes[self.mode] == "DecoderMaker" then
        DecoderMaker.trigger(self, primaryState, secondaryState, forceBuild, lookingAt)
    elseif MTMultitool.internalModes[self.mode] == "CopyPaste" then
        CopyPaste.trigger(self, primaryState, secondaryState, forceBuild, lookingAt)
    elseif MTMultitool.internalModes[self.mode] == "SingleConnect" then
        SingleConnect.trigger(self, primaryState, secondaryState, forceBuild, lookingAt)
    elseif MTMultitool.internalModes[self.mode] == "SeriesConnect" then
        SeriesConnect.trigger(self, primaryState, secondaryState, forceBuild, lookingAt)
    elseif MTMultitool.internalModes[self.mode] == "NtoNConnect" then
		NtoNConnect.trigger(self, primaryState, secondaryState, forceBuild, lookingAt)
	elseif MTMultitool.internalModes[self.mode] == "ParallelConnect" then
		ParallelConnect.trigger(self, primaryState, secondaryState, forceBuild, lookingAt)
	elseif MTMultitool.internalModes[self.mode] == "TensorConnect" then
		TensorConnect.trigger(self, primaryState, secondaryState, forceBuild, lookingAt)
	end
end

function MTMultitool.client_onEquippedUpdate(self, primaryState, secondaryState, forceBuild)
    if self.enabledModes[self.mode] == false then
        self.mode = self.mode + 1
		if self.mode > #self.modes then
			self.mode = 1
		end
	end
    -- print("mode: " .. self.modes[self.mode])
	-- print(self.mode)
    local lookingAt = self.BlockSelector.raycastLookingAt
    -- pcall triggerTool to catch errors
    local success, result = pcall(triggerTool, self, primaryState, secondaryState, forceBuild, lookingAt)
    if not success then
        print("Error in triggerTool: " .. result)
    end

    local enabledModes = 0
    local modeOfEnabled = 0
	for i, enabled in pairs(self.enabledModes) do
		if enabled then
			enabledModes = enabledModes + 1
			if i == self.mode then
				modeOfEnabled = enabledModes
			end
		end
	end

    -- print("EEEEEEE")
    if MTMultitool.modes[self.mode] ~= nil then
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("NextCreateRotation", true), "Rotate Mode ",
            "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
            MTMultitool.modes[self.mode] .. " (" .. modeOfEnabled .. "/" .. enabledModes .. ")</p>")
    else
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("NextCreateRotation", true), "Rotate Mode ",
            "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
            self.mode .. "</p>")
    end
    -- print("EEEEEEEEEE")
	return false, true
end

function MTMultitool.server_makeConnections(self, data)
    ConnectionManager.server_makeConnections(self, data)
end

function MTMultitool.server_breakConnections(self, data)
    ConnectionManager.server_breakConnections(self, data)
end

function MTMultitool.server_convertBody(self, data)
    sm.MTFastLogic.FastLogicRunnerRunner.server_convertBody(self, data)
end

MTGateUUIDs = {
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88087"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88088"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88089"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88090"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88091"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88092"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88093"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88094"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88095"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88096"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88097"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88098"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88099"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88100"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88101"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88102"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88103"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88104"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88105"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88106"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88107"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88108"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88109"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88110"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88111"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88112"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88113"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88114"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88115"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88116"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88117"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88118"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88119"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88120"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88121"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88122"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88123"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88124"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88125"),
    sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88126"),
}

function MTMultitool.server_onFixedUpdate(self, dt)
    MTFlying.server_onFixedUpdate(self, dt)
    TensorConnect.server_onFixedUpdate(self, dt)
    Heatmap.server_onFixedUpdate(self, dt)
    CopyPaste.server_onFixedUpdate(self, dt)
end

function MTMultitool.server_convertSilicon(self, data)
    local wantedType = data.wantedType
    local positions = {}
    local originLocal = data.origin
    local finalLocal = data.final
    local x = math.min(originLocal.x, finalLocal.x)
    local y = math.min(originLocal.y, finalLocal.y)
    local z = math.min(originLocal.z, finalLocal.z)
    local xMax = math.max(originLocal.x, finalLocal.x)
    local yMax = math.max(originLocal.y, finalLocal.y)
    local zMax = math.max(originLocal.z, finalLocal.z)
    for i = x * 4, xMax * 4 do
        for j = y * 4, yMax * 4 do
            for k = z * 4, zMax * 4 do
                table.insert(positions, sm.vec3.new(i, j, k))
            end
        end
    end
    local success, result = pcall(
        sm.MTFastLogic.FastLogicRunnerRunner.convertSilicon,
        sm.MTFastLogic.FastLogicRunnerRunner, wantedType, data.originBody, positions
    )
    if not success then
        self:sendMessageToAll("AN ERROR OCCURRED IN FAST LOGIC (id: 4). Please report to ItchyTrack on discord")
        self:sendMessageToAll(result)
    end
    
    -- print(wantedType)
    -- print(origin)
    -- print(positions)
end

function MTMultitool.gui_buttonCallback(self, buttonName)
    Settings.gui_buttonCallback(self, buttonName)
end

function MTMultitool.server_changeModes(self, data)
    local mode = data.mode
    local originLocal = data.origin
    local finalLocal = data.final
    local body = data.body
    local halfBlock = 0.125
    local x = math.min(originLocal.x, finalLocal.x) - halfBlock
    local y = math.min(originLocal.y, finalLocal.y) - halfBlock
    local z = math.min(originLocal.z, finalLocal.z) - halfBlock
    local xMax = math.max(originLocal.x, finalLocal.x) - halfBlock
    local yMax = math.max(originLocal.y, finalLocal.y) - halfBlock
    local zMax = math.max(originLocal.z, finalLocal.z) - halfBlock
    local voxelMap = MTMultitoolLib.getVoxelMap(body, true)
    local VinclingUUID = sm.uuid.new("bc336a10-675a-4942-94ce-e83ecb4b501a")
    local VanillaGateUUID = sm.uuid.new("9f0f56e8-2c31-4d83-996c-d00a9b296c3f")
    local vanillaGateList = {}
    for i = x * 4, xMax * 4 do
        for j = y * 4, yMax * 4 do
            for k = z * 4, zMax * 4 do
                local indexString = i / 4 .. ";" .. j / 4 .. ";" .. k / 4
                local shape = voxelMap[indexString]
                if shape == nil then
                    goto continue
                end
                if table.contains(MTGateUUIDs, shape.uuid) then
                    local interactable = shape:getInteractable()
                    if interactable ~= nil then
                        sm.event.sendToInteractable(interactable, "server_saveMode", mode)
                    end
                elseif shape.uuid == VinclingUUID then
                    local interactable = shape:getInteractable()
                    if interactable ~= nil then
                        sm.event.sendToInteractable(interactable, "sv_saveMode", mode)
                    end
                elseif shape.uuid == VanillaGateUUID then
                    local interactable = shape:getInteractable()
                    if interactable ~= nil then
                        table.insert(vanillaGateList, interactable)
                    end
                end
                ::continue::
            end
        end
    end
    if #vanillaGateList > 0 then
        local world = body:getWorld()
        local worldPos = body.worldPosition
        local worldRot = body.worldRotation
        local bp = sm.creation.exportToTable(body, true)
        -- sm.json.save(bp, "$CONTENT_DATA/bp.json")
        local bodies = bp.bodies --list of all bodies
        for i = 1, #bodies do
            local body = bodies[i]
            local childs = body.childs
            for j = 1, #childs do
                local child = childs[j]
                if child.shapeId ~= "9f0f56e8-2c31-4d83-996c-d00a9b296c3f" then
                    goto continue
                end
                local controllerId = child.controller.id
                for k = 1, #vanillaGateList do
                    local interactable = vanillaGateList[k]
                    if interactable.id == controllerId then
                        child.controller.mode = mode - 1
                    end
                end
                ::continue::
            end
        end
        local shapes = body:getCreationShapes()
        for _, shape in pairs(shapes) do
            shape:destroyShape()
        end

        sm.creation.importFromString(world, sm.json.writeJsonString(bp), worldPos, worldRot, false)
    end
end

function MTMultitool.server_blockMerge(self, data)
    local originLocal = data.origin
    local finalLocal = data.final
    local body = data.body
    local halfBlock = 0.125
    local x = math.min(originLocal.x, finalLocal.x) - halfBlock
    local y = math.min(originLocal.y, finalLocal.y) - halfBlock
    local z = math.min(originLocal.z, finalLocal.z) - halfBlock
    local xMax = math.max(originLocal.x, finalLocal.x) - halfBlock
    local yMax = math.max(originLocal.y, finalLocal.y) - halfBlock
    local zMax = math.max(originLocal.z, finalLocal.z) - halfBlock
    local voxelMap = MTMultitoolLib.getVoxelMap(body, true)
    local deleteShapes = {}
    for i = x * 4, xMax * 4 do
        for j = y * 4, yMax * 4 do
            for k = z * 4, zMax * 4 do
                local indexString = i / 4 .. ";" .. j / 4 .. ";" .. k / 4
                local shape = voxelMap[indexString]
                if shape == nil then
                    goto continue
                end
                local interactable = shape:getInteractable()
                if interactable == nil then
                    goto continue
                end
                local children = interactable:getChildren()
                local parents = interactable:getParents()
                -- disconnect all connections going from the interactable to the children and from the parents to the interactable
                for _, child in pairs(children) do
                    interactable:disconnect(child)
                end
                for _, parent in pairs(parents) do
                    parent:disconnect(interactable)
                end
                -- now connect every parent to every child
                for _, parent in pairs(parents) do
                    for _, child in pairs(children) do
                        parent:connect(child)
                    end
                end
                table.insert(deleteShapes, shape)
                ::continue::
            end
        end
    end
    -- delete all shapes
    for _, shape in pairs(deleteShapes) do
        shape:destroyShape()
    end
end

function MTMultitool.server_volumeDelete(self, data)
    local originLocal = data.origin
    local finalLocal = data.final
    local body = data.body
    local halfBlock = 0.125
    local x = math.min(originLocal.x, finalLocal.x) - halfBlock
    local y = math.min(originLocal.y, finalLocal.y) - halfBlock
    local z = math.min(originLocal.z, finalLocal.z) - halfBlock
    local xMax = math.max(originLocal.x, finalLocal.x) - halfBlock
    local yMax = math.max(originLocal.y, finalLocal.y) - halfBlock
    local zMax = math.max(originLocal.z, finalLocal.z) - halfBlock
    local voxelMap = MTMultitoolLib.getVoxelMapShapesGW(body, true)
    local deleteShapes = {}
    for i = x * 4, xMax * 4 do
        for j = y * 4, yMax * 4 do
            for k = z * 4, zMax * 4 do
                local indexString = i / 4 .. ";" .. j / 4 .. ";" .. k / 4
                local shapes = voxelMap[indexString]
                if shapes == nil then
                    goto continue
                end
                for _, shape in pairs(shapes) do
                    if shape == nil then
                        goto continue2
                    end
                    if not sm.exists(shape) then
                        goto continue2
                    end
                    shape:destroyShape()
                    ::continue2::
                end
                ::continue::
            end
        end
    end
end


function MTMultitool.server_volumePlace(self, data)
    -- same data as blockMerge, but here we need to fill the space with logic gates
    local originLocal = data.origin
    local finalLocal = data.final
    local body = data.body
    local placingType = data.placingType -- "vanilla" | "fast"
    local uuidPlacing = sm.uuid.new("9f0f56e8-2c31-4d83-996c-d00a9b296c3f")
    if placingType == "fast" then
        uuidPlacing = sm.uuid.new("6a9dbff5-7562-4e9a-99ae-3590ece88112")
    end
    local halfBlock = 0.125
    local x = math.min(originLocal.x, finalLocal.x) - halfBlock
    local y = math.min(originLocal.y, finalLocal.y) - halfBlock
    local z = math.min(originLocal.z, finalLocal.z) - halfBlock
    local xMax = math.max(originLocal.x, finalLocal.x) - halfBlock
    local yMax = math.max(originLocal.y, finalLocal.y) - halfBlock
    local zMax = math.max(originLocal.z, finalLocal.z) - halfBlock
    for i = x * 4, xMax * 4 do
        for j = y * 4, yMax * 4 do
            for k = z * 4, zMax * 4 do
                local indexString = i / 4 .. ";" .. j / 4 .. ";" .. k / 4
                -- uuid, position, z-axis, x-axis, forceAccept
                local shape = body:createPart(uuidPlacing, sm.vec3.new(i, j+1, k), sm.vec3.new(0, -1, 0), sm.vec3.new(1, 0, 0), true)
            end
        end
    end
end

function MTMultitool.server_callCallbackTrigger(self, data)
    CallbackEngine.server_callCallbackTrigger(self, data)
end

function MTMultitool.client_callCallCallbackFromServer(self, data)
    CallbackEngine.client_callCallCallbackFromServer(self, data)
end

local function getInverseColor(colorId)
    if colorId == 0 then
        return 3
    elseif colorId == 1 then
        return 2
    elseif colorId == 2 then
        return 1
    elseif colorId == 3 then
        return 0
    end
    local color = sm.MTFastLogic.FastLogicBlockColors[colorId + 1]
    local maxDist = -1
    local colorIdLocal = 0
    for i = 4, 40 do
        local compColor = sm.MTFastLogic.FastLogicBlockColors[i]
        local diff = math.sqrt(
            (color.r - compColor.r) ^ 2 +
            (color.g - compColor.g) ^ 2 +
            (color.b - compColor.b) ^ 2
        )
        if diff > maxDist then
            maxDist = diff
            colorIdLocal = i - 1
        end
    end
    return colorIdLocal
end

function MTMultitool.server_recolor(self, data)
    local colorId = data.color
    local mode = data.mode
    if colorId ~= "invert" and colorId ~= "match" then
        colorId = colorId - 1
    end
    local originLocal = data.origin
    local finalLocal = data.final
    local body = data.body
    local halfBlock = 0.125
    local x = math.min(originLocal.x, finalLocal.x) - halfBlock
    local y = math.min(originLocal.y, finalLocal.y) - halfBlock
    local z = math.min(originLocal.z, finalLocal.z) - halfBlock
    local xMax = math.max(originLocal.x, finalLocal.x) - halfBlock
    local yMax = math.max(originLocal.y, finalLocal.y) - halfBlock
    local zMax = math.max(originLocal.z, finalLocal.z) - halfBlock
    local voxelMap = MTMultitoolLib.getVoxelMapShapesGW(body, true)
    local creationId = sm.MTFastLogic.CreationUtil.getCreationId(body)
    local creation = sm.MTFastLogic.Creations[creationId]
    for i = x * 4, xMax * 4 do
        for j = y * 4, yMax * 4 do
            for k = z * 4, zMax * 4 do
                local indexString = i / 4 .. ";" .. j / 4 .. ";" .. k / 4
                local shapes = voxelMap[indexString]
                if shapes == nil then
                    goto continue
                end
                for _, shape in pairs(shapes) do
                    if shape == nil then
                        goto continue2
                    end
                    if not sm.exists(shape) then
                        goto continue2
                    end
                    if mode == "Connection" then
                        if creation == nil then
                            return
                        end
                        local interactable = shape:getInteractable()
                        if interactable == nil then
                            goto continue2
                        end
                        if not table.contains(MTGateUUIDs, shape.uuid) then
                            goto continue2
                        end
                        if type(colorId) == "number" then
                            creation.FastLogicRealBlockManager:changeConnectionColor(interactable.id, colorId)
                        else
                            local currentShapeColor = shape:getColor()
                            local colorIdLocal = 0
                            local minDist = 1000000
                            for i = 1, 40 do
                                local compColor = sm.MTFastLogic.FastLogicBlockColors[i]
                                local diff = math.sqrt(
                                    (currentShapeColor.r - compColor.r) ^ 2 +
                                    (currentShapeColor.g - compColor.g) ^ 2 +
                                    (currentShapeColor.b - compColor.b) ^ 2
                                )
                                if diff < minDist then
                                    minDist = diff
                                    colorIdLocal = i - 1
                                end
                            end
                            if colorId == "match" then
                                creation.FastLogicRealBlockManager:changeConnectionColor(interactable.id, colorIdLocal)
                            elseif colorId == "invert" then
                                if minDist < 5 then
                                    creation.FastLogicRealBlockManager:changeConnectionColor(interactable.id,
                                    getInverseColor(colorIdLocal))
                                else
                                    local maxDist = -1
                                    for i = 1, 40 do
                                        local compColor = sm.MTFastLogic.FastLogicBlockColors[i]
                                        local diff = math.sqrt(
                                            (currentShapeColor.r - compColor.r) ^ 2 +
                                            (currentShapeColor.g - compColor.g) ^ 2 +
                                            (currentShapeColor.b - compColor.b) ^ 2
                                        )
                                        if diff > maxDist then
                                            maxDist = diff
                                            colorIdLocal = i - 1
                                        end
                                    end
                                    creation.FastLogicRealBlockManager:changeConnectionColor(interactable.id, colorIdLocal)
                                end
                            end
                        end
                    elseif mode == "Block" then
                        if type(colorId) == "number" then
                            shape:setColor(sm.MTFastLogic.FastLogicBlockColors[colorId + 1])
                        else
                            local interactable = shape:getInteractable()
                            if interactable == nil then
                                goto continue2
                            end
                            -- check if the shape is a gate
                            if table.contains(MTGateUUIDs, shape.uuid) then
                                -- check the connection color
                                
                                if creation == nil then
                                    return
                                end
                                local gateUuid = creation.uuids[interactable.id]
                                if gateUuid == nil then
                                    goto continue2
                                end
                                local gate = creation.blocks[gateUuid]
                                if gate == nil then
                                    goto continue2
                                end
                                local gateColorId = gate.connectionColorId
                                if gateColorId == nil then
                                    goto continue2
                                end
                                if colorId == "match" then
                                    local connectionColor = sm.MTFastLogic.FastLogicBlockColors[gateColorId + 1]
                                    local minDist = 1000000
                                    local colorIdLocal = 0
                                    for i = 1, 40 do
                                        local compColor = sm.MTFastLogic.FastLogicBlockColors[i]
                                        local diff = math.sqrt(
                                            (connectionColor.r - compColor.r) ^ 2 +
                                            (connectionColor.g - compColor.g) ^ 2 +
                                            (connectionColor.b - compColor.b) ^ 2
                                        )
                                        if diff < minDist then
                                            minDist = diff
                                            colorIdLocal = i - 1
                                        end
                                    end
                                    shape:setColor(sm.MTFastLogic.FastLogicBlockColors[colorIdLocal + 1])
                                elseif colorId == "invert" then
                                    local maxDist = -1
                                    local colorIdLocal = getInverseColor(gateColorId)
                                    shape:setColor(sm.MTFastLogic.FastLogicBlockColors[colorIdLocal + 1])
                                end
                            end
                        end
                    end
                    ::continue2::
                end
                -- if shape == nil then
                --     goto continue
                -- end
                -- -- if shape.uuid == MTGateUUID then
                -- if table.contains(MTGateUUIDs, shape.uuid) then
                --     local interactable = shape:getInteractable()
                --     if interactable ~= nil then
                --         creation.FastLogicRealBlockManager:changeConnectionColor(interactable.id, colorId)
                --     end
                -- end
                ::continue::
            end
        end
    end
end

function MTMultitool.cl_notifyFlying(self, data)
    MTFlying.cl_notifyFlying(self, data)
end

function MTMultitool.sv_toggleFlying(self, data)
    MTFlying.sv_toggleFlying(self, data)
end

function MTMultitool.sv_connectTensors(self, data)
    TensorConnect.sv_connectTensors(self, data)
end

function MTMultitool.sv_receiveBlueprintPacket(self, data)
    BlueprintSpawner.sv_receiveBlueprintPacket(self, data)
end

function MTMultitool.sv_loadBackup(self, data)
    sm.MTBackupEngine.sv_loadBackup(self, data)
end

function MTMultitool.server_copyPaste(self, data)
    CopyPaste.server_copyPaste(self, data)
end