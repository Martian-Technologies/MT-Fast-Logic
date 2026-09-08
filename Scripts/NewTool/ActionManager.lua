ActionManager = {}

function ActionManager.init(tool, actionRegistry)
    tool.ActionManager = {}
    local self = tool.ActionManager
    local registry = actionRegistry

    local function executeRegistered(actionId)
        local action = registry.get(actionId)
        if action == nil then
            print("Unknown NewTool registered action: " .. tostring(actionId))
            return
        end

        if action.kind == "tool" then
            tool.ToolModeManager.select(action)
            return
        end

        if action.kind == "command" then
            tool.ToolModeManager.applyCommandPolicy(action.activePolicy)
            print("NewTool command selected: " .. tostring(action.label or action.id))
            if action.run ~= nil then
                action.run(tool, action)
            end
            return
        end

        if action.kind == "submenu" then
            if action.menu ~= nil then
                tool.MenuManager.open(action.menu)
            else
                print("NewTool submenu missing menu id: " .. tostring(action.id))
            end
            return
        end

        print("Unknown NewTool action kind: " .. tostring(action.kind) .. " for " .. tostring(actionId))
    end

    function self.executeAction(action)
        if action == nil then return end

        if action.type == "registered" then
            executeRegistered(action.id)
            return
        end

        if action.type == "openMenu" then
            tool.MenuManager.open(action.menu or "main")
            return
        end

        print("Unhandled NewTool action: " .. tostring(action.type))
    end
end
