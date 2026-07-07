ActionManager = {}

function ActionManager.init(tool)
    tool.ActionManager = {}
    local self = tool.ActionManager

    function self.executeAction(action)
        print(action)
    end
end