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
    function self.new(origin, rotation, width, height, rectsPath)
        local id
        local rectData = getRectData(rectsPath)
        local image
        if #self.unusedIds > 0 then
            id = table.remove(self.unusedIds)
            image = self.images[id]
            image.origin = origin
            image.rotation = rotation
            image.width = width
            image.height = height
            image.rectsPath = rectsPath
        else
            id = getNewId()
            image = {
                origin = origin,
                rotation = rotation,
                width = width,
                height = height,
                rectsPath = rectsPath,
                effects = {}
            }
            self.images[id] = image
        end
        while #self.images[id].effects < rectData.n do
            local effect = sm.effect.createEffect("ShapeRenderable")
            effect:setParameter("uuid", plane_no_walls_uuid)
            image.effects[#image.effects + 1] = effect
        end
        local xFitScale = width / rectData.w
        local yFitScale = height / rectData.h
        local fitScale = math.min(xFitScale, yFitScale)
        local imageRotation = rotation * sm.quat.fromEuler(sm.vec3.new(0, 0, -90))
        for index = 1, rectData.n do
            local effect = self.images[id].effects[index]
            local x = rectData.rects[index * 6 - 5]
            local y = rectData.rects[index * 6 - 4]
            local z = rectData.rects[index * 6 - 3]
            local w = rectData.rects[index * 6 - 2]
            local h = rectData.rects[index * 6 - 1]
            local c = rectData.rects[index * 6]
            local color = rectData.palette[c + 1]
            local localOffset = sm.vec3.new(z * 0.0005, (x + w / 2 - rectData.w / 2) * fitScale,
                (y + h / 2 - rectData.h / 2) * -fitScale)
            effect:setScale(sm.vec3.new(1, w * fitScale * 100, h * fitScale * 100))
            effect:setPosition(origin + imageRotation * localOffset)
            effect:setRotation(imageRotation)
            effect:setParameter("color", color)
            effect:start()
        end
        return id
    end

    function self.updateOrigin(id, origin)
        local image = self.images[id]
        if image == nil then return end
        image.origin = origin
        local rectData = getRectData(image.rectsPath)
        local xFitScale = image.width / rectData.w
        local yFitScale = image.height / rectData.h
        local fitScale = math.min(xFitScale, yFitScale)
        local imageRotation = image.rotation * sm.quat.fromEuler(sm.vec3.new(0, 0, -90))
        for index = 1, rectData.n do
            local effect = self.images[id].effects[index]
            local x = rectData.rects[index * 6 - 5]
            local y = rectData.rects[index * 6 - 4]
            local z = rectData.rects[index * 6 - 3]
            local w = rectData.rects[index * 6 - 2]
            local h = rectData.rects[index * 6 - 1]
            local localOffset = sm.vec3.new(z * 0.0005, (x + w / 2 - rectData.w / 2) * fitScale,
            (y + h / 2 - rectData.h / 2) * -fitScale)
            effect:setPosition(origin + imageRotation * localOffset)
        end
    end

    function self.updateOrientation(id, origin, rotation)
        local image = self.images[id]
        if image == nil then return end
        image.origin = origin
        image.rotation = rotation
        local rectData = getRectData(image.rectsPath)
        local xFitScale = image.width / rectData.w
        local yFitScale = image.height / rectData.h
        local fitScale = math.min(xFitScale, yFitScale)
        local imageRotation = rotation * sm.quat.fromEuler(sm.vec3.new(0, 0, -90))
        for index = 1, rectData.n do
            local effect = self.images[id].effects[index]
            local x = rectData.rects[index * 6 - 5]
            local y = rectData.rects[index * 6 - 4]
            local z = rectData.rects[index * 6 - 3]
            local w = rectData.rects[index * 6 - 2]
            local h = rectData.rects[index * 6 - 1]
            local localOffset = sm.vec3.new(z * 0.0005, (x + w / 2 - rectData.w / 2) * fitScale,
            (y + h / 2 - rectData.h / 2) * -fitScale)
            effect:setPosition(origin + imageRotation * localOffset)
            effect:setRotation(imageRotation)
        end
    end

    function self.destroy(id)
        if table.contains(self.unusedIds, id) then
            print("error: self.unusedIds contains id", self.unusedIds, id)
            return
        end
        if self.images[id] == nil then
            print("error: self.images[id] == nil", self.images, id, self.images[id])
            return
        end
        for _, effect in ipairs(self.images[id].effects) do
            effect:stop()
        end
        table.insert(self.unusedIds, id)
    end
end
