dofile "../util/util.lua"

ImRend = {}

local plane_no_walls_uuid = sm.uuid.new("d43a391f-913d-488b-b8ac-247644b02b8b")

function ImRend.init(tool)
    tool.ImRend = {}
    local self = tool.ImRend
    self.images = {}
    local nextId = 1

    self.rect_data = {}

    local function getNewId()
        local newId = nextId
        nextId = nextId + 1
        return newId
    end

    local function getRectData(rectsPath)
        if self.rect_data[rectsPath] == nil then
            local data = sm.json.open(rectsPath)
            local parsed = {
                w = data.width,
                h = data.height,
                l = data.layer_count,
                n = #data.rectangles,
                palette = {},
                rects = {}
            }
            for _, color in ipairs(data.color_palette) do
                table.insert(parsed.palette, sm.color.new(color[1] / 255, color[2] / 255, color[3] / 255))
            end
            for _, rect in ipairs(data.rectangles) do
                table.insert(parsed.rects, rect.x)
                table.insert(parsed.rects, rect.y)
                table.insert(parsed.rects, rect.z)
                table.insert(parsed.rects, rect.w)
                table.insert(parsed.rects, rect.h)
                table.insert(parsed.rects, rect.c)
            end
            self.rect_data[rectsPath] = parsed
        end
        return self.rect_data[rectsPath]
    end

    self.unusedIds = {}
    function self.new(origin, orientation, width, height, rectsPath)
        local id
        local rectData = getRectData(rectsPath)
        local image
        if #self.unusedIds > 0 then
            id = table.remove(self.unusedIds)
            image = self.images[id]
            image.origin = origin
            image.orientation = orientation
            image.width = width
            image.height = height
            image.rects_path = rectsPath
        else
            id = getNewId()
            image = {
                origin = origin,
                orientation = orientation,
                width = width,
                height = height,
                rects_path = rectsPath,
                effects = {}
            }
            self.images[id] = image
        end
        local numPixels = rectData.w * rectData.h
        while #self.images[id].effects < numPixels do
            local effect = sm.effect.createEffect("ShapeRenderable")
            effect:setParameter("uuid", plane_no_walls_uuid)
            image.effects[#image.effects + 1] = effect
        end
        local xFitScale = width / rectData.w
        local yFitScale = height / rectData.h
        local fitScale = math.min(xFitScale, yFitScale)
        for index = 1, rectData.n do
            local effect = self.images[id].effects[index]
            local x = rectData.rects[index * 6 - 5]
            local y = rectData.rects[index * 6 - 4]
            local z = rectData.rects[index * 6 - 3]
            local w = rectData.rects[index * 6 - 2]
            local h = rectData.rects[index * 6 - 1]
            local c = rectData.rects[index * 6]
            print(x, y, z, w, h, c)
            local color = rectData.palette[c + 1]
            effect:setScale(sm.vec3.new(1, w * fitScale * 100, h * fitScale * 100))
            effect:setPosition(origin + sm.vec3.new(z * 0.0001, (x + w / 2) * fitScale, (y + h / 2) * -fitScale))
            -- effect:setRotation(orientation)
            effect:setParameter("color", color)
            effect:start()
        end
        return id
    end
end
