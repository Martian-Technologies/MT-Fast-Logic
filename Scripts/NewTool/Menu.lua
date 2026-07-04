Menu = {}

local plane_no_walls_uuid = sm.uuid.new("d43a391f-913d-488b-b8ac-247644b02b8b")

function Menu.init(tool)
    tool.Menu = {}
    local self = tool.Menu

    local effectsMade = false
    -- self.origin = nil
    -- self.startTime = nil

    function self.client_onUpdate(dt)
        if not effectsMade then
            effectsMade = true
            -- self.startTime = os.clock()
            -- self.origin = sm.camera.getPosition()
            -- self.effects = {}
            -- local data = sm.json.open("$CONTENT_DATA/Scripts/NewTool/images/rectangles.json")
            -- local rectangles = data.rectangles
            -- for _, rectangle in ipairs(rectangles) do
            --     local effect = sm.effect.createEffect("ShapeRenderable")
            --     local color = sm.color.new(rectangle.rgb[1] / 255, rectangle.rgb[2] / 255, rectangle.rgb[3] / 255)
            --     effect:setParameter("uuid", plane_no_walls_uuid)
            --     effect:setScale(sm.vec3.new(1, rectangle.w, rectangle.h))
            --     effect:setPosition(self.origin +
            --         sm.vec3.new(rectangle.z * 0.01 + 1000, (rectangle.x + rectangle.w / 2) * 0.01,
            --             (rectangle.y + rectangle.h / 2) * -0.01))
            --     effect:setParameter("color", color)
            --     effect:start()
            --     table.insert(self.effects, {
            --         eff = effect,
            --         x = (rectangle.x + rectangle.w / 2) * 0.01,
            --         y = (rectangle.y + rectangle.h / 2) * -0.01,
            --         z = rectangle.z,
            --     })
            -- end
            local id = tool.ImRend.new(sm.camera.getPosition(), sm.camera.getRotation(), 1, 1, "$CONTENT_DATA/Scripts/NewTool/images/rectangles.json")
        end
        -- local elapsed = os.clock() - self.startTime
        -- for _, eff in ipairs(self.effects) do
        --     local effect = eff.eff
        --     effect:setPosition(self.origin + sm.vec3.new(math.max(eff.z * 0.0001 - 1, 10-elapsed * 3 + eff.z * 0.2), eff.x, eff.y))
        -- end
    end
end