MenuLayout = {}

MenuLayout.defaults = {
    menuDistance = 18,
    hoverDistanceScale = 0.75,
    hoverDirectionLerp = 0.9,
    slots = {
        left = { x = -4.0, y = 0, maxWidth = 6.0, maxHeight = 16.0 },
        right = { x = 2.75, y = 0, maxWidth = 8.0, maxHeight = 25.0 }
    },
    tileSizes = {
        goal = {
            iconSize = 1.75,
            labelLayoutId = "hub_label",
            labelCellHeight = 0.6,
            labelGap = 0.05,
            itemGap = 0.15,
            labelWidth = 2.8,
            labelHeight = 0.6
        },
        action = {
            iconSize = 3.0,
            labelLayoutId = "hub_label",
            labelCellHeight = 0.7,
            labelGap = 0.15,
            itemGap = 0.25,
            labelWidth = 3.6,
            labelHeight = 0.7
        }
    }
}

local validDirections = { vertical = true, horizontal = true }
local validSwitcherAlign = { top = true, center = true, bottom = true }
local validateWidget = nil
local layoutWidget = nil

local function fail(message)
    local fullMessage = "MenuLayout validation failed: " .. tostring(message)
    print(fullMessage)
    error(fullMessage)
end

local function getTileSize(tileSizeName)
    local tileSize = MenuLayout.defaults.tileSizes[tileSizeName]
    if tileSize == nil then
        fail("unknown tile size '" .. tostring(tileSizeName) .. "'")
    end
    return tileSize
end

local function getIconWidth(tileSize)
    return tileSize.iconWidth or tileSize.iconSize or 0
end

local function getIconHeight(tileSize)
    return tileSize.iconHeight or tileSize.iconSize or 0
end

local function getStackItemGap(widget, tileSize)
    if widget.itemGap ~= nil then return widget.itemGap end
    return tileSize.itemGap or 0
end

local function getItemId(item)
    return item.id or item.actionId or item.child
end

local function resolveActionItem(item)
    if item.actionId == nil then return item end

    local action = NewToolActionRegistry.get(item.actionId)
    if action == nil then
        fail("unknown actionId '" .. tostring(item.actionId) .. "'")
    end

    return {
        id = item.id or item.actionId,
        label = item.label or action.label,
        description = item.description or action.description,
        icon = item.icon or action.icon,
        selectedIcon = item.selectedIcon or action.selectedIcon,
        action = { type = "registered", id = item.actionId }
    }
end

local function getLabelOptions(tileSize)
    return {
        layoutId = tileSize.labelLayoutId,
        cellHeight = tileSize.labelCellHeight,
        background = true
    }
end

local function measureLabel(text, tileSize, textMeasurer)
    if text == nil or tileSize.labelLayoutId == false then
        return { width = 0, height = 0, options = nil }
    end

    local options = getLabelOptions(tileSize)
    if textMeasurer ~= nil and textMeasurer.measure ~= nil then
        local measured = textMeasurer.measure(tostring(text), options)
        if measured ~= nil then
            return {
                width = measured.width or measured[1] or 0,
                height = measured.height or measured[2] or 0,
                options = options
            }
        end
    end

    return {
        width = tileSize.labelWidth or getIconWidth(tileSize),
        height = tileSize.labelHeight or 0,
        options = options
    }
end

local function measureTile(stackWidget, rawItem, textMeasurer)
    local item = resolveActionItem(rawItem)
    local tileSize = getTileSize(stackWidget.tileSize)
    local iconWidth = getIconWidth(tileSize)
    local iconHeight = getIconHeight(tileSize)
    local label = measureLabel(item.label, tileSize, textMeasurer)
    local labelGap = 0
    if label.height > 0 then labelGap = tileSize.labelGap or 0 end

    return {
        item = item,
        iconWidth = iconWidth,
        iconHeight = iconHeight,
        label = label,
        labelGap = labelGap,
        width = math.max(iconWidth, label.width),
        height = iconHeight + labelGap + label.height
    }
end

local function measureTileStackDetailed(widget, textMeasurer)
    local tileSize = getTileSize(widget.tileSize)
    local items = widget.items or {}
    local count = #items
    local itemGap = getStackItemGap(widget, tileSize)
    local tiles = {}

    if count == 0 then
        return { width = 0, height = 0, tiles = tiles, itemGap = itemGap }
    end

    local main = 0
    local cross = 0
    for index, rawItem in ipairs(items) do
        local tile = measureTile(widget, rawItem, textMeasurer)
        tiles[index] = tile

        if widget.direction == "horizontal" then
            main = main + tile.width
            cross = math.max(cross, tile.height)
        else
            main = main + tile.height
            cross = math.max(cross, tile.width)
        end
    end

    main = main + (count - 1) * itemGap

    if widget.direction == "horizontal" then
        return { width = main, height = cross, tiles = tiles, itemGap = itemGap }
    end

    return { width = cross, height = main, tiles = tiles, itemGap = itemGap }
end

local function measureTileStack(widget, textMeasurer)
    local stack = measureTileStackDetailed(widget, textMeasurer)
    return { width = stack.width, height = stack.height }
end

local function measureWidget(widget, textMeasurer)
    if widget.kind == "tileStack" then
        return measureTileStack(widget, textMeasurer)
    end

    if widget.kind == "switcher" then
        local maxWidth = 0
        local maxHeight = 0
        for _, child in pairs(widget.children or {}) do
            local size = measureWidget(child, textMeasurer)
            maxWidth = math.max(maxWidth, size.width)
            maxHeight = math.max(maxHeight, size.height)
        end
        return { width = maxWidth, height = maxHeight }
    end

    fail("unknown widget kind '" .. tostring(widget.kind) .. "'")
end

local function validateNonNegativeNumber(value, path)
    if value == nil then return end
    if type(value) ~= "number" or value < 0 then
        fail(path .. " must be a non-negative number")
    end
end

local function validateTileStack(widget, path)
    if widget.id == nil then fail(path .. " is missing id") end
    if widget.direction == nil or not validDirections[widget.direction] then
        fail(path .. " has invalid direction '" .. tostring(widget.direction) .. "'")
    end
    if widget.tileSize == nil then fail(path .. " is missing tileSize") end
    local tileSize = getTileSize(widget.tileSize)
    validateNonNegativeNumber(widget.itemGap, path .. ".itemGap")
    validateNonNegativeNumber(tileSize.itemGap, "tileSize '" .. tostring(widget.tileSize) .. "'.itemGap")
    validateNonNegativeNumber(tileSize.labelGap, "tileSize '" .. tostring(widget.tileSize) .. "'.labelGap")
    if widget.items == nil then fail(path .. " is missing items") end

    local itemIds = {}
    for index, rawItem in ipairs(widget.items) do
        local item = resolveActionItem(rawItem)
        local itemId = getItemId(item)
        if itemId == nil then
            fail(path .. ".items[" .. tostring(index) .. "] is missing id or actionId")
        end
        if itemIds[itemId] then
            fail(path .. ".items[" .. tostring(index) .. "] duplicates item id '" .. tostring(itemId) .. "'")
        end
        itemIds[itemId] = true
        if item.label == nil then
            fail(path .. ".items[" .. tostring(index) .. "] is missing label")
        end
        if item.icon == nil then
            fail(path .. ".items[" .. tostring(index) .. "] is missing icon")
        end
    end
end

local function validateSwitcher(widget, path, textMeasurer)
    assert(validateWidget ~= nil)
    if widget.id == nil then fail(path .. " is missing id") end
    if widget.align == nil or not validSwitcherAlign[widget.align] then
        fail(path .. " has invalid or missing align; expected top, center, or bottom")
    end
    if widget.initialChild == nil then fail(path .. " is missing initialChild") end
    if widget.children == nil then fail(path .. " is missing children") end
    if widget.children[widget.initialChild] == nil then
        fail(path .. " initialChild '" .. tostring(widget.initialChild) .. "' is not a child")
    end

    for childId, child in pairs(widget.children) do
        validateWidget(child, path .. ".children." .. tostring(childId), false, textMeasurer)
    end
end

validateWidget = function(widget, path, requireSlot, textMeasurer)
    if widget == nil then fail(path .. " is nil") end
    if widget.kind == "tileStack" then
        validateTileStack(widget, path)
    elseif widget.kind == "switcher" then
        validateSwitcher(widget, path, textMeasurer)
    else
        fail(path .. " has unknown kind '" .. tostring(widget.kind) .. "'")
    end

    if requireSlot then
        if widget.slot == nil then fail(path .. " is missing slot") end
        local slot = MenuLayout.defaults.slots[widget.slot]
        if slot == nil then fail(path .. " uses unknown slot '" .. tostring(widget.slot) .. "'") end
        local size = measureWidget(widget, textMeasurer)
        if size.width > slot.maxWidth or size.height > slot.maxHeight then
            fail(path .. " overflows slot '" .. tostring(widget.slot) .. "' (" ..
                tostring(size.width) .. "x" .. tostring(size.height) .. " > " ..
                tostring(slot.maxWidth) .. "x" .. tostring(slot.maxHeight) .. ")")
        end
    end
end

local function collectSwitchers(widget, switchers)
    if widget.kind == "switcher" then
        if switchers[widget.id] ~= nil then
            fail("duplicate switcher id '" .. tostring(widget.id) .. "'")
        end
        switchers[widget.id] = widget
        for _, child in pairs(widget.children or {}) do
            collectSwitchers(child, switchers)
        end
    end
end

local function validateMenuEvents(widget, path, switchers)
    if widget.kind == "tileStack" then
        for index, rawItem in ipairs(widget.items or {}) do
            local item = resolveActionItem(rawItem)
            local event = item.onSelect
            if event ~= nil then
                if event.type ~= "selectSwitcher" then
                    fail(path .. ".items[" .. tostring(index) .. "] has unknown menu event '" .. tostring(event.type) .. "'")
                end
                local switcher = switchers[event.switcher]
                if switcher == nil then
                    fail(path .. ".items[" .. tostring(index) .. "] references unknown switcher '" .. tostring(event.switcher) .. "'")
                end
                if switcher.children[event.child] == nil then
                    fail(path .. ".items[" .. tostring(index) .. "] references unknown switcher child '" .. tostring(event.child) .. "'")
                end
            end
        end
        return
    end

    if widget.kind == "switcher" then
        for childId, child in pairs(widget.children or {}) do
            validateMenuEvents(child, path .. ".children." .. tostring(childId), switchers)
        end
    end
end

function MenuLayout.validateMenu(menu, menuId, textMeasurer)
    if menu == nil then fail("menu '" .. tostring(menuId) .. "' is nil") end
    if menu.layout == nil then fail("menu '" .. tostring(menuId) .. "' is missing layout") end
    if menu.layout.widgets == nil then fail("menu '" .. tostring(menuId) .. "' layout is missing widgets") end

    local switchers = {}
    for index, widget in ipairs(menu.layout.widgets) do
        validateWidget(widget, "menu '" .. tostring(menuId) .. "'.layout.widgets[" .. tostring(index) .. "]", true, textMeasurer)
        collectSwitchers(widget, switchers)
    end
    for index, widget in ipairs(menu.layout.widgets) do
        validateMenuEvents(widget, "menu '" .. tostring(menuId) .. "'.layout.widgets[" .. tostring(index) .. "]", switchers)
    end
end

function MenuLayout.validateAll(manifests, textMeasurer)
    for menuId, menu in pairs(manifests or {}) do
        if type(menu) == "table" and menu.layout ~= nil then
            MenuLayout.validateMenu(menu, menuId, textMeasurer)
        end
    end
end

local function collectInitialStateFromWidget(widget, switchers)
    if widget.kind == "switcher" then
        switchers[widget.id] = widget.initialChild
        for _, child in pairs(widget.children or {}) do
            collectInitialStateFromWidget(child, switchers)
        end
    elseif widget.kind == "tileStack" then
        return
    end
end

function MenuLayout.createState(menu)
    local state = { switchers = {} }
    for _, widget in ipairs(menu.layout.widgets or {}) do
        collectInitialStateFromWidget(widget, state.switchers)
    end
    return state
end

local function isItemSelected(item, state)
    local onSelect = item.onSelect
    if onSelect == nil then return false end
    if onSelect.type == "selectSwitcher" then
        return state.switchers[onSelect.switcher] == onSelect.child
    end
    return false
end

local function addTile(plan, stackWidget, measuredTile, iconX, iconY, labelX, labelY, hitboxX, hitboxY, state, idPrefix)
    local item = measuredTile.item
    local itemId = tostring(getItemId(item))
    local selected = isItemSelected(item, state)
    local tileId = idPrefix .. "." .. itemId
    local iconPath = item.icon
    if selected and item.selectedIcon ~= nil then iconPath = item.selectedIcon end

    plan.tiles[#plan.tiles + 1] = {
        id = tileId,
        type = item.action ~= nil and "action" or "menuEvent",
        localX = iconX,
        localY = iconY,
        width = measuredTile.iconWidth,
        height = measuredTile.iconHeight,
        rectsPath = iconPath,
        label = item.label,
        description = item.description,
        selected = selected,
        onSelect = item.onSelect,
        action = item.action
    }

    if measuredTile.label.height > 0 then
        plan.texts[#plan.texts + 1] = {
            id = tileId .. ".label",
            kind = "label",
            localX = labelX,
            localY = labelY,
            text = tostring(item.label or ""),
            options = measuredTile.label.options,
            width = measuredTile.label.width,
            height = measuredTile.label.height
        }
    end

    plan.hitboxes[#plan.hitboxes + 1] = {
        id = tileId,
        localX = hitboxX,
        localY = hitboxY,
        width = measuredTile.width,
        height = measuredTile.height
    }
end

local function layoutVerticalTileStack(plan, widget, originX, originY, state, idPrefix, stack)
    local cursorTop = originY + stack.height / 2

    for _, tile in ipairs(stack.tiles) do
        local tileCenterY = cursorTop - tile.height / 2
        local iconY = cursorTop - tile.iconHeight / 2
        local labelY = cursorTop - tile.iconHeight - tile.labelGap - tile.label.height / 2

        addTile(
            plan,
            widget,
            tile,
            originX,
            iconY,
            originX,
            labelY,
            originX,
            tileCenterY,
            state,
            idPrefix
        )

        cursorTop = cursorTop - tile.height - stack.itemGap
    end
end

local function layoutHorizontalTileStack(plan, widget, originX, originY, state, idPrefix, stack)
    local cursorLeft = originX - stack.width / 2

    for _, tile in ipairs(stack.tiles) do
        local tileCenterX = cursorLeft + tile.width / 2
        local tileTop = originY + tile.height / 2
        local iconY = tileTop - tile.iconHeight / 2
        local labelY = tileTop - tile.iconHeight - tile.labelGap - tile.label.height / 2

        addTile(
            plan,
            widget,
            tile,
            tileCenterX,
            iconY,
            tileCenterX,
            labelY,
            tileCenterX,
            originY,
            state,
            idPrefix
        )

        cursorLeft = cursorLeft + tile.width + stack.itemGap
    end
end

local function layoutTileStack(plan, widget, originX, originY, state, idPrefix, textMeasurer)
    local stack = measureTileStackDetailed(widget, textMeasurer)
    local stackPrefix = idPrefix or widget.id

    if widget.direction == "horizontal" then
        layoutHorizontalTileStack(plan, widget, originX, originY, state, stackPrefix, stack)
    else
        layoutVerticalTileStack(plan, widget, originX, originY, state, stackPrefix, stack)
    end
end

local function layoutSwitcher(plan, widget, originX, originY, state, idPrefix, textMeasurer)
    assert(layoutWidget ~= nil)
    local activeChildId = state.switchers[widget.id] or widget.initialChild
    local child = widget.children and widget.children[activeChildId]
    if child == nil then return end

    local reservedSize = measureWidget(widget, textMeasurer)
    local childSize = measureWidget(child, textMeasurer)
    local childY = originY

    if widget.align == "top" then
        childY = originY + (reservedSize.height - childSize.height) / 2
    elseif widget.align == "bottom" then
        childY = originY - (reservedSize.height - childSize.height) / 2
    elseif widget.align == "center" then
        childY = originY
    end

    layoutWidget(plan, child, originX, childY, state, (idPrefix or widget.id) .. "." .. tostring(activeChildId), textMeasurer)
end

layoutWidget = function(plan, widget, originX, originY, state, idPrefix, textMeasurer)
    if widget.kind == "tileStack" then
        layoutTileStack(plan, widget, originX, originY, state, idPrefix or widget.id, textMeasurer)
    elseif widget.kind == "switcher" then
        layoutSwitcher(plan, widget, originX, originY, state, idPrefix or widget.id, textMeasurer)
    end
end

function MenuLayout.build(menu, state, textMeasurer)
    local plan = {
        tiles = {},
        texts = {},
        hitboxes = {},
        menuDistance = MenuLayout.defaults.menuDistance,
        hoverDistanceScale = MenuLayout.defaults.hoverDistanceScale,
        hoverDirectionLerp = MenuLayout.defaults.hoverDirectionLerp
    }

    for _, widget in ipairs(menu.layout.widgets or {}) do
        local slot = MenuLayout.defaults.slots[widget.slot]
        layoutWidget(plan, widget, slot.x, slot.y, state, widget.id, textMeasurer)
    end

    return plan
end
