MenuManager = {}

local plane_no_walls_uuid = sm.uuid.new("d43a391f-913d-488b-b8ac-247644b02b8b")

function MenuManager.init(tool)
    tool.MenuManager = {}
    local self = tool.MenuManager

    local menus = {}

    function self.client_onUpdate(dt)
        -- if not effectsMade then
        --     effectsMade = true
        --     id1 = tool.ImRend.new(sm.camera.getPosition() + sm.camera.getDirection() * 20, sm.camera.getRotation(),
        --         55, 55, "$CONTENT_DATA/Scripts/NewTool/images/rectangles.json")
        -- end
        -- tool.ImRend.updateOrientation(id1, sm.camera.getPosition() + sm.camera.getDirection() * 20, sm.camera.getRotation())
    end

    function self.new()
        local id = table.findFirstNil(menus)
        menus[id] = {
            elements = {},
            rotation = sm.camera.getRotation()
        }
        return id
    end

    function self.addElement(id, element)
        local menu = menus[id]
        if menu == nil then return end
        table.insert(menu.elements, element)
    end
end
