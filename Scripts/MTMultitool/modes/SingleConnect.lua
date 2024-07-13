SingleConnect = {}

function SingleConnect.inject(multitool)
    multitool.SingleConnect = {}
    multitool.SingleConnect.data = {}
    multitool.SingleConnect.data.selected = {}
end

function SingleConnect.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    multitool.ConnectionManager.displayMode = "fast"
    local self = multitool.SingleConnect
    local selfData = self.data
    if #selfData.selected < 2 then
        multitool.BlockSelector.enabled = true
    else
        multitool.BlockSelector.enabled = false
    end
    multitool.VolumeSelector.enabled = false
    if primaryState == 1 then
        if #selfData.selected < 2 then
            if lookingAt ~= nil then
                selfData.selected[#selfData.selected + 1] = lookingAt
                -- selfData.body = lookingAt:getBody()
                -- if #selfData.selected == 2 then
                --     local from = selfData.selected[1]
                --     local to = selfData.selected[2]
                --     local task = {
                --         from = from,
                --         to = to
                --     }
                --     table.insert(multitool.ConnectionManager.preview, task)
                -- end
            end
        else
            -- commit the preview
            ConnectionManager.commitPreview(multitool)
            SingleConnect.cleanUp(multitool)
        end
    end
    if #selfData.selected == 2 then
        local from = selfData.selected[1]
        local to = selfData.selected[2]
        local task = {
            from = from,
            to = to
        }
        multitool.ConnectionManager.preview = { task }
    elseif #selfData.selected == 1 then
        if lookingAt ~= nil then
            local from = selfData.selected[1]
            local to = lookingAt
            local task = {
                from = from,
                to = to
            }
            multitool.ConnectionManager.preview = { task }
        else
            multitool.ConnectionManager.preview = {}
        end
    else
        multitool.ConnectionManager.preview = {}
    end
    if secondaryState == 1 then
        if #selfData.selected > 0 then
            -- pop the last element
            table.remove(selfData.selected)
            multitool.ConnectionManager.preview = {}
        end
    end
    if #selfData.selected == 0 then
        sm.gui.setInteractionText("Select a block", sm.gui.getKeyBinding("Create", true), "Select")
    elseif #selfData.selected == 1 then
        sm.gui.setInteractionText("Select another block", sm.gui.getKeyBinding("Create", true), "Select")
    else
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("ForceBuild", true), "Toggle", "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" .. multitool.ConnectionManager.mode .. "<p>")
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Connect")
        if MTMultitool.handleForceBuild(multitool, forceBuild) then
            ConnectionManager.toggleMode(multitool)
        end
    end
    if #selfData.selected == 0 then
        multitool.BlockSelector.bodyConstraint = nil
    else
        multitool.BlockSelector.bodyConstraint = selfData.selected[1]:getBody():getCreationBodies()
    end
    -- multitool.BlockSelector.bodyConstraint = selfData.selected[1]:getCreationBodies()
    -- print(selfData.selected)
    -- print(multitool.BlockSelector.bodyConstraint)
end

function SingleConnect.client_onUpdate(multitool)
    local self = multitool.SingleConnect
    local selfData = self.data
    -- check if all shapes still exist
    for i, shape in pairs(selfData.selected) do
        if not sm.exists(shape) then
            SingleConnect.cleanUp(multitool)
        end
    end
end

function SingleConnect.createVertexSubsription(multitool)
    local self = multitool.SingleConnect
    local selfData = self.data
    local function getVertices()
        if #selfData.selected == 0 then
            return {}
        end
        local vertices = {}
        local worldPosition = selfData.selected[1]:getWorldPosition()
        table.insert(vertices, {
            pos = worldPosition,
            color = sm.color.new(1, 1, 1, 1),
            txt = "<[  ]>"
        })
        if #selfData.selected == 1 then
            return vertices
        end
        worldPosition = selfData.selected[2]:getWorldPosition()
        table.insert(vertices, {
            pos = worldPosition,
            color = sm.color.new(1, 1, 1, 1),
            txt = ">[  ]<"
        })
        return vertices
    end
    return getVertices
end

function SingleConnect.cleanUp(multitool)
    local self = multitool.SingleConnect
    self.data.body = nil
    self.data.selected = {}
    multitool.BlockSelector.bodyConstraint = nil
    multitool.ConnectionManager.preview = {}
end