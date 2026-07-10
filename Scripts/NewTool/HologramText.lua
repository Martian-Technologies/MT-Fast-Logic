HologramText = {}

local glyphPoolPath = "$CONTENT_DATA/Scripts/NewTool/text/generated/glyph_pool.json"

function HologramText.init(tool)
    tool.HologramText = {}
    local self = tool.HologramText

    local glyphPool = sm.json.open(glyphPoolPath)
    local glyphs = glyphPool.glyphs or {}
    local fallbackKey = glyphPool.fallback or "003F"
    local fallbackGlyph = glyphs[fallbackKey]
    local cellWidth = glyphPool.cell_width
    local cellHeight = glyphPool.cell_height
    local compiledCache = {}
    local rectDataCache = {}
    local missingGlyphs = {}
    local blocks = {}
    local unusedIds = {}
    local nextId = 1
    local defaultColor = sm.color.new(1, 1, 1)

    local function allocId()
        if #unusedIds > 0 then
            return table.remove(unusedIds)
        end
        local id = nextId
        nextId = nextId + 1
        return id
    end

    local function utf8Chars(text)
        local chars = {}
        local index = 1
        local length = #text
        while index <= length do
            local b1 = string.byte(text, index)
            local bytes = 1
            local codepoint = b1

            if b1 >= 0xF0 then
                local b2, b3, b4 = string.byte(text, index + 1, index + 3)
                if b2 ~= nil and b3 ~= nil and b4 ~= nil then
                    bytes = 4
                    codepoint = (b1 - 0xF0) * 0x40000 + (b2 - 0x80) * 0x1000 + (b3 - 0x80) * 0x40 + (b4 - 0x80)
                end
            elseif b1 >= 0xE0 then
                local b2, b3 = string.byte(text, index + 1, index + 2)
                if b2 ~= nil and b3 ~= nil then
                    bytes = 3
                    codepoint = (b1 - 0xE0) * 0x1000 + (b2 - 0x80) * 0x40 + (b3 - 0x80)
                end
            elseif b1 >= 0xC0 then
                local b2 = string.byte(text, index + 1)
                if b2 ~= nil then
                    bytes = 2
                    codepoint = (b1 - 0xC0) * 0x40 + (b2 - 0x80)
                end
            end

            chars[#chars + 1] = {
                text = string.sub(text, index, index + bytes - 1),
                codepoint = codepoint,
                key = string.format("%04X", codepoint)
            }
            index = index + bytes
        end
        return chars
    end

    local function charCount(text)
        return #utf8Chars(text)
    end

    local function utf8Sub(text, firstChar, lastChar)
        local chars = utf8Chars(text)
        local out = {}
        lastChar = math.min(lastChar or #chars, #chars)
        for index = firstChar, lastChar do
            if chars[index] ~= nil then out[#out + 1] = chars[index].text end
        end
        return table.concat(out)
    end

    local function splitLongWord(word, maxColumns)
        local count = charCount(word)
        local parts = {}
        local start = 1
        while start <= count do
            parts[#parts + 1] = utf8Sub(word, start, start + maxColumns - 1)
            start = start + maxColumns
        end
        if #parts == 0 then parts[1] = "" end
        return parts
    end

    local function wrapText(text, maxColumns, maxLines)
        if maxColumns <= 0 or maxLines <= 0 then return {} end
        local lines = {}
        text = string.gsub(string.gsub(text, "\r\n", "\n"), "\r", "\n")

        local paragraphStart = 1
        while paragraphStart <= #text + 1 do
            local newlineStart, newlineEnd = string.find(text, "\n", paragraphStart, true)
            local paragraph
            if newlineStart ~= nil then
                paragraph = string.sub(text, paragraphStart, newlineStart - 1)
                paragraphStart = newlineEnd + 1
            else
                paragraph = string.sub(text, paragraphStart)
                paragraphStart = #text + 2
            end

            local words = {}
            for word in string.gmatch(paragraph, "%S+") do
                words[#words + 1] = word
            end

            if #words == 0 then
                lines[#lines + 1] = ""
                if #lines >= maxLines then return lines end
            else
                local current = ""
                for _, word in ipairs(words) do
                    local wordParts
                    if charCount(word) > maxColumns then
                        wordParts = splitLongWord(word, maxColumns)
                    else
                        wordParts = { word }
                    end

                    for _, part in ipairs(wordParts) do
                        if current == "" then
                            current = part
                        elseif charCount(current) + 1 + charCount(part) <= maxColumns then
                            current = current .. " " .. part
                        else
                            lines[#lines + 1] = current
                            if #lines >= maxLines then return lines end
                            current = part
                        end
                    end
                end

                if current ~= "" then
                    lines[#lines + 1] = current
                    if #lines >= maxLines then return lines end
                end
            end
        end

        return lines
    end

    local function getGlyph(char)
        local glyph = glyphs[char.key]
        if glyph ~= nil then return glyph end

        if missingGlyphs[char.key] == nil then
            missingGlyphs[char.key] = true
            print("HologramText missing glyph U+" .. tostring(char.key) .. " (" .. tostring(char.text) .. ")")
        end
        return fallbackGlyph
    end

    local function addRowRuns(rects, active, row, y, width)
        local currentActive = {}
        local x = 1
        while x <= width do
            if not row[x] then
                x = x + 1
            else
                local start = x
                while x <= width and row[x] do
                    x = x + 1
                end
                local runWidth = x - start
                local key = tostring(start) .. ":" .. tostring(runWidth)
                local prev = active[key]
                if prev ~= nil and prev[2] + prev[4] == y - 1 then
                    prev[4] = prev[4] + 1
                    currentActive[key] = prev
                else
                    local rect = { start - 1, y - 1, runWidth, 1 }
                    rects[#rects + 1] = rect
                    currentActive[key] = rect
                end
            end
        end
        return currentActive
    end

    local function compilePayload(text, layout)
        local maxColumns = layout.max_columns or layout.maxColumns or 32
        local maxLines = layout.max_lines or layout.maxLines or 1
        local align = layout.align or "left"
        local lines = wrapText(tostring(text or ""), maxColumns, maxLines)
        local width = maxColumns * cellWidth
        local height = math.max(maxLines, 1) * cellHeight
        local rects = {}
        local active = {}

        for y = 1, height do
            local row = {}
            local lineIndex = math.floor((y - 1) / cellHeight) + 1
            local glyphY = ((y - 1) % cellHeight) + 1
            local line = lines[lineIndex]

            if line ~= nil then
                local chars = utf8Chars(line)
                local lineLength = math.min(#chars, maxColumns)
                local cellOffset = 0
                if align == "center" then
                    cellOffset = math.max(math.floor((maxColumns - lineLength) / 2), 0)
                elseif align == "right" then
                    cellOffset = math.max(maxColumns - lineLength, 0)
                end

                for charIndex = 1, lineLength do
                    local glyph = getGlyph(chars[charIndex])
                    local glyphRow = glyph and glyph.rows and glyph.rows[glyphY]
                    if glyphRow ~= nil then
                        local x0 = (cellOffset + charIndex - 1) * cellWidth
                        for glyphX = 1, cellWidth do
                            if string.sub(glyphRow, glyphX, glyphX) == "1" then
                                row[x0 + glyphX] = true
                            end
                        end
                    end
                end
            end

            active = addRowRuns(rects, active, row, y, width)
        end

        return { w = width, h = height, r = rects }
    end

    local function getLayout(options)
        options = options or {}
        return {
            max_columns = options.maxColumns or options.max_columns or 32,
            max_lines = options.maxLines or options.max_lines or 1,
            align = options.align or "left"
        }
    end

    local function getBackgroundPadding(options)
        options = options or {}
        local padding = options.backgroundPadding or 0
        return options.backgroundPaddingX or padding, options.backgroundPaddingY or padding
    end

    local function colorKey(color)
        if color == nil then return "default" end
        return tostring(color.r) .. "," .. tostring(color.g) .. "," .. tostring(color.b)
    end

    local function cacheKey(text, layout, options)
        local backgroundKey = options and options.background and "bg" or "plain"
        local fitKey = options and options.fitBackground and "fit" or "fixed"
        local paddingX, paddingY = getBackgroundPadding(options)
        local foregroundKey = options and options.background and colorKey(options.color) or ""
        local backgroundColorKey = options and options.background and colorKey(options.backgroundColor) or ""
        return tostring(layout.max_columns) .. "\31" .. tostring(layout.max_lines) .. "\31" .. tostring(layout.align) .. "\31" .. backgroundKey .. "\31" .. fitKey .. "\31" .. tostring(paddingX) .. "\31" .. tostring(paddingY) .. "\31" .. foregroundKey .. "\31" .. backgroundColorKey .. "\31" .. tostring(text)
    end

    local function getPayloadBounds(payload, options)
        local paddingX, paddingY = getBackgroundPadding(options)
        local minX = payload.w or 0
        local minY = payload.h or 0
        local maxX = 0
        local maxY = 0

        for _, rect in ipairs(payload.r or {}) do
            local x = rect[1]
            local y = rect[2]
            local w = rect[3]
            local h = rect[4]
            minX = math.min(minX, x)
            minY = math.min(minY, y)
            maxX = math.max(maxX, x + w)
            maxY = math.max(maxY, y + h)
        end

        if maxX <= minX or maxY <= minY then
            return {
                x = -paddingX,
                y = -paddingY,
                w = math.max(cellWidth + paddingX * 2, 1),
                h = math.max(cellHeight + paddingY * 2, 1)
            }
        end

        return {
            x = minX - paddingX,
            y = minY - paddingY,
            w = math.max(maxX - minX + paddingX * 2, 1),
            h = math.max(maxY - minY + paddingY * 2, 1)
        }
    end

    local function cropPayload(payload, bounds)
        if bounds == nil then return payload end

        local croppedRects = {}
        local cropRight = bounds.x + bounds.w
        local cropBottom = bounds.y + bounds.h

        for _, rect in ipairs(payload.r or {}) do
            local x = rect[1]
            local y = rect[2]
            local w = rect[3]
            local h = rect[4]
            local left = math.max(x, bounds.x)
            local top = math.max(y, bounds.y)
            local right = math.min(x + w, cropRight)
            local bottom = math.min(y + h, cropBottom)

            if right > left and bottom > top then
                local croppedRect = { left - bounds.x, top - bounds.y, right - left, bottom - top }
                if rect[5] ~= nil then croppedRect[5] = rect[5] end
                if rect[6] ~= nil then croppedRect[6] = rect[6] end
                croppedRects[#croppedRects + 1] = croppedRect
            end
        end

        return {
            w = bounds.w,
            h = bounds.h,
            r = croppedRects
        }
    end

    local function paletteColor(color, fallback)
        color = color or fallback
        return {
            math.floor(math.max(0, math.min(color.r, 1)) * 255 + 0.5),
            math.floor(math.max(0, math.min(color.g, 1)) * 255 + 0.5),
            math.floor(math.max(0, math.min(color.b, 1)) * 255 + 0.5)
        }
    end

    local function withBackground(payload, bounds, options)
        payload = cropPayload(payload, bounds)
        local rects = {
            { 0, 0, payload.w, payload.h, 0, 0 }
        }
        for _, rect in ipairs(payload.r or {}) do
            rects[#rects + 1] = { rect[1], rect[2], rect[3], rect[4], 1, 1 }
        end
        return {
            w = payload.w,
            h = payload.h,
            color_palette = {
                paletteColor(options and options.backgroundColor, sm.color.new(0, 0, 0)),
                paletteColor(options and options.color, defaultColor)
            },
            r = rects
        }
    end

    local function getPayload(text, layout, options)
        local key = cacheKey(text, layout, options)
        local cached = compiledCache[key]
        if cached ~= nil then return cached end

        local useBackground = options ~= nil and options.background
        local basePayload = compilePayload(text, layout)

        if useBackground then
            local bounds = nil
            if options.fitBackground then
                bounds = getPayloadBounds(basePayload, options)
            end
            cached = withBackground(basePayload, bounds, options)
        else
            cached = basePayload
        end
        compiledCache[key] = cached
        return cached
    end

    local function getRectData(text, options)
        local layout = getLayout(options)
        local key = cacheKey(text, layout, options)
        local cachedRectData = rectDataCache[key]
        if cachedRectData ~= nil then return cachedRectData, layout end

        local payload = getPayload(text, layout, options)
        cachedRectData = tool.ImRend.makeRectData(payload)
        rectDataCache[key] = cachedRectData
        return cachedRectData, layout
    end

    local function getWorldSize(rectData, cellWorldHeight)
        local pixelWorldSize = (cellWorldHeight or 0.2) / cellHeight
        return rectData.w * pixelWorldSize, rectData.h * pixelWorldSize
    end

    local function applyBlock(block, changes)
        local update = {}
        local textChanged = false
        local sizeChanged = false

        if changes.text ~= nil and changes.text ~= block.text then
            block.text = changes.text
            textChanged = true
        end
        if changes.options ~= nil then
            block.options = changes.options
            textChanged = true
            sizeChanged = true
        end
        if changes.cellHeight ~= nil and changes.cellHeight ~= block.cellHeight then
            block.cellHeight = changes.cellHeight
            sizeChanged = true
        end
        if changes.origin ~= nil then update.origin = changes.origin end
        if changes.rotation ~= nil then update.rotation = changes.rotation end
        if changes.color ~= nil then update.color = changes.color end

        if textChanged then
            block.rectData = getRectData(block.text, block.options)
            update.rectData = block.rectData
        end

        if textChanged or sizeChanged then
            local width, height = getWorldSize(block.rectData, block.cellHeight)
            update.size = { width, height }
        end

        tool.ImRend.update(block.imageId, update)
    end

    function self.measure(text, options)
        options = options or {}
        local rectData = getRectData(text, options)
        local cellWorldHeight = options.cellHeight or 0.2
        local width, height = getWorldSize(rectData, cellWorldHeight)
        return { width = width, height = height }
    end

    function self.new(origin, rotation, text, options)
        options = options or {}
        local id = allocId()
        local rectData = getRectData(text, options)
        local cellWorldHeight = options.cellHeight or 0.2
        local width, height = getWorldSize(rectData, cellWorldHeight)
        local color = nil
        if not options.background then
            color = options.color or defaultColor
        end
        local imageId = tool.ImRend.newData(origin, rotation, width, height, rectData, color)

        blocks[id] = {
            imageId = imageId,
            text = text,
            options = options,
            rectData = rectData,
            cellHeight = cellWorldHeight
        }
        return id
    end

    function self.update(id, changes)
        local block = blocks[id]
        if block == nil then return end
        applyBlock(block, changes or {})
    end

    function self.destroy(id)
        local block = blocks[id]
        if block == nil then return end
        tool.ImRend.destroy(block.imageId)
        blocks[id] = nil
        unusedIds[#unusedIds + 1] = id
    end

    function self.getDefaultColor()
        return defaultColor
    end
end
