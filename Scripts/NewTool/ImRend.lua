dofile "../util/util.lua"

ImRend = {}

local plane_no_walls_uuid = sm.uuid.new("d43a391f-913d-488b-b8ac-247644b02b8b")
local render_rotation_offset = sm.quat.fromEuler(sm.vec3.new(0, 0, -90))

function ImRend.init(tool)
    tool.ImRend = {}
    local self = tool.ImRend
    self.images = {}
    self.rect_data = {}
    self.unusedIds = {}

    local nextId = 1

    local function getNewId()
        local newId = nextId
        nextId = nextId + 1
        return newId
    end

    local function getRectData(rectsPath)
        local cached = self.rect_data[rectsPath]
        if cached ~= nil then return cached end

        local data = sm.json.open(rectsPath)
        local palette = {}
        for _, color in ipairs(data.color_palette) do
            palette[#palette + 1] = sm.color.new(color[1] / 255, color[2] / 255, color[3] / 255)
        end

        local parsed = {
            w = data.width,
            h = data.height,
            l = data.layer_count,
            n = #data.rectangles,
            x = {},
            y = {},
            z = {},
            wRect = {},
            hRect = {},
            color = {}
        }

        local halfWidth = data.width / 2
        local halfHeight = data.height / 2
        for index, rect in ipairs(data.rectangles) do
            parsed.x[index] = rect.x + rect.w / 2 - halfWidth
            parsed.y[index] = -(rect.y + rect.h / 2 - halfHeight)
            parsed.z[index] = rect.z * 0.0005
            parsed.wRect[index] = rect.w
            parsed.hRect[index] = rect.h
            parsed.color[index] = palette[rect.c + 1]
        end

        self.rect_data[rectsPath] = parsed
        return parsed
    end

    local function ensureEffects(image, count)
        while #image.effects < count do
            local effect = sm.effect.createEffect("ShapeRenderable")
            effect:setParameter("uuid", plane_no_walls_uuid)
            image.effects[#image.effects + 1] = effect
        end
    end

    local function stopEffectsAfter(image, count)
        for index = count + 1, #image.effects do
            image.effects[index]:stop()
        end
    end

    local function syncImage(image, updatePosition, updateRotation, updateScale, updateColor, startEffects)
        local rectData = image.rectData
        local fitScale = math.min(image.width / rectData.w, image.height / rectData.h)
        local imageRotation = image.rotation * render_rotation_offset
        local origin = image.origin
        local effects = image.effects

        for index = 1, rectData.n do
            local effect = effects[index]

            if updateScale then
                effect:setScale(sm.vec3.new(1, rectData.wRect[index] * fitScale * 100, rectData.hRect[index] * fitScale * 100))
            end

            if updatePosition then
                local localOffset = sm.vec3.new(
                    rectData.z[index],
                    rectData.x[index] * fitScale,
                    rectData.y[index] * fitScale
                )
                effect:setPosition(origin + imageRotation * localOffset)
            end

            if updateRotation then
                effect:setRotation(imageRotation)
            end

            if updateColor then
                effect:setParameter("color", rectData.color[index])
            end

            if startEffects then
                effect:start()
            end
        end
    end

    local function recycleOrCreateImage(origin, rotation, width, height, rectsPath, rectData)
        local id
        local image

        if #self.unusedIds > 0 then
            id = table.remove(self.unusedIds)
            image = self.images[id]
            image.origin = origin
            image.rotation = rotation
            image.width = width
            image.height = height
            image.rectsPath = rectsPath
            image.rectData = rectData
        else
            id = getNewId()
            image = {
                origin = origin,
                rotation = rotation,
                width = width,
                height = height,
                rectsPath = rectsPath,
                rectData = rectData,
                effects = {}
            }
            self.images[id] = image
        end

        ensureEffects(image, rectData.n)
        return id, image
    end

    function self.new(origin, rotation, width, height, rectsPath)
        local rectData = getRectData(rectsPath)
        local id, image = recycleOrCreateImage(origin, rotation, width, height, rectsPath, rectData)
        syncImage(image, true, true, true, true, true)
        return id
    end

    -- Batched update API. Prefer this when multiple properties change; it does one rect pass.
    function self.update(id, changes)
        local image = self.images[id]
        if image == nil then return end

        local updatePosition = false
        local updateRotation = false
        local updateScale = false
        local updateColor = false

        if changes.origin ~= nil then
            image.origin = changes.origin
            updatePosition = true
        end

        if changes.rotation ~= nil then
            image.rotation = changes.rotation
            updatePosition = true
            updateRotation = true
        end

        if changes.width ~= nil then
            image.width = changes.width
            updatePosition = true
            updateScale = true
        end

        if changes.height ~= nil then
            image.height = changes.height
            updatePosition = true
            updateScale = true
        end

        if changes.rectsPath ~= nil and changes.rectsPath ~= image.rectsPath then
            image.rectsPath = changes.rectsPath
            image.rectData = getRectData(changes.rectsPath)
            ensureEffects(image, image.rectData.n)
            stopEffectsAfter(image, image.rectData.n)
            updatePosition = true
            updateRotation = true
            updateScale = true
            updateColor = true
        end

        if changes.size ~= nil then
            image.width = changes.size[1] or changes.size.width or image.width
            image.height = changes.size[2] or changes.size.height or image.height
            updatePosition = true
            updateScale = true
        end

        if updatePosition or updateRotation or updateScale or updateColor then
            syncImage(image, updatePosition, updateRotation, updateScale, updateColor, false)
        end
    end

    function self.updateOrigin(id, origin)
        self.update(id, { origin = origin })
    end

    function self.updateOrientation(id, origin, rotation)
        self.update(id, { origin = origin, rotation = rotation })
    end

    function self.updateSize(id, width, height)
        self.update(id, { width = width, height = height })
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
