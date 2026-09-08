MenuRenderer = {}

function MenuRenderer.init(tool)
    tool.MenuRenderer = {}
    local self = tool.MenuRenderer
    local channels = {}

    local function getChannel(channelId)
        local channel = channels[channelId]
        if channel == nil then
            channel = {
                imageById = {},
                imageStateById = {},
                textById = {},
                textOptionsById = {}
            }
            channels[channelId] = channel
        end
        return channel
    end

    local function optionsEqual(left, right)
        if left == right then return true end
        if left == nil or right == nil then return false end
        for key, value in pairs(left) do
            if right[key] ~= value then return false end
        end
        for key, value in pairs(right) do
            if left[key] ~= value then return false end
        end
        return true
    end

    function self.render(channelId, plan)
        local channel = getChannel(channelId)
        local seenImages = {}
        local seenTexts = {}

        for _, tile in ipairs(plan.tiles or {}) do
            local imageId = channel.imageById[tile.id]
            if imageId == nil then
                imageId = tool.ImRend.new(
                    tile.origin,
                    tile.rotation,
                    tile.width,
                    tile.height,
                    tile.rectsPath,
                    tile.color
                )
                channel.imageById[tile.id] = imageId
                channel.imageStateById[tile.id] = {
                    width = tile.width,
                    height = tile.height,
                    rectsPath = tile.rectsPath,
                    color = tile.color
                }
            else
                local previous = channel.imageStateById[tile.id] or {}
                local changes = {
                    origin = tile.origin,
                    rotation = tile.rotation
                }
                if previous.width ~= tile.width then changes.width = tile.width end
                if previous.height ~= tile.height then changes.height = tile.height end
                if previous.rectsPath ~= tile.rectsPath then changes.rectsPath = tile.rectsPath end
                if previous.color ~= tile.color then
                    if tile.color ~= nil then
                        changes.color = tile.color
                    else
                        changes.clearColor = true
                    end
                end
                tool.ImRend.update(imageId, changes)
                channel.imageStateById[tile.id] = {
                    width = tile.width,
                    height = tile.height,
                    rectsPath = tile.rectsPath,
                    color = tile.color
                }
            end
            seenImages[tile.id] = true
        end

        for id, imageId in pairs(channel.imageById) do
            if not seenImages[id] then
                tool.ImRend.destroy(imageId)
                channel.imageById[id] = nil
                channel.imageStateById[id] = nil
            end
        end

        for _, text in ipairs(plan.texts or {}) do
            local textId = channel.textById[text.id]
            if textId == nil then
                textId = tool.HologramText.new(text.origin, text.rotation, text.text, text.options)
                channel.textById[text.id] = textId
                channel.textOptionsById[text.id] = text.options
            else
                local changes = {
                    origin = text.origin,
                    rotation = text.rotation,
                    text = text.text
                }
                if not optionsEqual(channel.textOptionsById[text.id], text.options) then
                    changes.options = text.options
                    channel.textOptionsById[text.id] = text.options
                end
                tool.HologramText.update(textId, changes)
            end
            seenTexts[text.id] = true
        end

        for id, textId in pairs(channel.textById) do
            if not seenTexts[id] then
                tool.HologramText.destroy(textId)
                channel.textById[id] = nil
                channel.textOptionsById[id] = nil
            end
        end
    end

    function self.clear(channelId)
        local channel = channels[channelId]
        if channel == nil then return end

        for _, imageId in pairs(channel.imageById) do
            tool.ImRend.destroy(imageId)
        end
        for _, textId in pairs(channel.textById) do
            tool.HologramText.destroy(textId)
        end
        channels[channelId] = nil
    end

    function self.clearAll()
        local channelIds = {}
        for channelId in pairs(channels) do
            channelIds[#channelIds + 1] = channelId
        end
        for _, channelId in ipairs(channelIds) do
            self.clear(channelId)
        end
    end
end
