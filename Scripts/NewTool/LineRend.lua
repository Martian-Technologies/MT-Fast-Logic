-- LineRend is a local, vector-only ShapeRenderable line renderer.
--
-- Retained lines:
--   local id = tool.LineRend.new(from, to, { color = color, thickness = 0.01 })
--   tool.LineRend.update(id, { to = newTo })
--   tool.LineRend.destroy(id)
--
-- Immediate lines:
--   tool.LineRend.draw(from, to, { color = color, thickness = 0.01 })
--
-- draw() submissions are visible until the next beginFrame(). NewTool calls
-- beginFrame() once per equipped-tool update, before it runs the selected tool
-- mode, so a mode keeps a line visible by submitting it once every update.

LineRend = {}

local line_uuid = sm.uuid.new("1364f63d-663f-4d50-b422-49d3a4ce2938")
local line_axis = sm.vec3.new(0, 1, 0)
local default_color = sm.color.new(1, 1, 1, 1)
local default_thickness = 0.01
local minimum_length = 0.0001

function LineRend.init(tool)
    tool.LineRend = {}
    local self = tool.LineRend

    local lines = {}
    local unusedIds = {}
    local nextId = 1
    local immediateLines = {}
    local effectPool = {}

    self.suspended = false

    local function acquireEffect()
        local effect = table.remove(effectPool)
        if effect == nil then
            effect = sm.effect.createEffect("ShapeRenderable")
            effect:setParameter("uuid", line_uuid)
        end
        return effect
    end

    local function releaseEffect(effect)
        if effect == nil then return end
        effect:stop()
        effectPool[#effectPool + 1] = effect
    end

    local function getId()
        if #unusedIds > 0 then
            return table.remove(unusedIds)
        end

        local id = nextId
        nextId = nextId + 1
        return id
    end

    local function isExpired(line, now)
        return line.expiresAt ~= nil and now >= line.expiresAt
    end

    local function syncLine(line)
        local delta = line.to - line.from
        local length = delta:length()

        if length < minimum_length then
            line.effect:stop()
            line.visible = false
            return false
        end

        local direction = delta:safeNormalize(line_axis)
        line.effect:setPosition(line.from + delta * 0.5)
        line.effect:setRotation(sm.vec3.getRotation(line_axis, direction))
        line.effect:setScale(sm.vec3.new(line.thickness, length, line.thickness))
        line.effect:setParameter("color", line.color)

        if not self.suspended then
            if not line.visible then
                line.effect:start()
            end
            line.visible = true
        else
            line.effect:stop()
            line.visible = false
        end
        return true
    end

    local function destroyLine(id)
        local line = lines[id]
        if line == nil then return false end

        releaseEffect(line.effect)
        lines[id] = nil
        unusedIds[#unusedIds + 1] = id
        return true
    end

    local function clearImmediate()
        for _, line in ipairs(immediateLines) do
            releaseEffect(line.effect)
        end
        immediateLines = {}
    end

    local function makeLine(from, to, options)
        assert(from ~= nil, "LineRend requires a from position")
        assert(to ~= nil, "LineRend requires a to position")

        options = options or {}
        return {
            from = from,
            to = to,
            color = options.color or default_color,
            thickness = options.thickness or default_thickness,
            effect = acquireEffect(),
            visible = false
        }
    end

    -- Creates a retained line. If lifetime is supplied, it is automatically
    -- destroyed after that many seconds; otherwise it lives until destroy().
    function self.new(from, to, options)
        options = options or {}
        local id = getId()
        local line = makeLine(from, to, options)
        local lifetime = options.lifetime
        if lifetime ~= nil then
            line.expiresAt = os.clock() + math.max(lifetime, 0)
        end

        lines[id] = line
        syncLine(line)
        return id
    end

    -- Updates a retained line. Supplying lifetime renews its expiry timer.
    -- Pass lifetime = false to make an expiring line persistent again.
    function self.update(id, changes)
        local line = lines[id]
        if line == nil then return false end

        changes = changes or {}
        if changes.from ~= nil then line.from = changes.from end
        if changes.to ~= nil then line.to = changes.to end
        if changes.color ~= nil then line.color = changes.color end
        if changes.thickness ~= nil then line.thickness = changes.thickness end
        if changes.lifetime == false then
            line.expiresAt = nil
        elseif changes.lifetime ~= nil then
            line.expiresAt = os.clock() + math.max(changes.lifetime, 0)
        end

        syncLine(line)
        return true
    end

    function self.destroy(id)
        return destroyLine(id)
    end

    -- Submits a line for the current immediate frame. It has no handle and is
    -- removed by the next beginFrame(), unless it is submitted again.
    function self.draw(from, to, options)
        if self.suspended then return nil end

        local line = makeLine(from, to, options)
        immediateLines[#immediateLines + 1] = line
        syncLine(line)
        return true
    end

    -- Creates a retained, self-cleaning line. It returns an optional handle so
    -- callers may still cancel it early with destroy().
    function self.flash(from, to, lifetime, options)
        local flashOptions = {}
        for key, value in pairs(options or {}) do
            flashOptions[key] = value
        end
        flashOptions.lifetime = lifetime or 0
        return self.new(from, to, flashOptions)
    end

    -- Called by the host before a new immediate-mode submission phase.
    function self.beginFrame()
        clearImmediate()
    end

    -- Removes expired retained lines. NewTool invokes this from client_onUpdate.
    function self.client_onUpdate(dt)
        local now = os.clock()
        local expired = {}
        for id, line in pairs(lines) do
            if isExpired(line, now) then
                expired[#expired + 1] = id
            end
        end
        for _, id in ipairs(expired) do
            destroyLine(id)
        end
    end

    -- Stops visuals while preserving retained line handles for a later resume.
    function self.suspend()
        if self.suspended then return end
        self.suspended = true
        clearImmediate()
        for _, line in pairs(lines) do
            line.effect:stop()
            line.visible = false
        end
    end

    function self.resume()
        if not self.suspended then return end
        self.suspended = false
        for _, line in pairs(lines) do
            syncLine(line)
        end
    end

    function self.clear()
        clearImmediate()
        local ids = {}
        for id in pairs(lines) do
            ids[#ids + 1] = id
        end
        for _, id in ipairs(ids) do
            destroyLine(id)
        end
    end
end
