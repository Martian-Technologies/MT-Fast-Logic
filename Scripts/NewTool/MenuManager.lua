MenuManager = {}

function MenuManager.init(tool, manifests, layoutEngine, view)
    tool.MenuManager = {}
    local self = tool.MenuManager
    local menuManifests = manifests or {}
    local layout = layoutEngine
    local menuView = view
    local menuId = nil
    local menuState = nil
    local forceBuildHeldTime = 0
    local tapMaxTime = 0.2

    local function showInteractionText(tile)
        if tile == nil then
            tool.PromptPresenter.show("Aim at an icon | Left-click: select | Right-click/F: close", 300)
            return
        end

        local actionText = "select"
        if tile.action ~= nil then
            actionText = "activate"
        elseif tile.onSelect ~= nil then
            actionText = "show actions"
        end

        local label = tostring(tile.label or "")
        local description = tostring(tile.description or "")
        if description ~= "" then
            tool.PromptPresenter.show(label .. " - " .. description .. " | Left-click: " .. actionText .. " | Right-click/F: close", 300)
        else
            tool.PromptPresenter.show(label .. " | Left-click: " .. actionText .. " | Right-click/F: close", 300)
        end
    end

    local function handleMenuEvent(event)
        assert(menuState ~= nil)
        if event == nil then return end

        if event.type == "selectSwitcher" then
            if menuState.switchers[event.switcher] == event.child then return end
            menuState.switchers[event.switcher] = event.child
            print("NewTool hub selected switcher child: " .. tostring(event.switcher) .. " = " .. tostring(event.child))
            return
        end

        print("Unknown NewTool menu event: " .. tostring(event.type))
    end

    local function buildAndRender()
        local manifest = menuManifests[menuId]
        if manifest == nil or menuState == nil then return nil end
        local plan = layout.build(manifest, menuState, tool.HologramText)
        return menuView.render(plan)
    end

    function self.isOpen()
        return menuId ~= nil
    end

    function self.open(id)
        local requestedId = id or "main"
        local manifest = menuManifests[requestedId]
        if manifest == nil or manifest.kind ~= "hub" or manifest.layout == nil then
            print("Unknown NewTool hub menu: " .. tostring(requestedId))
            return
        end

        menuId = requestedId
        menuState = layout.createState(manifest)
        forceBuildHeldTime = 0
        menuView.open()
        print("NewTool hub opened: " .. tostring(menuId))
    end

    function self.close()
        if menuId == nil then return end
        print("NewTool hub closed")
        menuId = nil
        menuState = nil
        forceBuildHeldTime = 0
        menuView.close()
    end

    function self.run(dt, primaryState, secondaryState, forceBuild)
        if menuId == nil then return false end

        local hoveredTile = buildAndRender()
        showInteractionText(hoveredTile)

        if forceBuild then
            forceBuildHeldTime = forceBuildHeldTime + dt
            return true
        elseif forceBuildHeldTime > 0 then
            if forceBuildHeldTime <= tapMaxTime then
                self.close()
            end
            forceBuildHeldTime = 0
            return true
        end

        if secondaryState == 1 then
            self.close()
            return true
        end

        if primaryState == 1 and hoveredTile ~= nil then
            if hoveredTile.onSelect ~= nil then
                handleMenuEvent(hoveredTile.onSelect)
            elseif hoveredTile.action ~= nil then
                local action = hoveredTile.action
                self.close()
                tool:executeAction(action)
            end
            return true
        end

        return true
    end
end
