Menu = {}

local plane_no_walls_uuid = sm.uuid.new("d43a391f-913d-488b-b8ac-247644b02b8b")

function Menu.init(tool)
    tool.Menu = {}
    local self = tool.Menu

    local effectsMade = false
    -- self.origin = nil
    -- self.startTime = nil
    local id1

    function self.client_onUpdate(dt)
        if not effectsMade then
            effectsMade = true
            id1 = tool.ImRend.new(sm.camera.getPosition() + sm.camera.getDirection() * 20, sm.camera.getRotation(),
                55, 55, "$CONTENT_DATA/Scripts/NewTool/images/rectangles.json")
        end
        tool.ImRend.updateOrientation(id1, sm.camera.getPosition() + sm.camera.getDirection() * 20, sm.camera.getRotation())
    end
end
