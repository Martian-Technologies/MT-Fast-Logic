RadialMenu = {}

function RadialMenu.init(tool, radialManifest, layoutEngine, view)
    tool.RadialMenu = {}
    local self = tool.RadialMenu
    local manifest = radialManifest
    local layout = layoutEngine
    local menuView = view
    local timeForceBuild = 0
    local frameCountForceBuild = 0
    local maxTimeToOpenBigMenu = 0.2
    local isOpen = false

    local function open()
        menuView.open(layout.buildRadial(manifest))
        isOpen = true
    end

    local function close()
        menuView.close()
        isOpen = false
    end

    function self.run(dt, primaryState, secondaryState, forceBuild)
        if forceBuild then
            if timeForceBuild == 0 and not isOpen then open() end
            timeForceBuild = timeForceBuild + dt
            frameCountForceBuild = frameCountForceBuild + 1
        elseif timeForceBuild ~= 0 then
            local bestOption = menuView.getClosestIndex()
            local action = nil
            if (bestOption == 1 and timeForceBuild < maxTimeToOpenBigMenu) or frameCountForceBuild < 3 then
                action = { type = "openMenu", menu = "main" }
            elseif bestOption ~= nil then
                action = menuView.getAction(bestOption)
            end

            timeForceBuild = 0
            frameCountForceBuild = 0
            close()

            if action ~= nil then tool:executeAction(action) end
            return true
        end

        if isOpen then
            menuView.render()
            return true
        end
        return false
    end

    function self.unequip()
        timeForceBuild = 0
        frameCountForceBuild = 0
        close()
    end
end
