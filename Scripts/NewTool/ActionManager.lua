ActionManager = {}

function ActionManager.init(tool)
    tool.ActionManager = {}
    local self = tool.ActionManager

    function self.executeAction(action)
        if action == nil then return end

        if action.type == "toggleFlight" then
            MTFlight.toggleFlying(tool)
            return
        end

        print("Unhandled NewTool action: " .. tostring(action.type))
    end
end