ToolWorkflowManager = {}

function ToolWorkflowManager.init(tool)
    tool.ToolWorkflowManager = {}
    local self = tool.ToolWorkflowManager

    self.active = nil
    self.sleeping = false

    local function getLabel(workflow)
        if workflow == nil then return "<none>" end
        return workflow.label or workflow.id or "<unnamed>"
    end

    function self.hasActive()
        return self.active ~= nil
    end

    function self.start(action)
        if action == nil then return end

        if self.active ~= nil then
            print("NewTool workflow cancelled before replacement: " .. getLabel(self.active))
        end

        local instance = nil
        if action.create ~= nil then
            instance = action.create(tool, action)
        end
        if instance == nil then
            instance = {
                id = action.id,
                label = action.label,
                description = action.description
            }
        end

        self.active = instance
        self.sleeping = false
        print("NewTool workflow activated: " .. getLabel(self.active))
    end

    function self.complete()
        if self.active == nil then return end
        print("NewTool workflow completed: " .. getLabel(self.active))
        self.active = nil
        self.sleeping = false
    end

    function self.cancel(reason)
        if self.active == nil then return end
        local suffix = ""
        if reason ~= nil then suffix = " (" .. tostring(reason) .. ")" end
        print("NewTool workflow cancelled: " .. getLabel(self.active) .. suffix)
        self.active = nil
        self.sleeping = false
    end

    function self.sleep()
        if self.active == nil then return end
        self.sleeping = true
        print("NewTool workflow sleeping: " .. getLabel(self.active))
    end

    function self.wake()
        if self.active == nil then return end
        if self.sleeping then
            print("NewTool workflow resumed: " .. getLabel(self.active))
        end
        self.sleeping = false
    end

    function self.applyCommandPolicy(policy)
        if self.active == nil then return end
        if policy == "cancel" then
            self.cancel("command policy")
        elseif policy == "complete" then
            self.complete()
        end
    end

    function self.run(dt, primaryState, secondaryState, forceBuild)
        if self.active == nil or self.sleeping then return false end

        local label = getLabel(self.active)
        sm.gui.setInteractionText(
            "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
            label .. " active | Left-click: complete | Right-click: cancel</p>"
        )

        if primaryState == 1 then
            self.complete()
            return true
        end

        if secondaryState == 1 then
            self.cancel("secondary")
            return true
        end

        return false
    end
end
