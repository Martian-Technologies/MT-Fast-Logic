-- Owns only the currently selected tool mode. Tool modes directly control
-- their selection components; this manager has no selection policy.

ToolModeManager = {}

function ToolModeManager.init(tool)
    tool.ToolModeManager = {}
    local self = tool.ToolModeManager

    local active = nil
    local sleeping = false

    local function getLabel(mode)
        if mode == nil then return "<none>" end
        return mode.label or mode.id or "<unnamed>"
    end

    local function deselect(reason)
        if active == nil then return end
        if active.onDeselect ~= nil then active.onDeselect(reason) end
        print("NewTool mode deselected: " .. getLabel(active))
        active = nil
        sleeping = false
    end

    function self.select(action)
        if action == nil then return end
        deselect("replaced")

        if action.create ~= nil then
            active = action.create(tool, action)
        end
        if active == nil then
            active = {
                id = action.id,
                label = action.label,
                description = action.description
            }
        end

        sleeping = false
        if active.onSelect ~= nil then active.onSelect() end
        print("NewTool mode selected: " .. getLabel(active))
    end

    function self.clear(reason)
        deselect(reason)
    end

    function self.hasActive()
        return active ~= nil
    end

    function self.getActive()
        return active
    end

    function self.applyCommandPolicy(policy)
        if policy == "cancel" or policy == "complete" then
            deselect("command policy")
        end
    end

    function self.sleep()
        if active == nil or sleeping then return end
        sleeping = true
        if active.onSleep ~= nil then active.onSleep() end
    end

    function self.wake()
        if active == nil or not sleeping then return end
        sleeping = false
        if active.onWake ~= nil then active.onWake() end
    end

    function self.render(context)
        if active ~= nil and active.render ~= nil then
            active.render(context)
        end
    end

    function self.run(context, input)
        if active == nil or sleeping then return false end

        if active.update ~= nil then
            local result = active.update(context, input)
            if result == "exit" then
                deselect("mode requested exit")
                return true
            end
            return result == true
        end

        sm.gui.setInteractionText(
            "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
            getLabel(active) .. " selected | F: choose another tool</p>"
        )
        return false
    end
end
